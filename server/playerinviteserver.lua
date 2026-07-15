local inviteTimeout = 10 * 1000
local inviteRadius = 10.0
local activeGroups = {}

function invite(source, targetId)
    if not targetId or not GetPlayerName(targetId) then return false end
    if source == targetId then return false end

    local srcCoords = GetEntityCoords(GetPlayerPed(source))
    local tgtCoords = GetEntityCoords(GetPlayerPed(targetId))
    if #(srcCoords - tgtCoords) <= inviteRadius then
        TriggerClientEvent("receiveInvite", targetId, source, inviteTimeout)
        return true
    end
    return false
end

RegisterServerEvent('sendInvite')
AddEventHandler('sendInvite', function(targetId)
    invite(source, targetId)
end)

RegisterNetEvent('inviteResponse', function(inviterId, accepted)
    local src = source
    if not GetPlayerName(inviterId) then return end

    if accepted then
        TriggerClientEvent('inviteAccepted', inviterId, src)
        activeGroups[inviterId] = src
        activeGroups[src] = inviterId
        TriggerClientEvent('updateInviterUI', inviterId, { name = GetPlayerName(src), id = src })
        TriggerClientEvent('updateInviteeUI', src, { name = GetPlayerName(inviterId), id = inviterId })
    else
        TriggerClientEvent('inviteDeclined', inviterId, src)
    end
end)

RegisterServerEvent('leaveGroup')
AddEventHandler('leaveGroup', function(otherPlayerInfo)
    local src = source
    local otherPlayerId = otherPlayerInfo and otherPlayerInfo.id or activeGroups[src]
    if otherPlayerId then
        TriggerClientEvent('playerLeftGroup', otherPlayerId, { name = GetPlayerName(src), id = src })
        activeGroups[src] = nil
        activeGroups[otherPlayerId] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local otherPlayerId = activeGroups[src]
    if otherPlayerId then
        TriggerClientEvent('playerLeftGroup', otherPlayerId, { name = GetPlayerName(src) or "Player", id = src })
        activeGroups[src] = nil
        activeGroups[otherPlayerId] = nil
    end
end)

RegisterNetEvent('postman:server:notifyInviteeStartMission')
AddEventHandler('postman:server:notifyInviteeStartMission', function(inviteeId, column, id)
    TriggerClientEvent('postman:client:startMissionAsInvitee', inviteeId, column, id)
end)

RegisterNetEvent('postman:server:notifyGroupMemberReset')
AddEventHandler('postman:server:notifyGroupMemberReset', function(partnerId)
    TriggerClientEvent('postman:client:groupMemberReset', partnerId)
end)

local completedMissions = {}

RegisterNetEvent('postman:server:notifyMissionComplete')
AddEventHandler('postman:server:notifyMissionComplete', function(partnerId, missionColumn, missionId)
    local src = source
    local missionKey = missionColumn .. "_" .. missionId
    if not completedMissions[missionKey] then completedMissions[missionKey] = {} end
    completedMissions[missionKey][src] = true

    if completedMissions[missionKey][src] and completedMissions[missionKey][partnerId] then
        TriggerClientEvent('postman:client:bothPlayersCompleted', src)
        TriggerClientEvent('postman:client:bothPlayersCompleted', partnerId)
        completedMissions[missionKey] = nil
    else
        TriggerClientEvent('postman:client:waitingForPartner', src, GetPlayerName(partnerId) or "Partner")
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for missionKey, players in pairs(completedMissions) do
        if players[src] then completedMissions[missionKey] = nil end
    end
end)

RegisterNetEvent('postman:server:getPartnerId')
AddEventHandler('postman:server:getPartnerId', function()
    TriggerClientEvent('postman:client:receivePartnerId', source, activeGroups[source])
end)
