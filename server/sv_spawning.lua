local MissionEntities = {}

local PROP_BY_TYPE = {
    mailbox = "prop_letterbox_01",
    package = "prop_cs_cardbox_01",
    cluster = "prop_letterbox_02",
    registered = "prop_notepad_01",
    newspaper = "prop_cs_newspaper",
}

local function getPropModel(stopType)
    return PROP_BY_TYPE[stopType] or "prop_letterbox_01"
end

local function PostmanServerDebug(...)
    if not Config.Debug then return end
    local parts = { ... }
    local msg = ""
    for i, v in ipairs(parts) do
        msg = msg .. tostring(v) .. (i < #parts and " " or "")
    end
    print(("^5[nn_postman:server]^7 %s"):format(msg))
end

RegisterNetEvent('postman:server:SpawnMissionEntities')
AddEventHandler('postman:server:SpawnMissionEntities', function(missionKey, vanCoords, deliveryAreas, stopTypes, partnerId, clientVanNetId)
    local src = source
    PostmanServerDebug("SpawnMissionEntities from player", src, "mission=", missionKey, "vanNetId=", clientVanNetId)

    if MissionEntities[missionKey] then
        for _, ent in ipairs(MissionEntities[missionKey]) do
            if DoesEntityExist(ent) then DeleteEntity(ent) end
        end
    end
    MissionEntities[missionKey] = {}

    local propNetIds = {}
    local zoneNetIds = {}

    for areaIdx = 1, 5 do
        local area = deliveryAreas[areaIdx]
        local stopType = (stopTypes and stopTypes[areaIdx]) or "mailbox"
        propNetIds[areaIdx] = {}
        zoneNetIds[areaIdx] = stopType

        if not area then goto continue_area end

        if Config.ServerSpawnProps == false then
            goto continue_area
        end

        -- door_knock and dog_yard use client-side zones only
        if stopType == "door_knock" or stopType == "dog_yard" then
            goto continue_area
        end

        local modelName = getPropModel(stopType)
        local modelHash = GetHashKey(modelName)

        pcall(function()
            local prop = CreateObjectNoOffset(modelHash, area.x, area.y, area.z + (Config.PropGroundOffsetZ or 0.05), true, true, false)
            if prop and prop ~= 0 then
                local deadline = GetGameTimer() + 5000
                while not DoesEntityExist(prop) and GetGameTimer() < deadline do Wait(10) end
                if DoesEntityExist(prop) then
                    SetEntityHeading(prop, area.w or 0.0)
                    FreezeEntityPosition(prop, true)
                    local netId = NetworkGetNetworkIdFromEntity(prop)
                    if netId and netId ~= 0 then
                        propNetIds[areaIdx][1] = netId
                        table.insert(MissionEntities[missionKey], prop)
                    end
                end
            end

        end)

        ::continue_area::
    end

    TriggerClientEvent('postman:client:MissionEntitiesSpawned', src, missionKey, clientVanNetId or 0, propNetIds, zoneNetIds, deliveryAreas)
    PostmanServerDebug("Sent entities to player", src, "partner=", partnerId or "none")

    if partnerId and partnerId ~= src then
        TriggerClientEvent('postman:client:MissionEntitiesSpawned', partnerId, missionKey, clientVanNetId or 0, propNetIds, zoneNetIds, deliveryAreas)
        PostmanServerDebug("Sent entities to partner", partnerId)
    end
end)

RegisterNetEvent('postman:server:CleanupMissionEntities')
AddEventHandler('postman:server:CleanupMissionEntities', function(missionKey)
    if MissionEntities[missionKey] then
        for _, ent in ipairs(MissionEntities[missionKey]) do
            if DoesEntityExist(ent) then DeleteEntity(ent) end
        end
        MissionEntities[missionKey] = nil
    end
end)

RegisterNetEvent('registerInServer')
AddEventHandler('registerInServer', function(netId)
    if netId and netId ~= 0 then
        TriggerClientEvent('postman:client:entitySync', -1, netId)
    end
end)
