-- ALL balance numbers of the mod. Formulas live in Logic.lua, the status catalog in Effects.lua.
-- After changing anything here run `lua5.4 tools/generate.lua` and update docs/MOD_GUIDE.uk.md.
EG = EG or {}
local R = {}

R.MaxLevel = 20
R.Milestones = { 5, 10, 15, 20 }

---------------------------------------------------------------------------------------------------
-- Rarity: 1 Common, 2 Uncommon, 3 Rare, 4 VeryRare, 5 Legendary
---------------------------------------------------------------------------------------------------
R.RarityIds = { "Common", "Uncommon", "Rare", "VeryRare", "Legendary" }
R.RarityCap = { 5, 10, 15, 20, 20 }
R.RarityGoldPct = { 100, 115, 130, 150, 175 }
-- Stats "Rarity" field -> our index.
R.StatsRarity = { Common = 1, Uncommon = 2, Rare = 3, VeryRare = 4, Legendary = 5, Story = 5 }
-- Engine colour scale of the Value component is 0..4 (not the stats scale).
R.EngineRarity = { 0, 1, 2, 3, 4 }

---------------------------------------------------------------------------------------------------
-- Forge technology (campaign wide, never decreases)
---------------------------------------------------------------------------------------------------
R.TechCap = { 5, 10, 15, 20 }
R.TechByLevel = {
    TUT_Avernus_C = 1, WLD_Main_A = 1, CRE_Main_A = 1,
    SCL_Main_A = 2,
    INT_Main_A = 3, BGO_Main_A = 3,
    CTY_Main_A = 4, IRO_Main_A = 4, END_Main = 4,
}

---------------------------------------------------------------------------------------------------
-- Profiles and equipment slots
---------------------------------------------------------------------------------------------------
R.Profiles = { "weapon", "focus", "body", "shield", "helmet", "gloves", "boots", "cloak", "amulet", "ring" }
R.ProfileGroup = {
    weapon = "weapon", focus = "focus",
    body = "armor", shield = "armor", helmet = "armor", gloves = "armor", boots = "armor", cloak = "armor",
    amulet = "jewelry", ring = "jewelry",
}
-- Scrap and gold x0.75 (rounded up) for the forging steps; gold only for reforging.
R.CheapProfiles = { shield = true, helmet = true, gloves = true, boots = true, cloak = true, amulet = true, ring = true }
R.CheapPct = 75

-- Slot keys used in status ids and their engine slot names.
R.SlotOrder = { "MAIN", "OFF", "RMAIN", "ROFF", "BODY", "HELMET", "GLOVES", "BOOTS", "CLOAK", "AMULET", "RING1", "RING2" }
R.SlotEngine = {
    MAIN = "Melee Main Weapon", OFF = "Melee Offhand Weapon",
    RMAIN = "Ranged Main Weapon", ROFF = "Ranged Offhand Weapon",
    BODY = "Breast", HELMET = "Helmet", GLOVES = "Gloves", BOOTS = "Boots", CLOAK = "Cloak",
    AMULET = "Amulet", RING1 = "Ring", RING2 = "Ring2",
}
local weaponSlots = { "MAIN", "OFF", "RMAIN", "ROFF" }
R.ProfileSlots = {
    weapon = weaponSlots, focus = weaponSlots,
    body = { "BODY" }, shield = { "OFF" }, helmet = { "HELMET" }, gloves = { "GLOVES" },
    boots = { "BOOTS" }, cloak = { "CLOAK" }, amulet = { "AMULET" }, ring = { "RING1", "RING2" },
}
-- Armor stats "Slot" -> profile. Anything not listed (vanity, underwear, instruments...) is unsupported.
R.ArmorSlotProfile = {
    ["Breast"] = "body", ["Melee Offhand Weapon"] = "shield", ["Helmet"] = "helmet", ["Gloves"] = "gloves",
    ["Boots"] = "boots", ["Cloak"] = "cloak", ["Amulet"] = "amulet", ["Ring"] = "ring", ["Ring2"] = "ring",
}
R.WeaponSlots = { MAIN = true, OFF = true, RMAIN = true, ROFF = true }

-- Naturally legendary items get a smaller budget; named exceptions: stats id -> profile cap.
R.NaturalLegendaryCap = 10
R.NamedItemCaps = {}

