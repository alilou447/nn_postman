local function getPlayerIdentifier(src)
    if not src or src <= 0 then return nil end
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        if id and (string.sub(id, 1, 8) == "license:" or string.sub(id, 1, 9) == "license2:") then
            return id
        end
    end
    return identifiers[1]
end

Citizen.CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS player_levels_postman (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(50) NOT NULL UNIQUE,
            level INT NOT NULL DEFAULT 1,
            exp INT NOT NULL DEFAULT 0
        )
    ]])
end)

local function loadPlayerData(src, identifier)
    exports.oxmysql:execute(
        "SELECT level, exp FROM player_levels_postman WHERE identifier = ?",
        { identifier },
        function(result)
            if result[1] then
                TriggerClientEvent("levels:loadData", src, result[1].level, result[1].exp)
            else
                exports.oxmysql:insert(
                    "INSERT INTO player_levels_postman (identifier, level, exp) VALUES (?, ?, ?)",
                    { identifier, 1, 0 }
                )
                TriggerClientEvent("levels:loadData", src, 1, 0)
            end
        end
    )
end

RegisterNetEvent('community_bridge:Server:OnPlayerLoaded', function(loadedSrc)
    local src = tonumber(loadedSrc) or source
    local identifier = getPlayerIdentifier(src)
    if identifier then loadPlayerData(src, identifier) end
end)

AddEventHandler('playerConnecting', function()
    local src = source
    Wait(5000)
    local identifier = getPlayerIdentifier(src)
    if identifier then loadPlayerData(src, identifier) end
end)

local function getExpRequired(level)
    return 100 * (level + 1)
end

RegisterNetEvent("levels:addExp")
AddEventHandler("levels:addExp", function(amount)
    local src = source
    local identifier = getPlayerIdentifier(src)
    if not identifier then return end

    exports.oxmysql:execute(
        "SELECT level, exp FROM player_levels_postman WHERE identifier = ?",
        { identifier },
        function(result)
            if result[1] then
                local level = result[1].level
                local exp = result[1].exp + amount
                local required = getExpRequired(level)
                while exp >= required do
                    exp = exp - required
                    level = level + 1
                    required = getExpRequired(level)
                end
                exports.oxmysql:execute(
                    "UPDATE player_levels_postman SET level = ?, exp = ? WHERE identifier = ?",
                    { level, exp, identifier }
                )
                TriggerClientEvent("levels:loadData", src, level, exp)
            end
        end
    )
end)

RegisterNetEvent("levels:getExp")
AddEventHandler("levels:getExp", function()
    local src = source
    local identifier = getPlayerIdentifier(src)
    if identifier then loadPlayerData(src, identifier) end
end)

RegisterNetEvent("levels:resetPlayer")
AddEventHandler("levels:resetPlayer", function()
    local src = source
    local identifier = getPlayerIdentifier(src)
    if not identifier then return end
    exports.oxmysql:execute(
        "UPDATE player_levels_postman SET level = 1, exp = 0 WHERE identifier = ?",
        { identifier }
    )
    TriggerClientEvent("levels:loadData", src, 1, 0)
end)
