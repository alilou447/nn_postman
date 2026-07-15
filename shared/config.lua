Config = {}

-- ============================================================
-- nn_postman Configuration
-- Uses Community Bridge (QBCore, ESX, QBox, etc.)
-- ============================================================

Config.ReputationMultiplier = 0.1
Config.MultiplayerMultiplier = 1.5
Config.BaseReputationReward = 50

-- GO Postal depot — job board + map blip
Config.job_search_zone = vector3(-424.56, -2789.79, 6.00)
Config.depotVanCoords = vector4(-431.15, -2788.48, 6.00, 315.0)

Config.MoneyType = "bank"
Config.BlipName = "Postman Job"
Config.Debug = true

-- Route planning minigame (shortest-path puzzle before deliveries begin)
Config.RouteMinigame = {
    enabled = true,
    distanceTolerance = 1.0, -- meters; player's route must match optimal within this margin
    skipForInvitee = true,    -- partner follows leader's solved route order
    urgentMin = 1,            -- minimum urgent mail stops per mission
    urgentMax = 2,            -- maximum urgent mail stops per mission
    challengingStops = true,  -- pick stops where a simple "circle" route is NOT optimal
    minCircleTrapMeters = 60, -- prefer sets where going around in a ring wastes at least this much
}

Config.PostVanModel = "boxville2"
Config.PostVanEngineAudio = "BISON"
Config.PostVanEngineAudioCandidates = {
    "BISON", "MULE", "MULE2", "SPEEDO", "SPEEDO2", "YOUGA", "YOUGA2",
}

Config.PropGroundOffsetZ = 0.05

-- Client spawns a visible mailbox at each stop when you get close.
Config.SpawnDeliveryProps = true
Config.ServerSpawnProps = false
Config.DeliveryZoneSize = 5.0
Config.DeliveryZoneDistance = 6.0
Config.DepotReturnRadius = 18.0
Config.DeliveriesPerStop = 1

-- Delivery stop types (creative interactions per stop):
--   mailbox    — quick letter drop in roadside mailbox
--   door_knock — knock, resident answers, hand over mail
--   package    — heavy box carry from van to porch
--   cluster    — apartment cluster box, sort letter into slot
--   registered — signature on clipboard
--   newspaper  — toss rolled paper onto porch
--   dog_yard   — wait for dog to calm, then deliver
Config.StopTypesByMission = {
    [1] = { "mailbox", "door_knock", "package", "cluster", "registered" },
    [2] = { "newspaper", "mailbox", "door_knock", "package", "registered" },
    [3] = { "door_knock", "dog_yard", "package", "cluster", "registered" },
    [4] = { "mailbox", "newspaper", "door_knock", "cluster", "registered" },
    [5] = { "dog_yard", "mailbox", "package", "newspaper", "registered" },
    [6] = { "cluster", "door_knock", "dog_yard", "package", "registered" },
    [7] = { "mailbox", "newspaper", "door_knock", "cluster", "registered" },
    [8] = { "door_knock", "package", "dog_yard", "mailbox", "registered" },
    [9] = { "newspaper", "cluster", "door_knock", "package", "registered" },
}

