require("NonuLuaLib")

-- Attempt to join the Novice Network
function JoinNN()
    yield("/callback ChatLog true 3 1 0") -- Press the Novice Network button
end

-- Toggles on or off Chat 2 as a means to access the ChatLog callback.
function Chat2Toggle() yield("/xltoggleplugin Chat 2") end

-- Check if we've successfully joined
function InYet()
    if IsAddonReady("BeginnerChatList") then
        yield("/callback BeginnerChatList true -1 1 0") -- Close the Novice Network list
        return true
    end
    return false
end

-- Main function loop
function Main()
    Chat2Toggle() -- Toggle Chat2 OFF

    while not InYet() do
        JoinNN() -- Keep trying to join
        Sleep(1) -- Wait a bit before checking again
    end

    Chat2Toggle() -- Toggle Chat2 ON
end

Main()
