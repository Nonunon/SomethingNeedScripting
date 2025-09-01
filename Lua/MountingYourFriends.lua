--[=====[
[[SND Metadata]]
author: Nonu
version: 1.0.0
description: "A silly dynamic way to mount your friends without it being totally automated."

configs:
  friendName:
    default: FirstName LastName
    description: Your friend's name!
  focusRetries:
    default: 20
    description: How many attempts it'll try to mount your friend's mount through Focus target fuckery.
    min: 0
    max: 100
  focusDelay:
    default: 0.1
    description: How often it'll attempt each focus retry after a decimal second delay.
    min: 0.1
    max: 0.5
  targetRetries:
    default: 20
    description: How many attempts it'll try to mount your friend's mount through raw/hard targeting fuckery. You can set this to 0 to stop hard targeting all together.
    min: 0
    max: 100
  targetDelay:
    default: 0.1
    description: How often it'll attempt each target retry after a decimal second delay.
    min: 0.1
    max: 0.5

[[End Metadata]]
--]=====]

require("NonuLuaLib")

local friendName = Config.Get("friendName")

---
--- Helper: Build "Name@World" string from FocusTarget
---
local function GetFullNameFromFocus()
    if not Entity.FocusTarget then return nil end

    local targetName = Entity.FocusTarget.Name
    local targetHomeworld = Entity.FocusTarget.HomeWorld

    local sheet = Excel.GetSheet("World")
    local row = sheet and sheet:GetRow(targetHomeworld)
    local worldName = row and row:GetProperty("Name") or nil

    if targetName and worldName then
        return targetName .. "@" .. worldName
    elseif targetName then
        return targetName
    end
    return nil
end

---
--- Main Script Logic
---
function RidePillion()
    if GetCharacterCondition(10) then
        Echo("[RidePillion] Already mounted as a passenger. Exiting.")
        return
    end

    -- Retry configs
    local focusRetries  = Config.Get("focusRetries")
    local focusDelay    = Config.Get("focusDelay")
    local targetRetries = Config.Get("targetRetries")   -- set to 0 to fully disable <t>
    local targetDelay   = Config.Get("targetDelay")

    if friendName ~= "" then
        if AcquireTarget(friendName) then
            Entity.Target:SetAsFocusTarget()
            Sleep(0.1)

            local fullName = GetFullNameFromFocus()
            Echo("[RidePillion] Focus set to: " .. tostring(fullName))

            if Entity.Target then
                Entity.Target:ClearTarget()
            end

            -- Try with <f>
            Echo("[RidePillion] Attempting to ride with focus target...")
            for i = 1, focusRetries do
                yield('/ridepillion <f>')
                Sleep(focusDelay)
                if GetCharacterCondition(10) then
                    Echo("[RidePillion] Successfully mounted " .. tostring(fullName) .. "!")
                    return
                end
            end
        end
    end

    -- Fallback: <t>, only if retries > 0
    if targetRetries > 0 then
        Echo("[RidePillion] Falling back to current target...")
        for i = 1, targetRetries do
            yield('/ridepillion <t>')
            Sleep(targetDelay)
            if GetCharacterCondition(10) then
                Echo("[RidePillion] Successfully mounted your target!")
                return
            end
        end
    end

    Echo("[RidePillion] Failed to mount anyone. Make sure they are on a multi-person mount and within range.")
end

RidePillion()
