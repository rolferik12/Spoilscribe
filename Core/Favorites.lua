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

-- Returns favorite items from all party members, resolved from the loot cache.
-- Only includes items from senders whose broadcast difficulty matches the viewer's selection.
-- Each result includes a .sender field with the party member's name.
function Spoilscribe:GetPartyFavoriteItems()
    if not self._partyFavItems or not next(self._partyFavItems) then return {} end

    -- Determine the viewer's selected difficulty.
    local frame = self.UI and self.UI.frame
    local viewerDiffId = 23
    if frame then
        local difficulty = self.Data.Difficulties[frame.selectedDifficultyIndex or 1]
        viewerDiffId = difficulty and difficulty.id or 23
    end

    -- Build a lookup of itemID -> item data from the matching difficulty cache only.
    local itemLookup = {}
    local specs = self:GetSpecList()
    for _, spec in ipairs(specs) do
        local key = self:CacheKey(viewerDiffId, spec.specID)
        local dungeons = self._lootCache[key]
        if dungeons then
            for _, dungeonEntry in ipairs(dungeons) do
                for _, item in ipairs(dungeonEntry.items) do
                    if item.itemID and not itemLookup[item.itemID] then
                        itemLookup[item.itemID] = {
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
        end
    end

    local results = {}
    for sender, data in pairs(self._partyFavItems) do
        -- Only show items from senders whose difficulty matches ours.
        if data.diffId == viewerDiffId then
            for id in pairs(data.items) do
                local cached = itemLookup[id]
                if cached then
                    local entry = {}
                    for k, v in pairs(cached) do entry[k] = v end
                    entry.sender = sender
                    results[#results + 1] = entry
                end
            end
        end
    end
    return results
end
