local _, Spoilscribe = ...
local L = Spoilscribe.L

local UI = Spoilscribe.UI

function UI:CreateResultArea(frame)
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
    frame.linesPerPage = nil

    local nextButton = CreateFrame("Button", nil, resultArea, "UIPanelButtonTemplate")
    nextButton:SetSize(26, 22)
    nextButton:SetPoint("BOTTOMRIGHT", resultArea, "BOTTOMRIGHT", -25, 8)
    nextButton:SetText(">")
    nextButton:SetScript("OnClick", function()
        if frame.currentPage < (frame.totalPages or 1) then
            frame.currentPage = frame.currentPage + 1
            UI:RenderPage()
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
            UI:RenderPage()
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
            UI:RenderPage()
        elseif delta < 0 and frame.currentPage < (frame.totalPages or 1) then
            frame.currentPage = frame.currentPage + 1
            UI:RenderPage()
        end
    end)

    -- Clear-filter button.
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
        GameTooltip:SetText(L["Clear Filter"])
        GameTooltip:Show()
    end)
    clearFilterBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    clearFilterBtn:SetScript("OnClick", function()
        frame._hasFilter = false
        frame._zoomedFavorites = false
        frame._zoomedPartyFavorites = false
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

        frame.searchBox:SetText("")
        frame.searchBox:ClearFocus()
        Spoilscribe:RefreshLoot()
    end)
    frame.clearFilterBtn = clearFilterBtn

    frame.resultArea = resultArea
    frame.content = content
    frame.rows = {}

    return resultArea
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
    local PAGE_BOTTOM_MARGIN = 28
    local COL_LEFT_X = 29
    local COL_RIGHT_X = 800 - 25 - 318

    -- Hide all previous rows.
    for _, row in ipairs(frame.rows) do
        row:Hide()
    end

    local TOP_PADDING = 10
    local availableHeight = frame.resultArea:GetHeight() - PAGE_BOTTOM_MARGIN
    local colHeight = availableHeight - TOP_PADDING

    local columns = {}

    for _, line in ipairs(lines) do
        local isItem = (type(line) == "table" and line.type == "item")
        local isHeader = (type(line) == "table" and line.type == "header")

        if isHeader then
            columns[#columns + 1] = { entries = {}, height = 0 }
            local col = columns[#columns]
            col.entries[#col.entries + 1] = { line = line, isHeader = true }
            col.height = col.height + HEADER_ROW_HEIGHT
        elseif isItem then
            if #columns == 0 then
                columns[#columns + 1] = { entries = {}, height = 0 }
            end
            local col = columns[#columns]
            local itemH = ITEM_ROW_HEIGHT + 2
            if col.height + itemH > colHeight and #col.entries > 0 then
                columns[#columns + 1] = { entries = {}, height = 0 }
                col = columns[#columns]
            end
            col.entries[#col.entries + 1] = { line = line, isHeader = false }
            col.height = col.height + itemH
        else
            if #columns == 0 then
                columns[#columns + 1] = { entries = {}, height = 0 }
            end
            local col = columns[#columns]
            col.entries[#col.entries + 1] = { line = line, isHeader = false }
            col.height = col.height + TEXT_ROW_HEIGHT
        end
    end

    -- Paginate: 2 columns per page.
    local pages = {}
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
                row = self:CreateLootRow(frame)
                frame.rows[rowIndex] = row
            end

            self:ResetRow(row)
            self:PopulateRow(row, line, frame, ICON_SIZE, ITEM_ROW_HEIGHT, TEXT_ROW_HEIGHT, HEADER_ROW_HEIGHT)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", xOffset, y)
            row:Show()

            local isHeader = (type(line) == "table" and line.type == "header")
            local showIcon = (type(line) == "table" and line.type == "item" and line.icon)
            local rowHeight
            if isHeader then
                rowHeight = HEADER_ROW_HEIGHT
            elseif showIcon then
                rowHeight = ITEM_ROW_HEIGHT
            else
                rowHeight = TEXT_ROW_HEIGHT
            end
            y = y - rowHeight
        end
    end

    -- Update page controls.
    frame.pageText:SetText(string.format(L["Page %d / %d"], frame.currentPage, frame.totalPages))
    frame.prevButton:SetEnabled(frame.currentPage > 1)
    frame.nextButton:SetEnabled(frame.currentPage < frame.totalPages)
end

function UI:CreateLootRow(frame)
    local ICON_SIZE = 40
    local ITEM_ROW_HEIGHT = 62

    local row = CreateFrame("Button", nil, frame.content, "BackdropTemplate")
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

    -- Favorite button.
    row.favBtn = CreateFrame("Button", nil, row)
    row.favBtn:SetSize(22, 20)
    row.favBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 3, -3)
    row.favBtn:SetNormalAtlas("PetJournal-FavoritesIcon")
    row.favBtn:GetNormalTexture():SetDesaturated(true)
    row.favBtn:GetNormalTexture():SetAlpha(0.3)
    row.favBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Favorite"])
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
            if frame._zoomedFavorites then
                Spoilscribe.UI:ZoomFavorites()
            elseif frame._pinnedItem and frame._pinnedItem.itemID == id then
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

    -- Party favorites stacked stars.
    row.partyFavBtn = CreateFrame("Frame", nil, row)
    row.partyFavBtn:SetSize(22, 20)
    row.partyFavBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 3, -3)
    row.partyFavBtn:EnableMouse(true)
    row.partyFavBtn._stars = {}
    local MAX_STARS = 5
    for si = 1, MAX_STARS do
        local star = row.partyFavBtn:CreateTexture(nil, "OVERLAY")
        star:SetAtlas("PetJournal-FavoritesIcon")
        star:SetDesaturated(true)
        star:SetVertexColor(0.4, 0.9, 0.9)
        star:SetSize(22, 20)
        star:SetPoint("TOP", row.partyFavBtn, "TOP", 0, (si - 1) * -6)
        star:Hide()
        row.partyFavBtn._stars[si] = star
    end
    row.partyFavBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local names = self._senderNames
        if names and #names > 0 then
            GameTooltip:SetText(L["Favorited by:"])
            for _, name in ipairs(names) do
                GameTooltip:AddLine(name, 1, 1, 1)
            end
        else
            GameTooltip:SetText(L["Party Favorite"])
        end
        GameTooltip:Show()
    end)
    row.partyFavBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.partyFavBtn._senderNames = {}
    row.partyFavBtn:Hide()

    -- Party member icons.
    row.partyIcons = {}
    for pi = 1, 4 do
        local pFrame = CreateFrame("Frame", nil, row)
        pFrame:SetSize(25, 25)
        pFrame:Hide()
        local pIcon = pFrame:CreateTexture(nil, "ARTWORK")
        pIcon:SetAtlas("housefinder_neighborhood-list-friend-icon")
        pIcon:SetAllPoints(pFrame)
        pFrame._icon = pIcon
        local pCount = pFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pCount:SetPoint("TOPRIGHT", pFrame, "TOPRIGHT", 2, 2)
        pCount:SetTextColor(1, 1, 1)
        pFrame._count = pCount
        pFrame:EnableMouse(true)
        pFrame:SetScript("OnEnter", function(self)
            if self._senderName then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self._senderName)
                GameTooltip:Show()
            end
        end)
        pFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row.partyIcons[pi] = pFrame
    end

    -- Keystone icon for dungeon headers.
    local keystoneFrame = CreateFrame("Frame", nil, row)
    keystoneFrame:SetSize(30, 30)
    keystoneFrame:Hide()
    local kIcon = keystoneFrame:CreateTexture(nil, "ARTWORK")
    kIcon:SetAtlas("unitframeicon-chromietime")
    kIcon:SetAllPoints(keystoneFrame)
    keystoneFrame._icon = kIcon
    keystoneFrame._holders = {}
    keystoneFrame:EnableMouse(true)
    keystoneFrame:SetScript("OnEnter", function(self)
        if self._holders and #self._holders > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Keystone"])
            for _, holder in ipairs(self._holders) do
                GameTooltip:AddLine(holder.name .. " (+" .. holder.level .. ")", 1, 1, 1)
            end
            GameTooltip:Show()
        end
    end)
    keystoneFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.keystoneIcon = keystoneFrame

    return row
end

function UI:ResetRow(row)
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
    if row.partyFavBtn then
        row.partyFavBtn:Hide()
        if row.partyFavBtn._stars then
            for _, star in ipairs(row.partyFavBtn._stars) do star:Hide() end
        end
    end
    if row.bg then row.bg:Hide() end
    row._senders = nil
    if row.partyIcons then
        for _, pIcon in ipairs(row.partyIcons) do pIcon:Hide() end
    end
    if row.keystoneIcon then row.keystoneIcon:Hide() end
end

function UI:PopulateRow(row, line, frame, ICON_SIZE, ITEM_ROW_HEIGHT, TEXT_ROW_HEIGHT, HEADER_ROW_HEIGHT)
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
        row._senders = line.senders
        if line.icon then
            showIcon = true
            iconTexture = line.icon
        end
    elseif type(line) == "table" then
        text = line.text or ""
        row.itemID = line.itemID
        row.itemLink = line.itemLink
        row._senders = line.senders
    else
        text = tostring(line)
    end

    -- Icon and quality border.
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

    -- Slot label.
    local slotLabel = ""
    if type(line) == "table" and line.type == "item" and line.slot and line.slot ~= "" then
        slotLabel = line.slot
    end
    if row.slotText then
        row.slotText:SetText(slotLabel)
        row.slotText:SetTextColor(75/255, 50/255, 20/255)
        if slotLabel ~= "" then row.slotText:Show() else row.slotText:Hide() end
    end

    -- Armor type label.
    local armorLabel = ""
    if type(line) == "table" and line.type == "item" and line.armorType and line.armorType ~= "" then
        armorLabel = line.armorType
    end
    if row.armorText then
        row.armorText:SetText(armorLabel)
        row.armorText:SetTextColor(75/255, 50/255, 20/255)
        if armorLabel ~= "" then row.armorText:Show() else row.armorText:Hide() end
    end

    -- Boss name label.
    local bossLabel = ""
    if type(line) == "table" and line.type == "item" and line.bossName and line.bossName ~= "" then
        bossLabel = string.format(L["Boss: %s"], line.bossName)
    end
    if row.bossText then
        row.bossText:SetText(bossLabel)
        row.bossText:SetTextColor(75/255, 50/255, 20/255)
        if bossLabel ~= "" then row.bossText:Show() else row.bossText:Hide() end
    end

    -- Size and layout.
    row.text:ClearAllPoints()
    if isHeader then
        row:SetSize(318, HEADER_ROW_HEIGHT)
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
        -- Party icons for header rows.
        local dungeonName = line.text or ""
        -- Keystone icon shown in party favorites view (anchored to far right).
        local keystoneShown = false
        if row.keystoneIcon and frame._zoomedPartyFavorites then
            local holders = Spoilscribe:GetKeystoneHolders(dungeonName)
            if #holders > 0 then
                row.keystoneIcon._holders = holders
                row.keystoneIcon:ClearAllPoints()
                row.keystoneIcon:SetPoint("RIGHT", row, "RIGHT", 6, 0)
                row.keystoneIcon:Show()
                keystoneShown = true
            end
        end
        -- Party icons stacked to the left of the keystone icon.
        local partyIconCount = 0
        local partyBaseOffset = keystoneShown and (-6 + 30) or -6
        if row.partyIcons then
            local partyData = Spoilscribe:GetPartyFavDungeons()
            for sender, dungeons in pairs(partyData) do
                local count = dungeons[dungeonName]
                if count then
                    partyIconCount = partyIconCount + 1
                    if partyIconCount <= #row.partyIcons then
                        local pFrame = row.partyIcons[partyIconCount]
                        pFrame:ClearAllPoints()
                        pFrame:SetPoint("RIGHT", row, "RIGHT", -partyBaseOffset - (partyIconCount - 1) * 24, 0)
                        pFrame._count:SetText(tostring(count))
                        pFrame._senderName = sender
                        pFrame:Show()
                    end
                end
            end
        end
        row.text:SetText("")
    else
        local rowHeight = showIcon and ITEM_ROW_HEIGHT or TEXT_ROW_HEIGHT
        row:SetSize(318, rowHeight)
        row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 11, -4)
        row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end

    row:EnableMouse(row.itemID ~= nil or (row.itemLink ~= nil and row.itemLink ~= ""))

    -- Favorite button state.
    if row.favBtn and row.partyFavBtn then
        if row.itemID and frame._zoomedPartyFavorites then
            -- In party favorites view, show stacked stars instead of favorite button.
            row.favBtn:Hide()
            local senders = row._senders
            local names = {}
            if senders then
                for name in pairs(senders) do
                    local short = name:match("^([^-]+)") or name
                    names[#names + 1] = short
                end
                table.sort(names)
            end
            row.partyFavBtn._senderNames = names
            -- Show one star per sender, up to the max.
            local starCount = #names
            if row.partyFavBtn._stars then
                for si = 1, #row.partyFavBtn._stars do
                    if si <= starCount then
                        row.partyFavBtn._stars[si]:Show()
                    else
                        row.partyFavBtn._stars[si]:Hide()
                    end
                end
            end
            -- Resize container to fit stacked stars.
            local h = 20 + math.max(0, starCount - 1) * 6
            row.partyFavBtn:SetHeight(h)
            row.partyFavBtn:Show()
        elseif row.itemID then
            row.partyFavBtn:Hide()
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
            row.partyFavBtn:Hide()
        end
    end

    row.text:SetText(text:gsub("[%[%]]", ""))
end
