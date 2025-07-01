require("NonuLuaLib")

local HOTBAR_TO_TOGGLE = 5
local SPECIAL_ZONE = 1252

local function IsReady()
    return IsPlayerAvailable("Really")
end

-- Wait for the player to fully load
while not IsReady() do Sleep(1) end
Sleep(1)

local currentZone = ZoneID()
local action = (currentZone == SPECIAL_ZONE) and "on" or "off"

yield("/hotbar display " .. HOTBAR_TO_TOGGLE .. " " .. action)
LogInfo("[NonuLuaLib] Toggled hotbar %d %s for zone %d",
    HOTBAR_TO_TOGGLE, action, currentZone)
