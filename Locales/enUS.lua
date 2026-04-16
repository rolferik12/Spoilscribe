local _, ns = ...

ns.LocaleData = {}

-- Create the localization table. Keys are the English (enUS) strings.
-- If a locale file does not provide a translation for a key, the key
-- itself is returned as a fallback (i.e. the English string is used).
ns.L = setmetatable({}, {
    __index = function(_, k)
        return k
    end,
})

-- Debug: switch the active locale at runtime without a reload.
-- Usage (in-game): /ss locale deDE
function ns.SetDebugLocale(code)
    local data = ns.LocaleData[code]
    if not data then
        local available = {}
        for k in pairs(ns.LocaleData) do table.insert(available, k) end
        table.sort(available)
        local list = next(available) and table.concat(available, ", ") or "(none)"
        DEFAULT_CHAT_FRAME:AddMessage(
            "Spoilscribe: unknown locale '" .. tostring(code) .. "'. Available: " .. list)
        return
    end
    for k in pairs(ns.L) do ns.L[k] = nil end
    for k, v in pairs(data) do ns.L[k] = v end
    if type(ns.RefreshLocaleUI) == "function" then
        ns.RefreshLocaleUI()
    end
    DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: locale switched to " .. code)
end
