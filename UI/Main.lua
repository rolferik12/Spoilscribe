local _, Spoilscribe = ...
local L = Spoilscribe.L

-- UI table is initialized by UIWidgets.lua (loaded first).
local UI = Spoilscribe.UI
local Widgets = UI.Widgets

function UI:CreateMainFrame()
    if self.frame then
        return self.frame
    end

    if not Widgets:EnsureDropdownAPILoaded() then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(L["Spoilscribe: Blizzard dropdown UI failed to load."])
        end
        return nil
    end

    local frame = CreateFrame("Frame", "SpoilscribeFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(800, 579)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)

    tinsert(UISpecialFrames, "SpoilscribeFrame")
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE)
    end)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
    frame.title:SetText(L["Spoilscribe - Dungeon Loot"])

    -- Controls bar (dropdowns).
    local controls = CreateFrame("Frame", nil, frame)
    controls:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
    controls:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -32)
    controls:SetHeight(100)

    local totalWidth = 800 - 24
    local colWidth = math.floor(totalWidth / 4)
    local dropdownWidth = colWidth - 24

    local labelOffsets = { 10, 10 + colWidth, 10 + colWidth * 2, 10 + colWidth * 3 }
    local dropdownOffsets = { -16, -16 + colWidth, -16 + colWidth * 2, -16 + colWidth * 3 }

    local difficultyLabel = Widgets:CreateLabel(controls, L["Difficulty"])
    difficultyLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", labelOffsets[1], -10)

    local slotLabel = Widgets:CreateLabel(controls, L["Slot"])
    slotLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", labelOffsets[2], -10)

    local statsLabel = Widgets:CreateLabel(controls, L["Secondary Stats"])
    statsLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", labelOffsets[3], -10)

    local specLabel = Widgets:CreateLabel(controls, L["Loot Spec"])
    specLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", labelOffsets[4], -10)

    local savedDifficultyIndex = SpoilscribeCharDB.options and SpoilscribeCharDB.options.difficultyIndex or 1
    frame.difficultyDropdown = Widgets:BuildDropdown(
        controls,
        dropdownWidth,
        Spoilscribe.Data.Difficulties,
        savedDifficultyIndex,
        function(index)
            frame.selectedDifficultyIndex = index
            SpoilscribeCharDB.options = SpoilscribeCharDB.options or {}
            SpoilscribeCharDB.options.difficultyIndex = index
            Spoilscribe:RefreshLoot()
            Spoilscribe:BroadcastFavorites()
        end
    )
    frame.difficultyDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", dropdownOffsets[1], -23)
    frame.selectedDifficultyIndex = savedDifficultyIndex

    frame.slotDropdown = Widgets:BuildDropdown(
        controls,
        dropdownWidth,
        Spoilscribe.Data.Filters.slots,
        1,
        function(index)
            frame.selectedSlotIndex = index
            Spoilscribe:RefreshLoot()
        end
    )
    frame.slotDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", dropdownOffsets[2], -23)

    frame.secondaryDropdown = Widgets:BuildDropdown(
        controls,
        dropdownWidth,
        Spoilscribe.Data.Filters.secondaryStats,
        1,
        function(index)
            frame.selectedSecondaryIndex = index
            Spoilscribe:RefreshLoot()
        end
    )
    frame.secondaryDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", dropdownOffsets[3], -23)

    local specList = Spoilscribe:GetSpecList()
    local defaultSpecIndex = 1
    local lootSpecID = GetLootSpecialization and GetLootSpecialization() or 0
    if lootSpecID == 0 then
        local currentSpec = GetSpecialization and GetSpecialization() or 0
        if currentSpec > 0 and GetSpecializationInfo then
            lootSpecID = GetSpecializationInfo(currentSpec) or 0
        end
    end
    if lootSpecID > 0 then
        for i, spec in ipairs(specList) do
            if spec.specID == lootSpecID then
                defaultSpecIndex = i
                break
            end
        end
    end
    frame.selectedSpecIndex = defaultSpecIndex
    frame._defaultSpecIndex = defaultSpecIndex
    frame.specDropdown = Widgets:BuildDropdown(
        controls,
        dropdownWidth,
        specList,
        defaultSpecIndex,
        function(index)
            frame.selectedSpecIndex = index
            Spoilscribe:RefreshLoot()
        end
    )
    frame.specDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", dropdownOffsets[4], -23)

    -- Search bar and settings popup (from UISearch).
    local searchContainer = UI.Search:CreateSearchBar(controls, frame)
    UI.Search:CreateSettingsPopup(controls, frame, searchContainer)

    -- Result area with pagination (from UILoot).
    self:CreateResultArea(frame)

    -- Tab buttons and favorites panel (from UIFavorites).
    UI.Favorites:CreateHomeButton(frame)
    local slideOut = UI.Favorites:CreatePanel(frame)
    local slideBtn = UI.Favorites:CreateToggleButton(frame, slideOut)
    local zoomBtn = UI.Favorites:CreateZoomButton(frame, slideBtn)
    UI.Favorites:CreateAssistButton(frame, zoomBtn)

    self.frame = frame

    Spoilscribe.RefreshLocaleUI = function()
        frame.title:SetText(L["Spoilscribe - Dungeon Loot"])
        difficultyLabel:SetText(L["Difficulty"])
        slotLabel:SetText(L["Slot"])
        statsLabel:SetText(L["Secondary Stats"])
        specLabel:SetText(L["Loot Spec"])
        frame.difficultyDropdown:RefreshLocale()
        frame.slotDropdown:RefreshLocale()
        frame.secondaryDropdown:RefreshLocale()
        frame.specDropdown:RefreshLocale()
    end

    return frame
end

function UI:ToggleMainFrame()
    local frame = self:CreateMainFrame()
    if not frame then
        return
    end
    if frame:IsShown() then
        frame:Hide()
    else
        if EncounterJournal and EncounterJournal:IsShown() then
            EncounterJournal:Hide()
        end

        if not self._ejHooked then
            self._ejHooked = true
            if EncounterJournal_LoadUI then
                pcall(EncounterJournal_LoadUI)
            end
            if EncounterJournal then
                EncounterJournal:HookScript("OnShow", function()
                    if self.frame and self.frame:IsShown() then
                        self.frame:Hide()
                    end
                end)
            end
        end

        frame:Show()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
        UI.Favorites:UpdateAssistButton(frame)
        if SpoilscribeCharDB.favoritesOpen and frame.SetFavoritesOpen then
            frame.SetFavoritesOpen(true)
        end
        Spoilscribe:RefreshLoot()
    end
end

function UI:HasActiveFilter()
    local frame = self.frame
    if not frame then return false end
    if frame._hasFilter then return true end
    if (frame.selectedDifficultyIndex or 1) ~= 1 then return true end
    if (frame.selectedSlotIndex or 1) ~= 1 then return true end
    if (frame.selectedSecondaryIndex or 1) ~= 1 then return true end
    if (frame.selectedSpecIndex or 1) ~= (frame._defaultSpecIndex or 1) then return true end
    if frame.searchText and frame.searchText ~= "" then return true end
    return false
end
