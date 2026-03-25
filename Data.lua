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
Spoilscribe.Data.Dungeons = {
    -- New Midnight Dungeons
    {
        name = "Magisters' Terrace",
        instanceID = 15829,
        encounters = { 2782, 2783, 2784, 2785 },
    },
    {
        name = "Windrunner Spire",
        instanceID = 15808,
        encounters = { 2801, 2802, 2803, 2804 },
    },
    {
        name = "Maisara Caverns",
        instanceID = 15842,
        encounters = { 2815, 2816, 2817, 2818 },
    },
    {
        name = "Nexus-Point Xenas",
        instanceID = 15855,
        encounters = { 2830, 2831, 2832, 2833 },
    },
    -- Legacy Dungeon Rotation
    {
        name = "Algeth'ar Academy",
        instanceID = 14032,
        encounters = { 2512, 2513, 2514, 2515 },
    },
    {
        name = "Seat of the Triumvirate",
        instanceID = 1753,
        encounters = { 1979, 1980, 1981, 1982 },
    },
    {
        name = "Skyreach",
        instanceID = 1209,
        encounters = { 1162, 1163, 1164, 1165 },
    },
    {
        name = "Pit of Saron",
        instanceID = 658,
        encounters = { 605, 606, 607 },
    },
}
