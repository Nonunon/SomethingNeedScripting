require("NonuLuaLib")

function Main()
    local currentZone = ZoneID()

    -- Handle Retainer List Closure
    if IsAddonReady("RetainerList") then
        Sleep(0.1)
        yield("/callback RetainerList true -1 1 0")
    end

    while IsAddonReady("RetainerList") do Sleep(0.1) end

    -- Handle specific zones
    if currentZone == 179 then  -- The Roost|
        PathToObject("Heavy Oaken Door", false, 3.0)
        Target("Heavy Oaken Door")
        Interact("Heavy Oaken Door")
        WaitForZoneChange()
        currentZone = ZoneID()  -- refresh after zoning

    elseif currentZone == 133 then  -- Old Gridania
        PathToObject("Aethernet Shard", false, 3.5)
        Lifestream("Gridania")
        WaitForZoneChange()
        currentZone = ZoneID()  -- refresh after zoning

    elseif currentZone ~= 132 then  -- Not in New Gridania yet
        Lifestream("tp Gridania")
        WaitForZoneChange()
        currentZone = ZoneID()  -- refresh after zoning
    end

    -- Finally, you're in New Gridania (132), proceed to delivery
    if currentZone == 132 then
        Movement(-67.457, -0.502, -8.274)
        AutoRetainerDelivery()
    else
        yield('/echo Unexpected zone ID: ' .. tostring(currentZone))
    end
end

-- Execute the Main function
Main()
