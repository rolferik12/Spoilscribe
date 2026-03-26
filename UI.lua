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
    controls:SetHeight(72)

    local difficultyLabel = CreateLabel(controls, "Difficulty")
    difficultyLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 10, -10)

    local slotLabel = CreateLabel(controls, "Slot")
    slotLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 160, -10)

    local statsLabel = CreateLabel(controls, "Secondary Stats")
    statsLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 330, -10)

    local defaultDifficultyIndex = 1 -- Mythic first in table.
    frame.difficultyDropdown = BuildDropdown(
        controls,
        100,
        Spoilscribe.Data.Difficulties,
        defaultDifficultyIndex,
        function(index)
            frame.selectedDifficultyIndex = index
            Spoilscribe:RefreshLoot()
        end
    )
    frame.difficultyDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", -16, -28)

    frame.slotDropdown = BuildDropdown(
        controls,
        120,
        Spoilscribe.Data.Filters.slots,
        1,
        function(index)
            frame.selectedSlotIndex = index
            Spoilscribe:RefreshLoot()
        end
    )
    frame.slotDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 134, -28)

    frame.secondaryDropdown = BuildDropdown(
        controls,
        120,
        Spoilscribe.Data.Filters.secondaryStats,
        1,
        function(index)
            frame.selectedSecondaryIndex = index
            Spoilscribe:RefreshLoot()
        end
    )
    frame.secondaryDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 304, -28)

    local resultArea = CreateFrame("Frame", nil, frame)
    resultArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -104)
    resultArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    resultArea:SetSize(700, 375)
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

    frame.resultArea = resultArea
    frame.content = content
    frame.rows = {}

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
        Spoilscribe:RefreshLoot()
    end
end

function UI:RenderLoot(lines)
    local frame = self.frame or self:CreateMainFrame()
    frame._lines = lines
    frame.currentPage = 1
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
                row.text:SetText("")
            else
                row:SetSize(318, rowHeight)
                row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 11, -4)
                row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            end

            row:EnableMouse(row.itemID ~= nil or (row.itemLink ~= nil and row.itemLink ~= ""))
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