---------------------------------------------------------------------------------------------------
-- Forging steps: cost of reaching level N (base profiles, Common rarity)
---------------------------------------------------------------------------------------------------
R.Steps = {
    [1] = { scrap = 1, gold = 20 },
    [2] = { scrap = 1, gold = 30 },
    [3] = { scrap = 2, gold = 40 },
    [4] = { scrap = 2, gold = 50 },
    [5] = { scrap = 3, gold = 80 },
    [6] = { scrap = 2, dust = 1, gold = 90 },
    [7] = { scrap = 2, dust = 1, gold = 100 },
    [8] = { scrap = 3, dust = 1, gold = 120 },
    [9] = { scrap = 3, dust = 1, gold = 140 },
    [10] = { scrap = 4, dust = 2, gold = 200 },
    [11] = { scrap = 3, dust = 2, ingot = 1, gold = 220 },
    [12] = { scrap = 3, dust = 2, ingot = 1, gold = 240 },
    [13] = { scrap = 4, dust = 2, ingot = 1, gold = 260 },
    [14] = { scrap = 4, dust = 2, ingot = 1, gold = 280 },
    [15] = { scrap = 5, dust = 3, ingot = 2, gold = 400 },
    [16] = { scrap = 4, dust = 3, ingot = 2, gold = 420 },
    [17] = { scrap = 4, dust = 3, ingot = 2, gold = 450 },
    [18] = { scrap = 5, dust = 3, ingot = 2, gold = 480 },
    [19] = { scrap = 5, dust = 4, ingot = 2, gold = 520 },
    [20] = { scrap = 6, dust = 4, ingot = 3, core = 1, gold = 800 },
}

---------------------------------------------------------------------------------------------------
-- Reforging (rarity +1). Key = new rarity.
---------------------------------------------------------------------------------------------------
R.Reforge = {
    [2] = { cost = { scrap = 4, dust = 2, gold = 150 }, tech = 1 },
    [3] = { cost = { scrap = 6, dust = 4, ingot = 1, gold = 400 }, tech = 2 },
    [4] = { cost = { dust = 6, ingot = 3, gold = 900 }, tech = 3 },
    [5] = { cost = { dust = 8, ingot = 5, core = 1, gold = 2000 }, tech = 4 },
}

-- Affix slots: tier by current rarity (0 = slot closed / no effect) and the rarity whose reforge opens it.
R.AffixSlots = { "slot1", "slot2" }
R.AffixTier = {
    slot1 = { 0, 1, 2, 2, 3 },
    slot2 = { 0, 0, 0, 1, 1 },
}
R.AffixSlotOpensAt = { slot1 = 2, slot2 = 4 }

---------------------------------------------------------------------------------------------------
-- Effects. Atoms: { "AC", n } { "MaxHP", n } { "Save", Ability, n } { "Skill", Skill, n } { "Initiative", n }
-- { "Movement", metres } { "SpellAttack", n } { "SpellDC", n } { "ReduceAll", n } { "Reduce", Type, n }
-- { "Resist", Type } { "WeaponDamage", dice, Type } { "Enchant", n } { "FirstHit", n }
---------------------------------------------------------------------------------------------------
R.Weapon = {
    enchantCap = 3, -- own enchantment + forging never exceeds +3
    firstHitMax = 7,
    milestones = {
        [5] = { enchant = 1, firstHit = 0 },
        [10] = { enchant = 1, firstHit = 2 },
        [15] = { enchant = 2, firstHit = 3 },
        [20] = { enchant = 3, firstHit = 4 },
    },
}

