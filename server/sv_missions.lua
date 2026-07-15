local ListOfMissionsStarted = {}
local ListOfObjectsSpawned = {}

function UpdateMissionStatus(column, missionId, isStarted, playerId)
    local key = column .. "_" .. missionId
    if isStarted then
        ListOfMissionsStarted[key] = playerId
    else
        ListOfMissionsStarted[key] = nil
    end
end

RegisterNetEvent('postman:server:sendPartnerStage')
AddEventHandler('postman:server:sendPartnerStage', function(targetId, stage)
    TriggerClientEvent('postman:client:notifyPartnerStage', targetId, stage)
end)

RegisterServerEvent('postman:server:updateMissionStatus')
AddEventHandler('postman:server:updateMissionStatus', function(column, missionId, isStarted)
    UpdateMissionStatus(column, missionId, isStarted, source)
end)

RegisterServerEvent('postman:server:addObjectSpawned')
AddEventHandler('postman:server:addObjectSpawned', function(mission, objectName, objectValue)
    if not ListOfObjectsSpawned[mission] then
        ListOfObjectsSpawned[mission] = {}
    end
    ListOfObjectsSpawned[mission][objectName] = objectValue
end)

RegisterServerEvent('postman:server:clearObjectsForMission')
AddEventHandler('postman:server:clearObjectsForMission', function(mission)
    ListOfObjectsSpawned[mission] = {}
end)

RegisterServerEvent('postman:server:getObjectSpawned')
AddEventHandler('postman:server:getObjectSpawned', function(mission, objectName)
    local src = source
    local value = nil
    if ListOfObjectsSpawned[mission] then
        value = ListOfObjectsSpawned[mission][objectName]
    end
    TriggerClientEvent('postman:client:receiveObjectSpawned', src, objectName, value)
end)

RegisterServerEvent('postman:server:getMissionStatus')
AddEventHandler('postman:server:getMissionStatus', function()
    TriggerClientEvent('postman:client:receiveMissionStatus', source, ListOfMissionsStarted)
end)

RegisterNetEvent('postman:server:removeEntityHighlightServer')
AddEventHandler('postman:server:removeEntityHighlightServer', function(targetId, objectName)
    TriggerClientEvent('postman:client:removeEntityHighlightClient', targetId, objectName)
end)

RegisterNetEvent('postman:server:setPartnerWaypoint')
AddEventHandler('postman:server:setPartnerWaypoint', function(targetId, coords)
    TriggerClientEvent('postman:client:setWaypointClient', targetId, coords)
end)

RegisterNetEvent('postman:server:syncRouteOrder')
AddEventHandler('postman:server:syncRouteOrder', function(targetId, missionKey, order, urgentIds)
    if type(targetId) ~= 'number' or type(missionKey) ~= 'string' or type(order) ~= 'table' then return end
    TriggerClientEvent('postman:client:receiveRouteOrder', targetId, missionKey, order, urgentIds)
end)

RegisterNetEvent('postman:server:StopDelivered')
AddEventHandler('postman:server:StopDelivered', function(targetId, siteIdx, count)
    if type(targetId) ~= 'number' or type(siteIdx) ~= 'number' then return end
    TriggerClientEvent('postman:client:StopDelivered', targetId, siteIdx, count)
end)

local function bridgeAddAccountBalance(src, accountType, amount)
    accountType = tostring(accountType or Config.MoneyType or "bank"):lower()
    local amt = tonumber(amount)
    if not amt or amt <= 0 then return false end
    return exports["community_bridge"]:Bridge().Framework.AddAccountBalance(src, accountType, amt)
end

local function bridgeAddItem(src, itemName, amount)
    local item = tostring(itemName or ""):lower()
    local amt = math.floor(tonumber(amount) or 0)
    if item == "" or amt <= 0 then return false end
    local framework = exports["community_bridge"]:Bridge().Framework
    if not framework then return false end
    if framework.AddItem then return framework.AddItem(src, item, amt) end
    if framework.GiveItem then return framework.GiveItem(src, item, amt) end
    if framework.AddInventoryItem then return framework.AddInventoryItem(src, item, amt) end
    return false
end

RegisterNetEvent("mission:giveMoney", function(amount)
    local src = source
    if amount and amount > 0 then
        bridgeAddAccountBalance(src, Config.MoneyType, amount)
    end
end)

RegisterNetEvent("mission:giveItems", function(items, fallbackMoneyAmount)
    local src = source
    if type(items) ~= "table" or #items == 0 then return end
    local anyGranted, hadFailure = false, false
    for _, entry in ipairs(items) do
        local ok = bridgeAddItem(src, entry and entry.name, entry and entry.amount)
        if ok then anyGranted = true else hadFailure = true end
    end
    if hadFailure and not anyGranted then
        bridgeAddAccountBalance(src, Config.MoneyType, tonumber(fallbackMoneyAmount) or 0)
    end
end)
