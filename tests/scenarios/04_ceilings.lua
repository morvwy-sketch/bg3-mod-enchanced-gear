-- Ceiling = lowest of rarity, technology and profile caps; tie naming order tech > profile > rarity.
return function(T)
    local L, R = T.L, T.R
    local function item(level, rarity, baseRarity, statsId, story)
        return { state = { level = level, rarity = rarity, baseRarity = baseRarity or rarity, profile = "weapon",
            affixes = {}, spent = {} }, info = { statsId = statsId, story = story } }
    end
    local function ceil(it, tier) return { L.Ceiling(it, { techTier = tier }) } end
    T.eq(ceil(item(0, 1), 1), { 5, "tech" }, "tech and rarity tie -> tech")
    T.eq(ceil(item(0, 1), 2), { 5, "rarity" }, "rarity limits")
    T.eq(ceil(item(0, 3), 2), { 10, "tech" }, "tech limits")
    T.eq(ceil(item(0, 5, 5), 4), { 10, "profile" }, "naturally legendary: +10")
    T.eq(ceil(item(0, 5, 5), 2), { 10, "tech" }, "tech and profile tie -> tech")
    R.NamedItemCaps.WPN_Named = 10
    T.eq(ceil(item(0, 2, 2, "WPN_Named"), 4), { 10, "profile" }, "profile and rarity tie -> profile")
    T.eq(ceil(item(0, 4, 4, "WPN_Named"), 4), { 10, "profile" }, "named cap")
    R.NamedItemCaps.WPN_Named = nil

    local env4 = { techTier = 4, cfg = {} }
    local rich = { scrap = 99, dust = 99, ingot = 99, core = 9, gold = 99999 }
    T.eq(L.CheckUpgrade(item(5, 1), env4, rich).reason, "rarityCap")
    T.eq(L.CheckUpgrade(item(5, 2), { techTier = 1 }, rich).reason, "techCap")
    T.eq(L.CheckUpgrade(item(10, 5, 5), env4, rich).reason, "profileCap")
    T.eq(L.CheckUpgrade(item(20, 4), env4, rich).reason, "max")
    T.eq(L.CheckUpgrade(item(3, 1, 1, nil, true), { techTier = 4, cfg = { AllowStoryItemUpgrades = false } }, rich).reason, "story")
    T.ok(L.CheckUpgrade(item(3, 1, 1, nil, true), env4, rich).ok, "story items can be forged by default")
    local unsupported = item(0, 1)
    unsupported.state.profile = nil
    T.eq(L.CheckUpgrade(unsupported, env4, rich).reason, "unsupported")

    -- The server applies the same limits.
    local h = T.New()
    h:Rich()
    local sword = h:Item(h.host, "longsword")
    h:Upgrade(sword, 5)
    T.eq(h:Req("upgrade", { item = sword }).reason, "techCap", "tech I and common rarity: tech is named")
    local legend = h:Item(h.host, "legendary")
    h:Tech(4)
    h:Req("upgradeTo", { item = legend, target = 5 })
    h:Req("upgradeTo", { item = legend, target = 10 })
    T.eq(h:State(legend).level, 10)
    T.eq(h:Req("upgrade", { item = legend }).reason, "profileCap")
    h:Clean()
end
