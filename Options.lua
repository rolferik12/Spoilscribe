local addonName, Spoilscribe = ...

-- Ensure per-character settings exist.
SpoilscribeCharDB = SpoilscribeCharDB or {}
SpoilscribeCharDB.options = SpoilscribeCharDB.options or {}

local defaults = {
    groupSync = true,
}

local function GetOption(key)
    local v = SpoilscribeCharDB.options[key]
    if v == nil then return defaults[key] end
    return v
end

local function SetOption(key, value)
    SpoilscribeCharDB.options[key] = value
end

-- Expose for other files.
function Spoilscribe:GetOption(key)
    return GetOption(key)
end

-- ── Keybinding support ──────────────────────────────────────────────────────
-- WoW reads BINDING_HEADER_* and BINDING_NAME_* globals to populate the
-- Keybindings UI automatically when a Bindings.xml is present.
-- We use the SetBindingClick approach with a hidden button instead, registered
-- via the options panel.

local bindingBtn = CreateFrame("Button", "SpoilscribeOpenButton", UIParent, "SecureActionButtonTemplate")
bindingBtn:SetAttribute("type", "macro")
bindingBtn:SetAttribute("macrotext", "/spoilscribe")
bindingBtn:RegisterForClicks("AnyDown", "AnyUp")
bindingBtn:Hide()

-- Set globals so the binding appears in the default Keybindings UI.
BINDING_HEADER_SPOILSCRIBE = "Spoilscribe"
_G["BINDING_NAME_CLICK SpoilscribeOpenButton:LeftButton"] = "Open Spoilscribe"

-- ── Options panel ───────────────────────────────────────────────────────────
local panel = CreateFrame("Frame", "SpoilscribeOptionsPanel", UIParent)
panel.name = "Spoilscribe"
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
title:SetText("Spoilscribe")

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Per-character settings")

-- ── Group sync checkbox ─────────────────────────────────────────────────────
local syncCheck = CreateFrame("CheckButton", "SpoilscribeOptSync", panel, "InterfaceOptionsCheckButtonTemplate")
syncCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
syncCheck.Text:SetText("Enable group sync (share favorites with party)")
syncCheck:SetChecked(GetOption("groupSync"))
syncCheck:SetScript("OnClick", function(self)
    SetOption("groupSync", self:GetChecked() and true or false)
end)

-- ── Keybind label + button ──────────────────────────────────────────────────
local keybindLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
keybindLabel:SetPoint("TOPLEFT", syncCheck, "BOTTOMLEFT", 4, -24)
keybindLabel:SetText("Open Spoilscribe:")

local keybindBtn = CreateFrame("Button", "SpoilscribeOptKeybind", panel, "UIPanelButtonTemplate")
keybindBtn:SetSize(180, 26)
keybindBtn:SetPoint("LEFT", keybindLabel, "RIGHT", 10, 0)

local _waitingForKey = false

local function GetCurrentKeybind()
    return GetBindingKey("CLICK SpoilscribeOpenButton:LeftButton") or ""
end

local function UpdateKeybindText()
    local key = GetCurrentKeybind()
    if _waitingForKey then
        keybindBtn:SetText("Press a key...")
    elseif key ~= "" then
        keybindBtn:SetText(key)
    else
        keybindBtn:SetText("Not bound")
    end
end

UpdateKeybindText()

keybindBtn:SetScript("OnClick", function()
    if _waitingForKey then
        _waitingForKey = false
        UpdateKeybindText()
        return
    end
    _waitingForKey = true
    UpdateKeybindText()
end)

panel:EnableKeyboard(false)

panel:SetScript("OnKeyDown", function(self, key)
    if not _waitingForKey then return end
    self:SetPropagateKeyboardInput(false)

    if key == "ESCAPE" then
        _waitingForKey = false
        UpdateKeybindText()
        return
    end

    -- Ignore bare modifier keys.
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT" then
        self:SetPropagateKeyboardInput(true)
        return
    end

    -- Build modifier prefix.
    local mods = ""
    if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
    if IsControlKeyDown() then mods = mods .. "CTRL-" end
    if IsAltKeyDown() then mods = mods .. "ALT-" end

    local combo = mods .. key
    local bindTarget = "CLICK SpoilscribeOpenButton:LeftButton"

    -- Clear any old binding.
    local old = GetCurrentKeybind()
    if old and old ~= "" then
        SetBinding(old)
    end

    SetBinding(combo, bindTarget)
    SaveBindings(GetCurrentBindingSet())

    _waitingForKey = false
    UpdateKeybindText()
end)

panel:SetScript("OnShow", function(self)
    syncCheck:SetChecked(GetOption("groupSync"))
    UpdateKeybindText()
    if _waitingForKey then
        self:EnableKeyboard(true)
    end
end)

panel:SetScript("OnHide", function(self)
    _waitingForKey = false
    self:EnableKeyboard(false)
    UpdateKeybindText()
end)

-- Enable/disable keyboard capture when waiting state changes.
keybindBtn:HookScript("OnClick", function()
    panel:EnableKeyboard(_waitingForKey)
    if _waitingForKey then
        panel:SetPropagateKeyboardInput(false)
    end
end)

-- Clear keybind button.
local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
clearBtn:SetSize(70, 26)
clearBtn:SetPoint("LEFT", keybindBtn, "RIGHT", 6, 0)
clearBtn:SetText("Clear")
clearBtn:SetScript("OnClick", function()
    _waitingForKey = false
    local old = GetCurrentKeybind()
    if old and old ~= "" then
        SetBinding(old)
        SaveBindings(GetCurrentBindingSet())
    end
    UpdateKeybindText()
end)

-- Register in the Interface Options addon list.
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end
