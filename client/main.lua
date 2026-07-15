local spawnedVehicle = nil
local stage = 0
local STOP_COUNT = 5
local DELIVERIES_PER_STOP = Config.DeliveriesPerStop or 1

local deliverySites = {}
for i = 1, STOP_COUNT do
    deliverySites[i] = { props = {}, netIds = {}, delivered = 0, stopType = "mailbox", zoneName = nil, deliveryZoneName = nil }
end

local spawnedEntities = {}
local invitee = false
local ingroup = false
local jobSearchLocation = Config.job_search_zone
local MissionStarted = false
local missionid = ""
local missioncolumn = ""
local holdingMail = false
local heldMailObj = nil
local highlightedEntities = {}
local highlightVisibilityDistance = 30.0
local highlightMonitorActive = false
local whichmission = nil
local baseReputation = Config.BaseReputationReward
local missionLoopToken = 0
local clientActive = true
local blueHighlight = { r = 100, g = 180, b = 255, a = 255 }

local serverEntitiesReceived = false
local serverVanNetId = nil
local serverPropNetIds = {}
local serverStopTypes = {}
local missionBlip = nil
local partnerId = nil
local spawnedObjects = {}
local missionRouteStops = nil
local missionRawAreas = nil
local serverDeliveryAreas = nil
local missionUrgentStopIds = nil
local activeStopIndex = nil
local stopBlips = {}
local missionDepotCoords = nil
local sortPhaseDone = false
local routeMinigameDone = false
local vanLoadTargetAdded = false
local depotReturnZoneAdded = false
local Target = nil
local Notify = nil
local missionGuideToken = 0
local postmanResetting = false
local Postman_ResetMission

local Postman_RouteSolver = {}

local function Postman_RouteVec3(coords)
    return { x = coords.x, y = coords.y, z = coords.z or 0.0 }
end

