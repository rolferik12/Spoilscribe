local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function SafeCall(fn, errorPrefix)
    local ok, err = pcall(fn)
    if not ok and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(errorPrefix .. ": " .. tostring(err))
    end
end

---------------------------------------------------------------------------
-- Slash command dispatch
---------------------------------------------------------------------------

SLASH_SPOILSCRIBE1 = "/spoilscribe"
SLASH_SPOILSCRIBE2 = "/ss"
SlashCmdList.SPOILSCRIBE = function()
    if type(Spoilscribe.Open) == "function" then
        SafeCall(function() Spoilscribe:Open() end, "Spoilscribe: command failed")
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "Spoilscribe: addon not fully loaded. Enable Lua errors with /console scriptErrors 1 and reload.")
    end
end
