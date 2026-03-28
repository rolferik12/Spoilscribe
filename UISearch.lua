local _, Spoilscribe = ...

local UI = Spoilscribe.UI
local Search = {}
UI.Search = Search

function Search:CreateSearchBar(controls, frame)
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

    -- Clear button inside search bar.
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

    searchBox:HookScript("OnTextChanged", function(self)
        if self:GetText() ~= "" then
            clearBtn:Show()
        else
            clearBtn:Hide()
        end
    end)

    return searchContainer
end

function Search:CreateSettingsPopup(controls, frame, searchContainer)
    local gearBtn = CreateFrame("Button", nil, controls)
    gearBtn:SetSize(16, 16)
    gearBtn:SetPoint("LEFT", searchContainer, "RIGHT", 6, 0)
    gearBtn:SetNormalTexture("Interface/WorldMap/GEAR_64GREY")
    gearBtn:SetHighlightTexture("Interface/WorldMap/GEAR_64GREY")
    gearBtn:GetHighlightTexture():SetAlpha(0.4)

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

    return gearBtn, settingsPopup
end
