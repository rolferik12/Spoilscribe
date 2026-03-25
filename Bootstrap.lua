local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}
_G[addonName] = Spoilscribe

local function OpenFromSlash(msg)
    if type(Spoilscribe.Open) == "function" then
        local ok, err = pcall(Spoilscribe.Open, Spoilscribe, msg)
        if not ok and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: command failed - " .. tostring(err))
        end
        return
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: addon not fully loaded. Enable Lua errors with /console scriptErrors 1 and reload.")
    end
end

SLASH_SPOILSCRIBE1 = "/spoilscribe"
SLASH_SPOILSCRIBE2 = "/ss"
SlashCmdList.SPOILSCRIBE = OpenFromSlash
