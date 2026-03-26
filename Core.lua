local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}
_G[addonName] = Spoilscribe

-- Tracks whether any EJ item links were missing during the last scan.
local _hadMissingLinks = false
-- Guard to prevent re-entrancy during scanning.
local _isScanning = false
SpoilscribeDB = SpoilscribeDB or {}

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

local function LogToConsole(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: " .. tostring(message))
    elseif print then
        print("Spoilscribe: " .. tostring(message))
    end
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
                _hadMissingLinks = true
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

local function GetQualityColoredItemText(loot)
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

local function NormalizeSlotText(value)
    if not value then
        return ""
    end

    local normalized = string.lower(tostring(value))
    normalized = normalized:gsub("[^%a%d]", "")
    return normalized
end

local function LootMatchesSlotFilter(loot, selectedSlotLabel)
    if not selectedSlotLabel or selectedSlotLabel == "Any Slot" then
        return true
    end

    local normalizedSlot = NormalizeSlotText(loot and loot.slot)
    if normalizedSlot == "" then
        return false
    end

    local normalizedFilter = NormalizeSlotText(selectedSlotLabel)
    local aliasesByFilter = {
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

    local aliases = aliasesByFilter[normalizedFilter] or { normalizedFilter }
    for _, alias in ipairs(aliases) do
        if string.find(normalizedSlot, alias, 1, true) then
            return true
        end
    end

    return false
end

local function LootMatchesSecondaryFilter(loot, selectedSecondaryLabel)
    if not selectedSecondaryLabel or selectedSecondaryLabel == "Any Stats" then
        return true
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

    local requiredTokensByLabel = {
        ["Critical Strike"] = { "CRIT", "CRITICAL" },
        ["Haste"] = { "HASTE" },
        ["Mastery"] = { "MASTERY" },
        ["Versatility"] = { "VERSATILITY" },
    }

    local requiredTokens = requiredTokensByLabel[selectedSecondaryLabel]
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

function Spoilscribe:BuildLootLines()
    local frame = self.UI and self.UI.frame
    if not frame then
        return { "Spoilscribe UI is not ready." }
    end

    local difficulty = self.Data.Difficulties[frame.selectedDifficultyIndex or 1]
    local selectedSlotLabel = "Any Slot"
    if self.Data and self.Data.Filters and self.Data.Filters.slots then
        selectedSlotLabel = self.Data.Filters.slots[frame.selectedSlotIndex or 1] or "Any Slot"
    end
    local selectedSecondaryLabel = "Any Stats"
    if self.Data and self.Data.Filters and self.Data.Filters.secondaryStats then
        selectedSecondaryLabel = self.Data.Filters.secondaryStats[frame.selectedSecondaryIndex or 1] or "Any Stats"
    end

    EnsureEncounterJournalLoaded()

    -- Save the current EJ state so we can restore it after our scan.
    -- This prevents conflicts when the Encounter Journal UI is also open.
    local savedDifficulty = EJ_GetDifficulty and EJ_GetDifficulty()
    local savedInstanceID = EJ_GetCurrentInstance and EJ_GetCurrentInstance()

    _isScanning = true

    local initialTier = nil
    if EJ_GetNumTiers and EJ_GetNumTiers() and EJ_GetNumTiers() > 0 then
        initialTier = EJ_GetNumTiers()
    end
    if EJ_SelectTier and initialTier then
        EJ_SelectTier(initialTier)
    end
    if EJ_SetDifficulty and difficulty and difficulty.id then
        EJ_SetDifficulty(difficulty.id)
    end

    local lines = {}
    lines[#lines + 1] = string.format("Difficulty: %s", difficulty and difficulty.label or "Unknown")
    lines[#lines + 1] = string.format("Slot Filter: %s", selectedSlotLabel)
    lines[#lines + 1] = string.format("Secondary Filter: %s", selectedSecondaryLabel)
    lines[#lines + 1] = "---------------------------------------------"

    local validDungeonCount = 0

    for _, dungeon in ipairs(self.Data.Dungeons) do
        if EJ_SelectTier and initialTier then
            EJ_SelectTier(initialTier)
        end
        if EJ_SetDifficulty and difficulty and difficulty.id then
            EJ_SetDifficulty(difficulty.id)
        end

        local selected, selectError = TrySelectInstance(dungeon.ejInstanceID)
        if selected then
            validDungeonCount = validDungeonCount + 1

            local dungeonItems = {}

            for _, encounterID in ipairs(dungeon.encounters) do
                local encounterSelected, encounterSelectError = TrySelectEncounter(encounterID)

                if not encounterSelected then
                    LogToConsole(string.format(
                        "Encounter select failed in %s (EncounterID: %d). %s",
                        tostring(dungeon.name),
                        tonumber(encounterID) or 0,
                        tostring(encounterSelectError or "No reason provided.")
                    ))
                else
                    if EJ_SetDifficulty and difficulty and difficulty.id then
                        EJ_SetDifficulty(difficulty.id)
                    end

                    -- Get boss name for this encounter.
                    local bossName = nil
                    if EJ_GetEncounterInfo then
                        local eName = EJ_GetEncounterInfo(encounterID)
                        if eName then bossName = eName end
                    end

                    local lootIndex = 1
                    while true do
                        local loot = GetLootInfoByIndex(lootIndex, encounterID)
                        if not loot then
                            break
                        end

                        if LootMatchesSlotFilter(loot, selectedSlotLabel)
                            and LootMatchesSecondaryFilter(loot, selectedSecondaryLabel) then

                            dungeonItems[#dungeonItems + 1] = {
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
                        end

                        lootIndex = lootIndex + 1
                    end
                end
            end

            if #dungeonItems > 0 then
                lines[#lines + 1] = { type = "header", text = dungeon.name }
                for _, item in ipairs(dungeonItems) do
                    lines[#lines + 1] = item
                end
            end
        else
            LogToConsole(string.format(
                "Instance select failed for %s (EJInstanceID: %d). %s",
                tostring(dungeon.name),
                tonumber(dungeon.ejInstanceID) or 0,
                tostring(selectError or "No reason provided.")
            ))

            lines[#lines + 1] = ""
            lines[#lines + 1] = string.format("|cffffd200Dungeon: %s|r", dungeon.name)
            lines[#lines + 1] = "|cff808080---------------------------------------------|r"
            lines[#lines + 1] = "  - Skipped: Encounter Journal could not select this instance ID."
            lines[#lines + 1] = string.format("  - EJInstanceID: %d", dungeon.ejInstanceID)
            if selectError and selectError ~= "" then
                lines[#lines + 1] = "  - Reason: " .. selectError
            end
            lines[#lines + 1] = ""
        end
    end

    if validDungeonCount == 0 then
        lines[#lines + 1] = "No configured dungeons are currently available in Encounter Journal for this client/tier."
    end

    -- Restore previous EJ state so the Encounter Journal UI isn't affected.
    _isScanning = false
    if savedDifficulty and EJ_SetDifficulty then
        EJ_SetDifficulty(savedDifficulty)
    end
    if savedInstanceID and savedInstanceID ~= 0 and EJ_SelectInstance then
        pcall(EJ_SelectInstance, savedInstanceID)
        -- Re-apply difficulty since SelectInstance resets it.
        if savedDifficulty and EJ_SetDifficulty then
            EJ_SetDifficulty(savedDifficulty)
        end
    end

    return lines
end

function Spoilscribe:RefreshLoot()
    _hadMissingLinks = false

    if not self.UI or not self.UI.RenderLoot then
        return
    end

    local ok, lines = pcall(function()
        return self:BuildLootLines()
    end)

    if not ok then
        local errorText = tostring(lines)
        lines = {
            "Spoilscribe failed to load loot.",
            "Error: " .. errorText,
            "Tip: /reload and open the addon again.",
        }

        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe error: " .. errorText)
        end
    end

    self.UI:RenderLoot(lines)
end

function Spoilscribe:Open()
    if not self.UI or not self.UI.ToggleMainFrame then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: UI failed to initialize.")
        end
        return
    end

    self.UI:ToggleMainFrame()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "EJ_LOOT_DATA_RECIEVED" then
        -- EJ item data has arrived; if our frame is visible and we're not mid-scan, re-render.
        if not _isScanning and Spoilscribe.UI and Spoilscribe.UI.frame and Spoilscribe.UI.frame:IsShown() then
            Spoilscribe:RefreshLoot()
        end
        return
    end

    if event ~= "ADDON_LOADED" or arg1 ~= addonName then
        return
    end

    -- Keep UI creation lazy to avoid startup failures if Blizzard UI modules are not loaded yet.
end)
