local _, ns = ...

-- Create the localization table. Keys are the English (enUS) strings.
-- If a locale file does not provide a translation for a key, the key
-- itself is returned as a fallback (i.e. the English string is used).
ns.L = setmetatable({}, {
    __index = function(_, k)
        return k
    end,
})
