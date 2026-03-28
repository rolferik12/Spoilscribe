local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}

SpoilscribeDB = SpoilscribeDB or {}
SpoilscribeCharDB = SpoilscribeCharDB or {}
SpoilscribeCharDB.favorites = SpoilscribeCharDB.favorites or {}

-- Shared state for cross-module access.
Spoilscribe._lootCache = {}
Spoilscribe._hadMissingLinks = false
Spoilscribe._isScanning = false
Spoilscribe._partyFavDungeons = {}

function Spoilscribe:LogToConsole(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: " .. tostring(message))
    elseif print then
        print("Spoilscribe: " .. tostring(message))
    end
end

function Spoilscribe:CacheKey(difficultyId, specId)
    return tostring(difficultyId) .. ":" .. tostring(specId or 0)
end

-- Build the player's specialization list at runtime.
-- Returns an array: { {label="All Specs", classID=0, specID=0}, {label="Frost", classID=6, specID=251}, ... }
local _specList = nil
function Spoilscribe:GetSpecList()
    if _specList then return _specList end
    _specList = { { label = "All Specs", classID = 0, specID = 0 } }
    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    for i = 1, numSpecs do
        local id, name, _, icon, _, classID = GetSpecializationInfo(i)
        if id and name then
            _specList[#_specList + 1] = {
                label   = name,
                classID = classID or select(3, UnitClass("player")),
                specID  = id,
            }
        end
    end
    return _specList
end

function Spoilscribe:GetQualityColoredItemText(loot)
    if loot.link and loot.link ~= "" then
        return loot.link
    end

    local name = loot.name or ("Item " .. tostring(loot.itemID))
    if not loot.itemID then
        return name
    end

    local quality = nil
    if C_Item and C_Item.GetItemQualityByID then
        quality = C_Item.GetItemQualityByID(loot.itemID)
    end

    if not quality and GetItemInfo then
        local _, _, infoQuality = GetItemInfo(loot.itemID)
        quality = infoQuality
    end

    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex then
        return ITEM_QUALITY_COLORS[quality].hex .. name .. "|r"
    end

    return name
end
