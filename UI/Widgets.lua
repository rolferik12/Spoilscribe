local _, Spoilscribe = ...
local L = Spoilscribe.L

local Widgets = {}
Spoilscribe.UI = Spoilscribe.UI or {}
Spoilscribe.UI.Widgets = Widgets

function Widgets:EnsureDropdownAPILoaded()
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

function Widgets:BuildDropdown(parent, width, items, defaultIndex, onChanged)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)

    local function GetItemText(item, index)
        local text = item
        if type(item) == "table" then
            text = item.label or item.name
        end
        if text == nil then
            return string.format(L["Option %d"], index)
        end
        return L[tostring(text)]
    end

    local function Initialize(self, level)
        for index, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = GetItemText(item, index)
            info.checked = (index == (dropdown.selectedIndex or defaultIndex or 1))
            info.func = function()
                dropdown.selectedIndex = index
                UIDropDownMenu_SetText(dropdown, GetItemText(item, index))
                CloseDropDownMenus()
                if onChanged then
                    onChanged(index, item)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)
    UIDropDownMenu_SetText(dropdown, GetItemText(items[defaultIndex or 1], defaultIndex or 1))
    dropdown.selectedIndex = defaultIndex or 1

    function dropdown:RefreshLocale()
        UIDropDownMenu_Initialize(self, Initialize)
        UIDropDownMenu_SetText(self, GetItemText(items[self.selectedIndex or defaultIndex or 1],
            self.selectedIndex or defaultIndex or 1))
    end

    return dropdown
end

function Widgets:CreateLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    return fs
end
