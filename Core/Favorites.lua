local _, Spoilscribe = ...

function Spoilscribe:GetFavoriteItems()
    SpoilscribeCharDB.favorites = SpoilscribeCharDB.favorites or {}
    local favIDs = SpoilscribeCharDB.favorites
    if not next(favIDs) then return {} end

    -- Use the currently selected difficulty but always resolve across all specs (class-wide).
    local frame = self.UI and self.UI.frame
    local diffId = 23
    if frame then
        local difficulty = self.Data.Difficulties[frame.selectedDifficultyIndex or 1]
        diffId = difficulty and difficulty.id or 23
    end

    local key = self:CacheKey(diffId, 0)
    local dungeons = self._lootCache[key]
    if not dungeons then return {} end

    local seen = {}
    local results = {}
    for _, dungeonEntry in ipairs(dungeons) do
        for _, item in ipairs(dungeonEntry.items) do
            if item.itemID and favIDs[item.itemID] and not seen[item.itemID] then
                seen[item.itemID] = true
                results[#results + 1] = {
                    type        = "item",
                    itemID      = item.itemID,
                    itemLink    = item.itemLink,
                    itemName    = item.itemName,
                    itemQuality = item.itemQuality,
                    icon        = item.icon,
                    slot        = item.slot or "",
                    armorType   = item.armorType or "",
                    bossName    = item.bossName,
                    dungeonName = dungeonEntry.dungeonName,
                }
            end
        end
    end
    return results
end

-- Returns a table of dungeon names mapped to favorite item counts.
function Spoilscribe:GetFavoriteDungeonNames()
    SpoilscribeCharDB.favorites = SpoilscribeCharDB.favorites or {}
    local favIDs = SpoilscribeCharDB.favorites
    if not next(favIDs) then return {} end

    local result = {}
    -- Check all cache keys so we don't depend on current UI selection.
    for _, dungeons in pairs(self._lootCache) do
        for _, dungeonEntry in ipairs(dungeons) do
            if not result[dungeonEntry.dungeonName] then
                local count = 0
                for _, item in ipairs(dungeonEntry.items) do
                    if item.itemID and favIDs[item.itemID] then
                        count = count + 1
                    end
                end
                if count > 0 then
                    result[dungeonEntry.dungeonName] = count
                end
            end
        end
    end
    return result
end
