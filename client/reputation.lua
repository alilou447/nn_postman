local Notify = nil

CreateThread(function()
    while not exports['community_bridge']:Bridge() do Wait(100) end
    Notify = exports['community_bridge']:Notify()
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent("levels:getExp")
end)

RegisterNetEvent('community_bridge:Client:OnPlayerLoaded', function()
    Wait(1000)
    TriggerServerEvent("levels:getExp")
end)

local myLevel = 1
local myExp = 0

local function rollItemRewards()
    local result = {}
    local itemsCfg = Config.Rewards and Config.Rewards.Items
    if not itemsCfg or not itemsCfg.enabled then return result end
    for _, item in ipairs(itemsCfg.list or {}) do
        local chance = tonumber(item.chance) or 0
        if chance > 0 and math.random(100) <= chance then
            table.insert(result, {
                name = item.name,
                amount = math.random(item.min or 1, item.max or 1)
            })
        end
    end
    return result
end

RegisterNetEvent("mission:giveCashReward")
AddEventHandler("mission:giveCashReward", function(isSolo, baseMoney, baseReputation)
    local money = tonumber(baseMoney) or 0
    local rep = tonumber(baseReputation) or Config.BaseReputationReward or 50
    local multiplier = 1 + (Config.ReputationMultiplier * (myLevel - 1))
    local rewardMoney = math.floor(money * multiplier)
    local reputationReward = math.floor(rep * multiplier)
    if not isSolo then
        rewardMoney = math.floor(rewardMoney * Config.MultiplayerMultiplier)
        reputationReward = math.floor(reputationReward * Config.MultiplayerMultiplier)
    end

    TriggerServerEvent("mission:giveMoney", rewardMoney)
    local rolledRewards = rollItemRewards()
    if #rolledRewards > 0 then
        TriggerServerEvent("mission:giveItems", rolledRewards, rewardMoney)
    end

    if Notify then
        Notify.SendNotify(("You received $%s and %s Reputation for completing the route!"):format(rewardMoney, reputationReward), "success", 5000)
    end
    TriggerServerEvent("levels:addExp", reputationReward)
end)

RegisterNetEvent("levels:loadData")
AddEventHandler("levels:loadData", function(level, exp)
    myLevel = level
    myExp = exp
end)

function getExpRequired(level)
    return 100 * (level + 1)
end

RegisterNUICallback("GetPlayerLevel", function(_, cb)
    cb({ level = myLevel, exp = myExp, expnextlevel = getExpRequired(myLevel) })
end)

RegisterNetEvent("SendLevelAndExp")
AddEventHandler("SendLevelAndExp", function()
    TriggerServerEvent("levels:addExp", 0)
    SendNUIMessage({
        action = "updateLevel",
        data = { level = myLevel, exp = myExp, expnextlevel = getExpRequired(myLevel) }
    })
end)
