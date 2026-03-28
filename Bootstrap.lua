local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}
_G[addonName] = Spoilscribe

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function MakeLogger(prefix)
    return function(msg)
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg))
    end
end

local function SafeCall(fn, errorPrefix)
    local ok, err = pcall(fn)
    if not ok and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(errorPrefix .. ": " .. tostring(err))
    end
end

local function EnsureEJLoaded()
    if EncounterJournal_LoadUI then pcall(EncounterJournal_LoadUI) end
end

local function SelectLatestTier()
    if EJ_GetNumTiers and EJ_GetNumTiers() > 0 then
        EJ_SelectTier(EJ_GetNumTiers())
    end
end

local function GetFirstDungeon()
    local data = Spoilscribe.Data
    if not data or not data.Dungeons or not data.Dungeons[1] then return nil end
    local dungeon = data.Dungeons[1]
    return dungeon, dungeon.encounters[1]
end

---------------------------------------------------------------------------
-- Debug: test item link generation at various M+ key levels
---------------------------------------------------------------------------
local function DebugLinks()
    local dungeon, encounterID = GetFirstDungeon()
    if not dungeon then
        DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe debug: Data not loaded.")
        return
    end

    local log = MakeLogger("[SS] ")
    EnsureEJLoaded()

    local initialTier
    if EJ_GetNumTiers and EJ_GetNumTiers() > 0 then
        initialTier = EJ_GetNumTiers()
    end

    log(string.format("Dungeon: %s (ej=%d) Encounter=%d", dungeon.name, dungeon.ejInstanceID, encounterID))

    -- Report which M+ APIs exist
    log("--- API availability ---")
    for _, name in ipairs({ "SetPreviewMythicPlusLevel", "GetPreviewMythicPlusLevel", "SetPreviewPvpTier" }) do
        log(name .. ": " .. tostring(C_EncounterJournal and C_EncounterJournal[name] or "nil"))
    end

    local setLevel = C_EncounterJournal and C_EncounterJournal.SetPreviewMythicPlusLevel
    local getLevel = C_EncounterJournal and C_EncounterJournal.GetPreviewMythicPlusLevel

    -- Apply difficulty + key level after each EJ selection step (required by the API)
    local function applyMythicPlus(keyLevel)
        EJ_SetDifficulty(23)
        if setLevel then setLevel(keyLevel) end
    end

    -- Configure EJ for the given key level and return the first loot entry
    local function getLinkForKeyLevel(keyLevel)
        if EJ_SelectTier and initialTier then EJ_SelectTier(initialTier) end
        applyMythicPlus(keyLevel)

        pcall(EJ_SelectInstance, dungeon.ejInstanceID)
        applyMythicPlus(keyLevel)

        pcall(EJ_SelectEncounter, encounterID)
        applyMythicPlus(keyLevel)

        local currentLevel = getLevel and tostring(getLevel()) or "N/A"
        local info = C_EncounterJournal.GetLootInfoByIndex(1)
        if info then
            return info.link, info.itemID, info.name, currentLevel
        end
        return nil, nil, nil, currentLevel
    end

    -- Test several key levels and collect results for comparison
    local testLevels = { 0, 5, 10 }
    local results = {}
    for _, level in ipairs(testLevels) do
        log(string.format("--- Key Level %d ---", level))
        local link, id, name, cur = getLinkForKeyLevel(level)
        log("  GetPreviewMythicPlusLevel=" .. cur)
        log("  id=" .. tostring(id) .. " name=" .. tostring(name))
        log("  link=" .. tostring(link))
        results[level] = link
    end

    log("--- Comparison ---")
    log("  0 vs 5 same? " .. tostring(results[0] == results[5]))
    log("  5 vs 10 same? " .. tostring(results[5] == results[10]))
end

---------------------------------------------------------------------------
-- Debug: dump raw loot info for first encounter
---------------------------------------------------------------------------
local function DebugLoot()
    local log = MakeLogger("|cff00ff00[SS Debug]|r ")
    EnsureEJLoaded()

    local dungeon, encounterID = GetFirstDungeon()
    if not dungeon then
        log("No dungeon data.")
        return
    end

    SelectLatestTier()
    EJ_SetDifficulty(23)
    pcall(EJ_SelectInstance, dungeon.ejInstanceID)
    pcall(EJ_SelectEncounter, encounterID)

    log("Dungeon: " .. dungeon.name .. " | Encounter: " .. tostring(encounterID))

    if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
        local info = C_EncounterJournal.GetLootInfoByIndex(1, encounterID)
        if info then
            log("--- Raw C_EncounterJournal.GetLootInfoByIndex fields ---")
            for k, v in pairs(info) do
                log("  " .. tostring(k) .. " = " .. tostring(v) .. "  (type: " .. type(v) .. ")")
            end
        else
            log("GetLootInfoByIndex(1, encounterID) returned nil")
            local info2 = C_EncounterJournal.GetLootInfoByIndex(1)
            if info2 then
                log("--- Fallback GetLootInfoByIndex(1) fields ---")
                for k, v in pairs(info2) do
                    log("  " .. tostring(k) .. " = " .. tostring(v) .. "  (type: " .. type(v) .. ")")
                end
            else
                log("Fallback also nil")
            end
        end
    else
        log("C_EncounterJournal.GetLootInfoByIndex not available")
    end

    if EJ_GetLootInfoByIndex then
        log("--- EJ_GetLootInfoByIndex returns ---")
        local a, b, c, d, e, f, g, h, i, j = EJ_GetLootInfoByIndex(1, encounterID)
        log("  1=" .. tostring(a) .. " 2=" .. tostring(b) .. " 3=" .. tostring(c))
        log("  4=" .. tostring(d) .. " 5=" .. tostring(e) .. " 6=" .. tostring(f))
        log("  7=" .. tostring(g) .. " 8=" .. tostring(h) .. " 9=" .. tostring(i) .. " 10=" .. tostring(j))
    end
