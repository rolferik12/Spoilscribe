local addonName, Spoilscribe = ...

Spoilscribe = Spoilscribe or {}
_G[addonName] = Spoilscribe

local function DebugLinks()
    local data = Spoilscribe.Data
    if not data or not data.Dungeons then
        DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe debug: Data not loaded.")
        return
    end

    local function log(msg)
        DEFAULT_CHAT_FRAME:AddMessage("[SS] " .. tostring(msg))
    end

    if EncounterJournal_LoadUI then EncounterJournal_LoadUI() end

    local initialTier = nil
    if EJ_GetNumTiers and EJ_GetNumTiers() > 0 then
        initialTier = EJ_GetNumTiers()
    end

    local dungeon = data.Dungeons[1]
    local encounterID = dungeon.encounters[1]
    log(string.format("Dungeon: %s (ej=%d) Encounter=%d", dungeon.name, dungeon.ejInstanceID, encounterID))

    -- Check what M+ APIs exist
    log("--- API availability ---")
    log("SetPreviewMythicPlusLevel: " .. tostring(C_EncounterJournal and C_EncounterJournal.SetPreviewMythicPlusLevel or "nil"))
    log("GetPreviewMythicPlusLevel: " .. tostring(C_EncounterJournal and C_EncounterJournal.GetPreviewMythicPlusLevel or "nil"))
    log("SetPreviewPvpTier: " .. tostring(C_EncounterJournal and C_EncounterJournal.SetPreviewPvpTier or "nil"))

    -- Helper to do a full setup and get a link
    local function getLinkForKeyLevel(keyLevel)
        if EJ_SelectTier and initialTier then EJ_SelectTier(initialTier) end
        EJ_SetDifficulty(23)
        if C_EncounterJournal and C_EncounterJournal.SetPreviewMythicPlusLevel then
            C_EncounterJournal.SetPreviewMythicPlusLevel(keyLevel)
        end
        pcall(EJ_SelectInstance, dungeon.ejInstanceID)
        EJ_SetDifficulty(23)
        if C_EncounterJournal and C_EncounterJournal.SetPreviewMythicPlusLevel then
            C_EncounterJournal.SetPreviewMythicPlusLevel(keyLevel)
        end
        pcall(EJ_SelectEncounter, encounterID)
        EJ_SetDifficulty(23)
        if C_EncounterJournal and C_EncounterJournal.SetPreviewMythicPlusLevel then
            C_EncounterJournal.SetPreviewMythicPlusLevel(keyLevel)
        end

        -- Check what GetPreviewMythicPlusLevel returns
        local currentLevel = "N/A"
        if C_EncounterJournal and C_EncounterJournal.GetPreviewMythicPlusLevel then
            currentLevel = tostring(C_EncounterJournal.GetPreviewMythicPlusLevel())
        end

        local info = C_EncounterJournal.GetLootInfoByIndex(1)
        if info then
            return info.link, info.itemID, info.name, currentLevel
        end
        return nil, nil, nil, currentLevel
    end

    -- Test key level 0 (regular mythic)
    log("--- Key Level 0 (base mythic) ---")
    local link0, id0, name0, cur0 = getLinkForKeyLevel(0)
    log("  GetPreviewMythicPlusLevel=" .. cur0)
    log("  id=" .. tostring(id0) .. " name=" .. tostring(name0))
    log("  link=" .. tostring(link0))

    -- Test key level 5
    log("--- Key Level 5 ---")
    local link5, id5, name5, cur5 = getLinkForKeyLevel(5)
    log("  GetPreviewMythicPlusLevel=" .. cur5)
    log("  id=" .. tostring(id5) .. " name=" .. tostring(name5))
    log("  link=" .. tostring(link5))

    -- Test key level 10
    log("--- Key Level 10 ---")
    local link10, id10, name10, cur10 = getLinkForKeyLevel(10)
    log("  GetPreviewMythicPlusLevel=" .. cur10)
    log("  id=" .. tostring(id10) .. " name=" .. tostring(name10))
    log("  link=" .. tostring(link10))

    -- Compare: are links different?
    log("--- Comparison ---")
    log("  0 vs 5 same? " .. tostring(link0 == link5))
    log("  5 vs 10 same? " .. tostring(link5 == link10))
end

local function OpenFromSlash(msg)
    if msg and string.lower(string.trim and string.trim(msg) or msg) == "debug" then
        local ok, err = pcall(DebugLinks)
        if not ok and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe debug error: " .. tostring(err))
        end
        return
    end

    if type(Spoilscribe.Open) == "function" then
        local ok, err = pcall(Spoilscribe.Open, Spoilscribe, msg)
        if not ok and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: command failed - " .. tostring(err))
        end
        return
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: addon not fully loaded. Enable Lua errors with /console scriptErrors 1 and reload.")
    end
end

SLASH_SPOILSCRIBE1 = "/spoilscribe"
SLASH_SPOILSCRIBE2 = "/ss"
SlashCmdList.SPOILSCRIBE = OpenFromSlash

SLASH_SSCLEARCACHE1 = "/ss_clearcache"
SlashCmdList.SSCLEARCACHE = function()
    local frame = SpoilscribeFrame
    if frame and frame.rows then
        for i, row in ipairs(frame.rows) do
            row:Hide()
        end
        wipe(frame.rows)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spoilscribe]|r Row cache cleared. Reopen to rebuild.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spoilscribe]|r No cached rows found.")
    end
end

SLASH_SSDEBOGLOOT1 = "/ss_debugloot"
SlashCmdList.SSDEBOGLOOT = function()
    local function log(msg)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SS Debug]|r " .. tostring(msg))
    end

    if EncounterJournal_LoadUI then pcall(EncounterJournal_LoadUI) end

    local data = Spoilscribe.Data
    if not data or not data.Dungeons or not data.Dungeons[1] then
        log("No dungeon data.")
        return
    end

    local dungeon = data.Dungeons[1]
    local encounterID = dungeon.encounters[1]

    if EJ_GetNumTiers and EJ_GetNumTiers() > 0 then
        EJ_SelectTier(EJ_GetNumTiers())
    end
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
