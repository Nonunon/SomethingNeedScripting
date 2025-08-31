require("NonuLuaLib")

local friendName = "Meow"

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
    local focusRetries  = 20
    local focusDelay    = 0.1
    local targetRetries = 0   -- set to 0 to fully disable <t>
    local targetDelay   = 0.2

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
