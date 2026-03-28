local _, Spoilscribe = ...

local function EnsureEncounterJournalLoaded()
    if not EncounterJournal then
        EncounterJournal_LoadUI()
    end
end

local function TrySelectInstance(ejInstanceID)
    if not EJ_SelectInstance then
        return false, "EJ_SelectInstance API is unavailable."
    end

    local ok, err = pcall(EJ_SelectInstance, ejInstanceID)
    if not ok then
        return false, tostring(err)
    end

    return true, nil
end

local function TrySelectEncounter(encounterID)
    if not EJ_SelectEncounter then
        return false, "EJ_SelectEncounter API is unavailable."
    end

    local ok, err = pcall(EJ_SelectEncounter, encounterID)
    if not ok then
        return false, tostring(err)
    end

    return true, nil
end

local function GetLootInfoByIndex(index, encounterID)
    local itemID, link, name, slot, armorType, icon, itemQuality

    if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
        local info = C_EncounterJournal.GetLootInfoByIndex(index, encounterID)
        if info then
            itemID      = info.itemID
            link        = info.link
            name        = info.name
            slot        = info.slot
            armorType   = info.armorType
            icon        = info.icon
            itemQuality = info.itemQuality
        end

        if not itemID then
            -- Some client builds expect only index after EJ_SelectEncounter.
            local fallbackInfo = C_EncounterJournal.GetLootInfoByIndex(index)
            if fallbackInfo then
                itemID      = fallbackInfo.itemID
                link        = fallbackInfo.link
                name        = fallbackInfo.name
                slot        = fallbackInfo.slot
                armorType   = fallbackInfo.armorType
                icon        = fallbackInfo.icon
                itemQuality = fallbackInfo.itemQuality
            end
        end
    end

    if not itemID and EJ_GetLootInfoByIndex then
        local id, encounterIcon, _, n, _, s, a, l = EJ_GetLootInfoByIndex(index, encounterID)
        if id then
            itemID = id ; link = l ; name = n ; slot = s ; armorType = a ; icon = encounterIcon
        else
            local id2, encounterIcon2, _, n2, _, s2, a2, l2 = EJ_GetLootInfoByIndex(index)
            if id2 then
                itemID = id2 ; link = l2 ; name = n2 ; slot = s2 ; armorType = a2 ; icon = encounterIcon2
            end
        end
    end

    if not itemID then return nil end

    -- If the EJ didn't give us a link (item data not yet cached), ask GetItemInfo.
    -- This also primes the client cache so a retry will get the proper link.
    if not link or link == "" then
        if GetItemInfo then
            local _, cachedLink, _, _, _, _, _, _, _, cachedIcon = GetItemInfo(itemID)
            if cachedLink and cachedLink ~= "" then
                link = cachedLink
            else
                Spoilscribe._hadMissingLinks = true
            end
            if not icon and cachedIcon then
                icon = cachedIcon
            end
        end
    end

    return {
        itemID      = itemID,
        link        = link,
        name        = name,
        slot        = slot,
        armorType   = armorType,
        icon        = icon,
        itemQuality = itemQuality,
    }
end

