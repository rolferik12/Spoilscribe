local _, Spoilscribe = ...

local UI = {}
Spoilscribe.UI = UI

local function EnsureDropdownAPILoaded()
    if UIDropDownMenu_SetWidth and UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo then
        return true
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_UIDropDownMenu")
    elseif LoadAddOn then
        LoadAddOn("Blizzard_UIDropDownMenu")
    end

    return UIDropDownMenu_SetWidth and UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo
end

local function BuildDropdown(parent, width, items, defaultIndex, onChanged)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)

    local function Initialize(self, level)
        for index, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            local text = item
            if type(item) == "table" then
                text = item.label or item.name
            end
            if text == nil then
                text = "Option " .. tostring(index)
            end
            text = tostring(text)
            info.text = text
            info.checked = (index == (dropdown.selectedIndex or defaultIndex or 1))
            info.func = function()
                dropdown.selectedIndex = index
                UIDropDownMenu_SetSelectedID(dropdown, index)
                if onChanged then
                    onChanged(index, item)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)
    UIDropDownMenu_SetSelectedID(dropdown, defaultIndex or 1)
    dropdown.selectedIndex = defaultIndex or 1

    return dropdown
end

local function CreateLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    return fs
end

function UI:CreateMainFrame()
    if self.frame then
        return self.frame
    end

    if not EnsureDropdownAPILoaded() then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: Blizzard dropdown UI failed to load.")
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
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
    frame.title:SetText("Spoilscribe - Dungeon Loot")

    local controls = CreateFrame("Frame", nil, frame)
    controls:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
    controls:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -32)
    controls:SetHeight(100)


    -- Calculate balanced widths and positions
    local totalWidth = 800 - 24  -- frame width minus left/right padding
    local colWidth = math.floor(totalWidth / 4)  -- 4 dropdowns
    local dropdownWidth = colWidth - 24  -- leave room for dropdown chrome

    local labelOffsets = { 10, 10 + colWidth, 10 + colWidth * 2, 10 + colWidth * 3 }
    local dropdownOffsets = { -16, -16 + colWidth, -16 + colWidth * 2, -16 + colWidth * 3 }

    local difficultyLabel = CreateLabel(controls, "Difficulty")
    difficultyLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", labelOffsets[1], -10)

    local slotLabel = CreateLabel(controls, "Slot")
    slotLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", labelOffsets[2], -10)

    local statsLabel = CreateLabel(controls, "Secondary Stats")
    statsLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", labelOffsets[3], -10)

    local specLabel = CreateLabel(controls, "Loot Spec")
    specLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", labelOffsets[4], -10)

    local defaultDifficultyIndex = 1 -- Mythic first in table.
    frame.difficultyDropdown = BuildDropdown(
        controls,
        dropdownWidth,
        Spoilscribe.Data.Difficulties,
        defaultDifficultyIndex,
        function(index)
            frame.selectedDifficultyIndex = index
            Spoilscribe:RefreshLoot()
        end
    )
    frame.difficultyDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", dropdownOffsets[1], -23)

    frame.slotDropdown = BuildDropdown(
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

    frame.secondaryDropdown = BuildDropdown(
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
    -- Default to the player's current loot spec (or active spec if loot spec is 0).
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
    frame.specDropdown = BuildDropdown(
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

    -- Search bar container (dark background with search icon + edit box + gear icon).
    local searchContainer = CreateFrame("Frame", nil, controls, "BackdropTemplate")
    searchContainer:SetSize(300, 24)
    searchContainer:SetPoint("TOP", controls, "TOP", 0, -68)
    searchContainer:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
    })
    searchContainer:SetBackdropColor(0, 0, 0, 0.7)
    searchContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

    local searchIcon = searchContainer:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", searchContainer, "LEFT", 6, 0)
    searchIcon:SetTexture("Interface/Common/UI-Searchbox-Icon")
    searchIcon:SetVertexColor(0.6, 0.6, 0.6)

    local searchBox = CreateFrame("EditBox", "SpoilscribeSearchBox", searchContainer)
    searchBox:SetSize(252, 18)
    searchBox:SetPoint("LEFT", searchIcon, "RIGHT", 4, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(100)
    searchBox:SetFontObject(ChatFontSmall)

    -- Placeholder text.
    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 2, 0)
    placeholder:SetText("Search items, stats, slot")
    placeholder:SetTextColor(0.5, 0.5, 0.5)
    searchBox._placeholder = placeholder

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        frame.searchText = text
        if text and text ~= "" then
            self._placeholder:Hide()
        else
            self._placeholder:Show()
        end
        Spoilscribe:RefreshLoot()
    end)
    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "" then self._placeholder:Hide() end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then self._placeholder:Show() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    frame.searchBox = searchBox

    -- Clear button inside search bar (hidden when search is empty).
    local clearBtn = CreateFrame("Button", nil, searchContainer)
    clearBtn:SetSize(14, 14)
    clearBtn:SetPoint("RIGHT", searchContainer, "RIGHT", -5, 0)
    clearBtn:SetNormalAtlas("common-search-clearbutton")
    clearBtn:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
    clearBtn:SetHighlightAtlas("common-search-clearbutton")
    clearBtn:GetHighlightTexture():SetVertexColor(1, 1, 1)
    clearBtn:GetHighlightTexture():SetAlpha(1)
    clearBtn:Hide()
    clearBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)
    frame.searchClearBtn = clearBtn

    -- Show/hide clear button based on search text.
    searchBox:HookScript("OnTextChanged", function(self)
        if self:GetText() ~= "" then
            clearBtn:Show()
        else
            clearBtn:Hide()
        end
    end)

    -- Gear (settings) button, placed to the right of the search bar.
    local gearBtn = CreateFrame("Button", nil, controls)
    gearBtn:SetSize(16, 16)
    gearBtn:SetPoint("LEFT", searchContainer, "RIGHT", 6, 0)
    gearBtn:SetNormalTexture("Interface/WorldMap/GEAR_64GREY")
    gearBtn:SetHighlightTexture("Interface/WorldMap/GEAR_64GREY")
    gearBtn:GetHighlightTexture():SetAlpha(0.4)

    -- Search-settings popup (toggled by the gear button).
    local settingsPopup = CreateFrame("Frame", "SpoilscribeSearchSettings", UIParent, "BackdropTemplate")
    settingsPopup:SetSize(180, 174)
    settingsPopup:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    settingsPopup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    settingsPopup:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    settingsPopup:SetFrameStrata("DIALOG")
    settingsPopup:Hide()

    local popupTitle = settingsPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popupTitle:SetPoint("TOPLEFT", settingsPopup, "TOPLEFT", 12, -10)
    popupTitle:SetText("Search fields")

    -- Default search settings (all on).
    SpoilscribeDB.searchFields = SpoilscribeDB.searchFields or {
        itemName    = true,
        bossName    = true,
        slot        = true,
        armorType   = true,
        dungeonName = true,
        secondaryStats = true,
    }

    local checkboxDefs = {
        { key = "itemName",       label = "Item Name" },
        { key = "bossName",       label = "Boss Name" },
        { key = "slot",           label = "Slot" },
        { key = "armorType",      label = "Armor Type" },
        { key = "dungeonName",    label = "Dungeon Name" },
        { key = "secondaryStats", label = "Secondary Stats" },
    }

    local cbY = -28
    for _, def in ipairs(checkboxDefs) do
        local cb = CreateFrame("CheckButton", nil, settingsPopup, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", settingsPopup, "TOPLEFT", 10, cbY)
        cb:SetChecked(SpoilscribeDB.searchFields[def.key])
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.text:SetText(def.label)
        cb:SetScript("OnClick", function(self)
            SpoilscribeDB.searchFields[def.key] = self:GetChecked() and true or false
            Spoilscribe:RefreshLoot()
        end)
        cbY = cbY - 22
    end

    gearBtn:SetScript("OnClick", function()
        if settingsPopup:IsShown() then
            settingsPopup:Hide()
        else
            settingsPopup:ClearAllPoints()
            settingsPopup:SetPoint("TOPLEFT", gearBtn, "BOTTOMRIGHT", -180, 0)
            settingsPopup:Show()
        end
    end)

    -- Close popup when clicking elsewhere.
    local settingsOverlay = CreateFrame("Button", nil, UIParent)
    settingsOverlay:SetAllPoints(UIParent)
    settingsOverlay:SetFrameStrata("DIALOG")
    settingsOverlay:SetFrameLevel(settingsPopup:GetFrameLevel() - 1)
    settingsOverlay:Hide()
    settingsOverlay:SetScript("OnClick", function()
        settingsPopup:Hide()
    end)

    settingsPopup:SetScript("OnShow", function()
        settingsOverlay:Show()
    end)
    settingsPopup:SetScript("OnHide", function()
        settingsOverlay:Hide()
    end)
    settingsPopup:EnableMouse(true)

    local resultArea = CreateFrame("Frame", nil, frame)
    resultArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -132)
    resultArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    resultArea:SetSize(700, 347)
    resultArea:SetFrameLevel(frame:GetFrameLevel() + 1)

    local resultBg = resultArea:CreateTexture(nil, "BACKGROUND")
    resultBg:SetAllPoints(resultArea)
    resultBg:SetTexture("Interface/EncounterJournal/UI-EJ-JournalBG")
    resultBg:SetTexCoord(0, 786/1024, 0, 426/512)

    local content = CreateFrame("Frame", nil, resultArea)
    content:SetAllPoints()
    content:SetFrameLevel(resultArea:GetFrameLevel() + 1)

    -- Page navigation.
    frame.currentPage = 1
    frame.linesPerPage = nil -- computed at render time

    local nextButton = CreateFrame("Button", nil, resultArea, "UIPanelButtonTemplate")
    nextButton:SetSize(26, 22)
    nextButton:SetPoint("BOTTOMRIGHT", resultArea, "BOTTOMRIGHT", -25, 8)
    nextButton:SetText(">")
    nextButton:SetScript("OnClick", function()
        if frame.currentPage < (frame.totalPages or 1) then
            frame.currentPage = frame.currentPage + 1
            Spoilscribe.UI:RenderPage()
        end
    end)
    frame.nextButton = nextButton

    local prevButton = CreateFrame("Button", nil, resultArea, "UIPanelButtonTemplate")
    prevButton:SetSize(26, 22)
    prevButton:SetPoint("RIGHT", nextButton, "LEFT", -2, 0)
    prevButton:SetText("<")
    prevButton:SetScript("OnClick", function()
        if frame.currentPage > 1 then
            frame.currentPage = frame.currentPage - 1
            Spoilscribe.UI:RenderPage()
        end
    end)
    frame.prevButton = prevButton

    local pageText = resultArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("RIGHT", prevButton, "LEFT", -6, 0)
    frame.pageText = pageText

    -- Mouse wheel paging.
    resultArea:EnableMouseWheel(true)
    resultArea:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 and frame.currentPage > 1 then
            frame.currentPage = frame.currentPage - 1
            Spoilscribe.UI:RenderPage()
        elseif delta < 0 and frame.currentPage < (frame.totalPages or 1) then
            frame.currentPage = frame.currentPage + 1
            Spoilscribe.UI:RenderPage()
        end
    end)

    -- Clear-filter button (visible only when a pinned/zoom view is active).
    local clearFilterBtn = CreateFrame("Button", nil, resultArea)
    clearFilterBtn:SetSize(21, 21)
    clearFilterBtn:SetPoint("TOPRIGHT", resultArea, "TOPRIGHT", -15, -11)
    clearFilterBtn:SetNormalAtlas("perks-dropdown-clear")
    clearFilterBtn:SetHighlightAtlas("perks-dropdown-clear")
    clearFilterBtn:GetHighlightTexture():SetAlpha(0.6)
    clearFilterBtn:SetFrameLevel(resultArea:GetFrameLevel() + 10)
    clearFilterBtn:Hide()
    clearFilterBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Clear Filter")
        GameTooltip:Show()
    end)
    clearFilterBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    clearFilterBtn:SetScript("OnClick", function()
        frame._hasFilter = false
        -- Reset dropdowns to defaults.
        frame.selectedDifficultyIndex = 1
        frame.difficultyDropdown.selectedIndex = 1
        UIDropDownMenu_SetSelectedID(frame.difficultyDropdown, 1)
        UIDropDownMenu_SetText(frame.difficultyDropdown, Spoilscribe.Data.Difficulties[1].label)

        frame.selectedSlotIndex = 1
        frame.slotDropdown.selectedIndex = 1
        UIDropDownMenu_SetSelectedID(frame.slotDropdown, 1)
        UIDropDownMenu_SetText(frame.slotDropdown, Spoilscribe.Data.Filters.slots[1])

        frame.selectedSecondaryIndex = 1
        frame.secondaryDropdown.selectedIndex = 1
        UIDropDownMenu_SetSelectedID(frame.secondaryDropdown, 1)
        UIDropDownMenu_SetText(frame.secondaryDropdown, Spoilscribe.Data.Filters.secondaryStats[1])

        local specList = Spoilscribe:GetSpecList()
        local defSpec = frame._defaultSpecIndex
        frame.selectedSpecIndex = defSpec
        frame.specDropdown.selectedIndex = defSpec
        UIDropDownMenu_SetSelectedID(frame.specDropdown, defSpec)
        local specItem = specList[defSpec]
        UIDropDownMenu_SetText(frame.specDropdown, specItem and (specItem.label or specItem.name) or "")

        -- Clear search text.
        frame.searchBox:SetText("")
        frame.searchBox:ClearFocus()
        Spoilscribe:RefreshLoot()
    end)
    frame.clearFilterBtn = clearFilterBtn

    frame.resultArea = resultArea
    frame.content = content
    frame.rows = {}

    -- Favorites box (slide-out panel, hidden by default, opens to the right).
    local slideOut = CreateFrame("Frame", "SpoilscribeSlideOut", frame, "BackdropTemplate")
    slideOut:SetSize(250, 579)
    slideOut:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    slideOut:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    slideOut:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    slideOut:SetFrameLevel(frame:GetFrameLevel() + 1)
    slideOut:Hide()
    frame.slideOut = slideOut

    local slideOutBg = slideOut:CreateTexture(nil, "BACKGROUND")
    slideOutBg:SetAllPoints(slideOut)
    slideOut._bg = slideOutBg

    function slideOut:UpdateBackground()
        SpoilscribeCharDB.favorites = SpoilscribeCharDB.favorites or {}
        local hasFavorites = next(SpoilscribeCharDB.favorites) ~= nil
        if hasFavorites then
            self._bg:SetAtlas("QuestLog-main-background")
        else
            self._bg:SetAtlas("QuestLog-empty-quest-background")
        end
    end
    slideOut:UpdateBackground()

    -- Scrollable content inside the favorites box.
    local favScroll = CreateFrame("ScrollFrame", "SpoilscribeFavScroll", slideOut, "UIPanelScrollFrameTemplate")
    favScroll:SetPoint("TOPLEFT", slideOut, "TOPLEFT", 8, -8)
    favScroll:SetPoint("BOTTOMRIGHT", slideOut, "BOTTOMRIGHT", -28, 8)
    local favContent = CreateFrame("Frame", nil, favScroll)
    favContent:SetSize(210, 1)
    favScroll:SetScrollChild(favContent)
    slideOut._favContent = favContent
    slideOut._favRows = {}

    -- Toggle button on the right edge of the main frame.
    local slideBtn = CreateFrame("Button", nil, frame)
    slideBtn:SetSize(48, 40)
    slideBtn:SetPoint("RIGHT", frame, "RIGHT", 41, 93)
    slideBtn:SetNormalAtlas("HordeFrame_Title-end")
    slideBtn:SetHighlightAtlas("HordeFrame_Title-end")
    slideBtn:GetHighlightTexture():SetAlpha(0.4)
    slideBtn:SetFrameLevel(frame:GetFrameLevel() + 2)

    local slideBtnIcon = slideBtn:CreateTexture(nil, "OVERLAY")
    slideBtnIcon:SetAtlas("crosshair_directions_128")
    slideBtnIcon:SetSize(20, 20)
    slideBtnIcon:SetPoint("CENTER", slideBtn, "CENTER", -8, 3)
    slideBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(slideOut:IsShown() and "Close Favorites" or "View Favorites")
        GameTooltip:Show()
    end)
    slideBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    local function SetFavoritesOpen(open)
        if open then
            slideOut:Show()
            Spoilscribe.UI:RenderFavorites()
            slideBtn:ClearAllPoints()
            slideBtn:SetPoint("RIGHT", slideOut, "RIGHT", 41, 93)
        else
            slideOut:Hide()
            slideBtn:ClearAllPoints()
            slideBtn:SetPoint("RIGHT", frame, "RIGHT", 41, 93)
        end
        SpoilscribeCharDB.favoritesOpen = open and true or false
    end
    frame.SetFavoritesOpen = SetFavoritesOpen

    slideBtn:SetScript("OnClick", function()
        SetFavoritesOpen(not slideOut:IsShown())
    end)
    frame.slideBtn = slideBtn

    -- Zoom Favorites button beneath the View Favorites button.
    local zoomBtn = CreateFrame("Button", nil, frame)
    zoomBtn:SetSize(48, 40)
    zoomBtn:SetPoint("TOP", slideBtn, "BOTTOM", 0, 0)
    zoomBtn:SetNormalAtlas("HordeFrame_Title-end")
    zoomBtn:SetHighlightAtlas("HordeFrame_Title-end")
    zoomBtn:GetHighlightTexture():SetAlpha(0.4)
    zoomBtn:SetFrameLevel(frame:GetFrameLevel() + 2)

    local zoomBtnIcon = zoomBtn:CreateTexture(nil, "OVERLAY")
    zoomBtnIcon:SetAtlas("Crosshair_pickup_48")
    zoomBtnIcon:SetSize(20, 20)
    zoomBtnIcon:SetPoint("CENTER", zoomBtn, "CENTER", -8, 3)

    zoomBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Zoom Favorites")
        GameTooltip:Show()
    end)
    zoomBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    zoomBtn:SetScript("OnClick", function()
        local items = Spoilscribe:GetFavoriteItems()
        if #items == 0 then return end

        -- Group by dungeon name.
        local dungeonOrder = {}
        local dungeonGroups = {}
        for _, item in ipairs(items) do
            local dn = item.dungeonName or "Unknown"
            if not dungeonGroups[dn] then
                dungeonGroups[dn] = {}
                dungeonOrder[#dungeonOrder + 1] = dn
            end
            dungeonGroups[dn][#dungeonGroups[dn] + 1] = item
        end

        local lines = {}
        for _, dn in ipairs(dungeonOrder) do
            lines[#lines + 1] = { type = "header", text = dn }
            for _, item in ipairs(dungeonGroups[dn]) do
                lines[#lines + 1] = item
            end
        end
        frame._hasFilter = true
        Spoilscribe.UI:RenderLoot(lines)
    end)
    frame.zoomBtn = zoomBtn

    self.frame = frame
    return frame
end

function UI:ToggleMainFrame()
    local frame = self:CreateMainFrame()
    if not frame then
        return
    end
    if frame:IsShown() then
        frame:Hide()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE)
    else
        -- Close the Encounter Journal if it's open.
        if EncounterJournal and EncounterJournal:IsShown() then
            EncounterJournal:Hide()
        end

        -- Hook EncounterJournal OnShow once so opening it closes Spoilscribe.
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

function UI:RenderLoot(lines)
    local frame = self.frame or self:CreateMainFrame()
    frame._lines = lines
    frame.currentPage = 1
    if frame.clearFilterBtn then
        if self:HasActiveFilter() then
            frame.clearFilterBtn:Show()
        else
            frame.clearFilterBtn:Hide()
        end
    end
    self:RenderPage()
end

function UI:RenderPage()
    local frame = self.frame
    if not frame or not frame._lines then return end

    local lines = frame._lines
    local ICON_SIZE = 40
    local ITEM_ROW_HEIGHT = 62
    local TEXT_ROW_HEIGHT = 20
    local HEADER_ROW_HEIGHT = 96
    local PAGE_BOTTOM_MARGIN = 28 -- space for page buttons
    local COL_LEFT_X = 29
    local COL_RIGHT_X = 800 - 25 - 318 -- 457

    -- Hide all previous rows.
    for _, row in ipairs(frame.rows) do
        row:Hide()
    end

    -- Build columns: each dungeon starts a new column.
    -- A column = header + items stacked vertically.
    -- If a dungeon overflows one column, a continuation column is created (no header).
    local TOP_PADDING = 10
    local availableHeight = frame.resultArea:GetHeight() - PAGE_BOTTOM_MARGIN
    local colHeight = availableHeight - TOP_PADDING

    local columns = {}  -- each entry: { entries = { {line=, isHeader=bool} }, height = N }

    for _, line in ipairs(lines) do
        local isItem = (type(line) == "table" and line.type == "item")
        local isHeader = (type(line) == "table" and line.type == "header")

        if isHeader then
            -- Start a new column for this dungeon.
            columns[#columns + 1] = { entries = {}, height = 0 }
            local col = columns[#columns]
            col.entries[#col.entries + 1] = { line = line, isHeader = true }
            col.height = col.height + HEADER_ROW_HEIGHT
        elseif isItem then
            -- Ensure there is a current column.
            if #columns == 0 then
                columns[#columns + 1] = { entries = {}, height = 0 }
            end
            local col = columns[#columns]
            local itemH = ITEM_ROW_HEIGHT + 2
            -- If adding this item would overflow, start a continuation column.
            if col.height + itemH > colHeight and #col.entries > 0 then
                columns[#columns + 1] = { entries = {}, height = 0 }
                col = columns[#columns]
            end
            col.entries[#col.entries + 1] = { line = line, isHeader = false }
            col.height = col.height + itemH
        else
            -- Plain text lines (non-header, non-item) — skip or place in current column.
            if #columns == 0 then
                columns[#columns + 1] = { entries = {}, height = 0 }
            end
            local col = columns[#columns]
            col.entries[#col.entries + 1] = { line = line, isHeader = false }
            col.height = col.height + TEXT_ROW_HEIGHT
        end
    end

    -- Paginate: 2 columns per page (left + right).
    local pages = {}  -- each page: { col1, col2 } or { col1 }
    local i = 1
    while i <= #columns do
        local page = { columns[i] }
        i = i + 1
        if i <= #columns then
            page[2] = columns[i]
            i = i + 1
        end
        pages[#pages + 1] = page
    end

    frame.totalPages = math.max(1, #pages)
    if frame.currentPage > frame.totalPages then
        frame.currentPage = frame.totalPages
    end

    -- Render the current page's columns.
    local pageCols = pages[frame.currentPage] or {}
    local rowIndex = 0

    for colIdx, col in ipairs(pageCols) do
        local xOffset = (colIdx == 1) and COL_LEFT_X or COL_RIGHT_X
        local hasHeader = (#col.entries > 0 and col.entries[1].isHeader)
        local y = hasHeader and -TOP_PADDING or -42

        for _, entry in ipairs(col.entries) do
            rowIndex = rowIndex + 1
            local line = entry.line

            local row = frame.rows[rowIndex]
            if not row then
                row = CreateFrame("Button", nil, frame.content, "BackdropTemplate")
                row:SetSize(318, ITEM_ROW_HEIGHT)

                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
                row.bg:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
                row.bg:SetHeight(65)
                row.bg:SetTexture("Interface/EncounterJournal/UI-EncounterJournalTextures")
                row.bg:SetTexCoord(0, 320/512, 536/1024, 600/1024)
                row.bg:Hide()

                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(ICON_SIZE, ICON_SIZE)
                row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)

                row.IconBorder = row:CreateTexture(nil, "OVERLAY")
                row.IconBorder:SetTexture("Interface/Common/WhiteIconFrame")
                row.IconBorder:SetSize(ICON_SIZE, ICON_SIZE)
                row.IconBorder:SetAllPoints(row.icon)
                row.IconBorder:Hide()

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
                row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 11, -4)
                row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetJustifyV("TOP")

                row.slotText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
                row.slotText:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -5)
                row.slotText:SetJustifyH("LEFT")

                row.armorText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
                row.armorText:SetPoint("TOPRIGHT", row.text, "BOTTOMRIGHT", -20, -5)
                row.armorText:SetJustifyH("RIGHT")

                row.bossText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
                row.bossText:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -47)
                row.bossText:SetJustifyH("LEFT")

                row.headerLine = row:CreateTexture(nil, "ARTWORK")
                row.headerLine:SetAtlas("spellbook-divider")
                row.headerLine:SetSize(335, 11)
                row.headerLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 15)
                row.headerLine:Hide()

                row.headerBg = row:CreateTexture(nil, "BACKGROUND")
                row.headerBg:SetAtlas("spellbook-list-backplate")
                row.headerBg:SetSize(316, 90)
                row.headerBg:SetPoint("TOPLEFT", row, "TOPLEFT", -40, 0)
                row.headerBg:Hide()

                row.headerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                row.headerText:SetJustifyH("LEFT")
                row.headerText:Hide()

                row:SetScript("OnEnter", function(self)
                    if not (self.itemLink or self.itemID) then
                        return
                    end

                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if self.itemLink and self.itemLink ~= "" then
                        GameTooltip:SetHyperlink(self.itemLink)
                    elseif self.itemID then
                        GameTooltip:SetItemByID(self.itemID)
                    end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                row.favBtn = CreateFrame("Button", nil, row)
                row.favBtn:SetSize(22, 20)
                row.favBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 3, -3)
                row.favBtn:SetNormalAtlas("PetJournal-FavoritesIcon")
                row.favBtn:GetNormalTexture():SetDesaturated(true)
                row.favBtn:GetNormalTexture():SetAlpha(0.3)
                row.favBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Favorite")
                    GameTooltip:Show()
                end)
                row.favBtn:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                row.favBtn:SetScript("OnClick", function(self)
                    local id = self:GetParent().itemID
                    if not id then return end
                    SpoilscribeCharDB.favorites = SpoilscribeCharDB.favorites or {}
                    if SpoilscribeCharDB.favorites[id] then
                        SpoilscribeCharDB.favorites[id] = nil
                        self:GetNormalTexture():SetDesaturated(true)
                        self:GetNormalTexture():SetAlpha(0.3)
                        -- If the unfavorited item was pinned, return to normal view.
                        if frame._pinnedItem and frame._pinnedItem.itemID == id then
                            Spoilscribe:RefreshLoot()
                        end
                    else
                        SpoilscribeCharDB.favorites[id] = true
                        self:GetNormalTexture():SetDesaturated(false)
                        self:GetNormalTexture():SetAlpha(1)
                    end
                    if frame.slideOut and frame.slideOut.UpdateBackground then
                        frame.slideOut:UpdateBackground()
                    end
                    if frame.slideOut and frame.slideOut:IsShown() then
                        Spoilscribe.UI:RenderFavorites()
                    end
                    Spoilscribe:BroadcastFavorites()
                end)
                row.favBtn:Hide()

                -- Party friend icons (up to 4 for party members with favorites in this dungeon).
                row.partyIcons = {}
                for pi = 1, 4 do
                    local pIcon = row:CreateTexture(nil, "OVERLAY")
                    pIcon:SetAtlas("housefinder_neighborhood-list-friend-icon")
                    pIcon:SetSize(16, 16)
                    pIcon:Hide()
                    row.partyIcons[pi] = pIcon
                end

                frame.rows[rowIndex] = row
            end

            -- Reset state.
            row.text:SetText("")
            row.itemID = nil
            row.itemLink = nil
            if row.icon then row.icon:Hide() end
            if row.IconBorder then row.IconBorder:Hide() end
            if row.slotText then row.slotText:SetText(""); row.slotText:Hide() end
            if row.armorText then row.armorText:SetText(""); row.armorText:Hide() end
            if row.bossText then row.bossText:SetText(""); row.bossText:Hide() end
            if row.headerLine then row.headerLine:Hide() end
            if row.headerBg then row.headerBg:Hide() end
            if row.headerText then row.headerText:SetText(""); row.headerText:Hide() end
            if row.favBtn then row.favBtn:Hide() end
            if row.partyIcons then
                for _, pIcon in ipairs(row.partyIcons) do pIcon:Hide() end
            end

            local text = ""
            local showIcon = false
            local iconTexture = nil
            local isHeader = (type(line) == "table" and line.type == "header")
            if isHeader then
                text = line.text or ""
                if row.headerLine then row.headerLine:Show() end
            elseif type(line) == "table" and line.type == "item" then
                text = line.itemLink or line.itemName or ("Item " .. tostring(line.itemID))
                row.itemID = line.itemID
                row.itemLink = line.itemLink
                if line.icon then
                    showIcon = true
                    iconTexture = line.icon
                end
            elseif type(line) == "table" then
                text = line.text or ""
                row.itemID = line.itemID
                row.itemLink = line.itemLink
            else
                text = tostring(line)
            end

            if showIcon and iconTexture then
                row.icon:SetTexture(iconTexture)
                row.icon:Show()
                row.bg:Show()
                local hexColor = type(line) == "table" and line.itemQuality
                if hexColor and type(hexColor) == "string" and #hexColor == 8 then
                    local r = tonumber(hexColor:sub(3, 4), 16) / 255
                    local g = tonumber(hexColor:sub(5, 6), 16) / 255
                    local b = tonumber(hexColor:sub(7, 8), 16) / 255
                    row.IconBorder:SetVertexColor(r, g, b)
                    row.IconBorder:Show()
                elseif hexColor and type(hexColor) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[hexColor] then
                    local c = ITEM_QUALITY_COLORS[hexColor]
                    row.IconBorder:SetVertexColor(c.r, c.g, c.b)
                    row.IconBorder:Show()
                else
                    row.IconBorder:Hide()
                end
            else
                row.icon:Hide()
                row.IconBorder:Hide()
                row.bg:Hide()
            end

            local slotLabel = ""
            if type(line) == "table" and line.type == "item" and line.slot and line.slot ~= "" then
                slotLabel = line.slot
            end
            if row.slotText then
                row.slotText:SetText(slotLabel)
                row.slotText:SetTextColor(75/255, 50/255, 20/255)
                if slotLabel ~= "" then
                    row.slotText:Show()
                else
                    row.slotText:Hide()
                end
            end

            local armorLabel = ""
            if type(line) == "table" and line.type == "item" and line.armorType and line.armorType ~= "" then
                armorLabel = line.armorType
            end
            if row.armorText then
                row.armorText:SetText(armorLabel)
                row.armorText:SetTextColor(75/255, 50/255, 20/255)
                if armorLabel ~= "" then
                    row.armorText:Show()
                else
                    row.armorText:Hide()
                end
            end

            local bossLabel = ""
            if type(line) == "table" and line.type == "item" and line.bossName and line.bossName ~= "" then
                bossLabel = "Boss: " .. line.bossName
            end
            if row.bossText then
                row.bossText:SetText(bossLabel)
                row.bossText:SetTextColor(75/255, 50/255, 20/255)
                if bossLabel ~= "" then
                    row.bossText:Show()
                else
                    row.bossText:Hide()
                end
            end

            local rowHeight = showIcon and ITEM_ROW_HEIGHT or TEXT_ROW_HEIGHT

            -- Headers span the column width and position text from the row edge.
            row.text:ClearAllPoints()
            if isHeader then
                rowHeight = HEADER_ROW_HEIGHT
                row:SetSize(318, rowHeight)
                -- Use dedicated header font/bg instead of row.text
                if row.headerBg then row.headerBg:Show() end
                if row.headerLine then row.headerLine:Show() end
                if row.headerText then
                    row.headerText:ClearAllPoints()
                    row.headerText:SetPoint("TOPLEFT", row, "TOPLEFT", 10, 0)
                    row.headerText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                    row.headerText:SetPoint("BOTTOM", row.headerBg, "BOTTOM", 0, 0)
                    local font, _, flags = row.headerText:GetFont()
                    row.headerText:SetFont(font, 20, flags)
                    row.headerText:SetText(text:gsub("[%[%]]", ""))
                    row.headerText:SetTextColor(75/255, 50/255, 20/255)
                    row.headerText:Show()
                end
                -- Show party friend icons for members with favorites in this dungeon.
                if row.partyIcons then
                    local partyData = Spoilscribe:GetPartyFavDungeons()
                    local dungeonName = line.text or ""
                    local iconIdx = 0
                    for sender, dungeons in pairs(partyData) do
                        if dungeons[dungeonName] then
                            iconIdx = iconIdx + 1
                            if iconIdx <= #row.partyIcons then
                                local pIcon = row.partyIcons[iconIdx]
                                pIcon:ClearAllPoints()
                                pIcon:SetPoint("RIGHT", row, "RIGHT", -4 - (iconIdx - 1) * 18, 0)
                                pIcon:Show()
                            end
                        end
                    end
                end
                row.text:SetText("")
            else
                row:SetSize(318, rowHeight)
                row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 11, -4)
                row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            end

            row:EnableMouse(row.itemID ~= nil or (row.itemLink ~= nil and row.itemLink ~= ""))

            -- Update favorite button.
            if row.favBtn then
                if row.itemID then
                    SpoilscribeCharDB.favorites = SpoilscribeCharDB.favorites or {}
                    if SpoilscribeCharDB.favorites[row.itemID] then
                        row.favBtn:GetNormalTexture():SetDesaturated(false)
                        row.favBtn:GetNormalTexture():SetAlpha(1)
                    else
                        row.favBtn:GetNormalTexture():SetDesaturated(true)
                        row.favBtn:GetNormalTexture():SetAlpha(0.3)
                    end
                    row.favBtn:Show()
                else
                    row.favBtn:Hide()
                end
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", xOffset, y)
            row.text:SetText(text:gsub("[%[%]]", ""))
            row:Show()
            y = y - rowHeight
        end
    end

    -- Update page controls.
    frame.pageText:SetText("Page " .. frame.currentPage .. " / " .. frame.totalPages)
    frame.prevButton:SetEnabled(frame.currentPage > 1)
    frame.nextButton:SetEnabled(frame.currentPage < frame.totalPages)
end

function UI:RenderFavorites()
    local frame = self.frame
    if not frame or not frame.slideOut then return end

    local slideOut = frame.slideOut
    local content = slideOut._favContent
    local rows = slideOut._favRows

    -- Hide existing rows.
    for _, row in ipairs(rows) do
        row:Hide()
    end

    local items = Spoilscribe:GetFavoriteItems()

    if #items == 0 then
        content:SetHeight(1)
        return
    end

    -- Detect current dungeon via instance info.
    local currentDungeonName = nil
    if GetInstanceInfo then
        local instanceName, instanceType = GetInstanceInfo()
        if instanceName and instanceType == "party" then
            -- Match against known dungeon names (case-insensitive).
            local lowerInstance = string.lower(instanceName)
            for _, item in ipairs(items) do
                if item.dungeonName and string.lower(item.dungeonName) == lowerInstance then
                    currentDungeonName = item.dungeonName
                    break
                end
            end
        end
    end

    -- Split items: current dungeon vs rest.
    local currentDungeonItems = {}
    local remainingItems = {}
    for _, item in ipairs(items) do
        if currentDungeonName and item.dungeonName == currentDungeonName then
            currentDungeonItems[#currentDungeonItems + 1] = item
        else
            remainingItems[#remainingItems + 1] = item
        end
    end

    -- Group remaining items by slot.
    local slotOrder = {}
    local slotGroups = {}
    for _, item in ipairs(remainingItems) do
        local slot = (item.slot and item.slot ~= "") and item.slot or "Other"
        if not slotGroups[slot] then
            slotGroups[slot] = {}
            slotOrder[#slotOrder + 1] = slot
        end
        slotGroups[slot][#slotGroups[slot] + 1] = item
    end

    local ICON_SIZE = 32
    local ROW_HEIGHT = 36
    local HEADER_HEIGHT = 24
    local y = 0
    local rowIndex = 0

    -- Unified row factory – every pooled frame is a Button with all elements
    -- so headers and items can freely swap positions on re-render.
    local function EnsureRow()
        rowIndex = rowIndex + 1
        local row = rows[rowIndex]
        if row then return row end

        row = CreateFrame("Button", nil, content, "BackdropTemplate")
        row:SetSize(210, ROW_HEIGHT)

        -- Header elements
        row.headerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.headerText:SetPoint("BOTTOM", row, "BOTTOM", 0, 6)
        row.headerText:SetJustifyH("CENTER")

        row.divider = row:CreateTexture(nil, "ARTWORK")
        row.divider:SetAtlas("Adventure-MissionEnd-Line")
        row.divider:SetHeight(4)
        row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
        row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)

        -- Item elements
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.bg:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        row.bg:SetHeight(ROW_HEIGHT)
        row.bg:SetAtlas("GarrMissionLocation-Maw-ButtonBG")

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints(row.bg)
        row.highlight:SetAtlas("Adventures_MissionList_Highlight")

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)

        row.IconBorder = row:CreateTexture(nil, "OVERLAY")
        row.IconBorder:SetTexture("Interface/Common/WhiteIconFrame")
        row.IconBorder:SetSize(ICON_SIZE, ICON_SIZE)
        row.IconBorder:SetAllPoints(row.icon)
        row.IconBorder:Hide()

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetJustifyV("MIDDLE")

        row:SetScript("OnEnter", function(self)
            if not (self.itemLink or self.itemID) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.itemLink and self.itemLink ~= "" then
                GameTooltip:SetHyperlink(self.itemLink)
            elseif self.itemID then
                GameTooltip:SetItemByID(self.itemID)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if not self.itemID then return end
            if button == "RightButton" then
                SpoilscribeCharDB.favorites[self.itemID] = nil
                Spoilscribe.UI:RenderFavorites()
                slideOut:UpdateBackground()
                Spoilscribe.UI:RenderPage()
                Spoilscribe:BroadcastFavorites()
                return
            end
            local pinnedItem = self._pinnedData
            if pinnedItem then
                frame._pinnedItem = pinnedItem
                frame._hasFilter = true
                local lines = {
                    { type = "header", text = pinnedItem.dungeonName or "" },
                    pinnedItem,
                }
                Spoilscribe.UI:RenderLoot(lines)
            end
        end)

        rows[rowIndex] = row
        return row
    end

    local function RenderHeader(label)
        local row = EnsureRow()
        row:SetSize(210, HEADER_HEIGHT)

        -- Hide item elements
        row.bg:Hide()
        row.highlight:Hide()
        row.icon:Hide()
        row.IconBorder:Hide()
        row.text:Hide()
        row:EnableMouse(false)
        row.itemID = nil
        row.itemLink = nil
        row._pinnedData = nil

        -- Show header elements
        row.headerText:SetText(label)
        row.headerText:SetTextColor(1, 0.82, 0)
        row.headerText:Show()
        row.divider:Show()

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        row:Show()
        y = y - HEADER_HEIGHT
    end

    local function RenderItemRow(item)
        local row = EnsureRow()
        row:SetSize(210, ROW_HEIGHT)

        -- Hide header elements
        row.headerText:Hide()
        row.divider:Hide()

        -- Show item elements
        row.bg:Show()
        row.highlight:Show()
        row:EnableMouse(true)

        row.itemID = item.itemID
        row._itemName = item.itemName or ""
        row._pinnedData = item
        row.itemLink = item.itemLink

        local name = Spoilscribe:GetQualityColoredItemText({
            link    = item.itemLink,
            name    = item.itemName,
            itemID  = item.itemID,
        })
        row.text:SetText(name:gsub("[%[%]]", ""))
        row.text:Show()

        if item.icon then
            row.icon:SetTexture(item.icon)
            row.icon:Show()
            local hexColor = type(item) == "table" and item.itemQuality
            if hexColor and type(hexColor) == "string" and #hexColor == 8 then
                local r = tonumber(hexColor:sub(3, 4), 16) / 255
                local g = tonumber(hexColor:sub(5, 6), 16) / 255
                local b = tonumber(hexColor:sub(7, 8), 16) / 255
                row.IconBorder:SetVertexColor(r, g, b)
                row.IconBorder:Show()
            elseif hexColor and type(hexColor) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[hexColor] then
                local c = ITEM_QUALITY_COLORS[hexColor]
                row.IconBorder:SetVertexColor(c.r, c.g, c.b)
                row.IconBorder:Show()
            else
                row.IconBorder:Hide()
            end
        else
            row.icon:Hide()
            row.IconBorder:Hide()
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        row:Show()
        y = y - ROW_HEIGHT - 2
    end

    -- Render "Current Dungeon" section at the top (flat, not categorized).
    if #currentDungeonItems > 0 then
        RenderHeader("Current Dungeon")
        for _, item in ipairs(currentDungeonItems) do
            RenderItemRow(item)
        end
    end

    for _, slot in ipairs(slotOrder) do
        RenderHeader(slot)
        for _, item in ipairs(slotGroups[slot]) do
            RenderItemRow(item)
        end
    end

    content:SetHeight(math.max(1, math.abs(y)))
end
