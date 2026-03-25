local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}
_G[addonName] = Spoilscribe

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
    if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
        local info = C_EncounterJournal.GetLootInfoByIndex(index, encounterID)
        if info then
            return {
                itemID = info.itemID,
                link = info.itemLink,
                name = info.name,
                slot = info.slot,
                armorType = info.armorType,
            }
        end

        -- Some client builds expect only index after EJ_SelectEncounter.
        local fallbackInfo = C_EncounterJournal.GetLootInfoByIndex(index)
        if fallbackInfo then
            return {
                itemID = fallbackInfo.itemID,
                link = fallbackInfo.itemLink,
                name = fallbackInfo.name,
                slot = fallbackInfo.slot,
                armorType = fallbackInfo.armorType,
            }
        end
    end

    if EJ_GetLootInfoByIndex then
        local itemID, _, _, name, _, slot, armorType, itemLink = EJ_GetLootInfoByIndex(index, encounterID)
        if itemID then
            return {
                itemID = itemID,
                link = itemLink,
                name = name,
                slot = slot,
                armorType = armorType,
            }
        end

        -- Some builds require encounter to be selected first, then queried by index only.
        local fallbackItemID, _, _, fallbackName, _, fallbackSlot, fallbackArmorType, fallbackLink = EJ_GetLootInfoByIndex(index)
        if fallbackItemID then
            return {
                itemID = fallbackItemID,
                link = fallbackLink,
                name = fallbackName,
                slot = fallbackSlot,
                armorType = fallbackArmorType,
            }
        end
    end

    return nil
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

    EnsureEncounterJournalLoaded()

    local initialTier = nil
    if EJ_GetNumTiers and EJ_GetNumTiers() and EJ_GetNumTiers() > 0 then
        initialTier = EJ_GetNumTiers()
    end
    if EJ_SelectTier and initialTier then
        EJ_SelectTier(initialTier)
    end

    local lines = {}
    lines[#lines + 1] = string.format("Difficulty: %s", difficulty and difficulty.label or "Unknown")
    lines[#lines + 1] = string.format("Slot Filter: %s", selectedSlotLabel)
    lines[#lines + 1] = "---------------------------------------------"

    local validDungeonCount = 0

    for _, dungeon in ipairs(self.Data.Dungeons) do
        if EJ_SelectTier and initialTier then
            EJ_SelectTier(initialTier)
        end

        local selected, selectError = TrySelectInstance(dungeon.ejInstanceID)
        if selected then
            validDungeonCount = validDungeonCount + 1

            if EJ_SetDifficulty and difficulty and difficulty.id then
                EJ_SetDifficulty(difficulty.id)
            end

            lines[#lines + 1] = ""
            lines[#lines + 1] = string.format("|cffffd200Dungeon: %s|r", dungeon.name)
            lines[#lines + 1] = "|cff808080---------------------------------------------|r"

            local dungeonHasLoot = false

            for _, encounterID in ipairs(dungeon.encounters) do
                local encounterSelected, encounterSelectError = TrySelectEncounter(encounterID)

                if not encounterSelected then
                    LogToConsole(string.format(
                        "Encounter select failed in %s (EncounterID: %d). %s",
                        tostring(dungeon.name),
                        tonumber(encounterID) or 0,
                        tostring(encounterSelectError or "No reason provided.")
                    ))
                    lines[#lines + 1] = string.format("  - Encounter select failed for ID %d", encounterID)
                    if encounterSelectError and encounterSelectError ~= "" then
                        lines[#lines + 1] = "  - Reason: " .. encounterSelectError
                    end
                else
                    local lootIndex = 1
                    while true do
                        local loot = GetLootInfoByIndex(lootIndex, encounterID)
                        if not loot then
                            break
                        end

                        if LootMatchesSlotFilter(loot, selectedSlotLabel) then
                            dungeonHasLoot = true
                            local itemText = GetQualityColoredItemText(loot)
                            local slotText = loot.slot or "Unknown slot"
                            local armorTypeText = loot.armorType or ""
                            local itemLineText = nil

                            if armorTypeText ~= "" then
                                itemLineText = string.format("  - %s (%s, %s)", itemText, slotText, armorTypeText)
                            else
                                itemLineText = string.format("  - %s (%s)", itemText, slotText)
                            end

                            lines[#lines + 1] = {
                                text = itemLineText,
                                itemID = loot.itemID,
                                itemLink = loot.link,
                            }
                        end

                        lootIndex = lootIndex + 1
                    end
                end
            end

            if not dungeonHasLoot then
                lines[#lines + 1] = "  - No loot entries found for this dungeon/difficulty."
            end

            lines[#lines + 1] = ""
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

    return lines
end

function Spoilscribe:RefreshLoot()
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
f:SetScript("OnEvent", function(_, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= addonName then
        return
    end

    -- Keep UI creation lazy to avoid startup failures if Blizzard UI modules are not loaded yet.
end)