-- Same outdoor roadside coords as nn_garbagejob dumpster stops (verified on the street).
-- Delivery zones + mailbox props spawn at these coords when you arrive.
Config.DeliveryStops = {
    -- Los Santos — difficulty "1"
    [1] = {
        vector4(-749.25, -2070.08, 7.915, 230.51),
        vector4(-968.27, -2116.51, 8.325, 138.27),
        vector4(-1002.53, -2225.14, 8.015, 315.2),
        vector4(-823.22, -2385.56, 13.595, 112.98),
        vector4(-859.35, -2326.41, 12.985, 340.05),
    },
    -- Los Santos — difficulty "2"
    [2] = {
        vector4(-444.14, -1699.41, 17.985, 67.94),
        vector4(-333.91, -1527.7, 26.575, 92.25),
        vector4(-223.88, -1379.23, 30.285, 304.75),
        vector4(-57.02, -1692.87, 28.515, 137.1),
        vector4(-30.98, -1742.79, 28.355, 144.9),
    },
    -- Los Santos — difficulty "3"
    [3] = {
        vector4(-634.71, -1657.97, 24.855, 153.38),
        vector4(-663.59, -1207.17, 9.655, 295.94),
        vector4(-719.92, -1140.5, 9.635, 300.52),
        vector4(-731.82, -1064.69, 11.355, 209.65),
        vector4(-696.59, -1102.83, 13.555, 31.78),
    },
    -- Sandy Shores — difficulty "1"
    [4] = {
        vector4(1982.79, 3784.74, 31.205, 31.39),
        vector4(1882.15, 3757.87, 31.935, 28.71),
        vector4(1717.16, 3783.94, 33.655, 16.26),
        vector4(1624.79, 3560.91, 34.295, 121.98),
        vector4(1481.74, 3579.68, 34.295, 123.57),
    },
    -- Sandy Shores — difficulty "2"
    [5] = {
        vector4(1964.21, 3833.77, 31.035, 129.24),
        vector4(1559.04, 3796.6, 33.135, 26.74),
        vector4(1434.85, 3735.51, 31.985, 270.11),
        vector4(980.8, 3623.65, 31.315, 180.39),
        vector4(925.84, 3662.9, 31.605, 353.57),
    },
    -- Sandy Shores — difficulty "3"
    [6] = {
        vector4(2484.47, 4124.44, 37.085, 65.36),
        vector4(2462.02, 4077.97, 37.085, 64.73),
        vector4(1975.38, 3714.07, 31.095, 267.62),
        vector4(1769.92, 3650.78, 33.465, 209.09),
        vector4(1576.06, 3527.87, 34.745, 13.99),
    },
    -- Paleto Bay — difficulty "1"
    [7] = {
        vector4(2704.99, 3454.03, 54.675, 339.64),
        vector4(1714.06, 6421.94, 31.855, 337.19),
        vector4(1462.39, 6550.25, 13.325, 271.85),
        vector4(402.85, 6628.98, 27.265, 67.33),
        vector4(205.97, 6587.8, 30.685, 271.7),
    },
    -- Paleto Bay — difficulty "2"
    [8] = {
        vector4(202.87, 6608.37, 30.665, 275.59),
        vector4(98.41, 6636.63, 30.465, 315.44),
        vector4(18.33, 6665.9, 30.555, 0.4),
        vector4(-56.14, 6624.85, 28.945, 36.47),
        vector4(-120.31, 6571.68, 28.545, 44.54),
    },
    -- Paleto Bay — difficulty "3"
    [9] = {
        vector4(-184.91, 6436.63, 30.545, 225.54),
        vector4(-356.81, 6331.91, 28.855, 42.43),
        vector4(-431.32, 6264.66, 29.375, 81.95),
        vector4(-368.92, 6132.23, 30.465, 221.9),
        vector4(-420.68, 6129.6, 30.505, 38.69),
    },
}

for missionId, stops in pairs(Config.DeliveryStops) do
    Config["DeliveryStop" .. missionId] = stops[1]
    for stopIndex = 2, #stops do
        Config["DeliveryStop" .. missionId .. "_" .. (stopIndex - 1)] = stops[stopIndex]
    end
end

-- Each region has 15 outdoor stops (3 routes x 5). Every mission picks 5 random points from its region pool.
Config.StopsPerMission = 5

Config.RegionMissionIds = {
    los_santos = { 1, 2, 3 },
    sandy_shores = { 4, 5, 6 },
    paleto_bay = { 7, 8, 9 },
}

Config.RegionStopPools = {}

