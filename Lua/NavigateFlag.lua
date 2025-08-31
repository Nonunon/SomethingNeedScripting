require("NonuLuaLib")

-- Set the preferred mount
-- Leave this blank ("") to use Mount Roulette, or set a specific mount name (e.g., "Company Chocobo")
mount = ""

-- Function to choose a mount
-- Uses a named mount if provided; otherwise falls back to Mount Roulette
function UseMount()
    if mount ~= nil and mount ~= "" then
        LogVerbose("[NonuLuaLib] Attempting to mount: " .. mount)
        yield('/mount "' .. mount .. '"') -- Use the specified mount
    else
        LogVerbose("[NonuLuaLib] Attempting Mount Roulette")
        yield('/gaction "Mount Roulette"') -- Use Mount Roulette
    end
end

-- Function to mount with retry and timeout logic
-- Attempts to mount, waits for success, retries once after a short delay if needed
-- Returns true if mounted, false if not
function Mount(timeout, retryAfter)
    timeout = timeout or 6.0 -- Max total wait time for mounting (in seconds)
    retryAfter = retryAfter or 3.0 -- Time to wait before retrying the mount once

    -- If already mounted, skip mount logic
    if GetCharacterCondition(4) then
        LogVerbose("[NonuLuaLib] Already mounted. Skipping mount.")
        return true
    end

    -- If mounting is not allowed (e.g., in combat, indoors), abort
    if not Player.CanMount then
        LogVerbose("[NonuLuaLib] Cannot mount right now. Mounting unavailable.")
        return false
    end

    -- Attempt to mount initially
    LogVerbose("[NonuLuaLib] Attempting mount...")
    UseMount()

    -- Initialize mount timer and retry flag
    local timer = 0
    local retried = false

    -- Loop until mounted or timeout is reached
    while not GetCharacterCondition(4) and timer < timeout do
        Sleep(0.5)
        timer = timer + 0.5

        -- Retry mount once after retryAfter seconds, if still eligible
        if timer >= retryAfter and not retried and Player.CanMount then
            LogVerbose("[NonuLuaLib] First mount attempt failed, retrying...")
            UseMount()
            retried = true
        end
    end

    -- Return whether the player successfully mounted
    if GetCharacterCondition(4) then
        LogVerbose("[NonuLuaLib] Mount succeeded.")
        return true
    else
        LogVerbose("[NonuLuaLib] Mount failed after timeout.")
        return false
    end
end

-- Main navigation logic
-- Handles zoning, state checks, mounting, and fly/ground movement commands
function Main()
    LogVerbose("[NonuLuaLib] Starting navigation logic...")

    -- Check if the player is in stealth or carrying an object (e.g., coffer)
    -- If so, skip mounting and just walk to the flag
    if GetCharacterCondition(46) or GetCharacterCondition(9) then
        LogVerbose("[NonuLuaLib] Player is stealthed or carrying object. Skipping mount.")
        yield('/vnav moveflag')
        return
    end

    -- Attempt to mount with a 6s timeout and retry at 2.2s
    Mount(6.0, 2.2)
        -- If mounted, check if flying is available
    if GetCharacterCondition(4) then
        if Player.CanFly then
            LogVerbose("[NonuLuaLib] Mounted and flying is available.")
            yield('/vnav flyflag') -- Use flying navigation
        else
            LogVerbose("[NonuLuaLib] Mounted, but flying not available. Using ground movement.")
            yield('/vnav moveflag') -- Use ground navigation
        end
    else
        -- If still not mounted, default to walking
        LogVerbose("[NonuLuaLib] Mount failed, defaulting to walking.")
        yield('/vnav moveflag') 
    end
end

Main()