end

---------------------------------------------------------------------------
-- Debug: dump comm/party sync state
---------------------------------------------------------------------------
local function DebugComm()
    local log = MakeLogger("|cff00ff00[SS Comm]|r ")
    local syncOn = Spoilscribe.GetOption and Spoilscribe:GetOption("groupSync")
    log("groupSync: " .. tostring(syncOn))
    log("InGroup: " .. tostring(IsInGroup and IsInGroup()))
    local _, instType = _G.IsInInstance()
    log("Instance type: " .. tostring(instType))

    local myDungeons = Spoilscribe:GetFavoriteDungeonNames()
    local myList = {}
    for dn in pairs(myDungeons) do myList[#myList + 1] = dn end
    log("My fav dungeons (" .. #myList .. "): " .. (next(myList) and table.concat(myList, ", ") or "none"))

    local partyData = Spoilscribe:GetPartyFavDungeons()
    local count = 0
    for sender, dungeons in pairs(partyData) do
        count = count + 1
        local names = {}
        for dn in pairs(dungeons) do names[#names + 1] = dn end
        log("  " .. sender .. ": " .. table.concat(names, ", "))
    end
    if count == 0 then
        log("  No party member data received.")
    end
end

---------------------------------------------------------------------------
-- Simulated party toggle
---------------------------------------------------------------------------
local FAKE_MEMBERS = {
    "Thrallina-Stormrage",
    "Jainapriest-Illidan",
    "Grommlock-Tichondrius",
}

local function ToggleSimParty()
    Spoilscribe._simParty = not Spoilscribe._simParty
    local partyData = Spoilscribe:GetPartyFavDungeons()

    if Spoilscribe._simParty then
        local dungeons = Spoilscribe.Data and Spoilscribe.Data.Dungeons or {}
        for _, name in ipairs(FAKE_MEMBERS) do partyData[name] = {} end
        for i, d in ipairs(dungeons) do
            if i % 2 == 1 then partyData[FAKE_MEMBERS[1]][d.name] = math.random(1, 5) end
            if i % 3 == 0 then partyData[FAKE_MEMBERS[2]][d.name] = math.random(1, 3) end
            if i <= 3   then partyData[FAKE_MEMBERS[3]][d.name] = math.random(2, 6) end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spoilscribe]|r Simulated party ON (3 fake members).")
    else
        for _, name in ipairs(FAKE_MEMBERS) do partyData[name] = nil end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spoilscribe]|r Simulated party OFF.")
    end

    if Spoilscribe.UI and Spoilscribe.UI.frame and Spoilscribe.UI.frame:IsShown() then
        Spoilscribe.UI:RenderPage()
    end
end

---------------------------------------------------------------------------
-- Slash command dispatch
---------------------------------------------------------------------------

local SubCommands = {
    debug     = function() SafeCall(DebugLinks, "Spoilscribe debug error") end,
    debugcomm = function() SafeCall(DebugComm, "|cffff0000[SS Comm Error]|r") end,
    simparty  = ToggleSimParty,
}

SLASH_SPOILSCRIBE1 = "/spoilscribe"
SLASH_SPOILSCRIBE2 = "/ss"
SlashCmdList.SPOILSCRIBE = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    local handler = SubCommands[msg]
    if handler then
        handler()
        return
    end

    -- Default: open the main UI
    if type(Spoilscribe.Open) == "function" then
        SafeCall(function() Spoilscribe:Open(msg) end, "Spoilscribe: command failed")
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "Spoilscribe: addon not fully loaded. Enable Lua errors with /console scriptErrors 1 and reload.")
    end
end

---------------------------------------------------------------------------
-- Utility slash commands
---------------------------------------------------------------------------

SLASH_SSCLEARCACHE1 = "/ss_clearcache"
SlashCmdList.SSCLEARCACHE = function()
    local frame = SpoilscribeFrame
    if frame and frame.rows then
        for _, row in ipairs(frame.rows) do row:Hide() end
        wipe(frame.rows)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spoilscribe]|r Row cache cleared. Reopen to rebuild.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spoilscribe]|r No cached rows found.")
    end
end

SLASH_SSDEBOGLOOT1 = "/ss_debugloot"
SlashCmdList.SSDEBOGLOOT = function()
    SafeCall(DebugLoot, "|cffff0000[SS Debug Error]|r")
end
