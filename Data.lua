local _, Spoilscribe = ...

Spoilscribe.Data = {}

-- Retail Encounter Journal difficulty IDs.
-- Mythic+ entries reuse EJ difficulty 23 (Mythic) with a keyLevel field.
Spoilscribe.Data.Difficulties = {
    { label = "Normal", id = 1 },
    { label = "Heroic", id = 2 },
    { label = "Mythic", id = 23 },
    { label = "Mythic+ 2",  id = 23, keyLevel = 2 },
    { label = "Mythic+ 3",  id = 23, keyLevel = 3 },
    { label = "Mythic+ 4",  id = 23, keyLevel = 4 },
    { label = "Mythic+ 5",  id = 23, keyLevel = 5 },
    { label = "Mythic+ 6",  id = 23, keyLevel = 6 },
    { label = "Mythic+ 7",  id = 23, keyLevel = 7 },
    { label = "Mythic+ 8",  id = 23, keyLevel = 8 },
    { label = "Mythic+ 9",  id = 23, keyLevel = 9 },
    { label = "Mythic+ 10", id = 23, keyLevel = 10 },
    { label = "Mythic + Voidcore", id = 23, keyLevel = "voidcore" },
}

-- Midnight Season 1 Mythic+ end-of-dungeon reward data.
-- Maps key level to item level, upgrade track, and track-specific bonus ID.
-- Common M+ bonus IDs (13440, 6652, 12699) are shared across all M+ items.
-- Track bonus IDs: Champion 12785-12790, Hero 12793-12798, Myth 12801-12806.
Spoilscribe.Data.MythicPlusBonusIDs = { 13440, 6652, 12699 }
Spoilscribe.Data.MythicPlusRewards = {
    [2]  = { ilvl = 250, track = "Champion 2/6", bonusID = 12786 },
    [3]  = { ilvl = 250, track = "Champion 2/6", bonusID = 12786 },
    [4]  = { ilvl = 253, track = "Champion 3/6", bonusID = 12787 },
    [5]  = { ilvl = 256, track = "Champion 4/6", bonusID = 12788 },
    [6]  = { ilvl = 259, track = "Hero 1/6",     bonusID = 12793 },
    [7]  = { ilvl = 259, track = "Hero 1/6",     bonusID = 12793 },
    [8]  = { ilvl = 263, track = "Hero 2/6",     bonusID = 12794 },
    [9]  = { ilvl = 263, track = "Hero 2/6",     bonusID = 12794 },
    [10] = { ilvl = 266, track = "Hero 3/6",     bonusID = 12795 },
    ["voidcore"] = { ilvl = 272, track = "Myth 1/6", bonusID = 12801 },
}

-- Filter option scaffolding. Filtering behavior will be added later.
Spoilscribe.Data.Filters = {
    slots = {
        "Any Slot",
        "Head",
        "Neck",
        "Shoulder",
        "Back",
        "Chest",
        "Wrist",
        "Hands",
        "Waist",
        "Legs",
        "Feet",
        "Ring",
        "Trinket",
        "One-Hand",
        "Two-Hand",
        "Off-Hand",
        "Ranged",
    },
    secondaryStats = {
        "Any Stats",
        "Critical Strike",
        "Haste",
        "Mastery",
        "Versatility",
    },
}

-- Static encounter IDs are intentionally explicit and easy to edit.
-- If Blizzard updates encounter IDs, adjust this table only.
-- Midnight Season 1 dungeon rotation.
-- To retrieve the instance ID: use /dump EJ_GetInstanceByIndex(n, false)
-- To retrieve the encounter IDs: use /dump EJ_GetEncounterInfoByIndex(n, instanceID)
Spoilscribe.Data.Dungeons = {
    -- New Midnight Dungeons
    {
        name = "Magisters' Terrace",
        ejInstanceID = 1300,
        encounters = { 2659, 2661, 2660, 2662 },
    },
    {
        name = "Windrunner Spire",
        ejInstanceID = 1299,
        encounters = { 2655, 2656, 2657, 2658 },
    },
    {
        name = "Maisara Caverns",
        ejInstanceID = 1315,
        encounters = { 2810, 2811, 2812 },
    },
    {
        name = "Nexus-Point Xenas",
        ejInstanceID = 1316,
        encounters = { 2813, 2814, 2815 },
    },
    -- Legacy Dungeon Rotation
    {
        name = "Algeth'ar Academy",
        ejInstanceID = 1201,
        encounters = { 2509, 2512, 2495, 2514 },
    },
    {
        name = "Seat of the Triumvirate",
        ejInstanceID = 945,
        encounters = { 1979, 1980, 1981, 1982 },
    },
    {
        name = "Skyreach",
        ejInstanceID = 476,
        encounters = { 965, 966, 967, 968 },
    },
    {
        name = "Pit of Saron",
        ejInstanceID = 278,
        encounters = { 608, 609, 610 },
    },
}