for regionId, missionIds in pairs(Config.RegionMissionIds) do
    local pool = {}
    for _, missionId in ipairs(missionIds) do
        local stops = Config.DeliveryStops[missionId]
        if stops then
            for i = 1, #stops do
                pool[#pool + 1] = stops[i]
            end
        end
    end
    Config.RegionStopPools[regionId] = pool
end

function Postman_PickRandomMissionStops(pool, count)
    count = count or Config.StopsPerMission or 5
    if not pool or #pool == 0 then
        return {}
    end

    count = math.min(count, #pool)
    local indices = {}
    for i = 1, #pool do
        indices[i] = i
    end

    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    local picked = {}
    for i = 1, count do
        picked[i] = pool[indices[i]]
    end
    return picked
end

local function Postman_StopXY(coords)
    return coords.x, coords.y, coords.z or 0.0
end

local function Postman_StopDistance(a, b)
    local ax, ay, az = Postman_StopXY(a)
    local bx, by, bz = Postman_StopXY(b)
    local dx = ax - bx
    local dy = ay - by
    local dz = az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function Postman_RouteDistanceForPick(depot, stops, order)
    if not depot or not stops or not order or #order == 0 then
        return math.huge
    end

    local total = Postman_StopDistance(depot, stops[order[1]])
    for i = 1, #order - 1 do
        total = total + Postman_StopDistance(stops[order[i]], stops[order[i + 1]])
    end
    total = total + Postman_StopDistance(stops[order[#order]], depot)
    return total
end

local function Postman_SolveShortestRouteForPick(depot, stops)
    local count = #stops
    if count == 0 then
        return {}, 0.0
    end

    local order = {}
    for i = 1, count do
        order[i] = i
    end

    local bestDist = math.huge
    local bestOrder = {}

    local function permute(left)
        if left > count then
            local total = Postman_RouteDistanceForPick(depot, stops, order)
            if total < bestDist then
                bestDist = total
                for i = 1, count do
                    bestOrder[i] = order[i]
                end
            end
            return
        end

        for i = left, count do
            order[left], order[i] = order[i], order[left]
            permute(left + 1)
            order[left], order[i] = order[i], order[left]
        end
    end

    permute(1)
    return bestOrder, bestDist
end

local function Postman_GetCircleRouteOrder(depot, stops)
    local ranked = {}
    for i = 1, #stops do
        local stop = stops[i]
        ranked[i] = {
            id = i,
            angle = math.atan(stop.y - depot.y, stop.x - depot.x),
        }
    end

    table.sort(ranked, function(a, b)
        return a.angle < b.angle
    end)

    local order = {}
    for i = 1, #ranked do
        order[i] = ranked[i].id
    end
    return order
end

local function Postman_BuildStopCombinations(pool, count, startIndex, current, results)
    if #current == count then
        local combo = {}
        for i = 1, count do
            combo[i] = current[i]
        end
        results[#results + 1] = combo
        return
    end

    for i = startIndex, #pool - (count - #current) + 1 do
        current[#current + 1] = pool[i]
        Postman_BuildStopCombinations(pool, count, i + 1, current, results)
        current[#current] = nil
    end
end

function Postman_PickChallengingMissionStops(pool, count, depot)
    count = count or Config.StopsPerMission or 5
    if not pool or #pool < count or not depot then
        return Postman_PickRandomMissionStops(pool, count)
    end

    local cfg = Config.RouteMinigame or {}
    if cfg.challengingStops == false then
        return Postman_PickRandomMissionStops(pool, count)
    end

    local minTrap = cfg.minCircleTrapMeters or 60
    local combinations = {}
    Postman_BuildStopCombinations(pool, count, 1, {}, combinations)

    local qualifying = {}
    local bestTrap = -1.0
    local bestPick = nil

    for i = 1, #combinations do
        local stops = combinations[i]
        local _, optimalDist = Postman_SolveShortestRouteForPick(depot, stops)
        local circleOrder = Postman_GetCircleRouteOrder(depot, stops)
        local circleDist = Postman_RouteDistanceForPick(depot, stops, circleOrder)
        local trap = circleDist - optimalDist

        if trap > bestTrap then
            bestTrap = trap
            bestPick = stops
        end

        if trap >= minTrap then
            qualifying[#qualifying + 1] = stops
        end
    end

    if #qualifying > 0 then
        return qualifying[math.random(#qualifying)]
    end

    if bestPick then
        return bestPick
    end

    return Postman_PickRandomMissionStops(pool, count)
end

Config.MissionRewards = {
    los_santos = {
        ["1"] = 8500,
        ["2"] = 22000,
        ["3"] = 28000,
    },
    sandy_shores = {
        ["1"] = 18000,
        ["2"] = 35000,
        ["3"] = 45000,
    },
    paleto_bay = {
        ["1"] = 55000,
        ["2"] = 70000,
        ["3"] = 85000,
    },
}

Config.Rewards = {
    Items = {
        enabled = false,
        list = {
            { name = "water_bottle", chance = 30, min = 1, max = 2 },
            { name = "sandwich", chance = 15, min = 1, max = 1 },
        }
    }
}

local function buildRoute(missionNum)
    local n = missionNum
    return {
        vanCoords = Config.depotVanCoords,
        deliveryArea = Config["DeliveryStop" .. n],
        deliveryArea1 = Config["DeliveryStop" .. n .. "_1"],
        deliveryArea2 = Config["DeliveryStop" .. n .. "_2"],
        deliveryArea3 = Config["DeliveryStop" .. n .. "_3"],
        deliveryArea4 = Config["DeliveryStop" .. n .. "_4"],
        stopTypes = Config.StopTypesByMission[n] or Config.StopTypesByMission[1],
    }
end

Config.MissionRoutesLosSantos = {
    ["1"] = buildRoute(1),
    ["2"] = buildRoute(2),
    ["3"] = buildRoute(3),
}

Config.MissionRoutesLosSantosInvitee = {
    ["1"] = buildRoute(1),
    ["2"] = buildRoute(2),
    ["3"] = buildRoute(3),
}

Config.MissionRoutesSandyShores = {
    ["1"] = buildRoute(4),
    ["2"] = buildRoute(5),
    ["3"] = buildRoute(6),
}

Config.MissionRoutesPaletoBay = {
    ["1"] = buildRoute(7),
    ["2"] = buildRoute(8),
    ["3"] = buildRoute(9),
}

-- Labels shown during delivery interactions
Config.StopTypeLabels = {
    mailbox = "Drop Letter in Mailbox",
    door_knock = "Knock & Deliver",
    package = "Deliver Heavy Package",
    cluster = "Sort into Cluster Box",
    registered = "Collect Signature",
    newspaper = "Toss Newspaper",
    dog_yard = "Deliver Past Dog",
}

Config.StopTypeHints = {
    mailbox = "~b~Slide the letter into the mailbox.",
    door_knock = "~b~Knock on the door and hand over the mail.",
    package = "~b~Carry the heavy package to the porch.",
    cluster = "~b~Sort the letter into the cluster mailbox slot.",
    registered = "~b~Get the recipient's signature on the form.",
    newspaper = "~b~Toss the rolled paper onto the porch.",
    dog_yard = "~b~Wait for the dog to settle, then deliver quickly!",
}
