import("System.Numerics")

-- Constants for common game conditions
local CONDITION_ZONING = 45 -- Zoning related condition.
local CONDITION_ZONING_51 = 51 -- Zoning 51, No idea why it's 51.
local CONDITION_MOUNTED = 4 -- Player is considered mounted
local CONDITION_STEALTHED = 46 -- PLayer is considered stealthed
local CONDITION_CARRYING_OBJECT = 9 -- Player is considered holding an object.

-- Function to pause execution until the player is no longer zoning.
-- This prevents issues from mounting or moving while teleporting/loading.
-- Remade from VAC_Functions' ZoneTransition() using condition helpers.
-- Parameters: None
-- Returns: None
function WaitForZoneChange()
    LogInfo("[NonuLuaLib] WaitForZoneChange() started")

    -- Wait until zoning actually starts
    LogInfo("[NonuLuaLib] Waiting for zoning to start...")
    repeat Sleep(0.1) until (GetCharacterCondition(CONDITION_ZONING) or
        GetCharacterCondition(CONDITION_ZONING_51))

    LogInfo(
        "[NonuLuaLib] Zoning detected! Now waiting for zoning to complete...")

    -- Wait until zoning fully completes and player is loaded
    repeat Sleep(0.1) until (not GetCharacterCondition(CONDITION_ZONING) and
        not GetCharacterCondition(CONDITION_ZONING_51) and IsPlayerAvailable())

    LogInfo("[NonuLuaLib] Zoning complete. Player is available.")
end

-- Function to pause script execution for a specified number of seconds.
-- Internally uses the game's '/wait' command to maintain functionality within the game's coroutine system.
-- Parameters:
--   seconds (number): The duration in seconds to pause execution.
-- Returns: None
function Sleep(seconds) yield('/wait ' .. tostring(seconds)) end

-- Function to check if a specific game addon is loaded and ready.
-- Returns true if the addon exists and is marked as Ready.
-- Parameters:
--   name (string): The exact name of the addon to check.
-- Returns: boolean - True if the addon is ready, false otherwise.
function IsAddonReady(name)
    local addon = Addons.GetAddon(name)
    return addon and addon.Exists and addon.Ready
end

-- Function to pause execution until a specific game addon is loaded and ready.
-- Repeatedly checks readiness using IsAddonReady and waits between each check.
-- Parameters:
--   name (string): The exact name of the addon to wait for.
-- Returns: None
function WaitForAddonReady(name) repeat Sleep(0.1) until IsAddonReady(name) end

