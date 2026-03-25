local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}
_G[addonName] = Spoilscribe

SpoilscribeDB = SpoilscribeDB or {}

local function EnsureEncounterJournalLoaded()
    if not EncounterJournal then
        EncounterJournal_LoadUI()
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
    end

    return nil
end

function Spoilscribe:BuildLootLines()
    local frame = self.UI and self.UI.frame
    if not frame then
        return { "Spoilscribe UI is not ready." }
    end

    local difficulty = self.Data.Difficulties[frame.selectedDifficultyIndex or 1]

    EnsureEncounterJournalLoaded()

    if EJ_SelectTier and EJ_GetNumTiers then
        EJ_SelectTier(EJ_GetNumTiers())
    end

    local lines = {}
    lines[#lines + 1] = string.format("Difficulty: %s", difficulty and difficulty.label or "Unknown")
    lines[#lines + 1] = "---------------------------------------------"

    for _, dungeon in ipairs(self.Data.Dungeons) do
        if EJ_SelectInstance then
            EJ_SelectInstance(dungeon.instanceID)
        end

        if EJ_SetDifficulty and difficulty and difficulty.id then
            EJ_SetDifficulty(difficulty.id)
        end

        lines[#lines + 1] = string.format("== %s ==", dungeon.name)

        for _, encounterID in ipairs(dungeon.encounters) do
            local encounterName = "Encounter " .. tostring(encounterID)
            if EJ_GetEncounterInfo then
                local possibleName = EJ_GetEncounterInfo(encounterID)
                if possibleName and possibleName ~= "" then
                    encounterName = possibleName
                end
            end

            lines[#lines + 1] = string.format("[%s]", encounterName)

            local hasLoot = false
            local lootIndex = 1
            while true do
                local loot = GetLootInfoByIndex(lootIndex, encounterID)
                if not loot then
                    break
                end

                hasLoot = true
                local itemText = loot.link or loot.name or ("Item " .. tostring(loot.itemID))
                local slotText = loot.slot or "Unknown slot"
                local armorTypeText = loot.armorType or ""

                if armorTypeText ~= "" then
                    lines[#lines + 1] = string.format("  - %s (%s, %s)", itemText, slotText, armorTypeText)
                else
                    lines[#lines + 1] = string.format("  - %s (%s)", itemText, slotText)
                end

                lootIndex = lootIndex + 1
            end

            if not hasLoot then
                lines[#lines + 1] = "  - No loot entries found for this encounter/difficulty."
            end

            lines[#lines + 1] = ""
        end
    end

    return lines
end

function Spoilscribe:RefreshLoot()
    if not self.UI or not self.UI.RenderLoot then
        return
    end
    local lines = self:BuildLootLines()
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
