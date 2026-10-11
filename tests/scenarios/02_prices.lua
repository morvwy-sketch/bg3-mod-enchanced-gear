-- Prices: the guide's step table (gold x rarity, cheap profiles x0.75) and cost-to-milestone totals.
return function(T)
    local L = T.L
    local base = { 20, 30, 40, 50, 80, 90, 100, 120, 140, 200, 220, 240, 260, 280, 400, 420, 450, 480, 520, 800 }
    local uncommon = { 23, 35, 46, 58, 92, 104, 115, 138, 161, 230, 253, 276, 299, 322, 460, 483, 518, 552, 598, 920 }
    local legendary = { 35, 53, 70, 88, 140, 158, 175, 210, 245, 350, 385, 420, 455, 490, 700, 735, 788, 840, 910, 1400 }
    for lvl = 1, 20 do
        T.eq(L.StepCost("weapon", lvl, 1).gold, base[lvl], "common gold +" .. lvl)
        T.eq(L.StepCost("focus", lvl, 2).gold, uncommon[lvl], "uncommon gold +" .. lvl)
        T.eq(L.StepCost("body", lvl, 5).gold, legendary[lvl], "legendary gold +" .. lvl)
    end
    T.eq(L.StepCost("body", 20, 4), { scrap = 6, dust = 4, ingot = 3, core = 1, gold = 1200 }, "+20 at very rare")
    T.eq(L.StepCost("ring", 5, 1), { scrap = 3, gold = 60 }, "cheap profile: scrap and gold x0.75")
    T.eq(L.StepCost("boots", 11, 3), { scrap = 3, dust = 2, ingot = 1, gold = 215 }, "cheap gold x0.75 then x rarity")

    local totals = {
        weapon = {
            [5] = { scrap = 9, gold = 220 },
            [10] = { scrap = 27, dust = 8, gold = 1118 },
            [15] = { scrap = 52, dust = 23, ingot = 7, gold = 3338 },
            [20] = { scrap = 76, dust = 46, ingot = 21, core = 1, gold = 8243 },
        },
        shield = {
            [5] = { scrap = 9, gold = 166 },
            [10] = { scrap = 26, dust = 8, gold = 843 },
            [15] = { scrap = 48, dust = 23, ingot = 7, gold = 2509 },
            [20] = { scrap = 67, dust = 46, ingot = 21, core = 1, gold = 6189 },
        },
    }
    for profile, rows in pairs(totals) do
        for m, want in pairs(rows) do T.eq((L.MilestoneTotal(profile, m)), want, profile .. " to +" .. m) end
    end
    T.eq(L.ReforgeCost("weapon", 2), { scrap = 4, dust = 2, gold = 150 }, "reforge to uncommon")
    T.eq(L.ReforgeCost("cloak", 2), { scrap = 4, dust = 2, gold = 113 }, "cheap reforge: gold only")
    T.eq(L.ReforgeCost("ring", 4), { dust = 6, ingot = 3, gold = 675 }, "cheap reforge to very rare")
    T.eq(L.ReforgeCost("body", 5), { dust = 8, ingot = 5, core = 1, gold = 2000 }, "reforge to legendary")

    -- The server charges exactly the previewed amounts.
    local h = T.New()
    h:Tech(4)
    local sword = h:Item(h.host, "longsword")
    h:Give(h.host, { scrap = 6, gold = 220 })
    local before = h:Bundle()
    T.ok(h:Req("upgradeTo", { item = sword, target = 5 }).ok, "upgrade to +5")
    local after = h:Bundle()
    T.eq(before.scrap - after.scrap, 9, "scrap spent")
    T.eq(before.gold - after.gold, 220, "gold spent")
    T.eq(h:State(sword).spent, { scrap = 9, gold = 220 }, "investment recorded")
    h:Clean()
end
