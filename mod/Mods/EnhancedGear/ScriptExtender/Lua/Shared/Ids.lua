-- Permanent identifiers of the mod. Saves, templates and localization refer to them:
-- never change a value after release, only add new ones.
EG = EG or {}
local Ids = {}

Ids.ModName = "EnhancedGear"
Ids.DisplayName = "Enhanced Gear"
Ids.Author = "morvwy-sketch"
Ids.ModuleUUID = "7c2e9f14-3b8a-4d61-9e57-a0c4d2b8f613"
Ids.Version = { 0, 4, 0, 0 }
Ids.RequiredSE = 27

-- Material keys in display order. "gold" is a resource but not an item of the mod.
Ids.Materials = { "scrap", "dust", "ingot", "core" }
Ids.Resources = { "scrap", "dust", "ingot", "core", "gold" }

-- Items of the mod. `parent` is a key of tools/data/vanilla_templates.json (borrowed 3D model).
Ids.Items = {
    scrap = { stats = "EG_OBJ_Scrap", template = "4a91d3e7-62bc-4f08-8d2a-b5e17c90f3a4",
        icon = "EG_Item_Scrap", parent = "ingot_bronze", weight = 0.1, value = 1, stack = 999 },
    dust = { stats = "EG_OBJ_Dust", template = "d8f04b2c-9e15-4a7d-b36f-21c8e5a7d9b0",
        icon = "EG_Item_Dust", parent = "fluorite_purple", weight = 0.05, value = 2, stack = 999 },
    ingot = { stats = "EG_OBJ_Ingot", template = "1e6b8a3f-c42d-4590-a8e1-7f3d0b9c2e65",
        icon = "EG_Item_Ingot", parent = "ingot_silver", weight = 0.5, value = 5, stack = 999 },
    core = { stats = "EG_OBJ_Core", template = "b3c7e129-58fa-4e2b-9d04-6a1f8e3c7b52",
        icon = "EG_Item_Core", parent = "diamond_black", weight = 0.1, value = 10, stack = 999, rare = true },
    kit = { stats = "EG_OBJ_ForgeKit", template = "9f5a2d81-e7c3-4b16-a59e-3d8b0f4c61e7",
        icon = "EG_Item_ForgeKit", parent = "hammer", weight = 1, value = 1 },
}
Ids.ItemOrder = { "scrap", "dust", "ingot", "core", "kit" }

-- Vanilla gold (LOOT_Gold_A). Gold is an ordinary stackable item in BG3.
Ids.GoldTemplate = "1c3c9c74-34a1-4685-989e-410dc080be6f"

Ids.IconAtlas = { uuid = "62d8b4f0-1a3e-4c97-b825-e9f7a0c3d146", name = "Icons_EnhancedGear" }

Ids.UserVar = "EG_ItemState"
Ids.ModVar = "EnhancedGear"
Ids.Channels = { request = "EG_Request", push = "EG_Push" }

Ids.Status = {
    ForgeOpen = "EG_FORGE_OPEN",
    Wielder = "EG_WIELDER",
}
Ids.Spell = { ForgeOpen = "EG_Shout_OpenForge" }

-- Suffix of per-instance name handles: <original handle>_EG_<item guid>.
Ids.NameSuffix = "_EG_"

function Ids.VersionString()
    local v = Ids.Version
    return string.format("%d.%d.%d", v[1], v[2], v[3])
end

-- BG3 packs versions into one 64-bit integer: major<<55 | minor<<47 | revision<<31 | build.
function Ids.Version64()
    local v = Ids.Version
    return (v[1] << 55) | (v[2] << 47) | (v[3] << 31) | v[4]
end

EG.Ids = Ids
return Ids