R.MilestoneEffects = {
    focus = {
        [5] = { { "SpellAttack", 1 } },
        [10] = { { "SpellAttack", 1 }, { "SpellDC", 1 } },
        [15] = { { "SpellAttack", 1 }, { "SpellDC", 1 }, { "Save", "Constitution", 1 } },
        [20] = { { "SpellAttack", 2 }, { "SpellDC", 1 }, { "Save", "Constitution", 1 } },
    },
    body = {
        [5] = { { "MaxHP", 5 } },
        [10] = { { "AC", 1 }, { "MaxHP", 5 } },
        [15] = { { "AC", 1 }, { "MaxHP", 10 } },
        [20] = { { "AC", 1 }, { "MaxHP", 10 }, { "ReduceAll", 1 } },
    },
    shield = {
        [5] = { { "Save", "Dexterity", 1 } },
        [10] = { { "AC", 1 } },
        [15] = { { "AC", 1 }, { "Save", "Dexterity", 1 } },
        [20] = { { "AC", 1 }, { "Save", "Dexterity", 1 }, { "MaxHP", 5 } },
    },
    helmet = {
        [5] = { { "Skill", "Perception", 1 } },
        [10] = { { "Skill", "Perception", 1 }, { "Save", "Wisdom", 1 } },
        [15] = { { "Skill", "Perception", 2 }, { "Save", "Wisdom", 1 } },
        [20] = { { "Skill", "Perception", 2 }, { "Save", "Wisdom", 1 }, { "Initiative", 2 } },
    },
    gloves = {
        [5] = { { "Skill", "Athletics", 1 } },
        [10] = { { "Skill", "Athletics", 1 }, { "Skill", "SleightOfHand", 1 } },
        [15] = { { "Skill", "Athletics", 1 }, { "Skill", "SleightOfHand", 1 }, { "Save", "Strength", 1 } },
        [20] = { { "Skill", "Athletics", 2 }, { "Skill", "SleightOfHand", 1 }, { "Save", "Strength", 1 }, { "Initiative", 1 } },
    },
    boots = {
        [5] = { { "Movement", 1.5 } },
        [10] = { { "Movement", 1.5 }, { "Save", "Dexterity", 1 } },
        [15] = { { "Movement", 3 }, { "Save", "Dexterity", 1 } },
        [20] = { { "Movement", 3 }, { "Save", "Dexterity", 1 }, { "Skill", "Acrobatics", 1 } },
    },
    cloak = {
        [5] = { { "Skill", "Stealth", 1 } },
        [10] = { { "Skill", "Stealth", 1 }, { "Save", "Charisma", 1 } },
        [15] = { { "Skill", "Stealth", 2 }, { "Save", "Charisma", 1 } },
        [20] = { { "Skill", "Stealth", 2 }, { "Save", "Charisma", 1 }, { "Save", "Wisdom", 1 } },
    },
    amulet = {
        [5] = { { "Save", "Wisdom", 1 } },
        [10] = { { "Save", "Wisdom", 1 }, { "Skill", "Insight", 1 } },
        [15] = { { "Save", "Wisdom", 1 }, { "Skill", "Insight", 1 }, { "Save", "Intelligence", 1 } },
        [20] = { { "Save", "Wisdom", 1 }, { "Skill", "Insight", 1 }, { "Save", "Intelligence", 1 }, { "Save", "Charisma", 1 } },
    },
    ring = {
        [5] = { { "Initiative", 1 } },
        [10] = { { "Initiative", 1 }, { "Save", "Constitution", 1 } },
        [15] = { { "Initiative", 2 }, { "Save", "Constitution", 1 } },
        [20] = { { "Initiative", 2 }, { "Save", "Constitution", 1 }, { "MaxHP", 5 } },
    },
}

---------------------------------------------------------------------------------------------------
-- Affixes (chosen on reforge). target: "weapon" = status on the weapon, "wearer" = on the character.
---------------------------------------------------------------------------------------------------
local ALL = { weapon = true, focus = true, body = true, shield = true, helmet = true, gloves = true,
    boots = true, cloak = true, amulet = true, ring = true }
local ARMOR = { body = true, shield = true, helmet = true, gloves = true, boots = true, cloak = true }
local function union(...)
    local out = {}
    for _, set in ipairs({ ... }) do
        for k in pairs(set) do out[k] = true end
    end
    return out
end
local FOCUS = { focus = true }
local JEWELRY = { amulet = true, ring = true }

