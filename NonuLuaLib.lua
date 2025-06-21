import("System.Numerics")

-- Function to pause execution until the player is no longer zoning
-- This prevents issues from mounting or moving while teleporting/loading
-- Remade from VAC_Functions' ZoneTransition() using condition helpers
function WaitForZoneChange()
    LogInfo("[NonuLuaLib] WaitForZoneChange() started")

    -- Wait until zoning actually starts
    LogInfo("[NonuLuaLib] Waiting for zoning to start...")
    repeat Sleep(0.1) until (GetCharacterCondition(45) or
        GetCharacterCondition(51))

    LogInfo(
        "[NonuLuaLib] Zoning detected! Now waiting for zoning to complete...")

    -- Wait until zoning fully completes and player is loaded
    repeat Sleep(0.1) until (not GetCharacterCondition(45) and
        not GetCharacterCondition(51) and IsPlayerAvailable())

    LogInfo("[NonuLuaLib] Zoning complete. Player is available.")
end

-- Function to sleep/wait for the specified number of seconds
-- Uses /wait wrapped so to maintain functionality.
function Sleep(seconds) yield('/wait ' .. tostring(seconds)) end

-- Function to check if a given addon is loaded and ready
-- Returns true if the addon exists and is marked as Ready
function IsAddonReady(name)
    local addon = Addons.GetAddon(name)
    return addon and addon.Exists and addon.Ready
end

-- Function to pause execution until a specific addon is ready
-- Repeatedly checks readiness using IsAddonReady and waits between each check
function WaitForAddonReady(name) repeat Sleep(0.1) until isAddonReady(name) end

