local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}

local L = Spoilscribe.L

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
SlashCmdList.SPOILSCRIBE = function(msg)
    local localeCode = msg and msg:match("^locale%s+(%S+)")
    if localeCode then
        if type(Spoilscribe.SetDebugLocale) == "function" then
            SafeCall(function() Spoilscribe.SetDebugLocale(localeCode) end, L["Spoilscribe: command failed"])
        end
        return
    end

    if type(Spoilscribe.Open) == "function" then
        SafeCall(function() Spoilscribe:Open() end, L["Spoilscribe: command failed"])
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            L["Spoilscribe: addon not fully loaded. Enable Lua errors with /console scriptErrors 1 and reload."])
    end
end
