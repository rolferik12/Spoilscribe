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
    frame:SetSize(920, 580)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
    frame.title:SetText("Spoilscribe - Dungeon Loot")

    local controls = CreateFrame("Frame", nil, frame)
    controls:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
    controls:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -32)
    controls:SetHeight(154)

    local difficultyLabel = CreateLabel(controls, "Difficulty")
    difficultyLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 10, -10)

    local slotLabel = CreateLabel(controls, "Slot (planned filter)")
    slotLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 210, -10)

    local armorLabel = CreateLabel(controls, "Armor (planned filter)")
    armorLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 10, -72)

    local weaponLabel = CreateLabel(controls, "Weapon (planned filter)")
    weaponLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 260, -72)

    local statsLabel = CreateLabel(controls, "Secondary Stats (planned filter)")
    statsLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 510, -72)

    local defaultDifficultyIndex = 1 -- Mythic first in table.
    frame.difficultyDropdown = BuildDropdown(
        controls,
        140,
        Spoilscribe.Data.Difficulties,
        defaultDifficultyIndex,
        function(index)
            frame.selectedDifficultyIndex = index
        end
    )
    frame.difficultyDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", -16, -28)

    frame.slotDropdown = BuildDropdown(
        controls,
        220,
        Spoilscribe.Data.Filters.slots,
        1,
        function(index)
            frame.selectedSlotIndex = index
        end
    )
    frame.slotDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 184, -28)

    frame.armorDropdown = BuildDropdown(
        controls,
        220,
        Spoilscribe.Data.Filters.armorTypes,
        1,
        function(index)
            frame.selectedArmorIndex = index
        end
    )
    frame.armorDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", -16, -90)

    frame.weaponDropdown = BuildDropdown(
        controls,
        220,
        Spoilscribe.Data.Filters.weaponTypes,
        1,
        function(index)
            frame.selectedWeaponIndex = index
        end
    )
    frame.weaponDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 234, -90)

    frame.secondaryDropdown = BuildDropdown(
        controls,
        220,
        Spoilscribe.Data.Filters.secondaryStats,
        1,
        function(index)
            frame.selectedSecondaryIndex = index
        end
    )
    frame.secondaryDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 484, -90)

    local refreshButton = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    refreshButton:SetSize(130, 24)
    refreshButton:SetPoint("TOPRIGHT", controls, "TOPRIGHT", -14, -24)
    refreshButton:SetText("Show Loot")
    refreshButton:SetScript("OnClick", function()
        Spoilscribe:RefreshLoot()
    end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 10, 6)
    hint:SetText("Filters are visible and stored in UI selection, but not applied yet.")

    local scroll = CreateFrame("ScrollFrame", "SpoilscribeLootScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -198)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 16)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    frame.scroll = scroll
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
        frame:Show()
        Spoilscribe:RefreshLoot()
    end
end

function UI:RenderLoot(lines)
    local frame = self.frame or self:CreateMainFrame()

    for _, row in ipairs(frame.rows) do
        row:Hide()
        row.text:SetText("")
        row.itemID = nil
        row.itemLink = nil
    end

    local y = -4
    for i, line in ipairs(lines) do
        local row = frame.rows[i]
        if not row then
            row = CreateFrame("Button", nil, frame.content)
            row:SetSize(830, 20)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetAllPoints(row)
            row.text:SetJustifyH("LEFT")
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
            frame.rows[i] = row
        end

        local text = line
        if type(line) == "table" then
            text = line.text or ""
            row.itemID = line.itemID
            row.itemLink = line.itemLink
        else
            row.itemID = nil
            row.itemLink = nil
        end

        row:EnableMouse(row.itemID ~= nil or (row.itemLink ~= nil and row.itemLink ~= ""))
        row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 4, y)
        row.text:SetText(text)
        row:Show()
        y = y - 20
    end

    frame.content:SetHeight(math.max(20, -y + 8))
end
