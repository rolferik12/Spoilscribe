local _, Spoilscribe = ...
local L = Spoilscribe.L

function Spoilscribe:BuildLootLines()
    local frame = self.UI and self.UI.frame
    if not frame then
        return { L["Spoilscribe UI is not ready."] }
    end

    local difficulty = self.Data.Difficulties[frame.selectedDifficultyIndex or 1]
    local selectedSlotLabel = "Any Slot"
    if self.Data and self.Data.Filters and self.Data.Filters.slots then
        selectedSlotLabel = self.Data.Filters.slots[frame.selectedSlotIndex or 1] or L["Any Slot"]
    end
    local selectedSecondaryLabel = "Any Stats"
    if self.Data and self.Data.Filters and self.Data.Filters.secondaryStats then
        selectedSecondaryLabel = self.Data.Filters.secondaryStats[frame.selectedSecondaryIndex or 1] or L["Any Stats"]
    end

    local specs = self:GetSpecList()
    local selectedSpec = specs[frame.selectedSpecIndex or 1] or specs[1]

    -- Scan (or use cache) for this difficulty + spec.
    local searchText = frame.searchText and frame.searchText ~= "" and string.lower(frame.searchText) or nil

    local diffId = difficulty and difficulty.id or 23
    local cachedDungeons = self:ScanLootForDifficultyAndSpec(diffId, selectedSpec.classID, selectedSpec.specID)

    local lines = {}

    if not cachedDungeons or #cachedDungeons == 0 then
        lines[#lines + 1] = L["No configured dungeons are currently available in Encounter Journal for this client/tier."]
        return lines
    end

    for _, dungeonEntry in ipairs(cachedDungeons) do
        local filtered = {}
        for _, item in ipairs(dungeonEntry.items) do
            if self:LootMatchesSlotFilter(item, selectedSlotLabel)
                and self:LootMatchesSecondaryFilter(item, selectedSecondaryLabel)
                and (not searchText
                     or (function()
                         local sf = SpoilscribeDB.searchFields or {}
                         if sf.itemName ~= false and item.itemName and string.find(string.lower(item.itemName), searchText, 1, true) then return true end
                         if sf.bossName ~= false and item.bossName and string.find(string.lower(item.bossName), searchText, 1, true) then return true end
                         if sf.slot ~= false and item.slot and string.find(string.lower(item.slot), searchText, 1, true) then return true end
                         if sf.armorType ~= false and item.armorType and string.find(string.lower(item.armorType), searchText, 1, true) then return true end
                         if sf.dungeonName ~= false and dungeonEntry.dungeonName and string.find(string.lower(dungeonEntry.dungeonName), searchText, 1, true) then return true end
                         if sf.secondaryStats ~= false then
                             local statLabels = self:GetSecondaryStatLabels(item)
                             if statLabels then
                                 for _, lbl in ipairs(statLabels) do
                                     if string.find(lbl, searchText, 1, true) then return true end
                                 end
                             end
                         end
                         return false
                     end)())
                then
                filtered[#filtered + 1] = item
            end
        end

        if #filtered > 0 then
            lines[#lines + 1] = { type = "header", text = dungeonEntry.dungeonName }
            for _, item in ipairs(filtered) do
                lines[#lines + 1] = item
            end
        end
    end

    return lines
end

function Spoilscribe:RefreshLoot()
    self._hadMissingLinks = false

    if not self.UI or not self.UI.RenderLoot then
        return
    end

    -- Clear any pinned favorite item so normal filtering resumes.
    if self.UI.frame then
        self.UI.frame._pinnedItem = nil
        self.UI.frame._zoomedFavorites = false
        self.UI.frame._zoomedPartyFavorites = false
    end

    local ok, lines = pcall(function()
        return self:BuildLootLines()
    end)

    if not ok then
        local errorText = tostring(lines)
        lines = {
            L["Spoilscribe failed to load loot."],
            string.format(L["Error: %s"], errorText),
            L["Tip: /reload and open the addon again."],
        }

        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe error: " .. errorText)
        end
    end

    self.UI:RenderLoot(lines)

    -- Highlight home tab when returning to the main view.
    if self.UI.frame and self.UI.frame.homeBtn then
        self.UI.Favorites:HighlightTab(self.UI.frame, self.UI.frame.homeBtn)
    end

    -- Refresh the favorites panel if it's open, since difficulty/spec may have changed.
    if self.UI.frame and self.UI.frame.slideOut and self.UI.frame.slideOut:IsShown() then
        self.UI:RenderFavorites()
    end
end
