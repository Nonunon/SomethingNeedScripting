require("NonuLuaLib")

function RetainerBell()
    yield('/target "Summoning Bell"')
    Sleep(0.2)
    yield("/interact")
end

function WaitForZone179()
    while ZoneID() ~= 179 do
        LogInfo("[NonuLuaLib] Waiting for ZoneID 179")
        Sleep(0.2)
    end
    LogInfo("[NonuLuaLib] Arrived in ZoneID 179")
end

function InteractWithBell()
    WaitForZone179()

    -- Confirm player is fully available
    while not IsPlayerAvailable() do
        LogInfo("[NonuLuaLib] Waiting for player availability")
        Sleep(0.1)
    end

    -- We only get here once IsPlayerAvailable() returned true
    LogInfo("[NonuLuaLib] Player is now available!")

    Sleep(0.2)
    RetainerBell()
end

-- Main logic controller
-- Handles behavior based on current zone and performs shard navigation when needed
function Main()
    local currentZone = ZoneID()

    if currentZone == 179 then
        -- Already inside inn room, no action needed
        RetainerBell()
        return
    elseif currentZone == 132 then
        -- In New Gridania: use shortcut command to enter inn
        Lifestream("Innnear")
        InteractWithBell()
        return
    elseif currentZone == 133 then
        -- In Old Gridania: determine closest shard and move to it
        PathToObject("Aethernet Shard", false, 3.5)
        Lifestream("innog")
        InteractWithBell()
        return
    else
        -- Any other zone: use default inn command
        Lifestream("inn")
        InteractWithBell()
        return
    end
end

-- Execute the main logic
Main()