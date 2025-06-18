import ("System.Numerics")

-- Function to pause execution until the player is no longer zoning
-- This prevents issues from mounting or moving while teleporting/loading
-- Remade from VAC_Functions' ZoneTransition()
function WaitForZoneChange()
    -- Wait until zoning actually starts
    repeat Sleep(0.1) until (Svc.Condition[45] or Svc.Condition[51])

    -- Then wait until zoning fully completes and player is loaded
    repeat Sleep(0.1) until (
        not Svc.Condition[45] and 
        not Svc.Condition[51] and 
        Player.Available
    )
end

-- Function to sleep/wait for the specified number of seconds
-- Uses /wait wrapped so to maintain functionality.
function Sleep(seconds) yield('/wait ' .. tostring(seconds)) end

-- Function to check if a given addon is loaded and ready
-- Returns true if the addon exists and is marked as Ready
function IsAddonReady(name)
    local addon = Addons.GetAddon(name)
    return addon and addon.Ready
end

-- Function to pause execution until a specific addon is ready
-- Repeatedly checks readiness using isAddonReady and waits between each check
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
        Dalamud.Log(string.format("[NonuLuaLib] Target acquired: %s [Word: %s]",
                                  Entity.Target.Name, name))
        return true
    else
        Dalamud.Log(string.format(
                        "[NonuLuaLib] Failed to acquire target [%s] after %d retries",
                        name, retries))
        return false
    end
end

-- Simplified function to acquire a target
-- Calls AcquireTarget and logs failure if unsuccessful
-- Usage: Target("Aetheryte"), Target("Aetheryte", 50, 0.05)
function Target(name, maxRetries, sleepTime)
    local success = AcquireTarget(name, maxRetries, sleepTime)
    if not success then Dalamud.Log("[NonuLuaLib] Target() failed.") end
end

-- Function to interact with a target
-- Attempts to acquire target first, then issues /interact if successful
-- Usage: Interact("Aetheryte"), Interact("Antoi", 30, 0.1)
function Interact(name, maxRetries, sleepTime)
    local success = AcquireTarget(name, maxRetries, sleepTime)
    if success then
        yield('/interact')
        Dalamud.Log("[NonuLuaLib] Interacted with: " .. Entity.Target.Name)
    else
        Dalamud.Log("[NonuLuaLib] Interact() failed to acquire target.")
    end
end

-- Function to lazily automove for a duration, optionally towards a target
-- If name is provided, will target first, face the target, then automove
-- Usage: Automove(1), Automove(2, "Heavy Oaken Door")
function Automove(duration, name, maxRetries, sleepTime)
    if name then
        local success = AcquireTarget(name, maxRetries, sleepTime)
        if not success then
            Dalamud.Log("[NonuLuaLib] Automove() failed to acquire target: " ..
                            name)
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
        Dalamud.Log(string.format(
                        "[NonuLuaLib] Automoved towards target: %s for %.1f seconds",
                        name, duration))
    else
        Dalamud.Log(string.format("[NonuLuaLib] Automoved for %.1f seconds",
                                  duration))
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
        Dalamud.Log("[NonuLuaLib] PathfindAndMoveTo() failed to start pathing!")
        return false
    end

    Dalamud.Log(string.format("[NonuLuaLib] Pathing issued to (%.3f, %.3f, %.3f)", x, y, z))

    local startupRetries = 0
    local maxStartupRetries = 10
    while not IPC.vnavmesh.IsRunning() and startupRetries < maxStartupRetries do
        Sleep(0.1)
        startupRetries = startupRetries + 1
    end

    if not IPC.vnavmesh.IsRunning() then
        Dalamud.Log("[NonuLuaLib] Pathing failed to start movement after issuing path.")
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
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

            if dist <= stopDistance then
                IPC.vnavmesh.Stop()
                Dalamud.Log(string.format("[NonuLuaLib] Stopped early at distance %.2f", dist))
                break
            end
        end
    end

    Dalamud.Log("[NonuLuaLib] Pathing complete. I'm done!")
    return true
end

-- Function to pathfind directly to an entity by name
-- Looks up the entity, retrieves its position, and calls PathFindTo()
-- Usage: PathToObject("Summoning Bell"), PathToObject("Retainer Vocate", false, 4.0)
function PathToObject(entityName, fly, stopDistance)
    fly = fly or false
    stopDistance = stopDistance or 0.0

    local targetEntity = Entity.GetEntityByName(entityName)
    if not targetEntity then
        Dalamud.Log(string.format("[NonuLuaLib] Entity '%s' not found!", entityName))
        return false
    end

    local pos = targetEntity.Position
    Dalamud.Log(string.format("[NonuLuaLib] Pathing to entity '%s' at (%.3f, %.3f, %.3f)", entityName, pos.X, pos.Y, pos.Z))

    return PathFindTo(pos.X, pos.Y, pos.Z, fly, stopDistance)
end



-- Helper to get current zone ID
function ZoneID()
    return Svc.ClientState.TerritoryType
end
