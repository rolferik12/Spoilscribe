local _, Spoilscribe = ...

local function NormalizeSlotText(value)
    if not value then
        return ""
    end

    local normalized = string.lower(tostring(value))
    normalized = normalized:gsub("[^%a%d]", "")
    return normalized
end

local _slotAliases = {
    head = { "head" },
    neck = { "neck" },
    shoulder = { "shoulder" },
    back = { "back", "cloak" },
    chest = { "chest", "robe", "tunic", "vest" },
    wrist = { "wrist", "bracer" },
    hands = { "hands", "hand", "glove", "gauntlet" },
    waist = { "waist", "belt" },
    legs = { "legs", "leg", "leggings", "pants", "greaves" },
    feet = { "feet", "foot", "boot" },
    ring = { "ring", "finger" },
    trinket = { "trinket" },
    onehand = { "onehand", "mainhand", "onehanded" },
    twohand = { "twohand", "twohanded" },
    offhand = { "offhand", "heldinoffhand", "shield" },
}

function Spoilscribe:LootMatchesSlotFilter(loot, selectedSlotLabel)
    if not selectedSlotLabel or selectedSlotLabel == "Any Slot" then
        return true
    end

    local normalizedSlot = NormalizeSlotText(loot and loot.slot)
    if normalizedSlot == "" then
        return false
    end

    local normalizedFilter = NormalizeSlotText(selectedSlotLabel)
    local aliases = _slotAliases[normalizedFilter] or { normalizedFilter }
    for _, alias in ipairs(aliases) do
        if string.find(normalizedSlot, alias, 1, true) then
            return true
        end
    end

    return false
end

local function GetItemStatTable(itemRef)
    if not itemRef then
        return nil
    end

    if C_Item and C_Item.GetItemStats then
        local cStats = C_Item.GetItemStats(itemRef)
        if cStats then
            return cStats
        end
    end

    if GetItemStats then
        local stats = GetItemStats(itemRef)
        if stats then
            return stats
        end
    end

    return nil
end

local _secondaryStatTokens = {
    { token = "CRIT",         label = "critical strike" },
    { token = "CRITICAL",     label = "critical strike" },
    { token = "HASTE",        label = "haste" },
    { token = "MASTERY",      label = "mastery" },
    { token = "VERSATILITY",  label = "versatility" },
}

function Spoilscribe:GetSecondaryStatLabels(loot)
    if not loot then return nil end
    local stats = GetItemStatTable(loot.link)
    if not stats and loot.itemID then
        stats = GetItemStatTable("item:" .. tostring(loot.itemID))
    end
    if not stats then return nil end

    local labels = {}
    local seen = {}
    for statKey, statValue in pairs(stats) do
        if statValue and statValue ~= 0 then
            local upperKey = string.upper(tostring(statKey))
            for _, entry in ipairs(_secondaryStatTokens) do
                if not seen[entry.label] and string.find(upperKey, entry.token, 1, true) then
                    labels[#labels + 1] = entry.label
                    seen[entry.label] = true
                end
            end
        end
    end
    if #labels > 0 then return labels end
    return nil
end

local _requiredTokensByLabel = {
    ["Critical Strike"] = { "CRIT", "CRITICAL" },
    ["Haste"] = { "HASTE" },
    ["Mastery"] = { "MASTERY" },
    ["Versatility"] = { "VERSATILITY" },
}

function Spoilscribe:LootMatchesSecondaryFilter(loot, selectedSecondaryLabel)
    if not selectedSecondaryLabel or selectedSecondaryLabel == "Any Stats" then
        return true
    end

    local stats = nil
    if loot then
        stats = GetItemStatTable(loot.link)
        if not stats and loot.itemID then
            stats = GetItemStatTable("item:" .. tostring(loot.itemID))
        end
    end

    if not stats then
        return false
    end

    local requiredTokens = _requiredTokensByLabel[selectedSecondaryLabel]
    if not requiredTokens then
        return true
    end

    for statKey, statValue in pairs(stats) do
        if statValue and statValue ~= 0 then
            local upperKey = string.upper(tostring(statKey))
            for _, token in ipairs(requiredTokens) do
                if string.find(upperKey, token, 1, true) then
                    return true
                end
            end
        end
    end

    return false
end
