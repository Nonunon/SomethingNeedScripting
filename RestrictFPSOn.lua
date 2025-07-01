-- Open the System Configuration menu if it's not already open
if not (Addons.GetAddon("ConfigSystem") and Addons.GetAddon("ConfigSystem").Ready) then
    yield("/systemconfig")
end

-- Wait until the ConfigSystem addon is fully loaded and ready
repeat
    yield("/wait 0.1")
until Addons.GetAddon("ConfigSystem") and Addons.GetAddon("ConfigSystem").Ready

-- Small buffer wait
yield("/wait 0.1")

-- Define a helper function to send a callback and wait after
function SendCallback(args)
    yield("/callback ConfigSystem true " .. table.concat(args, " "))
    yield("/wait 0.1")
end

-- Define the callback arguments in order
local callbacks = {
    {10, 0, 0, 0}, -- Select Display Settings
    {17, 8, 1},    -- Enable "Limit framerate when client is inactive"
    {0}            -- Apply changes
}

-- Loop through each callback and send it
for _, args in ipairs(callbacks) do
    SendCallback(args)
end

-- Close the System Configuration menu
yield("/systemconfig")
