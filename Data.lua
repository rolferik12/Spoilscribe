local _, Spoilscribe = ...

Spoilscribe.Data = {}

-- Retail Encounter Journal difficulty IDs.
Spoilscribe.Data.Difficulties = {
    { label = "Mythic", id = 23 },
    { label = "Heroic", id = 2 },
    { label = "Normal", id = 1 },
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
    },
    armorTypes = {
        "Any Armor",
        "Cloth",
        "Leather",
        "Mail",
        "Plate",
    },
    weaponTypes = {
        "Any Weapon",
        "Axe",
        "Dagger",
        "Fist",
        "Mace",
        "Polearm",
        "Staff",
        "Sword",
        "Warglaive",
        "Bow",
        "Crossbow",
        "Gun",
        "Wand",
        "Shield",
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