R.Affixes = {
    { id = "FLAME", target = "weapon", group = "element", profiles = { weapon = true },
        tiers = { { { "WeaponDamage", "1", "Fire" } }, { { "WeaponDamage", "1d4", "Fire" } }, { { "WeaponDamage", "1d6", "Fire" } } } },
    { id = "FROST", target = "weapon", group = "element", profiles = { weapon = true },
        tiers = { { { "WeaponDamage", "1", "Cold" } }, { { "WeaponDamage", "1d4", "Cold" } }, { { "WeaponDamage", "1d6", "Cold" } } } },
    { id = "STORM", target = "weapon", group = "element", profiles = { weapon = true },
        tiers = { { { "WeaponDamage", "1", "Lightning" } }, { { "WeaponDamage", "1d4", "Lightning" } }, { { "WeaponDamage", "1d6", "Lightning" } } } },
    { id = "VITALITY", target = "wearer", group = "life", profiles = ALL,
        tiers = { { { "MaxHP", 5 } }, { { "MaxHP", 10 } }, { { "MaxHP", 15 } } } },
    { id = "RESIST_FIRE", target = "wearer", group = "protection", profiles = union(FOCUS, ARMOR, JEWELRY),
        tiers = { { { "Reduce", "Fire", 2 } }, { { "Reduce", "Fire", 4 } }, { { "Resist", "Fire" } } } },
    { id = "RESIST_COLD", target = "wearer", group = "protection", profiles = union(FOCUS, ARMOR, JEWELRY),
        tiers = { { { "Reduce", "Cold", 2 } }, { { "Reduce", "Cold", 4 } }, { { "Resist", "Cold" } } } },
    { id = "RESIST_LIGHTNING", target = "wearer", group = "protection", profiles = union(FOCUS, ARMOR, JEWELRY),
        tiers = { { { "Reduce", "Lightning", 2 } }, { { "Reduce", "Lightning", 4 } }, { { "Resist", "Lightning" } } } },
    { id = "RESIST_POISON", target = "wearer", group = "protection", profiles = ARMOR,
        tiers = { { { "Reduce", "Poison", 2 } }, { { "Reduce", "Poison", 4 } }, { { "Resist", "Poison" } } } },
    { id = "AGILITY", target = "wearer", group = "movement", profiles = ARMOR,
        tiers = { { { "Movement", 1.5 } }, { { "Movement", 3 } }, { { "Movement", 4.5 } } } },
    { id = "VIGILANCE", target = "wearer", group = "senses", profiles = union(ARMOR, JEWELRY),
        tiers = { { { "Skill", "Perception", 1 } }, { { "Skill", "Perception", 2 } },
            { { "Skill", "Perception", 2 }, { "Initiative", 2 } } } },
    { id = "FOCUS", target = "wearer", group = "focus", profiles = union(FOCUS, JEWELRY),
        tiers = { { { "Save", "Constitution", 1 } }, { { "Save", "Constitution", 2 } }, { { "Save", "Constitution", 3 } } } },
}
R.AffixById = {}
for _, a in ipairs(R.Affixes) do R.AffixById[a.id] = a end

---------------------------------------------------------------------------------------------------
-- Salvage
---------------------------------------------------------------------------------------------------
R.Salvage = {
    base = {
        [1] = { scrap = 2 },
        [2] = { scrap = 2, dust = 1 },
        [3] = { scrap = 3, dust = 2 },
        [4] = { scrap = 4, dust = 3 },
        [5] = { scrap = 5, dust = 4, ingot = 1 },
    },
    scrapPct = { cloak = 50, amulet = 0, ring = 0 }, -- rounded down
    bonusDust = { amulet = 1, ring = 1 },
    refundPct = 50, -- of invested scrap, dust and ingots, rounded down
    refund = { "scrap", "dust", "ingot" },
}

---------------------------------------------------------------------------------------------------
-- Smelting
---------------------------------------------------------------------------------------------------
R.Smelt = { cost = { scrap = 6, dust = 2, gold = 100 }, output = { ingot = 1 }, tech = 2 }

---------------------------------------------------------------------------------------------------
-- Material sources
---------------------------------------------------------------------------------------------------
R.Loot = {
    starter = { kit = 1, scrap = 3 },
    regions = {
        TUT_Avernus_C = { scrap = 4, dust = 1 },
        WLD_Main_A = { scrap = 6, dust = 2 },
        CRE_Main_A = { scrap = 6, dust = 3, ingot = 1 },
        SCL_Main_A = { scrap = 8, dust = 4, ingot = 2 },
        INT_Main_A = { dust = 3, ingot = 1 },
        BGO_Main_A = { scrap = 8, dust = 5, ingot = 3 },
        CTY_Main_A = { scrap = 10, dust = 6, ingot = 4, core = 1 },
        IRO_Main_A = { ingot = 2, core = 1 },
        END_Main = {},
    },
    regionOrder = { "TUT_Avernus_C", "WLD_Main_A", "CRE_Main_A", "SCL_Main_A", "INT_Main_A", "BGO_Main_A",
        "CTY_Main_A", "IRO_Main_A", "END_Main" },
    boss = { dust = 2, ingot = 1, core = 1 },
    kill = {
        { mat = "scrap", chance = 50, min = 1, max = 2, minLevel = 1 },
        { mat = "dust", chance = 20, min = 1, max = 1, minLevel = 3 },
        { mat = "ingot", chance = 4, min = 1, max = 1, minLevel = 7 },
    },
}

EG.Rules = R
return R