function Postman_RouteSolver.Distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = (a.z or 0.0) - (b.z or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Postman_RouteSolver.RouteDistance(depot, stops, order)
    if not depot or not stops or not order or #order == 0 then
        return math.huge
    end

    local total = Postman_RouteSolver.Distance(depot, stops[order[1]])
    for i = 1, #order - 1 do
        total = total + Postman_RouteSolver.Distance(stops[order[i]], stops[order[i + 1]])
    end
    total = total + Postman_RouteSolver.Distance(stops[order[#order]], depot)
    return total
end

local function Postman_RouteCopyOrder(order)
    local copy = {}
    for i = 1, #order do
        copy[i] = order[i]
    end
    return copy
end

function Postman_RouteSolver.IsUrgentOrderValid(order, urgentIds)
    if not urgentIds or #urgentIds == 0 then
        return true
    end

    local urgentSet = {}
    for i = 1, #urgentIds do
        urgentSet[urgentIds[i]] = true
    end

    local maxUrgentPos = 0
    local minNormalPos = #order + 1

    for pos = 1, #order do
        local stopId = order[pos]
        if urgentSet[stopId] then
            if pos > maxUrgentPos then
                maxUrgentPos = pos
            end
        elseif pos < minNormalPos then
            minNormalPos = pos
        end
    end

    return maxUrgentPos < minNormalPos
end

function Postman_RouteSolver.SolveShortestRoute(depotCoords, stopCoordsList, urgentIds)
    local depot = Postman_RouteVec3(depotCoords)
    local stops = {}
    for i = 1, #stopCoordsList do
        stops[i] = Postman_RouteVec3(stopCoordsList[i])
    end

    local count = #stops
    if count == 0 then
        return {}, 0.0
    end

    local indices = {}
    for i = 1, count do
        indices[i] = i
    end

    local best = { dist = math.huge, order = {} }

    local function permute(arr, left)
        if left > count then
            if Postman_RouteSolver.IsUrgentOrderValid(arr, urgentIds) then
                local total = Postman_RouteSolver.RouteDistance(depot, stops, arr)
                if total < best.dist then
                    best.dist = total
                    best.order = Postman_RouteCopyOrder(arr)
                end
            end
            return
        end

        for i = left, count do
            arr[left], arr[i] = arr[i], arr[left]
            permute(arr, left + 1)
            arr[left], arr[i] = arr[i], arr[left]
        end
    end

    permute(indices, 1)
    return best.order, best.dist
end

function Postman_RouteSolver.IsOptimalRoute(depotCoords, stopCoordsList, playerOrder, tolerance, urgentIds)
    tolerance = tolerance or 1.0
    local _, optimalDist = Postman_RouteSolver.SolveShortestRoute(depotCoords, stopCoordsList, urgentIds)
    local stops = {}
    for i = 1, #stopCoordsList do
        stops[i] = Postman_RouteVec3(stopCoordsList[i])
    end
    local depot = Postman_RouteVec3(depotCoords)
    local playerDist = Postman_RouteSolver.RouteDistance(depot, stops, playerOrder)
    return math.abs(playerDist - optimalDist) <= tolerance, optimalDist, playerDist
end

function Postman_RouteSolver.ReorderStops(stops, order)
    local reordered = {}
    for i = 1, #order do
        reordered[i] = stops[order[i]]
    end
    return reordered
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then clientActive = false end
end)

local MISSION_IDS = { los_santos = true, sandy_shores = true, paleto_bay = true }
local MISSION_REGION_NAMES = {
    los_santos = "Los Santos",
    sandy_shores = "Sandy Shores",
    paleto_bay = "Paleto Bay",
}
local MAIL_ANIM_DICT = "mp_common"
local CARRY_ANIM_DICT = "anim@heists@box_carry@"
local PUTDOWN_ANIM_DICT = "pickup_object"
local PUTDOWN_ANIM_NAME = "putdown_low"
local MAIL_PROP = `prop_cs_documents_01`
local PACKAGE_PROP = `prop_cs_cardbox_01`
local NEWSPAPER_PROP = `prop_cs_r_business_card`

local function Postman_Debug(...)
    if not Config.Debug then return end
    local parts = { ... }
    local msg = ""
    for i, v in ipairs(parts) do
        msg = msg .. tostring(v) .. (i < #parts and " " or "")
    end
    print(("^3[nn_postman:debug]^7 %s"):format(msg))
end

local function Postman_SafeCanInteract(handler)
    return function(_entity, _distance, _data)
        local ok, result = pcall(handler)
        if not ok then
            Postman_Debug("^1canInteract error:^7", tostring(result))
            return false
        end
        return result == true
    end
end

local function Postman_SafeNetId(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return 0
    end
    return NetworkGetNetworkIdFromEntity(entity)
end

local function Postman_EntityDebugLabel(ent)
    if not ent or ent == 0 then return "nil" end
    if not DoesEntityExist(ent) then return ("invalid(%s)"):format(ent) end
    local netId = Postman_SafeNetId(ent)
    local model = GetEntityModel(ent)
    return ("ent=%s netId=%s model=%s"):format(ent, netId, model)
end

local function Postman_IsPlayerInMissionVan()
    local ped = PlayerPedId()
    if not spawnedVehicle or spawnedVehicle == 0 or not DoesEntityExist(spawnedVehicle) then
        return false
    end
    if IsPedInVehicle(ped, spawnedVehicle, false) then
        return true
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and veh == spawnedVehicle then
        return true
    end
    if veh ~= 0 and DoesEntityExist(veh) and DoesEntityExist(spawnedVehicle) then
        local a = Postman_SafeNetId(veh)
        local b = Postman_SafeNetId(spawnedVehicle)
        if a ~= 0 and a == b then
            return true
        end
    end
    return false
end

local function Postman_DumpMissionState(context)
    if not Config.Debug then return end
    local ped = PlayerPedId()
    local currentVeh = GetVehiclePedIsIn(ped, false)
    local lines = {
        ("--- postman state (%s) ---"):format(context or "?"),
        ("MissionStarted=%s stage=%s whichmission=%s"):format(tostring(MissionStarted), tostring(stage), tostring(whichmission)),
        ("missionid=%s column=%s invitee=%s ingroup=%s"):format(tostring(missionid), tostring(missioncolumn), tostring(invitee), tostring(ingroup)),
        ("spawnedVehicle: %s"):format(Postman_EntityDebugLabel(spawnedVehicle)),
        ("playerVehicle: %s"):format(Postman_EntityDebugLabel(currentVeh)),
        ("inMissionVan=%s holdingMail=%s sortPhaseDone=%s"):format(tostring(Postman_IsPlayerInMissionVan()), tostring(holdingMail), tostring(sortPhaseDone)),
        ("vanLoadTargetAdded=%s Target=%s Notify=%s"):format(tostring(vanLoadTargetAdded), tostring(Target ~= nil), tostring(Notify ~= nil)),
        ("serverEntitiesReceived=%s serverVanNetId=%s partnerId=%s"):format(tostring(serverEntitiesReceived), tostring(serverVanNetId), tostring(partnerId)),
        ("loopToken=%s missionLoopToken=%s"):format(tostring(missionLoopToken), tostring(missionLoopToken)),
    }
    if missionRouteStops and missionRouteStops[1] and missionRouteStops[1].coords then
        local c = missionRouteStops[1].coords
        lines[#lines + 1] = ("stop1 coords=%.2f, %.2f, %.2f type=%s"):format(c.x, c.y, c.z, tostring(missionRouteStops[1].stopType))
    end
    if currentVeh ~= 0 and spawnedVehicle and DoesEntityExist(spawnedVehicle) and currentVeh ~= spawnedVehicle then
        local dist = #(GetEntityCoords(currentVeh) - GetEntityCoords(spawnedVehicle))
        lines[#lines + 1] = ("^1WARNING: You may be in the WRONG van (dist to mission van=%.1fm)^7"):format(dist)
        lines[#lines + 1] = "Use the BLUE OUTLINED van spawned by the job, not a random parked boxville."
    end
    for _, line in ipairs(lines) do
        Postman_Debug(line)
    end
end

local function Postman_DebugVanEntryCheck()
    if not Config.Debug then return end
    local ped = PlayerPedId()
    local currentVeh = GetVehiclePedIsIn(ped, false)
    Postman_Debug("van entry check:",
        "IsPedInVehicle=", tostring(spawnedVehicle and IsPedInVehicle(ped, spawnedVehicle, false)),
        "GetVehiclePedIsIn=", currentVeh,
        "handlesMatch=", tostring(currentVeh ~= 0 and spawnedVehicle and currentVeh == spawnedVehicle))
    if currentVeh ~= 0 and spawnedVehicle and DoesEntityExist(spawnedVehicle) and DoesEntityExist(currentVeh) then
        local a = Postman_SafeNetId(currentVeh)
        local b = Postman_SafeNetId(spawnedVehicle)
        Postman_Debug("netId compare: player=", a, "mission=", b, "match=", tostring(a == b and a ~= 0))
    end
end

local function Postman_ShowHelp(text, durationMs)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentString(text)
    EndTextCommandDisplayHelp(0, false, true, durationMs or 5000)
end

local function Postman_Notify(msg, nType)
    if Notify and Notify.SendNotify then
        Notify.SendNotify(msg, nType or "inform", 6000)
    else
        Postman_ShowHelp(msg, 6000)
    end
end

local function Postman_GetCurrentStopIndex()
    if stage >= 2 and stage <= 10 and stage % 2 == 0 then
        return stage / 2
    end
    if stage >= 3 and stage <= 11 and stage % 2 == 1 then
        return (stage - 1) / 2
    end
    return nil
end

local function Postman_ToVec3(v)
    return vector3(v.x, v.y, v.z)
end

local function Postman_SnapToGround(coords)
    if not coords then return coords end
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 50.0, false)
    if found then
        return vector4(coords.x, coords.y, groundZ + 0.08, coords.w or 0.0)
    end
    return coords
end

local function Postman_GetActiveMissionAreas(missionConfig)
    if missionRawAreas then
        return missionRawAreas
    end
    return Postman_GetRawMissionAreas(missionConfig)
end

local function Postman_RandomizeMissionStops(regionId)
    local pool = Config.RegionStopPools and Config.RegionStopPools[regionId]
    if not pool or #pool < STOP_COUNT then
        return false
    end

    missionRawAreas = Postman_PickChallengingMissionStops(pool, STOP_COUNT, Config.depotVanCoords)
    Postman_Debug(
        "Challenging mission stops:",
        STOP_COUNT,
        "picked from",
        #pool,
        "pool points in",
        regionId
    )
    return true
end

local function Postman_IsUrgentStopId(stopId)
    if not missionUrgentStopIds then
        return false
    end
    for i = 1, #missionUrgentStopIds do
        if missionUrgentStopIds[i] == stopId then
            return true
        end
    end
    return false
end

local function Postman_GetUrgentStopLabels()
    if not missionUrgentStopIds or #missionUrgentStopIds == 0 then
        return ""
    end

    local labels = {}
    for i = 1, #missionUrgentStopIds do
        labels[i] = string.char(64 + missionUrgentStopIds[i])
    end
    return table.concat(labels, ", ")
end

local function Postman_PickUrgentStopIds()
    local cfg = Config.RouteMinigame or {}
    local minUrgent = math.max(1, cfg.urgentMin or 1)
    local maxUrgent = math.min(STOP_COUNT - 1, cfg.urgentMax or 2)
    if maxUrgent < minUrgent then
        maxUrgent = minUrgent
    end

    local urgentCount = math.random(minUrgent, maxUrgent)
    local pool = {}
    for i = 1, STOP_COUNT do
        pool[i] = i
    end

    for i = STOP_COUNT, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    missionUrgentStopIds = {}
    for i = 1, urgentCount do
        missionUrgentStopIds[i] = pool[i]
    end

    table.sort(missionUrgentStopIds)
    Postman_Debug("Urgent mail stops:", Postman_GetUrgentStopLabels())
    return missionUrgentStopIds
end

local function Postman_GetRawMissionAreas(missionConfig)
    return {
        missionConfig.deliveryArea,
        missionConfig.deliveryArea1,
        missionConfig.deliveryArea2,
        missionConfig.deliveryArea3,
        missionConfig.deliveryArea4,
    }
end

local function Postman_ResolveStopCoords(coords, snapGround)
    if not coords then return coords end
    if snapGround then
        return Postman_SnapToGround(coords)
    end
    return vector4(coords.x, coords.y, coords.z, coords.w or 0.0)
end

local function Postman_WaitForTarget(timeoutMs)
    timeoutMs = timeoutMs or 15000
    local deadline = GetGameTimer() + timeoutMs
    while not Target and GetGameTimer() < deadline do Wait(100) end
    return Target ~= nil
end

local function Postman_AllStopsComplete()
    for i = 1, STOP_COUNT do
        if (deliverySites[i].delivered or 0) < DELIVERIES_PER_STOP then
            return false
        end
    end
    return true
end

local function Postman_GetMissionVan()
    if spawnedVehicle and spawnedVehicle ~= 0 and DoesEntityExist(spawnedVehicle) then
        return spawnedVehicle
    end
    if serverVanNetId and serverVanNetId ~= 0 then
        local ent = Postman_WaitForNetEntity(serverVanNetId, 500)
        if ent then
            spawnedVehicle = ent
            return ent
        end
    end
    local netId = spawnedObjects["spawnedVehicle"]
    if netId and netId ~= 0 and NetworkDoesNetworkIdExist(netId) then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            spawnedVehicle = ent
            return ent
        end
    end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if GetEntityModel(veh) == joaat(Config.PostVanModel or "boxville2") then
            spawnedVehicle = veh
            return veh
        end
    end
    local vanModel = joaat(Config.PostVanModel or "boxville2")
    local pCoords = GetEntityCoords(ped)
    for _, veh in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(veh) and GetEntityModel(veh) == vanModel and #(GetEntityCoords(veh) - pCoords) < 80.0 then
            spawnedVehicle = veh
            return veh
        end
    end
    return nil
end

local function Postman_IsNearDepot(coords, radius)
    radius = radius or (Config.DepotReturnRadius or 18.0)
    if missionDepotCoords then
        local depot = Postman_ToVec3(missionDepotCoords)
        if #(coords - depot) <= radius then return true end
    end
    if #(coords - jobSearchLocation) <= radius then return true end
    return false
end

local function Postman_CanReturnToDepot()
    if not MissionStarted or not Postman_AllStopsComplete() then return false end
    if stage >= 12 then return true end
    if stage == 11 and sortPhaseDone then return true end
    return false
end

local function Postman_CompleteMissionReturn()
    if not MissionStarted then return false end
    Postman_Notify("~g~Route complete!~s~ Thanks for delivering the mail.", "success")
    Postman_ShowHelp("~g~Mission complete — payment sent.", 5000)
    local ok, gInfo = pcall(function() return exports.nn_postman:GetGroupInfo() end)
    if ok and gInfo and gInfo.currentInvitedPlayer then
        TriggerServerEvent("postman:server:notifyMissionComplete", gInfo.currentInvitedPlayer.id, missioncolumn, missionid)
    else
        local rewardTable = Config.MissionRewards[missionid]
        local reward = rewardTable and rewardTable[tostring(missioncolumn)] or 0
        TriggerEvent("mission:giveCashReward", true, reward, baseReputation)
        Postman_ResetMission()
    end
    return true
end

local function Postman_TryCompleteDepotReturn()
    if not Postman_CanReturnToDepot() then
        if MissionStarted and Postman_AllStopsComplete() and stage == 11 and not sortPhaseDone then
            Postman_Notify("Target the ~b~van~s~ → ~y~Sort Route Satchel~s~ before finishing.", "error")
        elseif MissionStarted and not Postman_AllStopsComplete() then
            Postman_Notify("Finish all ~b~5 mail stops~s~ before returning the van.", "error")
        end
        return false
    end

    local van = Postman_GetMissionVan()
    local checkCoords = van and GetEntityCoords(van) or GetEntityCoords(PlayerPedId())
    if not Postman_IsNearDepot(checkCoords) then
        Postman_Notify("Park the van at the ~b~GO Postal depot~s~ (job board area).", "error")
        return false
    end

    return Postman_CompleteMissionReturn()
end

local function Postman_RemoveDepotReturnZone()
    if depotReturnZoneAdded then
        Postman_RemoveBoxZone("postman_depot_return_active")
        depotReturnZoneAdded = false
    end
end

local function Postman_AddDepotReturnZone()
    if depotReturnZoneAdded or not Target then return end
    depotReturnZoneAdded = true
    local depot = jobSearchLocation
    AddTargetBoxZone("postman_depot_return_active", depot, 10.0, 10.0, {
        heading = 0,
        minZ = depot.z - 2.0,
        maxZ = depot.z + 3.0,
    }, {
        options = {
            {
                icon = "fas fa-warehouse",
                label = "Return Van & Complete Route",
                canInteract = Postman_SafeCanInteract(function()
                    return MissionStarted and Postman_CanReturnToDepot()
                end),
                action = function()
                    Postman_TryCompleteDepotReturn()
                end,
            },
        },
        distance = 8.0,
    })
end

local function Postman_LoadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function Postman_TargetOptsToBridge(wrapper)
    local bridgeOptions = {}
    local dist = wrapper.distance or 2.5
    for _, opt in ipairs(wrapper.options or {}) do
        local canInteract = opt.canInteract
        if type(canInteract) == 'function' then
            canInteract = Postman_SafeCanInteract(canInteract)
        end
        table.insert(bridgeOptions, {
            icon = opt.icon,
            label = opt.label,
            onSelect = opt.action,
            canInteract = canInteract,
            distance = dist,
        })
    end
    return bridgeOptions
end

local function Postman_GetRoutesForMission(missionId, inGroup, isInvitee)
    if missionId == "los_santos" then
        return (inGroup and isInvitee) and Config.MissionRoutesLosSantosInvitee or Config.MissionRoutesLosSantos
    end
    if missionId == "sandy_shores" then return Config.MissionRoutesSandyShores end
    if missionId == "paleto_bay" then return Config.MissionRoutesPaletoBay end
    return nil
end

local function Postman_StringHash(s)
    local h = 0
    for i = 1, #s do h = (h * 131 + string.byte(s, i)) % 1000003 end
    return h
end

local function Postman_GetVanEngineAudio()
    local fixed = Config.PostVanEngineAudio
    if type(fixed) == "string" and fixed ~= "" then return fixed end
    local list = Config.PostVanEngineAudioCandidates or { "BISON" }
    local key = whichmission or (tostring(missioncolumn) .. "_" .. tostring(missionid))
    return list[(Postman_StringHash(key) % #list) + 1]
end

local function Postman_ApplyVanEngineAudio(vehicle)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        pcall(function() ForceVehicleEngineAudio(vehicle, Postman_GetVanEngineAudio()) end)
    end
end

local function Postman_DeleteMissionVan()
    local veh = spawnedVehicle
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local ped = PlayerPedId()
    if IsPedInVehicle(ped, veh, false) then
        TaskLeaveVehicle(ped, veh, 16)
        local leaveBy = GetGameTimer() + 3000
        while IsPedInVehicle(ped, veh, false) and GetGameTimer() < leaveBy do Wait(0) end
    end
    if DoesEntityExist(veh) then
        NetworkRequestControlOfEntity(veh)
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end
end

local function Postman_WaitForNetEntity(netId, timeoutMs)
    timeoutMs = timeoutMs or 10000
    local start = GetGameTimer()
    while (GetGameTimer() - start) < timeoutMs do
        if NetworkDoesNetworkIdExist(netId) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
        end
        Wait(50)
    end
    return nil
end

function SendReactMessage(action, data)
    SendNUIMessage({ action = action, data = data })
end

function NotifyMissionStarted(col, id)
    closeUI()
    SendReactMessage('missionStatusChanged', {
        inMission = true,
        currentMissionId = id,
        currentMissionColumn = col,
        isInvitee = invitee
    })
end

function NotifyMissionFailed(reason)
    SendReactMessage('missionError', { message = reason or "Failed to start mission." })
    SendReactMessage('missionStatusChanged', { inMission = false, currentMissionId = "", currentMissionColumn = "" })
    MissionStarted = false
    missionid = ""
    missioncolumn = ""
end

CreateThread(function()
    Wait(1000)
    while not exports['community_bridge']:Bridge() do Wait(100) end
    Target = exports['community_bridge']:Target()
    Notify = exports['community_bridge']:Notify()
    Postman_Debug("Community Bridge ready — Target=", Target ~= nil, "Notify=", Notify ~= nil)
end)

function AddTargetToEntity(entity, options)
    if Target then Target.AddLocalEntity(entity, Postman_TargetOptsToBridge(options)) end
end

function Postman_RemoveTargetFromEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    pcall(function() if Target and Target.RemoveLocalEntity then Target.RemoveLocalEntity(entity) end end)
    pcall(function() exports["qb-target"]:RemoveTargetEntity(entity) end)
    pcall(function() exports.ox_target:removeLocalEntity(entity) end)
end

function AddTargetBoxZone(name, coords, length, width, zoneOptions, targetOptions)
    if not Target then return end
    local minZ = zoneOptions.minZ or (coords.z - 1)
    local maxZ = zoneOptions.maxZ or (coords.z + 1)
    Target.AddBoxZone(name, coords, vector3(length, width, maxZ - minZ), zoneOptions.heading or 0, Postman_TargetOptsToBridge(targetOptions))
end

function Postman_RemoveBoxZone(name)
    pcall(function() if Target and Target.RemoveZone then Target.RemoveZone(name) end end)
    pcall(function() exports["qb-target"]:RemoveZone(name) end)
    pcall(function() exports.ox_target:removeZone(name) end)
end

function AddEntityHighlight(entity, color)
    if DoesEntityExist(entity) then
        table.insert(highlightedEntities, { entity = entity, color = color, visible = false })
        StartHighlightMonitor()
    end
end

function RemoveEntityHighlight(entity)
    if DoesEntityExist(entity) then SetEntityDrawOutline(entity, false) end
    for i = #highlightedEntities, 1, -1 do
        if highlightedEntities[i].entity == entity then table.remove(highlightedEntities, i) end
    end
end

function RemoveAllHighlights()
    for _, data in ipairs(highlightedEntities) do
        if DoesEntityExist(data.entity) then SetEntityDrawOutline(data.entity, false) end
    end
    highlightedEntities = {}
end

function StartHighlightMonitor()
    if highlightMonitorActive then return end
    highlightMonitorActive = true
    CreateThread(function()
        while highlightMonitorActive and #highlightedEntities > 0 do
            local playerCoords = GetEntityCoords(PlayerPedId())
            for i = #highlightedEntities, 1, -1 do
                local data = highlightedEntities[i]
                if DoesEntityExist(data.entity) then
                    local dist = #(playerCoords - GetEntityCoords(data.entity))
                    if dist <= highlightVisibilityDistance then
                        if not data.visible then
                            SetEntityDrawOutline(data.entity, true)
                            SetEntityDrawOutlineColor(data.color.r, data.color.g, data.color.b, data.color.a)
                            SetEntityDrawOutlineShader(1)
                            data.visible = true
                        end
                    elseif data.visible then
                        SetEntityDrawOutline(data.entity, false)
                        data.visible = false
                    end
                else
                    table.remove(highlightedEntities, i)
                end
            end
            Wait(250)
        end
        highlightMonitorActive = false
    end)
end

local PROP_MODELS = {
    mailbox = `prop_letterbox_01`,
    package = `prop_cs_cardbox_01`,
    cluster = `prop_letterbox_02`,
    registered = `prop_notepad_01`,
    newspaper = `prop_cs_newspaper`,
}

local function Postman_TryResolveStopPropAsync(siteIdx, slot, netId)
    CreateThread(function()
        if not netId or netId == 0 then return end
        local ent = Postman_WaitForNetEntity(netId, 3000)
        if not ent or not MissionStarted then return end
        local site = deliverySites[siteIdx]
        if not site then return end
        site.props[slot] = ent
        table.insert(spawnedEntities, ent)
        AddEntityHighlight(ent, blueHighlight)
        Postman_Debug("Prop resolved async stop=", siteIdx, "slot=", slot)
    end)
end

local function Postman_ClearStopProp(siteIdx)
    local site = deliverySites[siteIdx]
    if not site or not site.props then return end
    for i, obj in pairs(site.props) do
        if obj and DoesEntityExist(obj) then
            RemoveEntityHighlight(obj)
            DeleteEntity(obj)
        end
        site.props[i] = nil
    end
end

local function Postman_SpawnClientStopProp(siteIdx, coords, stopType)
    if Config.SpawnDeliveryProps == false then return end
    -- Always spawn a mailbox so every stop has a visible landmark on the street.
    local model = PROP_MODELS.mailbox
    CreateThread(function()
        RequestModel(model)
        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(10) end
        if not HasModelLoaded(model) or not MissionStarted then return end
        local site = deliverySites[siteIdx]
        if not site or site.props[1] then return end
        local obj = CreateObject(model, coords.x, coords.y, coords.z + 0.05, false, false, false)
        if obj and obj ~= 0 and DoesEntityExist(obj) then
            SetEntityHeading(obj, coords.w or 0.0)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            site.props[1] = obj
            table.insert(spawnedEntities, obj)
            AddEntityHighlight(obj, blueHighlight)
            Postman_Debug("Client prop spawned stop=", siteIdx, stopType)
        end
        SetModelAsNoLongerNeeded(model)
    end)
end

local function Postman_GetMailPropForType(stopType)
    if stopType == "package" then return PACKAGE_PROP end
    if stopType == "newspaper" then return NEWSPAPER_PROP end
    return MAIL_PROP
end

local function Postman_ClearHeldMail()
    if heldMailObj and DoesEntityExist(heldMailObj) then DeleteEntity(heldMailObj) end
    heldMailObj = nil
    holdingMail = false
    ClearPedTasks(PlayerPedId())
end

local function Postman_GrabMailFromVan(stopType)
    if holdingMail then
        Postman_ShowHelp("~y~Deliver what you're carrying first.", 3000)
        return false
    end
    local ped = PlayerPedId()
    local propModel = Postman_GetMailPropForType(stopType)
    Postman_Debug("GrabMailFromVan start, stopType=", stopType, "prop=", propModel)

    RequestModel(propModel)
    local modelDeadline = GetGameTimer() + 5000
    while not HasModelLoaded(propModel) and GetGameTimer() < modelDeadline do Wait(10) end
    if not HasModelLoaded(propModel) then
        Postman_Debug("^1GrabMailFromVan: prop model failed to load^7", propModel)
        Postman_Notify("~r~Could not load mail prop — try again.", "error")
        return false
    end

    if stopType == "package" then
        Postman_LoadAnim("anim@heists@box_carry@")
        TaskPlayAnim(ped, "anim@heists@box_carry@", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        Postman_LoadAnim(MAIL_ANIM_DICT)
        TaskPlayAnim(ped, MAIL_ANIM_DICT, "givetake1_a", 8.0, -8.0, 1500, 49, 0, false, false, false)
        Wait(1500)
    end

    local bone = GetPedBoneIndex(ped, stopType == "package" and 60309 or 57005)
    local obj = CreateObject(propModel, 0.0, 0.0, 0.0, true, true, false)
    if not obj or obj == 0 or not DoesEntityExist(obj) then
        Postman_Debug("^1GrabMailFromVan: CreateObject failed^7")
        Postman_Notify("~r~Could not pick up mail — try again.", "error")
        return false
    end

    AttachEntityToEntity(obj, ped, bone,
        stopType == "package" and 0.025 or 0.12,
        stopType == "package" and 0.08 or 0.0,
        stopType == "package" and 0.255 or -0.03,
        stopType == "package" and -145.0 or 0.0,
        stopType == "package" and 290.0 or 0.0,
        stopType == "package" and 0.0 or 0.0,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(propModel)
    heldMailObj = obj
    holdingMail = true
    table.insert(spawnedEntities, obj)

    local stopIdx = Postman_GetCurrentStopIndex() or 1
    local label = Config.StopTypeLabels[stopType] or "Deliver mail"
    Postman_Notify("Mail picked up! Go to ~b~Stop " .. stopIdx .. "~s~ and use target → ~y~" .. label .. "~s~.", "success")
    Postman_ShowHelp("~g~Mail in hand~s~ — walk to the ~b~blue delivery zone~s~ at the GPS marker.", 6000)
    Postman_Debug("GrabMailFromVan OK, holdingMail=true stopIdx=", stopIdx)
    return true
end

local function Postman_PlaceHeldPackageOnGround(dropCoords)
    if not heldMailObj or not DoesEntityExist(heldMailObj) then return nil end

    local ped = PlayerPedId()
    local box = heldMailObj
    DetachEntity(box, true, true)

    if dropCoords then
        SetEntityCoords(box, dropCoords.x, dropCoords.y, dropCoords.z, false, false, false, false)
        SetEntityHeading(box, dropCoords.w or GetEntityHeading(ped))
    else
        local ahead = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.55, -0.9)
        SetEntityCoords(box, ahead.x, ahead.y, ahead.z, false, false, false, false)
        SetEntityHeading(box, GetEntityHeading(ped))
    end

    PlaceObjectOnGroundProperly(box)
    FreezeEntityPosition(box, true)
    heldMailObj = nil
    holdingMail = false
    return box
end

local function Postman_PlayPackagePutDownAnim(dropCoords, slow)
    local ped = PlayerPedId()
    local animSpeed = slow and 0.4 or 1.0
    local detachProgress = slow and 0.62 or 0.52
    local maxWait = slow and 6000 or 2800

    if dropCoords then
        TaskTurnPedToFaceCoord(ped, dropCoords.x, dropCoords.y, dropCoords.z, 600)
        Wait(600)
    end

    if IsEntityPlayingAnim(ped, CARRY_ANIM_DICT, "idle", 3) then
        StopAnimTask(ped, CARRY_ANIM_DICT, "idle", 2.0)
        Wait(250)
    else
        ClearPedSecondaryTask(ped)
        Wait(100)
    end

    Postman_LoadAnim(PUTDOWN_ANIM_DICT)
    TaskPlayAnim(ped, PUTDOWN_ANIM_DICT, PUTDOWN_ANIM_NAME, 8.0, -8.0, -1, 0, 0.0, false, false, false)

    if slow then
        Wait(150)
        SetEntityAnimSpeed(ped, PUTDOWN_ANIM_DICT, PUTDOWN_ANIM_NAME, animSpeed)
    end

    Postman_Debug("Package put-down anim started:", PUTDOWN_ANIM_DICT, PUTDOWN_ANIM_NAME, "slow=", slow)

    local start = GetGameTimer()
    local placedBox = nil
    while (IsEntityPlayingAnim(ped, PUTDOWN_ANIM_DICT, PUTDOWN_ANIM_NAME, 3) or (GetGameTimer() - start) < 350)
        and (GetGameTimer() - start) < maxWait do
        if not placedBox and heldMailObj and DoesEntityExist(heldMailObj) then
            local animTime = GetEntityAnimCurrentTime(ped, PUTDOWN_ANIM_DICT, PUTDOWN_ANIM_NAME)
            if animTime >= detachProgress then
                placedBox = Postman_PlaceHeldPackageOnGround(dropCoords)
            end
        end

        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        Wait(0)
    end

    if not IsEntityPlayingAnim(ped, PUTDOWN_ANIM_DICT, PUTDOWN_ANIM_NAME, 3) and not placedBox then
        Postman_Debug("^1Package put-down anim did not play — placing box anyway^7")
    end

    ClearPedTasks(ped)

    if not placedBox and heldMailObj and DoesEntityExist(heldMailObj) then
        placedBox = Postman_PlaceHeldPackageOnGround(dropCoords)
    end

    return placedBox
end

local function Postman_PlayDeliveryAnim(stopType)
    local ped = PlayerPedId()
    if stopType == "door_knock" then
        Postman_LoadAnim("timetable@jimmy@doorknock@")
        TaskPlayAnim(ped, "timetable@jimmy@doorknock@", "knockdoor_idle", 8.0, -8.0, 2500, 49, 0, false, false, false)
        Wait(2500)
        Postman_LoadAnim(MAIL_ANIM_DICT)
        TaskPlayAnim(ped, MAIL_ANIM_DICT, "givetake2_a", 8.0, -8.0, 2000, 49, 0, false, false, false)
        Wait(2000)
    elseif stopType == "registered" then
        Postman_LoadAnim("missheistdockssetup1clipboard@base")
        TaskPlayAnim(ped, "missheistdockssetup1clipboard@base", "base", 8.0, -8.0, 3500, 49, 0, false, false, false)
        Wait(3500)
    elseif stopType == "newspaper" then
        Postman_LoadAnim("weapons@projectile@")
        TaskPlayAnim(ped, "weapons@projectile@", "throw_l_fb_stand", 8.0, -8.0, 1200, 49, 0, false, false, false)
        Wait(1200)
    elseif stopType == "dog_yard" then
        Postman_ShowHelp("~y~The dog is barking... stay calm.", 3000)
        Wait(3000)
        Postman_LoadAnim(MAIL_ANIM_DICT)
        TaskPlayAnim(ped, MAIL_ANIM_DICT, "givetake1_a", 8.0, -8.0, 1500, 49, 0, false, false, false)
        Wait(1500)
    elseif stopType == "cluster" then
        Postman_LoadAnim(MAIL_ANIM_DICT)
        TaskPlayAnim(ped, MAIL_ANIM_DICT, "givetake1_a", 8.0, -8.0, 1200, 49, 0, false, false, false)
        Wait(1200)
    elseif stopType == "package" then
        local stopIdx = Postman_GetDeliveryStopIndex()
        local dropCoords = stopIdx and deliverySites[stopIdx] and deliverySites[stopIdx].outdoorCoords
        Postman_PlayPackagePutDownAnim(dropCoords, false)
    else
        Postman_LoadAnim(MAIL_ANIM_DICT)
        TaskPlayAnim(ped, MAIL_ANIM_DICT, "givetake1_a", 8.0, -8.0, 1200, 49, 0, false, false, false)
        Wait(1200)
    end
end

local function Postman_OnDeliveryComplete(siteIdx)
    local site = deliverySites[siteIdx]
    site.delivered = site.delivered + 1
    Postman_ClearHeldMail()

    if partnerId and ingroup then
        TriggerServerEvent('postman:server:StopDelivered', partnerId, siteIdx, site.delivered)
    end

    if site.delivered >= DELIVERIES_PER_STOP then
        Postman_Notify("Stop complete! Target the ~b~van~s~ → ~y~Sort Route Satchel~s~.", "success")
        Postman_ShowHelp("~g~Stop complete! Sort your satchel at the van.", 4000)
        if partnerId then TriggerServerEvent("postman:server:sendPartnerStage", partnerId, stage + 1) end
        stage = stage + 1
        sortPhaseDone = false
        if siteIdx >= STOP_COUNT and Postman_AllStopsComplete() then
            Postman_Notify("Last stop done — ~y~sort at the van~s~, then return to ~b~GO Postal~s~.", "inform")
        end
    elseif DELIVERIES_PER_STOP > 1 then
        Postman_Notify("Delivered! Grab one more from the ~b~van~s~.", "inform")
        Postman_ShowHelp("~b~One more delivery at this stop.", 3000)
    end
end

local function Postman_RunDeliveryAtStop(siteIdx)
    if not holdingMail then
        Postman_Notify("Grab mail from the ~b~van~s~ first.", "error")
        return
    end
    local site = deliverySites[siteIdx]
    if not site or (site.delivered or 0) >= DELIVERIES_PER_STOP then return end
    if stage ~= siteIdx * 2 then
        Postman_Notify("Finish the current stop first.", "error")
        Postman_Debug("Delivery blocked: stage=", stage, "expected=", siteIdx * 2)
        return
    end

    local stopType = site.stopType
    Postman_Debug("RunDeliveryAtStop", siteIdx, stopType)
    Postman_ShowHelp(Config.StopTypeHints[stopType] or "~b~Deliver the mail.", 3000)
    Postman_PlayDeliveryAnim(stopType)
    Postman_OnDeliveryComplete(siteIdx)
end

local function Postman_AddStopDeliveryZone(siteIdx, coords, stopType)
    if not coords then
        Postman_Debug("^1AddStopDeliveryZone skipped site^7", siteIdx, "nil coords")
        return false
    end
    if not Target and not Postman_WaitForTarget(10000) then
        Postman_Debug("^1AddStopDeliveryZone skipped site^7", siteIdx, "Target unavailable")
        return false
    end

    local site = deliverySites[siteIdx]
    site.outdoorCoords = coords
    local zoneName = ("postman_deliver_%d_%s"):format(siteIdx, whichmission or "x")
    if site.deliveryZoneName and site.deliveryZoneName ~= zoneName then
        Postman_RemoveBoxZone(site.deliveryZoneName)
    end
    site.deliveryZoneName = zoneName
    local label = Config.StopTypeLabels[stopType] or "Deliver Mail"
    local zoneSize = Config.DeliveryZoneSize or 5.0
    local zoneDist = Config.DeliveryZoneDistance or 6.0

    Postman_Debug("AddStopDeliveryZone", siteIdx, stopType, "at", coords.x, coords.y, coords.z)

    AddTargetBoxZone(zoneName, Postman_ToVec3(coords), zoneSize, zoneSize, {
        heading = coords.w or 0,
        minZ = coords.z - 2.0,
        maxZ = coords.z + 3.0,
    }, {
        options = {
            {
                icon = "fas fa-envelope",
                label = label,
                canInteract = Postman_SafeCanInteract(function()
                    if stage ~= siteIdx * 2 then return false end
                    return (site.delivered or 0) < DELIVERIES_PER_STOP
                end),
                action = function()
                    CreateThread(function()
                        if not holdingMail then
                            Postman_Notify("Grab mail from the ~b~van~s~ first → ~y~Grab Mail from Van~s~.", "error")
                            return
                        end
                        Postman_RunDeliveryAtStop(siteIdx)
                    end)
                end,
            },
        },
        distance = zoneDist,
    })
    return true
end

local function Postman_GetDeliveryStopIndex()
    if stage >= 2 and stage <= 10 and stage % 2 == 0 then
        return stage / 2
    end
    return nil
end

local function Postman_ClearStopBlips()
    for i, blip in pairs(stopBlips) do
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
        stopBlips[i] = nil
    end
end

local function Postman_SetStopBlip(siteIdx, coords)
    Postman_ClearStopBlips()
    if not coords then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 480)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.95)
    SetBlipAsShortRange(blip, false)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(("Mail Stop %d"):format(siteIdx))
    EndTextCommandSetBlipName(blip)
    stopBlips[siteIdx] = blip
end

local function Postman_DeactivateStop(siteIdx)
    local site = deliverySites[siteIdx]
    if not site then return end
    if site.deliveryZoneName then
        Postman_RemoveBoxZone(site.deliveryZoneName)
        site.deliveryZoneName = nil
    end
    Postman_ClearStopProp(siteIdx)
    site.activated = false
    site.activatedSnap = nil
    site.outdoorCoords = nil
end

local function Postman_ActivateStop(siteIdx, snapGround, force)
    if not missionRawAreas or not missionRawAreas[siteIdx] then return false end

    local site = deliverySites[siteIdx]
    local raw = missionRawAreas[siteIdx]
    local coords = Postman_ResolveStopCoords(raw, snapGround)

    if not force and site.activated and site.activatedSnap == snapGround then
        site.outdoorCoords = coords
        return true
    end

    if site.deliveryZoneName then
        Postman_RemoveBoxZone(site.deliveryZoneName)
        site.deliveryZoneName = nil
    end
    Postman_ClearStopProp(siteIdx)

    local stopType = site.stopType or "mailbox"
    if not Postman_AddStopDeliveryZone(siteIdx, coords, stopType) then
        Postman_Debug("^1ActivateStop failed to add zone^7", siteIdx)
        return false
    end
    Postman_SpawnClientStopProp(siteIdx, coords, stopType)

    site.activated = true
    site.activatedSnap = snapGround
    activeStopIndex = siteIdx
    if missionRouteStops and missionRouteStops[siteIdx] then
        missionRouteStops[siteIdx].coords = coords
    end
    Postman_Debug("ActivateStop", siteIdx, "snapGround=", snapGround, "force=", force, coords.x, coords.y, coords.z)
    return true
end

local function Postman_TransitionToStop(siteIdx)
    if not missionRawAreas or not missionRawAreas[siteIdx] then
        Postman_Debug("^1TransitionToStop: missing raw coords for stop^7", siteIdx)
        return false
    end

    for i = 1, STOP_COUNT do
        if i ~= siteIdx then Postman_DeactivateStop(i) end
    end

    local raw = missionRawAreas[siteIdx]
    local pedCoords = GetEntityCoords(PlayerPedId())
    local dist = #(pedCoords - vector3(raw.x, raw.y, raw.z))
    local snap = dist < 150.0

    if not Postman_ActivateStop(siteIdx, snap, true) then
        Postman_ActivateStop(siteIdx, false, true)
    end

    local c = deliverySites[siteIdx].outdoorCoords or Postman_ResolveStopCoords(raw, false)
    SetWaypointToLocaltion(c)
    Postman_SetStopBlip(siteIdx, c)
    if partnerId then
        TriggerServerEvent("postman:server:setPartnerWaypoint", partnerId, Postman_ToVec3(c))
    end
    if missionRouteStops and missionRouteStops[siteIdx] then
        missionRouteStops[siteIdx].coords = c
    end

    local stopType = (missionRouteStops and missionRouteStops[siteIdx] and missionRouteStops[siteIdx].stopType)
        or deliverySites[siteIdx].stopType
        or "mailbox"
    Postman_Notify(("~b~Stop %d~s~ ready — look for the ~b~mailbox~s~ and blue marker on the street."):format(siteIdx), "success")
    if deliverySites[siteIdx] and deliverySites[siteIdx].urgent then
        Postman_ShowHelp("~r~URGENT MAIL~s~ — deliver this stop before regular mail.", 5000)
    else
        Postman_ShowHelp("~b~Stop " .. siteIdx .. ":~s~ " .. (Config.StopTypeLabels[stopType] or "Deliver mail"), 6000)
    end
    Postman_Debug("TransitionToStop", siteIdx, c.x, c.y, c.z)
    return true
end

local function Postman_AddDeliveryTarget(entity, siteIdx, slotIndex)
    local site = deliverySites[siteIdx]
    local stopType = site.stopType
    local label = Config.StopTypeLabels[stopType] or "Deliver Mail"

    AddTargetToEntity(entity, {
        options = {
            {
                icon = "fas fa-envelope",
                label = label,
                canInteract = Postman_SafeCanInteract(function()
                    if not holdingMail then return false end
                    if stage ~= siteIdx * 2 then return false end
                    return (site.delivered or 0) < DELIVERIES_PER_STOP
                end),
                action = function()
                    CreateThread(function()
                        Postman_RunDeliveryAtStop(siteIdx)
                    end)
                end,
            },
        },
        distance = 2.5,
    })
end

local function Postman_AddDoorZone(siteIdx, coords)
    Postman_AddStopDeliveryZone(siteIdx, coords, deliverySites[siteIdx].stopType)
end

local function Postman_AddVanLoadTarget()
    if vanLoadTargetAdded then
        Postman_Debug("Postman_AddVanLoadTarget skipped: already added")
        return
    end
    if not Target then
        Postman_Debug("Postman_AddVanLoadTarget skipped: Target nil (community_bridge target not ready?)")
        return
    end
    if not spawnedVehicle or not DoesEntityExist(spawnedVehicle) then
        Postman_Debug("Postman_AddVanLoadTarget skipped: spawnedVehicle missing")
        return
    end
    vanLoadTargetAdded = true
    Postman_Debug("Postman_AddVanLoadTarget OK on", Postman_EntityDebugLabel(spawnedVehicle))

    AddTargetToEntity(spawnedVehicle, {
        options = {
            {
                icon = "fas fa-mail-bulk",
                label = "Grab Mail from Van",
                canInteract = Postman_SafeCanInteract(function()
                    if holdingMail then return false end
                    if stage < 2 or stage > 11 then return false end
                    if stage % 2 == 1 then return false end
                    local siteIdx = stage / 2
                    local site = deliverySites[siteIdx]
                    return site and (site.delivered or 0) < DELIVERIES_PER_STOP
                end),
                action = function()
                    CreateThread(function()
                        local siteIdx = stage / 2
                        local site = deliverySites[siteIdx]
                        if not site then
                            Postman_Debug("^1Grab mail: no site for stage^7", stage)
                            return
                        end
                        Postman_GrabMailFromVan(site.stopType)
                    end)
                end,
            },
            {
                icon = "fas fa-sort",
                label = "Sort Route Satchel",
                canInteract = Postman_SafeCanInteract(function()
                    if stage < 3 or stage > 11 then return false end
                    return stage % 2 == 1 and not sortPhaseDone
                end),
                action = function()
                    local ped = PlayerPedId()
                    Postman_LoadAnim(MAIL_ANIM_DICT)
                    TaskPlayAnim(ped, MAIL_ANIM_DICT, "givetake2_a", 8.0, -8.0, 2500, 49, 0, false, false, false)
                    Wait(2500)
                    sortPhaseDone = true
                    local nextStage = stage + 1
                    stage = nextStage
                    if partnerId then
                        TriggerServerEvent("postman:server:sendPartnerStage", partnerId, nextStage)
                    end
                    if nextStage == 12 and missionDepotCoords then
                        stage = 12
                        SetWaypointToLocaltion(missionDepotCoords)
                        Postman_ClearStopBlips()
                        if partnerId then TriggerServerEvent("postman:server:setPartnerWaypoint", partnerId, Postman_ToVec3(missionDepotCoords)) end
                        Postman_Notify("~g~All stops done!~s~ Return the van to ~b~GO Postal~s~ to get paid.", "success")
                        Postman_ShowHelp("~g~Drive the van back to the depot and park near the job board.", 8000)
                    elseif nextStage >= 2 and nextStage <= 10 and nextStage % 2 == 0 then
                        Postman_TransitionToStop(nextStage / 2)
                        Postman_ShowHelp("~g~Satchel sorted — next stop marked on GPS.", 4000)
                    end
                end,
            },
        },
        distance = 5.0,
    })
end

local function Postman_EnsureVanTargets()
    if not vanLoadTargetAdded then
        Postman_AddVanLoadTarget()
    end
    Postman_AddDepotReturnZone()
end

local function Postman_StartMissionGuide(loopToken)
    missionGuideToken = missionGuideToken + 1
    local guideToken = missionGuideToken
    CreateThread(function()
        while guideToken == missionGuideToken and loopToken == missionLoopToken and MissionStarted do
            Postman_EnsureVanTargets()

            if stage == 1 then
                Postman_Notify("Get in the ~b~post van~s~ to begin your route.", "inform")
            elseif stage == 12 then
                Postman_Notify("Return the van to the ~b~GO Postal depot~s~.", "inform")
            elseif stage >= 2 and stage <= 11 then
                local stopIdx = Postman_GetCurrentStopIndex()
                if stopIdx and missionRouteStops and missionRouteStops[stopIdx] then
                    local stop = missionRouteStops[stopIdx]
                    local label = Config.StopTypeLabels[stop.stopType] or "Deliver mail"
                    if stage % 2 == 0 then
                        local site = deliverySites[stopIdx]
                        if Postman_IsPlayerInMissionVan() then
                            Postman_Notify("Drive to the ~b~GPS marker~s~ (Stop " .. stopIdx .. ").", "inform")
                        elseif site and (site.delivered or 0) < DELIVERIES_PER_STOP and not holdingMail then
                            Postman_Notify("Stop " .. stopIdx .. ": Target the ~b~van~s~ → ~y~Grab Mail from Van~s~.", "inform")
                        elseif holdingMail then
                            Postman_Notify("Stop " .. stopIdx .. ": Stand on the ~b~blue marker~s~ on the street → " .. label, "inform")
                        end
                    elseif not sortPhaseDone then
                        Postman_Notify("Target the ~b~van~s~ → ~y~Sort Route Satchel~s~ before the next stop.", "inform")
                    end
                end
            end

            Wait(12000)
        end
    end)
end

local function Postman_AdvanceFromStage1(missionRouteStopsRef)
    Postman_Debug("Postman_AdvanceFromStage1 called, stage=", stage)
    if stage >= 2 then
        Postman_Debug("Postman_AdvanceFromStage1 aborted: already stage", stage)
        return
    end
    if not missionRouteStopsRef or not missionRouteStopsRef[1] or not missionRouteStopsRef[1].coords then
        Postman_Debug("^1Postman_AdvanceFromStage1 FAILED: missionRouteStops[1] missing^7")
        Postman_DumpMissionState("advance-stage1-failed")
        return
    end
    stage = 2
    Postman_TransitionToStop(1)
    RemoveEntityHighlight(spawnedVehicle)
    if partnerId then
        TriggerServerEvent("postman:server:sendPartnerStage", partnerId, 2)
    end
    Postman_EnsureVanTargets()
    Postman_DumpMissionState("stage1-complete")
end

local function Postman_BuildRouteStops(missionConfig)
    local areas = Postman_GetActiveMissionAreas(missionConfig)
    local types = missionConfig.stopTypes or {}
    local stops = {}
    for i = 1, STOP_COUNT do
        stops[i] = {
            coords = areas[i] and Postman_ResolveStopCoords(areas[i], false) or areas[i],
            stopType = types[i] or "mailbox",
            getDelivered = function() return deliverySites[i].delivered end,
        }
    end
    return stops
end

local function Postman_GetRouteMinigameConfig()
    return Config.RouteMinigame or { enabled = false }
end

local function Postman_ShouldRunRouteMinigame()
    local cfg = Postman_GetRouteMinigameConfig()
    if not cfg.enabled then return false end
    if invitee and cfg.skipForInvitee ~= false then return false end
    return true
end

local function Postman_BuildRouteMinigamePayload(missionConfig)
    local depot = missionConfig.vanCoords
    local areas = Postman_GetActiveMissionAreas(missionConfig)
    local stops = {}
    for i = 1, STOP_COUNT do
        local area = areas[i]
        stops[i] = {
            id = i,
            x = area.x,
            y = area.y,
            z = area.z,
            label = string.char(64 + i),
            urgent = Postman_IsUrgentStopId(i),
        }
    end
    return {
        depot = { x = depot.x, y = depot.y, z = depot.z, label = "Depot" },
        stops = stops,
        urgentLabels = Postman_GetUrgentStopLabels(),
        regionName = MISSION_REGION_NAMES[missionid] or "San Andreas",
        mapUrl = ("https://cfx-nui-%s/web/dist/gta-map-dark.jpg"):format(GetCurrentResourceName()),
        mapUrlFallback = ("https://cfx-nui-%s/web/dist/gta-map-dark.png"):format(GetCurrentResourceName()),
    }
end

local function Postman_ApplyRouteOrder(order, missionConfig)
    if not order or #order ~= STOP_COUNT then return false end

    local areas = Postman_GetActiveMissionAreas(missionConfig)
    local types = missionConfig.stopTypes or {}
    local reorderedAreas = Postman_RouteSolver.ReorderStops(areas, order)
    local reorderedTypes = Postman_RouteSolver.ReorderStops(types, order)

    missionRawAreas = reorderedAreas
    missionRouteStops = {}
    for i = 1, STOP_COUNT do
        missionRouteStops[i] = {
            coords = Postman_ResolveStopCoords(reorderedAreas[i], false),
            stopType = reorderedTypes[i] or "mailbox",
            urgent = Postman_IsUrgentStopId(order[i]),
            getDelivered = function() return deliverySites[i].delivered end,
        }
        deliverySites[i].stopType = reorderedTypes[i] or deliverySites[i].stopType or "mailbox"
        deliverySites[i].urgent = Postman_IsUrgentStopId(order[i])
    end

    routeMinigameDone = true
    Postman_Debug("Route order applied:", table.concat(order, ","))
    return true
end

local function Postman_CloseRouteMinigame()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeRouteMinigame" })
end

local function Postman_OpenRouteMinigame(missionConfig)
    local payload = Postman_BuildRouteMinigamePayload(missionConfig)
    closeUI()
    Wait(50)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "openRouteMinigame", data = payload })
    Postman_Debug("Route minigame opened with", #payload.stops, "stops")
    Postman_ShowHelp("~b~Plan your route:~s~ deliver ~r~URGENT~s~ mail first, then find the shortest path.", 8000)
end

local function Postman_RunRouteMinigame(missionConfig)
    if not Postman_ShouldRunRouteMinigame() then
        routeMinigameDone = true
        return true
    end

    routeMinigameDone = false
    Postman_OpenRouteMinigame(missionConfig)

    local completed = false
    local deadline = GetGameTimer() + 300000
    while not completed and GetGameTimer() < deadline and MissionStarted do
        if routeMinigameDone then
            completed = true
            break
        end
        Wait(100)
    end

    -- On success the NUI shows the result and closes itself after a short delay.
    if not completed then
        Postman_CloseRouteMinigame()
    end
    return completed
end

local function Postman_SetupDeliverySites(missionConfig)
    local types = missionConfig.stopTypes or {}

    for siteIdx = 1, STOP_COUNT do
        local site = deliverySites[siteIdx]
        site.props = {}
        site.netIds = {}
        site.delivered = 0
        site.stopType = types[siteIdx] or serverStopTypes[siteIdx] or "mailbox"
        site.urgent = false
        site.activated = false
        site.activatedSnap = nil
        site.outdoorCoords = nil
        if site.deliveryZoneName then
            Postman_RemoveBoxZone(site.deliveryZoneName)
            site.deliveryZoneName = nil
        end
    end

    Postman_AddVanLoadTarget()
    return true
end

function ManageProximityMarker(targetCoords, proximityDistance, markerType, markerColor, markerScale, markerRef)
    local distance = #(GetEntityCoords(PlayerPedId()) - targetCoords)
    if distance <= proximityDistance then
        markerRef.active = true
        DrawMarker(markerType or 1, targetCoords.x, targetCoords.y, targetCoords.z - 1.0,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            markerScale.x or 5.0, markerScale.y or 5.0, markerScale.z or 2.0,
            markerColor.r or 0, markerColor.g or 150, markerColor.b or 255, markerColor.a or 150,
            false, false, 2, false, nil, nil, false)
    else
        markerRef.active = false
    end
end

function StartMission(column, id)
    Postman_Debug("StartMission called:", "column=", column, "id=", id)
    if not MISSION_IDS[id] then
        Postman_Debug("^1StartMission aborted: invalid mission id^7", id)
        return
    end

    whichmission = column .. "_" .. id
    local vanModel = joaat(Config.PostVanModel or "boxville2")

    local success, groupInfo = pcall(function()
        return exports.nn_postman:GetGroupInfo()
    end)

    if success and groupInfo and groupInfo.currentInvitedPlayer then
        ingroup = true
        if groupInfo.wasInviter then
            TriggerServerEvent("postman:server:notifyInviteeStartMission", groupInfo.currentInvitedPlayer.id, column, id)
        else
            invitee = true
        end
    end

    local routes = Postman_GetRoutesForMission(id, ingroup, invitee)
    local missionConfig = routes and routes[tostring(column)]
    if not missionConfig then
        Postman_Debug("^1StartMission aborted: no missionConfig for^7", id, column)
        return
    end

    local vc = missionConfig.vanCoords
    if not invitee then
        for _, veh in ipairs(GetGamePool("CVehicle")) do
            if #(GetEntityCoords(veh) - vector3(vc.x, vc.y, vc.z)) < 3.0 then
                Postman_Debug("^1StartMission aborted: parking blocked by^7", Postman_EntityDebugLabel(veh))
                Postman_ShowHelp("~r~Van parking is full. Clear the spot first.", 3000)
                return
            end
        end
    end

    Postman_Debug("StartMission proceeding:", whichmission, "invitee=", invitee, "ingroup=", ingroup)

    MissionStarted = true
    missionid = id
    missioncolumn = column
    missionLoopToken = missionLoopToken + 1
    local loopToken = missionLoopToken
    sortPhaseDone = false
    vanLoadTargetAdded = false
    serverDeliveryAreas = nil
    missionRawAreas = nil
    missionUrgentStopIds = nil

    if not invitee then
        Postman_RandomizeMissionStops(id)
        Postman_PickUrgentStopIds()
    end

    NotifyMissionStarted(column, id)
    TriggerServerEvent("postman:server:updateMissionStatus", column, id, true)
    TriggerServerEvent("postman:server:getPartnerId")

    serverEntitiesReceived = false

    if not invitee then
        RequestModel(vanModel)
        while not HasModelLoaded(vanModel) do Wait(10) end

        spawnedVehicle = CreateVehicle(vanModel, vc.x, vc.y, vc.z, vc.w, true, false)
        Postman_Debug("Van spawned:", Postman_EntityDebugLabel(spawnedVehicle), "at", vc.x, vc.y, vc.z)
        NetworkRegisterEntityAsNetworked(spawnedVehicle)
        local vanNetId = VehToNet(spawnedVehicle)
        Postman_Debug("Van netId=", vanNetId)
        SetNetworkIdExistsOnAllMachines(vanNetId, true)
        SetModelAsNoLongerNeeded(vanModel)
        SetVehicleOnGroundProperly(spawnedVehicle)
        SetVehicleDoorsLocked(spawnedVehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(spawnedVehicle, false)
        SetVehicleDoorsLockedForPlayer(spawnedVehicle, PlayerId(), false)
        SetVehicleDoorsLockedForNonScriptPlayers(spawnedVehicle, false)
        SetVehicleHasBeenOwnedByPlayer(spawnedVehicle, true)
        SetEntityAsMissionEntity(spawnedVehicle, true, true)
        SetVehicleEngineOn(spawnedVehicle, true, true, false)
        Postman_ApplyVanEngineAudio(spawnedVehicle)
        AddEntityHighlight(spawnedVehicle, blueHighlight)
        table.insert(spawnedEntities, spawnedVehicle)
        TriggerServerEvent("postman:server:addObjectSpawned", whichmission, "spawnedVehicle", vanNetId)
        TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(spawnedVehicle))

        local deliveryAreas = Postman_GetActiveMissionAreas(missionConfig)
        local partnerIdToSend = (ingroup and groupInfo and groupInfo.currentInvitedPlayer) and groupInfo.currentInvitedPlayer.id or nil

        TriggerServerEvent('postman:server:SpawnMissionEntities', whichmission, vc, deliveryAreas, missionConfig.stopTypes, partnerIdToSend, vanNetId)
        Postman_Debug("Requested server entity spawn for", whichmission)

        local startWait = GetGameTimer()
        while not serverEntitiesReceived and (GetGameTimer() - startWait) < 20000 do Wait(100) end
        if not serverEntitiesReceived then
            Postman_Debug("^1Server spawn timeout after 20s — continuing with client-only stops^7")
            serverEntitiesReceived = true
        else
            Postman_Debug("Server entities received OK")
        end

        if not Postman_SetupDeliverySites(missionConfig) then
            Postman_Debug("^1Postman_SetupDeliverySites failed^7")
            Postman_ResetMission()
            return
        end
        Postman_Notify("Route loaded! Get in the ~b~highlighted post van~s~ nearby.", "success")
    else
        local startWait = GetGameTimer()
        while not serverEntitiesReceived and (GetGameTimer() - startWait) < 25000 do Wait(100) end
        if not serverEntitiesReceived then
            Postman_Debug("^1Partner sync timeout — continuing with client-only stops^7")
            serverEntitiesReceived = true
        end

        local van = Postman_WaitForNetEntity(serverVanNetId, 15000)
        if not van then
            NotifyMissionFailed('Failed to sync van from partner.')
            Postman_ResetMission()
            return
        end
        spawnedVehicle = van
        table.insert(spawnedEntities, van)
        Postman_ApplyVanEngineAudio(van)
        AddEntityHighlight(van, blueHighlight)

        if not Postman_SetupDeliverySites(missionConfig) then
            Postman_ResetMission()
            return
        end
        Postman_ShowHelp("~g~Partner route synced!", 5000)
    end

    if invitee and serverDeliveryAreas then
        missionRawAreas = serverDeliveryAreas
    elseif not missionRawAreas then
        missionRawAreas = Postman_GetRawMissionAreas(missionConfig)
    end
    missionRouteStops = Postman_BuildRouteStops(missionConfig)
    missionDepotCoords = missionConfig.vanCoords

    if invitee then
        local cfg = Postman_GetRouteMinigameConfig()
        if cfg.enabled and cfg.skipForInvitee ~= false then
            local routeWait = GetGameTimer() + 30000
            while not routeMinigameDone and GetGameTimer() < routeWait and MissionStarted do
                Wait(100)
            end
            if not routeMinigameDone then
                routeMinigameDone = true
                Postman_Debug("Route order sync timed out — using default stop order for invitee")
            end
        else
            routeMinigameDone = true
        end
    elseif not Postman_RunRouteMinigame(missionConfig) then
        Postman_Notify("~r~Route planning cancelled.~s~ Mission stopped.", "error")
        Postman_ResetMission()
        return
    end

    stage = 2
    Postman_TransitionToStop(1)
    if not (missionRouteStops[1] and missionRouteStops[1].coords) then
        SetWaypointToLocaltion(vc)
        stage = 1
    else
        Postman_ShowHelp("~y~At each stop:~s~ exit van → Grab Mail from Van → deliver at mailbox (or press ~y~E~s~)", 10000)
    end

    Postman_Debug("Mission ready — stage=", stage)
    Postman_DumpMissionState("mission-ready")
    Postman_EnsureVanTargets()
    Postman_AddDepotReturnZone()
    Postman_StartMissionGuide(loopToken)

    CreateThread(function()
        while loopToken == missionLoopToken and MissionStarted and spawnedVehicle and DoesEntityExist(spawnedVehicle) do
            if Postman_IsPlayerInMissionVan() then
                RemoveEntityHighlight(spawnedVehicle)
                Postman_Debug("Player entered mission van — highlight removed")
                break
            end
            Wait(500)
        end
    end)

    CreateThread(function()
        while loopToken == missionLoopToken and MissionStarted do
            local stopIdx = Postman_GetDeliveryStopIndex()
            if stopIdx and missionRawAreas and missionRawAreas[stopIdx] then
                if not deliverySites[stopIdx].activated then
                    Postman_TransitionToStop(stopIdx)
                end

                local raw = missionRawAreas[stopIdx]
                local pedCoords = GetEntityCoords(PlayerPedId())
                local dist = #(pedCoords - vector3(raw.x, raw.y, raw.z))

                if dist < 150.0 and deliverySites[stopIdx].activatedSnap ~= true then
                    Postman_ActivateStop(stopIdx, true, true)
                end

                local c = (deliverySites[stopIdx] and deliverySites[stopIdx].outdoorCoords)
                    or (missionRouteStops and missionRouteStops[stopIdx] and missionRouteStops[stopIdx].coords)
                    or raw

                if c and dist < 500.0 then
                    DrawMarker(1, c.x, c.y, c.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        4.0, 4.0, 1.5, 74, 144, 217, 200, false, false, 2, false, nil, nil, false)
                    DrawMarker(2, c.x, c.y, c.z + 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.5, 0.5, 0.5, 74, 144, 217, 220, false, false, 2, false, nil, nil, false)
                end

                if dist < 6.0 and holdingMail then
                    BeginTextCommandDisplayHelp("STRING")
                    AddTextComponentSubstringPlayerName("Press ~INPUT_CONTEXT~ to deliver mail")
                    EndTextCommandDisplayHelp(0, false, true, 1)
                    if IsControlJustPressed(0, 38) then
                        Postman_RunDeliveryAtStop(stopIdx)
                    end
                elseif dist < 30.0 and not holdingMail and not Postman_IsPlayerInMissionVan() then
                    BeginTextCommandDisplayHelp("STRING")
                    AddTextComponentSubstringPlayerName("Target the post van → Grab Mail from Van")
                    EndTextCommandDisplayHelp(0, false, true, 1)
                end
                Wait(0)
            else
                Wait(500)
            end
        end
    end)

    CreateThread(function()
        local lastStage = stage
        while loopToken == missionLoopToken and MissionStarted do
            if stage ~= lastStage then
                lastStage = stage
                if stage >= 2 and stage <= 10 and stage % 2 == 0 then
                    Postman_TransitionToStop(stage / 2)
                end
            end
            Wait(500)
        end
    end)

    CreateThread(function()
        while loopToken == missionLoopToken and MissionStarted do
            if stage >= 2 and stage <= 10 and stage % 2 == 0 then
                local siteIdx = stage / 2
                local site = deliverySites[siteIdx]
                if site and site.delivered >= DELIVERIES_PER_STOP and stage < 11 then
                    -- wait for sort phase (odd stage)
                end
            elseif stage >= 3 and stage <= 11 and stage % 2 == 1 then
                if sortPhaseDone and missionRouteStops then
                    local nextSiteIdx = (stage + 1) / 2
                    if nextSiteIdx <= STOP_COUNT and missionRouteStops[nextSiteIdx] then
                        local st = missionRouteStops[nextSiteIdx].stopType
                        Postman_ShowHelp("~b~Stop " .. nextSiteIdx .. ": ~s~" .. (Config.StopTypeLabels[st] or ""), 5000)
                    end
                end
            end
            Wait(1000)
        end
    end)

    CreateThread(function()
        local returnHandled = false
        local returnMarkerRef = { active = false }
        while loopToken == missionLoopToken and MissionStarted and not returnHandled do
            if Postman_CanReturnToDepot() then
                local van = Postman_GetMissionVan()
                local returnPoint = missionDepotCoords and Postman_ToVec3(missionDepotCoords) or jobSearchLocation
                ManageProximityMarker(returnPoint, 120.0, 1, { r = 0, g = 150, b = 255, a = 150 }, { x = 8.0, y = 8.0, z = 2.0 }, returnMarkerRef)
                ManageProximityMarker(jobSearchLocation, 120.0, 1, { r = 0, g = 200, b = 100, a = 120 }, { x = 6.0, y = 6.0, z = 2.0 }, returnMarkerRef)

                if van then
                    local vanPos = GetEntityCoords(van)
                    if Postman_IsNearDepot(vanPos) then
                        returnHandled = Postman_CompleteMissionReturn()
                    else
                        Wait(0)
                    end
                else
                    Wait(500)
                end
            else
                Wait(1000)
            end
        end
    end)

    CreateThread(function()
        while loopToken == missionLoopToken and MissionStarted do
            if stage >= 3 and stage <= 11 and stage % 2 == 1 then
                local prevSiteIdx = (stage - 1) / 2
                if deliverySites[prevSiteIdx] and deliverySites[prevSiteIdx].delivered >= DELIVERIES_PER_STOP and sortPhaseDone then
                    if stage == 11 and Postman_AllStopsComplete() then
                        stage = 12
                        if partnerId then TriggerServerEvent("postman:server:sendPartnerStage", partnerId, 12) end
                        SetWaypointToLocaltion(missionDepotCoords or missionConfig.vanCoords)
                        Postman_ClearStopBlips()
                        if partnerId then TriggerServerEvent("postman:server:setPartnerWaypoint", partnerId, Postman_ToVec3(missionDepotCoords or missionConfig.vanCoords)) end
                        Postman_Notify("~g~All stops done!~s~ Return the van to ~b~GO Postal~s~ to get paid.", "success")
                    end
                end
            end
            Wait(800)
        end
    end)
end

Postman_ResetMission = function()
    if postmanResetting then
        return
    end
    if not MissionStarted and whichmission == nil then
        return
    end

    postmanResetting = true
    local wasInMission = MissionStarted or whichmission ~= nil
    Postman_Debug("Postman_ResetMission() called")
    Postman_DumpMissionState("before-reset")
    missionLoopToken = missionLoopToken + 1
    missionGuideToken = missionGuideToken + 1
    RemoveWaypointToLocation()
    Postman_RemoveDepotReturnZone()
    Postman_ClearStopBlips()
    ClearGpsMultiRoute()
    SetWaypointOff()
    Postman_DeleteMissionVan()

    if whichmission then
        TriggerServerEvent('postman:server:CleanupMissionEntities', whichmission)
    end

    TriggerServerEvent('postman:server:updateMissionStatus', missioncolumn, missionid, false)
    TriggerServerEvent('postman:server:clearObjectsForMission', missioncolumn)

    for i = 1, STOP_COUNT do
        if deliverySites[i].zoneName then
            Postman_RemoveBoxZone(deliverySites[i].zoneName)
        end
        if deliverySites[i].deliveryZoneName then
            Postman_RemoveBoxZone(deliverySites[i].deliveryZoneName)
        end
    end

    local success, groupInfo = pcall(function() return exports.nn_postman:GetGroupInfo() end)
    if wasInMission and success and groupInfo and groupInfo.currentInvitedPlayer then
        TriggerServerEvent('postman:server:notifyGroupMemberReset', groupInfo.currentInvitedPlayer.id)
    end

    Postman_ClearHeldMail()
    RemoveAllHighlights()
    spawnedEntities = {}
    spawnedObjects = {}
    partnerId = nil
    for si = 1, STOP_COUNT do
        deliverySites[si] = { props = {}, netIds = {}, delivered = 0, stopType = "mailbox", zoneName = nil, deliveryZoneName = nil }
    end
    spawnedVehicle = nil
    ingroup = false
    invitee = false
    missionBlip = nil
    stage = 0
    serverEntitiesReceived = false
    serverVanNetId = nil
    serverPropNetIds = {}
    serverStopTypes = {}
    MissionStarted = false
    missioncolumn = ""
    missionid = ""
    whichmission = nil
    missionRouteStops = nil
    missionRawAreas = nil
    serverDeliveryAreas = nil
    missionUrgentStopIds = nil
    activeStopIndex = nil
    missionDepotCoords = nil
    sortPhaseDone = false
    routeMinigameDone = false
    vanLoadTargetAdded = false
    depotReturnZoneAdded = false

    SendNUIMessage({
        action = "missionStatusChanged",
        data = { inMission = false, currentMissionId = "", currentMissionColumn = "" }
    })

    if success and groupInfo and groupInfo.currentInvitedPlayer then
        TriggerServerEvent('leaveGroup', groupInfo.currentInvitedPlayer)
    end

    postmanResetting = false
end

function fetchObject(objectName)
    if whichmission == nil then return nil end
    TriggerServerEvent("postman:server:getObjectSpawned", whichmission, objectName)
    local value = nil
    local timeout = GetGameTimer() + 5000
    while value == nil and GetGameTimer() < timeout do
        Wait(100)
        local netId = spawnedObjects[objectName]
        if netId and NetworkDoesNetworkIdExist(netId) then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(ent) then value = ent end
        end
    end
    return value
end

function SetWaypointToLocaltion(coords)
    if not coords then
        Postman_Debug("^1SetWaypointToLocaltion: nil coords^7")
        return
    end

    if missionBlip then
        RemoveBlip(missionBlip)
        missionBlip = nil
    end

    ClearGpsMultiRoute()
    ClearGpsPlayerWaypoint()
    SetWaypointOff()

    SetNewWaypoint(coords.x, coords.y)

    missionBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(missionBlip, 480)
    SetBlipDisplay(missionBlip, 4)
    SetBlipScale(missionBlip, 1.0)
    SetBlipColour(missionBlip, 3)
    SetBlipAsShortRange(missionBlip, false)
    SetBlipRoute(missionBlip, true)
    SetBlipRouteColour(missionBlip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Mail Stop")
    EndTextCommandSetBlipName(missionBlip)

    Postman_Debug("Waypoint set:", coords.x, coords.y, coords.z, "blipId=", missionBlip)
end

function RemoveWaypointToLocation()
    if missionBlip then RemoveBlip(missionBlip) missionBlip = nil end
end

CreateThread(function()
    while not Target do Wait(100) end
    AddTargetBoxZone("postman_job_search_zone", jobSearchLocation, 1.5, 1.5, {
        heading = 0,
        minZ = jobSearchLocation.z - 1,
        maxZ = jobSearchLocation.z + 1,
    }, {
        options = {
            {
                label = "Browse mail routes",
                icon = "fas fa-envelope",
                action = function() openUI() end,
            },
        },
        distance = 2.0,
    })
end)

CreateThread(function()
    local blip = AddBlipForCoord(jobSearchLocation.x, jobSearchLocation.y, jobSearchLocation.z)
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.BlipName)
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while clientActive do
        if whichmission and (not spawnedVehicle or not DoesEntityExist(spawnedVehicle)) then
            spawnedVehicle = fetchObject("spawnedVehicle")
            if spawnedVehicle then
                Postman_ApplyVanEngineAudio(spawnedVehicle)
                vanLoadTargetAdded = false
                Postman_EnsureVanTargets()
            end
        elseif MissionStarted then
            Postman_EnsureVanTargets()
        end
        Wait(3000)
    end
end)

function openUI()
    SendNUIMessage({
        action = "setPlayerData",
        data = { playerId = GetPlayerServerId(PlayerId()), playerName = GetPlayerName(PlayerId()) }
    })
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "setVisible", data = true })
    TriggerEvent("SendLevelAndExp")
end

function closeUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisible", data = false })
end

RegisterNUICallback("close", function(_, cb) closeUI() cb({}) end)
RegisterNUICallback("pressedEscape", function(_, cb) closeUI() cb({}) end)
RegisterNUICallback("hideFrame", function(_, cb) closeUI() cb({}) end)
RegisterNUICallback("GetMultipliers", function(_, cb) cb({ xpMultiplier = 1.0, moneyMultiplier = 1.0 }) end)

RegisterNUICallback("IsInMission", function(_, cb)
    local isGroupInvitee = false
    local ok, groupInfo = pcall(function() return exports.nn_postman:GetGroupInfo() end)
    if ok and groupInfo and groupInfo.inviteAccepted and not groupInfo.wasInviter then isGroupInvitee = true end
    cb({
        inMission = MissionStarted,
        currentMissionId = missionid or "",
        currentMissionColumn = missioncolumn or "",
        isInvitee = invitee,
        isGroupInvitee = isGroupInvitee,
    })
end)

RegisterNUICallback("MissionStarted", function(data, cb)
    Postman_Debug("NUI MissionStarted column=", data and data.column, "id=", data and data.selectedId)
    if not MissionStarted then StartMission(data.column, data.selectedId) end
    Citizen.SetTimeout(500, function()
        if not MissionStarted then
            SendReactMessage('missionStatusChanged', { inMission = false, currentMissionId = "", currentMissionColumn = "" })
        end
    end)
    cb({ success = MissionStarted })
end)

RegisterNUICallback("ResetMy", function(_, cb) Postman_ResetMission() cb({}) end)

RegisterNUICallback("submitRouteOrder", function(data, cb)
    if not MissionStarted or routeMinigameDone then
        cb({ success = false, message = "No active route puzzle." })
        return
    end

    local order = data and data.order
    if type(order) ~= "table" or #order ~= STOP_COUNT then
        cb({ success = false, message = "Select all 5 stops before confirming." })
        return
    end

    local seen = {}
    for _, stopId in ipairs(order) do
        local id = tonumber(stopId)
        if not id or id < 1 or id > STOP_COUNT or seen[id] then
            cb({ success = false, message = "Each stop can only be used once." })
            return
        end
        seen[id] = true
    end

    local routes = Postman_GetRoutesForMission(missionid, ingroup, invitee)
    local missionConfig = routes and routes[tostring(missioncolumn)]
    if not missionConfig then
        cb({ success = false, message = "Mission data unavailable." })
        return
    end

    local depot = missionConfig.vanCoords
    local areas = Postman_GetActiveMissionAreas(missionConfig)
    local tolerance = (Config.RouteMinigame and Config.RouteMinigame.distanceTolerance) or 1.0

    if not Postman_RouteSolver.IsUrgentOrderValid(order, missionUrgentStopIds) then
        cb({
            success = false,
            message = ("Deliver URGENT mail first! Stops %s must come before regular stops."):format(Postman_GetUrgentStopLabels()),
        })
        return
    end

    local isOptimal, optimalDist, playerDist = Postman_RouteSolver.IsOptimalRoute(depot, areas, order, tolerance, missionUrgentStopIds)

    if not isOptimal then
        cb({
            success = false,
            playerDistance = playerDist,
            optimalDistance = optimalDist,
            message = ("Not the best route. URGENT stops must stay first, then keep it short. Your plan: %.0fm. Best possible: %.0fm."):format(playerDist, optimalDist),
        })
        return
    end

    if not Postman_ApplyRouteOrder(order, missionConfig) then
        cb({ success = false, message = "Could not apply that route." })
        return
    end

    if partnerId then
        TriggerServerEvent("postman:server:syncRouteOrder", partnerId, whichmission, order, missionUrgentStopIds)
    end

    cb({
        success = true,
        playerDistance = playerDist,
        optimalDistance = optimalDist,
        message = ("Perfect route! URGENT mail first, shortest path. Total distance: %.0fm."):format(playerDist),
    })
end)

RegisterNUICallback("closeRouteMinigame", function(_, cb)
    Postman_CloseRouteMinigame()
    Postman_Notify("~g~Optimal route confirmed!~s~ Deliveries will follow your plan.", "success")
    cb({})
end)

local deliveryHandOpen = false

local DELIVERY_HAND_NOTE_BY_TYPE = {
    mailbox = { note = "STANDARD MAIL", noteType = "regular" },
    door_knock = { note = "KNOCK FIRST", noteType = "regular" },
    package = { note = "FRAGILE", noteType = "fragile" },
    cluster = { note = "REGULAR", noteType = "regular" },
    registered = { note = "SIGNATURE", noteType = "signature" },
    newspaper = { note = "TOSS ON PORCH", noteType = "newspaper" },
    dog_yard = { note = "CAREFUL — DOG", noteType = "dog" },
}

local DELIVERY_HAND_DEMO_ADDRESSES = {
    "12 Mirror Park Blvd",
    "4 Grove St Apartments",
    "88 Vinewood Hills Dr",
    "221 Bay City Ave",
    "9 Del Perro Heights",
}

local DELIVERY_HAND_DEMO_RECIPIENTS = {
    "M. Santos",
    "L. Johnson",
    "R. De Santa",
    "T. Clinton",
    "Porch delivery",
}

local DELIVERY_HAND_INSTRUCTIONS_BY_TYPE = {
    mailbox = "Deposit in mailbox.",
    door_knock = "Knock before delivering.",
    package = "Handle with care. Leave at front door.",
    cluster = "Deliver all items at this stop.",
    registered = "Signature required. Deliver to recipient only.",
    newspaper = "Toss newspaper onto porch.",
    dog_yard = "Watch for dog in yard. Knock before entering gate.",
}

local function Postman_CloseDeliveryHandScene()
    if not deliveryHandOpen then return end
    deliveryHandOpen = false
    SetNuiFocus(false, false)
    SendReactMessage("closeDeliveryHand", {})
end

local function Postman_BuildDeliveryHandItems(stopTypes, urgentIds)
    local items = {}
    local labels = { "A", "B", "C", "D", "E" }
    local urgentLookup = {}
    if type(urgentIds) == "table" then
        for _, id in ipairs(urgentIds) do urgentLookup[id] = true end
    end

    for i = 1, 5 do
        local stopType = (stopTypes and stopTypes[i]) or "mailbox"
        local noteInfo = DELIVERY_HAND_NOTE_BY_TYPE[stopType] or DELIVERY_HAND_NOTE_BY_TYPE.mailbox
        local note = noteInfo.note
        local noteType = noteInfo.noteType
        if urgentLookup[i] then
            note = "URGENT"
            noteType = "urgent"
        end
        items[i] = {
            id = string.lower(labels[i]),
            label = labels[i],
            address = DELIVERY_HAND_DEMO_ADDRESSES[i] or ("Stop " .. i),
            note = note,
            noteType = noteType,
            stopType = stopType,
            recipient = DELIVERY_HAND_DEMO_RECIPIENTS[i] or "Resident",
            tracking = ("PM-%s-%05d"):format(labels[i], 42000 + (i * 1111)),
            instructions = DELIVERY_HAND_INSTRUCTIONS_BY_TYPE[stopType] or "Complete delivery at stop.",
        }
    end
    return items
end

local function Postman_OpenDeliveryHandScene(payload)
    deliveryHandOpen = true
    SetNuiFocus(true, true)
    SendReactMessage("openDeliveryHand", payload or {})
end

RegisterNUICallback("closeDeliveryHand", function(_, cb)
    Postman_CloseDeliveryHandScene()
    cb({})
end)

RegisterNUICallback("GetMissionReward", function(data, cb)
    local reward = 0
    if Config.MissionRewards[data.selectedId] then
        reward = Config.MissionRewards[data.selectedId][tostring(data.column)] or 0
    end
    cb({ reward = reward, xpReward = Config.BaseReputationReward })
end)

local pendingMissionStatusCb = nil
RegisterNetEvent("postman:client:receiveMissionStatus")
AddEventHandler("postman:client:receiveMissionStatus", function(missionData)
    local cb = pendingMissionStatusCb
    pendingMissionStatusCb = nil
    if cb then cb({ ListOfMissionsStarted = missionData }) end
end)

RegisterNUICallback("GetMissionStatus", function(_, cb)
    pendingMissionStatusCb = cb
    TriggerServerEvent("postman:server:getMissionStatus")
end)

RegisterNetEvent('postman:client:setWaypointClient')
AddEventHandler('postman:client:setWaypointClient', function(coords)
    if not MissionStarted or not whichmission then
        return
    end
    SetWaypointToLocaltion(coords)
end)

RegisterNetEvent('postman:client:notifyPartnerStage')
AddEventHandler('postman:client:notifyPartnerStage', function(value)
    if not MissionStarted or not whichmission then
        return
    end
    Postman_Debug("notifyPartnerStage:", value)
    stage = value
    if value % 2 == 1 then sortPhaseDone = false end
    Postman_EnsureVanTargets()
    if value >= 2 and value <= 10 and value % 2 == 0 then
        Postman_TransitionToStop(value / 2)
    end
end)

RegisterNetEvent('postman:client:StopDelivered')
AddEventHandler('postman:client:StopDelivered', function(siteIdx, count)
    if deliverySites[siteIdx] then deliverySites[siteIdx].delivered = count or 0 end
end)

RegisterNetEvent('postman:client:receiveObjectSpawned')
AddEventHandler('postman:client:receiveObjectSpawned', function(objectName, objectValue)
    if not MissionStarted and not whichmission then
        return
    end
    spawnedObjects[objectName] = objectValue
end)

RegisterNetEvent('postman:client:receivePartnerId')
AddEventHandler('postman:client:receivePartnerId', function(value)
    if not MissionStarted and not whichmission then
        return
    end
    if value then partnerId = value end
end)

RegisterNetEvent('postman:client:startMissionAsInvitee')
AddEventHandler('postman:client:startMissionAsInvitee', function(column, id) StartMission(column, id) end)

RegisterNetEvent('postman:client:groupMemberReset')
AddEventHandler('postman:client:groupMemberReset', function() Postman_ResetMission() end)

RegisterNetEvent("postman:client:bothPlayersCompleted")
AddEventHandler("postman:client:bothPlayersCompleted", function()
    Postman_ShowHelp("~g~Both carriers finished the route!", 5000)
    TriggerEvent("mission:giveCashReward", false, Config.MissionRewards[missionid][tostring(missioncolumn)], baseReputation)
    Postman_ResetMission()
end)

RegisterNetEvent("postman:client:waitingForPartner")
AddEventHandler("postman:client:waitingForPartner", function(partnerName)
    Postman_ShowHelp("~y~Waiting for " .. partnerName .. " to return the van...", 5000)
end)

RegisterNetEvent('postman:client:MissionEntitiesSpawned')
AddEventHandler('postman:client:MissionEntitiesSpawned', function(missionKey, vanNetId, propNetIds, stopTypes, deliveryAreas)
    Postman_Debug("MissionEntitiesSpawned:", missionKey, "vanNetId=", vanNetId)
    whichmission = missionKey
    serverVanNetId = vanNetId
    serverPropNetIds = propNetIds or {}
    serverStopTypes = stopTypes or {}
    if deliveryAreas and type(deliveryAreas) == "table" and #deliveryAreas >= STOP_COUNT then
        serverDeliveryAreas = deliveryAreas
        if invitee then
            missionRawAreas = deliveryAreas
        end
    end
    serverEntitiesReceived = true
    if Config.Debug and propNetIds then
        for i = 1, 5 do
            local row = propNetIds[i]
            if row then
                Postman_Debug("  stop", i, "type=", stopTypes and stopTypes[i], "props=", row[1] or 0, row[2] or 0)
            end
        end
    end
end)

RegisterCommand("postman", function()
    openUI()
end, false)

RegisterCommand("postmandebug", function()
    Config.Debug = not Config.Debug
    Postman_Debug("Debug mode toggled:", Config.Debug and "ON" or "OFF")
    Postman_DumpMissionState("postmandebug command")
    if Config.Debug then
        Postman_Notify("Postman debug ~g~ON~s~ — watch F8 console.", "inform")
    else
        Postman_Notify("Postman debug ~r~OFF~s~.", "inform")
    end
end, false)

RegisterCommand("postmanstage", function(_, args)
    Postman_DumpMissionState("postmanstage command")
    if args[1] then
        local forced = tonumber(args[1])
        if forced then
            stage = forced
            Postman_Debug("Stage force-set to", stage)
            Postman_EnsureVanTargets()
        end
    end
end, false)

local PACKAGE_TEST_ZONE = "postman_package_test_zone"
local PACKAGE_TEST_PAD = `prop_mp_placement`
local packageTestCoords = nil
local packageTestMarkerActive = false
local packageTestPlacedObj = nil
local packageTestPadObj = nil

local function Postman_StopPackageTestVisuals()
    packageTestMarkerActive = false
    if packageTestPadObj and DoesEntityExist(packageTestPadObj) then
        RemoveEntityHighlight(packageTestPadObj)
        DeleteEntity(packageTestPadObj)
    end
    packageTestPadObj = nil
    packageTestCoords = nil
end

local function Postman_ClearPackageTestPlacedBox()
    if packageTestPlacedObj and DoesEntityExist(packageTestPlacedObj) then
        DeleteEntity(packageTestPlacedObj)
    end
    packageTestPlacedObj = nil
end

local function Postman_SpawnPackageTestPad(coords)
    RequestModel(PACKAGE_TEST_PAD)
    local modelDeadline = GetGameTimer() + 5000
    while not HasModelLoaded(PACKAGE_TEST_PAD) and GetGameTimer() < modelDeadline do Wait(10) end
    if not HasModelLoaded(PACKAGE_TEST_PAD) then return false end

    local obj = CreateObject(PACKAGE_TEST_PAD, coords.x, coords.y, coords.z, false, false, false)
    if not obj or obj == 0 or not DoesEntityExist(obj) then
        SetModelAsNoLongerNeeded(PACKAGE_TEST_PAD)
        return false
    end

    SetEntityHeading(obj, coords.w or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetEntityAlpha(obj, 140, false)
    SetModelAsNoLongerNeeded(PACKAGE_TEST_PAD)
    packageTestPadObj = obj
    table.insert(spawnedEntities, obj)
    AddEntityHighlight(obj, { r = 74, g = 144, b = 217, a = 255 })
    return true
end

local function Postman_StartPackageTestMarker(coords)
    Postman_StopPackageTestVisuals()
    packageTestCoords = coords
    Postman_SpawnPackageTestPad(coords)
    packageTestMarkerActive = true

    CreateThread(function()
        while packageTestMarkerActive and packageTestCoords do
            local c = packageTestCoords
            local pulse = (math.sin(GetGameTimer() / 280.0) + 1.0) * 0.5
            local fillAlpha = math.floor(70 + pulse * 90)
            local ringAlpha = math.floor(120 + pulse * 100)

            DrawMarker(1, c.x, c.y, c.z - 0.99, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.45, 1.45, 0.06, 74, 144, 217, fillAlpha, false, false, 2, false, nil, nil, false)
            DrawMarker(27, c.x, c.y, c.z - 0.985, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.5, 1.5, 1.5, 74, 144, 217, ringAlpha, false, false, 2, false, nil, nil, false)
            Wait(0)
        end
    end)
end

local function Postman_StopPackageDeliveryTest()
    Postman_RemoveBoxZone(PACKAGE_TEST_ZONE)
    Postman_StopPackageTestVisuals()
    Postman_ClearPackageTestPlacedBox()
    Postman_ClearHeldMail()
    Postman_Notify("Package delivery test ~r~cleared~s~.", "inform")
end

local function Postman_GiveTestPackageInHand()
    if holdingMail then
        Postman_Notify("Already holding mail — deliver or run ~y~/postmantestpackage clear~s~ first.", "error")
        return false
    end

    local ped = PlayerPedId()
    RequestModel(PACKAGE_PROP)
    local modelDeadline = GetGameTimer() + 5000
    while not HasModelLoaded(PACKAGE_PROP) and GetGameTimer() < modelDeadline do Wait(10) end
    if not HasModelLoaded(PACKAGE_PROP) then
        Postman_Notify("~r~Could not load package prop.", "error")
        return false
    end

    Postman_LoadAnim(CARRY_ANIM_DICT)
    TaskPlayAnim(ped, CARRY_ANIM_DICT, "idle", 8.0, -8.0, -1, 49, 0, false, false, false)

    local bone = GetPedBoneIndex(ped, 60309)
    local obj = CreateObject(PACKAGE_PROP, 0.0, 0.0, 0.0, true, true, false)
    if not obj or obj == 0 or not DoesEntityExist(obj) then
        Postman_Notify("~r~Could not create package prop.", "error")
        return false
    end

    AttachEntityToEntity(obj, ped, bone, 0.025, 0.08, 0.255, -145.0, 290.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(PACKAGE_PROP)
    heldMailObj = obj
    holdingMail = true
    table.insert(spawnedEntities, obj)
    return true
end

local function Postman_StartPackageDeliveryTest()
    if not Target and not Postman_WaitForTarget(10000) then
        Postman_Notify("~r~Target system not ready — start ox_target / qb-target first.", "error")
        return
    end

    Postman_RemoveBoxZone(PACKAGE_TEST_ZONE)
    Postman_StopPackageTestVisuals()

    if not Postman_GiveTestPackageInHand() then return end

    local ped = PlayerPedId()
    local ahead = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
    local dropZ = ahead.z
    local found, groundZ = GetGroundZFor_3dCoord(ahead.x, ahead.y, ahead.z + 1.0, false)
    if found then dropZ = groundZ end
    local dropCoords = vector4(ahead.x, ahead.y, dropZ, GetEntityHeading(ped))

    Postman_StartPackageTestMarker(dropCoords)

    AddTargetBoxZone(PACKAGE_TEST_ZONE, Postman_ToVec3(dropCoords), 1.5, 1.5, {
        heading = dropCoords.w or 0,
        minZ = dropCoords.z - 1.0,
        maxZ = dropCoords.z + 2.0,
    }, {
        options = {
            {
                icon = "fas fa-box",
                label = "Place Package (Test)",
                canInteract = Postman_SafeCanInteract(function()
                    return holdingMail
                end),
                action = function()
                    CreateThread(function()
                        if not holdingMail then
                            Postman_Notify("No package in hand.", "error")
                            return
                        end
                        local placedBox = Postman_PlayPackagePutDownAnim(packageTestCoords, true)
                        if placedBox then
                            packageTestPlacedObj = placedBox
                        end
                        Postman_StopPackageTestVisuals()
                        Postman_RemoveBoxZone(PACKAGE_TEST_ZONE)
                        Postman_Notify("Package placed — test complete.", "success")
                    end)
                end,
            },
        },
        distance = 2.5,
    })

    Postman_Notify("Test ready: box in hand, drop spot ~b~2m ahead~s~. Use target → ~y~Place Package (Test)~s~.", "success")
    Postman_ShowHelp("~g~Package test~s~ — place the box on the ~b~highlighted area~s~ ahead.", 8000)
    Postman_Debug("Package test zone at", dropCoords.x, dropCoords.y, dropCoords.z)
end

RegisterCommand("postmantestpackage", function(_, args)
    local sub = args[1] and string.lower(args[1]) or nil
    if sub == "clear" or sub == "stop" then
        Postman_StopPackageDeliveryTest()
        return
    end
    Postman_StartPackageDeliveryTest()
end, false)

RegisterCommand("postmanmailhand", function()
    local missionNum = tonumber(missioncolumn) or 3
    local stopTypes = Config.StopTypesByMission[missionNum] or Config.StopTypesByMission[3]
    local payload = {
        regionName = (MISSION_REGION_NAMES[missionid] or "Los Santos") .. " — Mail In Hand",
        items = Postman_BuildDeliveryHandItems(stopTypes, { 1, 2 }),
    }

    Postman_OpenDeliveryHandScene(payload)
end, false)

RegisterNetEvent('postman:client:receiveRouteOrder')
AddEventHandler('postman:client:receiveRouteOrder', function(missionKey, order, urgentIds)
    if not MissionStarted or whichmission ~= missionKey then return end
    local routes = Postman_GetRoutesForMission(missionid, ingroup, invitee)
    local missionConfig = routes and routes[tostring(missioncolumn)]
    if not missionConfig then return end
    if type(urgentIds) == "table" then
        missionUrgentStopIds = urgentIds
    end
    Postman_ApplyRouteOrder(order, missionConfig)
    routeMinigameDone = true
    Postman_Debug("Partner route order synced:", table.concat(order, ","))
end)

RegisterNetEvent('postman:client:entitySync')
AddEventHandler('postman:client:entitySync', function(netId)
    if not MissionStarted and not whichmission then
        return
    end
    if NetworkDoesNetworkIdExist(netId) then
        NetworkGetEntityFromNetworkId(netId)
    end
end)