-- Function to perform a case-insensitive "startsWith" string comparison.
-- This allows for partial name matching, similar to how '/target' works in-game.
-- Parameters:
--   fullString (string): The string to search within.
--   partialString (string): The substring to check if the fullString starts with.
-- Returns: boolean - True if fullString starts with partialString (case-insensitive), false otherwise.
function StringStartsWithIgnoreCase(fullString, partialString)
    fullString = string.lower(fullString)
    partialString = string.lower(partialString)
    return string.sub(fullString, 1, #partialString) == partialString
end

-- Core targeting function to attempt acquiring a target based on its name.
-- Issues the '/target' command, then waits for the client to update Entity.Target,
-- and validates if the acquired target's name matches the requested name (case-insensitive, starts with).
-- Parameters:
--   name (string): The name or partial name of the target to acquire.
--   maxRetries (number, optional): The maximum number of times to retry acquiring the target. Defaults to 20.
--   sleepTime (number, optional): The time in seconds to wait between retries. Defaults to 0.1.
-- Returns: boolean - True if the target is successfully acquired and validated, false otherwise.
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
        StringStartsWithIgnoreCase(Entity.Target.Name, name) then
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

-- Simplified function to acquire a target using the default retry settings.
-- Calls AcquireTarget and logs a generic failure message if unsuccessful.
-- Parameters:
--   name (string): The name or partial name of the target to acquire.
--   maxRetries (number, optional): See AcquireTarget.
--   sleepTime (number, optional): See AcquireTarget.
-- Returns: None (logs success/failure internally)
-- Usage:
--   Target("Aetheryte")
--   Target("Aetheryte", 50, 0.05) -- Custom retries and sleep
function Target(name, maxRetries, sleepTime)
    local success = AcquireTarget(name, maxRetries, sleepTime)
    if not success then LogInfo("[NonuLuaLib] Target() failed.") end
end

-- Function to interact with a target.
-- Attempts to acquire the target first, then issues the '/interact' command if successful.
-- Parameters:
--   name (string): The name or partial name of the target to interact with.
--   maxRetries (number, optional): See AcquireTarget.
--   sleepTime (number, optional): See AcquireTarget.
-- Returns: None (logs success/failure internally)
-- Usage:
--   Interact("Aetheryte")
--   Interact("Antoi", 30, 0.1) -- Custom retries and sleep
function Interact(name, maxRetries, sleepTime)
    local success = AcquireTarget(name, maxRetries, sleepTime)
    if success then
        yield('/interact')
        LogInfo("[NonuLuaLib] Interacted with: " .. Entity.Target.Name)
    else
        LogInfo("[NonuLuaLib] Interact() failed to acquire target.")
    end
end

-- Function to lazily automove for a specified duration, optionally towards a specific target.
-- If a target name is provided, it will first attempt to target it, then face it,
-- and finally initiate automove.
-- Parameters:
--   duration (number): The duration in seconds to automove.
--   name (string, optional): The name or partial name of an object/entity to target and face before automoving.
--   maxRetries (number, optional): See AcquireTarget (used if 'name' is provided).
--   sleepTime (number, optional): See AcquireTarget (used if 'name' is provided).
-- Returns: None
-- Usage:
--   Automove(1) -- Automove for 1 second without targeting
--   Automove(2, "Heavy Oaken Door") -- Automove towards "Heavy Oaken Door" for 2 seconds
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
    yield("/automove") -- Stop automove

    if name then
        LogInfo("[NonuLuaLib] Automoved towards target: %s for %.1f seconds",
                name, duration)
    else
        LogInfo("[NonuLuaLib] Automoved for %.1f seconds", duration)
    end
end

-- Function to use vnavmesh IPC (Inter-Process Communication) to pathfind and move to a 3D XYZ coordinate.
-- Issues a PathfindAndMoveTo request, waits for pathing to begin, and actively monitors movement.
-- Optionally stops early if the player reaches a specified stopDistance from the destination.
-- Parameters:
--   x (number): The X-coordinate of the destination.
--   y (number): The Y-coordinate of the destination.
--   z (number): The Z-coordinate of the destination.
--   fly (boolean, optional): True to attempt flying movement, false for ground movement. Defaults to false.
--   stopDistance (number, optional): The distance from the destination (in units) at which to stop early. Defaults to 0.0.
-- Returns: boolean - True if pathing completed successfully or was stopped early, false if pathing could not start.
-- Usage:
--   Movement(-67.457, -0.502, -8.274)                  -- Normal ground movement
--   Movement(x, y, z, true)                            -- Flying movement
--   Movement(x, y, z, false, 4.0)                      -- Ground path, stop within 4.0 units
function Movement(x, y, z, fly, stopDistance)
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

-- Function to find the nearest game object to the player by a case-insensitive substring of its name.
-- Iterates through all loaded objects in the game world.
-- Parameters:
--   targetName (string): The partial or full name of the object to search for.
-- Returns:
--   obj (table/object): The found game object (an Entity or similar type), or nil if not found.
--   distance (number): The distance to the found object, or math.huge if not found.
function FindNearestObjectByName(targetName)
    local player = Svc.ClientState.LocalPlayer
    local closestObject = nil
    local closestDistance = math.huge

    for i = 0, Svc.Objects.Length - 1 do
        local obj = Svc.Objects[i]
        if obj then
            local name = obj.Name.TextValue
            if name and
                string.find(string.lower(name), string.lower(targetName)) then
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
        LogInfo(
            "[NonuLuaLib] Found nearest '%s': %s (%.2f units) | XYZ: (%.3f, %.3f, %.3f)",
            targetName, name, closestDistance, pos.X, pos.Y, pos.Z)
    else
        LogInfo("[NonuLuaLib] No object matching '%s' found nearby.", targetName)
    end

    return closestObject, closestDistance
end

-- Function to pathfind directly to a detected game entity (object) by its name.
-- It first uses FindNearestObjectByName to locate the entity, then retrieves its position
-- and calls the Movement() function to navigate to it.
-- Parameters:
--   targetName (string): The name or partial name of the entity to path to.
--   fly (boolean, optional): True to attempt flying movement, false for ground movement. Defaults to false.
--   stopDistance (number, optional): The distance from the target entity (in units) at which to stop early. Defaults to 0.0.
-- Returns: boolean - True if pathing completed successfully or was stopped early, false if the entity could not be found or pathing failed to start.
-- Usage:
--   PathToObject("Summoning Bell")                     -- Path to nearest "Summoning Bell" on ground, stop at 0.0 units
--   PathToObject("Retainer Vocate", false, 4.0)        -- Path to "Retainer Vocate" on ground, stop within 4.0 units
function PathToObject(targetName, fly, stopDistance)
    fly = fly or false
    stopDistance = stopDistance or 0.0

    local obj, dist = FindNearestObjectByName(targetName)
    if obj then
        local name = obj.Name.TextValue
        local pos = obj.Position

        LogInfo(
            "[NonuLuaLib] Pathing to nearest '%s': %s (%.2f units) at (%.3f, %.3f, %.3f)",
            targetName, name, dist, pos.X, pos.Y, pos.Z)

        return Movement(pos.X, pos.Y, pos.Z, fly, stopDistance)
    else
        LogInfo("[NonuLuaLib] Could not find '%s' nearby.", targetName)
        return false
    end
end

-- =================================================================================== --
-- =====================        UTILITIES AND SIMPLE WRAPPERS      =================== --
-- =================================================================================== --

-- Helper function to retrieve the current game zone ID.
-- Parameters: None
-- Returns: number - The current territory/zone ID.
function ZoneID() return Svc.ClientState.TerritoryType end

-- Wrapper function to check player or self conditions.
-- Can return a specific condition by index or all conditions if no index is provided.
-- Parameters:
--   index (number, optional): The numerical index of the character condition to check.
-- Returns: boolean (if index provided) or table (if no index) - The state of the condition(s).
function GetCharacterCondition(index)
    if index then
        return Svc.Condition[index]
    else
        return Svc.Condition
    end
end

-- Function to check if the player character is currently available for actions,
-- offering different levels of readiness checks based on the 'mode' parameter.
-- Parameters:
--   mode (string, optional): Specifies the type of availability check to perform.
--     - nil (no argument provided): Returns true if Player.Available is true.
--     - "NotBusy": Returns true if Player.Available is true AND Player.IsBusy is false.
--     - "Really": Returns true if Player.Available is true, Player.IsBusy is false,
--                 AND specific character conditions (45, 51, 33, 35) are NOT active.
-- Returns: boolean - True if the player meets the specified availability criteria, false otherwise.
function IsPlayerAvailable(mode)
    if mode == nil then
        -- Default behavior: Just check if the player is available in the game world.
        return Player.Available
    elseif mode == "NotBusy" then
        -- Checks if the player is available and explicitly NOT busy.
        return Player.Available and not Player.IsBusy
    elseif mode == "Really" then
        -- Checks for Player.Available, NOT busy, and absence of specific character conditions.
        return Player.Available and not Player.IsBusy and
                   not GetCharacterCondition(45) and
                   not GetCharacterCondition(51) and
                   not GetCharacterCondition(33) and
                   not GetCharacterCondition(35)
    else
        -- Handles an unrecognized mode, logs an error, and returns false.
        LogInfo("[NonuLuaLib] IsPlayerAvailable called with invalid mode: " ..
                    tostring(mode))
        return false
    end
end

-- Wrapper function to check if the player character is currently casting a spell or ability.
-- Parameters: None
-- Returns: boolean - True if the player is casting, false otherwise.
function IsPlayerCasting() return Player.Entity and Player.Entity.IsCasting end

-- Simple wrapper function to output a message to the in-game chat or console using the '/echo' command.
-- Converts any input message to a string.
-- Parameters:
--   msg (any): The message to be echoed. Can be a string, number, boolean, etc.
-- Returns: None
function Echo(msg) yield(string.format("/echo %s", tostring(msg))) end

-- Function to pause execution until the Lifestream IPC system indicates it is no longer busy.
-- Lifestream is assumed to be an external plugin or system.
-- Parameters: None
-- Returns: None
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

-- Function for executing a command via Lifestream IPC and waiting for its completion.
-- Parameters:
--   command (string): The command string to execute through Lifestream.
-- Returns: None
function Lifestream(command)
    LogInfo("[NonuLuaLib] Lifestream executing command '%s'", command)
    IPC.Lifestream.ExecuteCommand(command)
    WaitForLifestream()
end

-- Function for waiting for vnavmesh IPC to complete its current pathing operation.
-- This is usually called after initiating a Navmesh movement function to optimize subsequent actions.
-- Parameters: None
-- Returns: None
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

-- Function to calculate the Euclidean distance between two 3D positions (Vector3 objects).
-- Parameters:
--   pos1 (Vector3): The first 3D position.
--   pos2 (Vector3): The second 3D position.
-- Returns: number - The calculated distance between the two points.
function GetDistance(pos1, pos2)
    local dx = pos1.X - pos2.X
    local dy = pos1.Y - pos2.Y
    local dz = pos1.Z - pos2.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Function for starting and then checking if AutoRetainer is busy during Expert Delivery continunation.
function AutoRetainerDelivery()
    IPC.AutoRetainer.EnqueueInitiation() -- Start the initiation process
    LogInfo("[NonuLuaLib] AutoRetainer is starting Expert Delivery")
    while IPC.AutoRetainer.IsBusy() do
        Sleep(0.1) -- Loop until the AutoRetainer is no longer busy
    end
    LogInfo("[NonuLuaLib] AutoRetainer is done with Expert Delivery")
end

-- Sets the state of a specified Automaton tweak and confirms the change.
-- Parameters:
--    tweakName: The INTERNAL tweak name as found in the BundleofTweaks repo.
--    state: Either set to `true` or `false`, if you have none set, it will toggle between true or false instead.
-- Returns: None
function Automaton(tweakName, state)
    local maxAttempts = 200
    local attempt = 0

    -- Determine the target state if 'state' is not provided
    local targetState
    if state == nil then
        -- If 'state' is nil (not provided), get the current state and toggle it
        local currentState = IPC.Automaton.IsTweakEnabled(tweakName)
        targetState = not currentState -- Toggle the current state (true becomes false, false becomes true)
        LogInfo("[NonuLuaLib] Toggling " .. tweakName .. " from " .. tostring(currentState) .. " to " .. tostring(targetState))
    else
        -- If 'state' is provided, use it directly
        targetState = state
    end

    local actual = IPC.Automaton.IsTweakEnabled(tweakName)

    while actual ~= targetState and attempt < maxAttempts do
        IPC.Automaton.SetTweakState(tweakName, targetState)
        Sleep(0.05)
        actual = IPC.Automaton.IsTweakEnabled(tweakName)
        attempt = attempt + 1
        LogInfo("[NonuLuaLib] Attempt " .. attempt .. ": " .. tweakName .. " set to " .. tostring(targetState) .. ", currently reads as " .. tostring(actual))
    end

    if actual == targetState then
        LogInfo("[NonuLuaLib] " .. tweakName .. " successfully set to " .. tostring(targetState) .. " after " .. attempt .. " attempts.")
    else
        LogInfo("[NonuLuaLib] Warning: " .. tweakName .. " failed to set to " .. tostring(targetState) .. " after " .. maxAttempts .. " attempts. Current state: " .. tostring(actual))
    end
end


-- =================================================================================== --
-- =====================     MOUNTING AND NAVIGATION UTILITIES     =================== --
-- =================================================================================== --

-- Function to issue the command to use a specific mount or Mount Roulette.
-- Parameters:
--   mountName (string, optional): The name of the mount to use. If nil or empty, Mount Roulette is used.
-- Returns: None
-- Usage:
--   _UseMount("Company Chocobo") -- Attempts to summon "Company Chocobo"
--   _UseMount()                  -- Uses Mount Roulette
function _UseMount(mountName)
    if mountName ~= nil and mountName ~= "" then
        LogInfo("[NonuLuaLib] Attempting to mount: " .. mountName)
        yield('/mount "' .. mountName .. '"') -- Use the specified mount
    else
        LogInfo("[NonuLuaLib] Attempting Mount Roulette")
        yield('/gaction "Mount Roulette"') -- Use Mount Roulette
    end
end

-- Function to attempt mounting with retry and timeout logic.
-- Checks if already mounted or if mounting is disallowed, then attempts to mount,
-- waits for success, and retries once after a short delay if needed.
-- Parameters:
--   mountName (string, optional): The name of the mount to use. If nil or empty, Mount Roulette is used.
--   timeout (number, optional): The maximum total time in seconds to wait for mounting to succeed. Defaults to 6.0.
--   retryAfter (number, optional): The time in seconds to wait before retrying the mount once. Defaults to 3.0.
-- Returns: boolean - True if the player successfully mounted, false otherwise.
-- Usage:
--   Mount("Fatter Cat", 8.0, 3.5) -- Tries "Fatter Cat", 8s timeout, retry after 3.5s
--   Mount()                      -- Uses Mount Roulette with default timeout/retry
function Mount(mountName, timeout, retryAfter)
    timeout = timeout or 6.0 -- Max total wait time for mounting (in seconds)
    retryAfter = retryAfter or 3.0 -- Time to wait before retrying the mount once

    -- If already mounted, skip mount logic
    if GetCharacterCondition(CONDITION_MOUNTED) then
        LogInfo("[NonuLuaLib] Already mounted. Skipping mount.")
        return true
    end

    -- If mounting is not allowed (e.g., in combat, indoors), abort
    if not Player.CanMount then
        LogInfo("[NonuLuaLib] Cannot mount right now. Mounting unavailable.")
        return false
    end

    -- Attempt to mount initially
    LogInfo("[NonuLuaLib] Attempting mount...")
    _UseMount(mountName) -- Use the internal helper

    -- Initialize mount timer and retry flag
    local timer = 0
    local retried = false

    -- Loop until mounted or timeout is reached
    while not GetCharacterCondition(CONDITION_MOUNTED) and timer < timeout do
        Sleep(0.5)
        timer = timer + 0.5

        -- Retry mount once after retryAfter seconds, if still eligible
        if timer >= retryAfter and not retried and Player.CanMount then
            LogInfo("[NonuLuaLib] First mount attempt failed, retrying...")
            _UseMount(mountName)
            retried = true
        end
    end

    -- Return whether the player successfully mounted
    if GetCharacterCondition(CONDITION_MOUNTED) then
        LogInfo("[NonuLuaLib] Mount succeeded.")
        return true
    else
        LogInfo("[NonuLuaLib] Mount failed after timeout.")
        return false
    end
end

-- Function to issue a /vnav command to move the player to the currently set flag.
-- This relies on the 'vnavmesh' plugin being active and having a flag set.
-- Parameters:
--   useFly (boolean): True to use '/vnav flyflag', False to use '/vnav moveflag'.
-- Returns: None
-- Usage:
--   GoToFlag(true)  -- Uses '/vnav flyflag'
--   GoToFlag(false) -- Uses '/vnav moveflag'
function GoToFlag(useFly)
    if useFly then
        yield('/vnav flyflag')
        LogInfo("[NonuLuaLib] Issued /vnav flyflag.")
    else
        yield('/vnav moveflag')
        LogInfo("[NonuLuaLib] Issued /vnav moveflag.")
    end
end

-- =================================================================================== --
-- =====================          DALAMUD.LOG DISPENSER          =================== --
-- =================================================================================== --

-- Table defining supported log levels for structured logging.
local LogLevel = {Info = "Info", Debug = "Debug", Verbose = "Verbose"}

-- Core log function for outputting messages to the Dalamud log.
-- Supports different log levels and string formatting.
-- Parameters:
--   msg (string): The message string, potentially with format specifiers (e.g., "%s", "%.2f").
--   level (string, optional): The log level (e.g., LogLevel.Info, LogLevel.Debug). Defaults to LogLevel.Info.
--   ... (any): Additional arguments for string.format if 'msg' contains format specifiers.
-- Returns: None
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

-- Sugar function for logging informational messages (LogLevel.Info).
-- Parameters:
--   msg (string): The message string, potentially with format specifiers.
--   ... (any): Additional arguments for string.format.
-- Returns: None
function LogInfo(msg, ...) Log(msg, LogLevel.Info, ...) end

-- Sugar function for logging debug messages (LogLevel.Debug).
-- Parameters:
--   msg (string): The message string, potentially with format specifiers.
--   ... (any): Additional arguments for string.format.
-- Returns: None
function LogDebug(msg, ...) Log(msg, LogLevel.Debug, ...) end

-- Sugar function for logging verbose messages (LogLevel.Verbose).
-- Parameters:
--   msg (string): The message string, potentially with format specifiers.
--   ... (any): Additional arguments for string.format.
-- Returns: None
function LogVerbose(msg, ...) Log(msg, LogLevel.Verbose, ...) end
