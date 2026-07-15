local pendingInviteFrom = nil
local inviteExpiresAt = 0
local inviteAccepted = false
local currentInvitedPlayer = nil
local wasInviter = false
local inviteKeyListenerActive = true

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        inviteKeyListenerActive = false
    end
end)

RegisterNetEvent('receiveInvite', function(fromId, timeout)
    if inviteAccepted then return end
    pendingInviteFrom = fromId
    inviteExpiresAt = GetGameTimer() + (timeout or 10000)
    ShowNotification("Invite from " .. (GetPlayerName(GetPlayerFromServerId(fromId)) or fromId) .. ". Press Y to accept or N to decline.")
end)

CreateThread(function()
    while inviteKeyListenerActive do
        if pendingInviteFrom then
            Wait(0)
            if GetGameTimer() < inviteExpiresAt then
                if IsControlJustPressed(0, 246) then
                    TriggerServerEvent("inviteResponse", pendingInviteFrom, true)
                    inviteAccepted = true
                    pendingInviteFrom = nil
                elseif IsControlJustPressed(0, 249) then
                    TriggerServerEvent("inviteResponse", pendingInviteFrom, false)
                    pendingInviteFrom = nil
                end
            else
                ShowNotification("Invite expired.")
                pendingInviteFrom = nil
            end
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('inviteAccepted', function(playerId)
    ShowNotification("Player " .. (GetPlayerName(GetPlayerFromServerId(playerId)) or playerId) .. " accepted your invite.")
end)

RegisterNetEvent('inviteDeclined', function(playerId)
    ShowNotification("Player " .. (GetPlayerName(GetPlayerFromServerId(playerId)) or playerId) .. " declined your invite.")
end)

RegisterNetEvent('updateInviterUI', function(playerInfo)
    currentInvitedPlayer = playerInfo
    wasInviter = true
    SendNUIMessage({ action = "updateInvitedPlayer", data = playerInfo })
end)

RegisterNetEvent('updateInviteeUI', function(playerInfo)
    currentInvitedPlayer = playerInfo
    wasInviter = false
    SendNUIMessage({ action = "updateInvitedPlayer", data = playerInfo })
end)

function ShowNotification(text)
    local displayTime = 10000
    local startTime = GetGameTimer()
    CreateThread(function()
        while (GetGameTimer() - startTime) < displayTime do
            Wait(0)
            SetTextFont(6)
            SetTextProportional(1)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString(text)
            DrawText(0.350, 0.95)
        end
    end)
end

RegisterNUICallback('invite', function(data, cb)
    TriggerServerEvent('sendInvite', data.targetId)
    cb({})
end)

RegisterNUICallback('leaveGroup', function(data, cb)
    TriggerServerEvent('leaveGroup', currentInvitedPlayer)
    inviteAccepted = false
    currentInvitedPlayer = nil
    SendNUIMessage({ action = "updateInvitedPlayer", data = nil })
    cb({})
end)

RegisterNetEvent('playerLeftGroup', function(playerInfo)
    ShowNotification("Player " .. playerInfo.name .. " left the group.")
    inviteAccepted = false
    currentInvitedPlayer = nil
    SendNUIMessage({ action = "updateInvitedPlayer", data = nil })
end)

exports('GetGroupInfo', function()
    return {
        wasInviter = wasInviter,
        currentInvitedPlayer = currentInvitedPlayer,
        inviteAccepted = inviteAccepted
    }
end)