-- Function to perform a case-insensitive "startsWith" string comparison
-- Allows partial name targeting similar to how /target works in-game
function stringStartsWithIgnoreCase(fullString, partialString)
    fullString = string.lower(fullString)
    partialString = string.lower(partialString)
    return string.sub(fullString, 1, #partialString) == partialString
end

-- Core targeting function to attempt acquiring a target based on name
-- Issues /target, then waits for client to update Entity.Target, validates match
-- Returns true if successful, false if target not acquired after retries
function AcquireTarget(name, maxRetries, sleepTime)
    maxRetries = maxRetries or 20 -- Default retries if not provided
    sleepTime = sleepTime or 0.1 -- Default sleep interval if not provided

    yield('/target ' .. tostring(name))

    local retries = 0
    while (Entity == nil or Entity.Target == nil) and retries < maxRetries do
        Sleep(sleepTime)
        retries = retries + 1
    end

    if Entity and Entity.Target and
        stringStartsWithIgnoreCase(Entity.Target.Name, name) then
        Entity.Target:SetAsTarget()
        LogInfo("[NonuLuaLib] Target acquired: %s [Word: %s]",
                Entity.Target.Name, name)
        return true
    else
        LogInfo("[NonuLuaLib] Failed to acquire target [%s] after %d retries",
                name, retries)
        return false
    end
end

-- Simplified function to acquire a target
-- Calls AcquireTarget and logs failure if unsuccessful
-- Usage: Target("Aetheryte"), Target("Aetheryte", 50, 0.05)
function Target(name, maxRetries, sleepTime)
    local success = AcquireTarget(name, maxRetries, sleepTime)
    if not success then LogInfo("[NonuLuaLib] Target() failed.") end
end

-- Function to interact with a target
-- Attempts to acquire target first, then issues /interact if successful
-- Usage: Interact("Aetheryte"), Interact("Antoi", 30, 0.1)
function Interact(name, maxRetries, sleepTime)
    local success = AcquireTarget(name, maxRetries, sleepTime)
    if success then
        yield('/interact')
        LogInfo("[NonuLuaLib] Interacted with: " .. Entity.Target.Name)
    else
        LogInfo("[NonuLuaLib] Interact() failed to acquire target.")
    end
end

-- Function to lazily automove for a duration, optionally towards a target
-- If name is provided, will target first, face the target, then automove
-- Usage: Automove(1), Automove(2, "Heavy Oaken Door")
function Automove(duration, name, maxRetries, sleepTime)
    if name then
        local success = AcquireTarget(name, maxRetries, sleepTime)
        if not success then
            LogInfo("[NonuLuaLib] Automove() failed to acquire target: " .. name)
            return
        end

        -- Face the target after successful targeting
        yield("/facetarget")
        Sleep(0.1) -- Give tiny moment for facing to adjust
    end

    yield("/automove")
    Sleep(duration)
    yield("/automove")

    if name then
        LogInfo("[NonuLuaLib] Automoved towards target: %s for %.1f seconds",
                name, duration)
    else
        LogInfo("[NonuLuaLib] Automoved for %.1f seconds", duration)
    end
end

-- Function to use vnavmesh IPC to pathfind and move to a XYZ coordinate.
-- Issues PathfindAndMoveTo request, waits for pathing to begin, and monitors movement.
-- Optionally stops early if player reaches specified stopDistance from destination.
-- Returns true if path completed successfully or stopped early, false if path could not start.
-- Usage: PathFindTo(-67.457, -0.502, -8.274)           -- Normal ground movement
--        PathFindTo(x, y, z, true)                     -- Flying movement
--        PathFindTo(x, y, z, false, 4.0)               -- Ground path, stop within 4.0 units
function PathFindTo(x, y, z, fly, stopDistance)
    fly = fly or false
    stopDistance = stopDistance or 0.0

    local destination = Vector3(x, y, z)

    local success = IPC.vnavmesh.PathfindAndMoveTo(destination, fly)
    if not success then
        LogInfo(
            "[NonuLuaLib] Navmesh's PathfindAndMoveTo() failed to start pathing!")
        return false
    end

    LogInfo(
        "[NonuLuaLib] Navmesh pathing has been issued to (%.3f, %.3f, %.3f)", x,
        y, z)

    local startupRetries = 0
    local maxStartupRetries = 10
    while not IPC.vnavmesh.IsRunning() and startupRetries < maxStartupRetries do
        Sleep(0.1)
        startupRetries = startupRetries + 1
    end

    if not IPC.vnavmesh.IsRunning() then
        LogInfo(
            "[NonuLuaLib] Navmesh failed to start movement after creating a path.")
        return false
    end

    -- Actively monitor movement
    while IPC.vnavmesh.IsRunning() do
        Sleep(0.1)

        if stopDistance > 0 then
            local pos = Player.Entity.Position
            local dx = pos.X - x
            local dy = pos.Y - y
            local dz = pos.Z - z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

            if dist <= stopDistance then
                IPC.vnavmesh.Stop()
                LogInfo(
                    "[NonuLuaLib] Navmesh has been stopped early at distance %.2f",
                    dist)
                break
            end
        end
    end

    LogInfo("[NonuLuaLib] Navmesh is done pathing")
    return true
end

-- Function to find nearest object by name substring (case-insensitive)
function FindNearestObjectByName(targetName)
    local player = Svc.ClientState.LocalPlayer
    local closestObject = nil
    local closestDistance = math.huge

    for i = 0, Svc.Objects.Length - 1 do
        local obj = Svc.Objects[i]
        if obj then
            local name = obj.Name.TextValue
            if name and string.find(string.lower(name), string.lower(targetName)) then
                local distance = GetDistance(obj.Position, player.Position)
                if distance < closestDistance then
                    closestDistance = distance
                    closestObject = obj
                end
            end
        end
    end

    if closestObject then
        local name = closestObject.Name.TextValue
        local pos = closestObject.Position
        LogInfo("[NonuLuaLib] Found nearest '%s': %s (%.2f units) | XYZ: (%.3f, %.3f, %.3f)",
            targetName, name, closestDistance, pos.X, pos.Y, pos.Z)
    else
        LogInfo("[NonuLuaLib] No object matching '%s' found nearby.", targetName)
    end

    return closestObject, closestDistance
end




-- Function to pathfind directly to an entity by name
-- Looks up the entity, retrieves its position, and calls PathFindTo()
-- Usage: PathToObject("Summoning Bell"), PathToObject("Retainer Vocate", false, 4.0)
---  function PathToObject(entityName, fly, stopDistance)
---     fly = fly or false
---    stopDistance = stopDistance or 0.0
--- 
---     local targetEntity = Entity.GetEntityByName(entityName)
---     if not targetEntity then
---         LogInfo("[NonuLuaLib] Entity '%s' not found!", entityName)
---         return false
---     end
--- 
---     local pos = targetEntity.Position
---     LogInfo("[NonuLuaLib] Pathing to entity '%s' at (%.3f, %.3f, %.3f)", entityName, pos.X, pos.Y, pos.Z)
--- 
---     return PathFindTo(pos.X, pos.Y, pos.Z, fly, stopDistance)
--- end

-- Function to pathfind directly to an entity by name
-- Looks up the entity, retrieves its position, and calls PathFindTo()
-- Usage: PathToObject("Summoning Bell"), PathToObject("Retainer Vocate", false, 4.0)
function PathToObject(targetName, fly, stopDistance)
    fly = fly or false
    stopDistance = stopDistance or 0.0

    local obj, dist = FindNearestObjectByName(targetName)
    if obj then
        local name = obj.Name.TextValue
        local pos = obj.Position

        LogInfo(
            "[NonuLuaLib] Pathing to nearest '%s': %s (%.2f units) at (%.3f, %.3f, %.3f)", targetName, name, dist, pos.X, pos.Y, pos.Z)

        return PathFindTo(pos.X, pos.Y, pos.Z, fly, stopDistance)
    else
        LogInfo("[NonuLuaLib] Could not find '%s' nearby.", targetName)
        return false
    end
end

-- =================================================================================== --
-- =====================   UTILITIES AND SIMPLE WRAPPERS   =========================== --
-- =================================================================================== --

-- Helper to get current zone ID
function ZoneID() return Svc.ClientState.TerritoryType end

-- Player or self conditions service wrapper, use to check your conditions, usually always a number
function GetCharacterCondition(index)
    if index then
        return Svc.Condition[index]
    else
        return Svc.Condition
    end
end

-- Player.Available wrapper, use to check if player is available (e.g. cutscenes, loading zones.)
function IsPlayerAvailable() return Player.Available end

-- Player.Entity.IsCasting wrapper, use to check if player is casting (e.g. using spells,)
function IsPlayerCasting() return Player.Entity and Player.Entity.IsCasting end

-- Simply /echo wrapper with passage for numbers, and booleans, etc.
function Echo(msg) yield(string.format("/echo %s", tostring(msg))) end

function WaitForLifestream()
    local hasLoggedLifestream = false
    while IPC.Lifestream.IsBusy() do
        if not hasLoggedLifestream then
            LogInfo("[NonuLuaLib] Waiting for Lifestream")
            hasLoggedLifestream = true
        end
        Sleep(0.1)
    end
    LogInfo("[NonuLuaLib] Lifestream is done")
end

-- Function for using effectively Lifestream's commands to do things, while also waiting for it to complete.
function Lifestream(command)
    LogInfo("[NonuLuaLib] Lifestream executing command '%s'", command)
    IPC.Lifestream.ExecuteCommand(command)
    WaitForLifestream()
end

-- Function for waiting for Navmesh to complete, usually called after Navmesh function, as to optimize actions during.
function WaitForNavmesh()
    local hasLoggedNavmesh = false
    while IPC.vnavmesh.IsRunning() do
        if not hasLoggedNavmesh then
            LogInfo("[NonuLuaLib] Navmesh is running")
            hasLoggedNavmesh = true
        end
        Sleep(0.1)
    end
    LogInfo("[NonuLuaLib] Navmesh is done")
end

-- Function to calculate distance between two positions
function GetDistance(pos1, pos2)
    local dx = pos1.X - pos2.X
    local dy = pos1.Y - pos2.Y
    local dz = pos1.Z - pos2.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- =================================================================================== --
-- =====================       DALAMUD.LOG DISPENSER       =========================== --
-- =================================================================================== --

-- Log levels defined
local LogLevel = {Info = "Info", Debug = "Debug", Verbose = "Verbose"}

-- Core log function with formatting support
function Log(msg, level, ...)
    level = level or LogLevel.Info

    -- Auto format if additional arguments provided
    if select("#", ...) > 0 then msg = string.format(msg, ...) end

    if level == LogLevel.Info then
        Dalamud.Log(msg)
    elseif level == LogLevel.Debug then
        Dalamud.LogDebug(msg)
    elseif level == LogLevel.Verbose then
        Dalamud.LogVerbose(msg)
    else
        Dalamud.Log("[UNKNOWN LEVEL] " .. msg)
    end
end

-- Sugar functions for easy usage
function LogInfo(msg, ...) Log(msg, LogLevel.Info, ...) end

function LogDebug(msg, ...) Log(msg, LogLevel.Debug, ...) end

function LogVerbose(msg, ...) Log(msg, LogLevel.Verbose, ...) end

