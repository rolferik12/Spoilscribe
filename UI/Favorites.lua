local _, Spoilscribe = ...

local UI = Spoilscribe.UI
local Favorites = {}
UI.Favorites = Favorites

function Favorites:CreatePanel(frame)
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

    return slideOut
end

function Favorites:CreateToggleButton(frame, slideOut)
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
            UI:RenderFavorites()
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

    return slideBtn
end

function Favorites:CreateZoomButton(frame, slideBtn)
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
        UI:ZoomFavorites()
    end)
    frame.zoomBtn = zoomBtn

    return zoomBtn
end

function UI:ZoomFavorites()
    local frame = self.frame
    if not frame then return end

    local items = Spoilscribe:GetFavoriteItems()
    if #items == 0 then
        frame._zoomedFavorites = false
        Spoilscribe:RefreshLoot()
        return
    end

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
    frame._zoomedFavorites = true
    UI:RenderLoot(lines)
end

function UI:RenderFavorites()
    local frame = self.frame
    if not frame or not frame.slideOut then return end

    local slideOut = frame.slideOut
    local content = slideOut._favContent
    local rows = slideOut._favRows

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

    local function EnsureRow()
        rowIndex = rowIndex + 1
        local row = rows[rowIndex]
        if row then return row end

        row = CreateFrame("Button", nil, content, "BackdropTemplate")
        row:SetSize(210, ROW_HEIGHT)

        row.headerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.headerText:SetPoint("BOTTOM", row, "BOTTOM", 0, 6)
        row.headerText:SetJustifyH("CENTER")

        row.divider = row:CreateTexture(nil, "ARTWORK")
        row.divider:SetAtlas("Adventure-MissionEnd-Line")
        row.divider:SetHeight(4)
        row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
        row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)

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
                UI:RenderFavorites()
                slideOut:UpdateBackground()
                if frame._zoomedFavorites then
                    UI:ZoomFavorites()
                else
                    UI:RenderPage()
                end
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
                UI:RenderLoot(lines)
            end
        end)

        rows[rowIndex] = row
        return row
    end

    local function RenderHeader(label)
        local row = EnsureRow()
        row:SetSize(210, HEADER_HEIGHT)

        row.bg:Hide()
        row.highlight:Hide()
        row.icon:Hide()
        row.IconBorder:Hide()
        row.text:Hide()
        row:EnableMouse(false)
        row.itemID = nil
        row.itemLink = nil
        row._pinnedData = nil

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

        row.headerText:Hide()
        row.divider:Hide()

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
