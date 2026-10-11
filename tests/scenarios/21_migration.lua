-- Migration: damaged or old item states and campaign data are normalized to the current schema.
return function(T)
    local L = T.L
    local s = L.Normalize({ level = 99, rarity = 9, baseRarity = -3, profile = "weird",
        affixes = { slot1 = "NOPE", slot2 = "FLAME" }, spent = { scrap = -5, gold = 12.7 }, baseEnchant = 7 },
        { kind = "weapon", rarity = 1 })
    T.eq(s.level, 20)
    T.eq(s.rarity, 5)
    T.eq(s.baseRarity, 1)
    T.eq(s.profile, "weapon", "bad profile reset to the default")
    T.eq(s.affixes, { slot2 = "FLAME" }, "unknown affix dropped")
    T.eq(s.spent, { gold = 12 })
    T.eq(s.baseEnchant, 3)
    T.eq(s.v, L.StateVersion)
    T.eq(L.Normalize({ level = 1, rarity = 4, baseRarity = 1, profile = "body",
        affixes = { slot1 = "RESIST_FIRE", slot2 = "RESIST_COLD" }, spent = {} }).affixes, { slot1 = "RESIST_FIRE" },
        "incompatible pair loses slot 2")
    T.eq(L.Normalize({ level = 1, rarity = 2, baseRarity = 4, profile = "body", affixes = {}, spent = {} }).rarity, 4,
        "base rarity above rarity lifts rarity")
    T.eq(L.Normalize("garbage", { kind = "armor", slot = "Breast", rarity = 2 }).profile, "body")

    local h = T.New()
    local sword = h:Item(h.host, "longsword")
    h.w:E(sword).vars[T.Ids.UserVar] = { level = "7", rarity = 1 }
    h.w.p.modvars[T.Ids.ModuleUUID .. "/" .. T.Ids.ModVar] = { techTier = 9, regions = { WLD_Main_A = true },
        killed = "bad", index = { x = { level = 50, rarity = 2, profile = "body" } }, journal = 5 }
    h:Reload()
    local d = h:Data()
    T.eq(d.techTier, 4)
    T.eq(d.killed, {})
    T.eq(d.regions, { WLD_Main_A = true })
    T.eq(d.index.x.level, 20)
    T.eq(d.journal, nil)
    T.eq(d.v, 1)
    local st = h:State(sword)
    T.eq(st.level, 0, "non-numeric level becomes 0")
    T.eq(st.profile, "weapon")
    h:Clean()
end