function Spoilscribe:ScanLootForDifficultyAndSpec(difficultyId, classId, specId)
    local key = self:CacheKey(difficultyId, specId)
    if self._lootCache[key] then
        return self._lootCache[key]
    end

    EnsureEncounterJournalLoaded()

    local savedDifficulty = EJ_GetDifficulty and EJ_GetDifficulty()
    local savedInstanceID = EJ_GetCurrentInstance and EJ_GetCurrentInstance()

    local ejWasShown = EncounterJournal and EncounterJournal:IsShown()
    if ejWasShown then
        EncounterJournal:Hide()
    end

    self._isScanning = true

    local initialTier = nil
    if EJ_GetNumTiers and EJ_GetNumTiers() and EJ_GetNumTiers() > 0 then
        initialTier = EJ_GetNumTiers()
    end
    if EJ_SelectTier and initialTier then
        EJ_SelectTier(initialTier)
    end
    if EJ_SetDifficulty and difficultyId then
        EJ_SetDifficulty(difficultyId)
    end

    -- Set loot spec filter.  specId 0 = all specs (no filter).
    if EJ_SetLootFilter and classId and classId > 0 and specId and specId > 0 then
        EJ_SetLootFilter(classId, specId)
    elseif EJ_ResetLootFilter then
        EJ_ResetLootFilter()
    end

    local result = {}

    for _, dungeon in ipairs(self.Data.Dungeons) do
        if EJ_SelectTier and initialTier then
            EJ_SelectTier(initialTier)
        end
        if EJ_SetDifficulty and difficultyId then
            EJ_SetDifficulty(difficultyId)
        end

        local selected, selectError = TrySelectInstance(dungeon.ejInstanceID)
        if selected then
            local dungeonEntry = { dungeonName = dungeon.name, items = {} }

            for _, encounterID in ipairs(dungeon.encounters) do
                local encounterSelected, encounterSelectError = TrySelectEncounter(encounterID)

                if not encounterSelected then
                    self:LogToConsole(string.format(
                        "Encounter select failed in %s (EncounterID: %d). %s",
                        tostring(dungeon.name),
                        tonumber(encounterID) or 0,
                        tostring(encounterSelectError or "No reason provided.")
                    ))
                else
                    if EJ_SetDifficulty and difficultyId then
                        EJ_SetDifficulty(difficultyId)
                    end

                    local bossName = nil
                    if EJ_GetEncounterInfo then
                        local eName = EJ_GetEncounterInfo(encounterID)
                        if eName then bossName = eName end
                    end

                    local lootIndex = 1
                    while true do
                        local loot = GetLootInfoByIndex(lootIndex, encounterID)
                        if not loot then break end

                        dungeonEntry.items[#dungeonEntry.items + 1] = {
                            type        = "item",
                            itemID      = loot.itemID,
                            itemLink    = loot.link,
                            itemName    = loot.name,
                            itemQuality = loot.itemQuality,
                            icon        = loot.icon,
                            slot        = loot.slot or "",
                            armorType   = loot.armorType or "",
                            bossName    = bossName,
                        }

                        lootIndex = lootIndex + 1
                    end
                end
            end

            if #dungeonEntry.items > 0 then
                result[#result + 1] = dungeonEntry
            end
        else
            self:LogToConsole(string.format(
                "Instance select failed for %s (EJInstanceID: %d). %s",
                tostring(dungeon.name),
                tonumber(dungeon.ejInstanceID) or 0,
                tostring(selectError or "No reason provided.")
            ))
        end
    end

    self._isScanning = false
    if savedDifficulty and EJ_SetDifficulty then
        EJ_SetDifficulty(savedDifficulty)
    end
    if savedInstanceID and savedInstanceID ~= 0 and EJ_SelectInstance then
        pcall(EJ_SelectInstance, savedInstanceID)
        if savedDifficulty and EJ_SetDifficulty then
            EJ_SetDifficulty(savedDifficulty)
        end
    end
    if ejWasShown and EncounterJournal then
        EncounterJournal:Show()
    end

    -- Only cache if we got items with complete details.  If the client
    -- hasn't loaded the item data yet (common at startup) we'll have IDs
    -- but no name/link/icon — skip caching so a retry can pick them up.
    local totalItems = 0
    local incompleteItems = 0
    for _, entry in ipairs(result) do
        for _, item in ipairs(entry.items) do
            totalItems = totalItems + 1
            if not item.itemName or item.itemName == ""
                or not item.icon then
                incompleteItems = incompleteItems + 1
            end
        end
    end
    if totalItems > 0 and incompleteItems == 0 then
        self._lootCache[key] = result
    elseif totalItems > 0 then
        -- Prime the client item cache so the next retry succeeds.
        for _, entry in ipairs(result) do
            for _, item in ipairs(entry.items) do
                if item.itemID and GetItemInfo then
                    GetItemInfo(item.itemID)
                end
            end
        end
    end
    return result
end

local _scanRetries = 0
local _maxScanRetries = 5

function Spoilscribe:ScanAllCombinations()
    EnsureEncounterJournalLoaded()
    local specs = self:GetSpecList()
    for _, diff in ipairs(self.Data.Difficulties) do
        for _, spec in ipairs(specs) do
            self:ScanLootForDifficultyAndSpec(diff.id, spec.classID, spec.specID)
        end
    end

    -- Check whether every combination got cached.
    local allCached = true
    for _, diff in ipairs(self.Data.Difficulties) do
        for _, spec in ipairs(specs) do
            if not self._lootCache[self:CacheKey(diff.id, spec.specID)] then
                allCached = false
                break
            end
        end
        if not allCached then break end
    end

    if not allCached and _scanRetries < _maxScanRetries then
        _scanRetries = _scanRetries + 1
        local delay = _scanRetries * 2
        C_Timer.After(delay, function()
            local ok, err = pcall(function() Spoilscribe:ScanAllCombinations() end)
            if not ok then
                Spoilscribe:LogToConsole("Retry scan failed: " .. tostring(err))
            end
        end)
    elseif allCached then
        self:LogToConsole("Loot scan complete for all difficulties and specs.")
    end
end

function Spoilscribe:InvalidateLootCache()
    wipe(self._lootCache)
end
