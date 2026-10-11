-- Affixes: allowed per profile, slot 2 never repeats the id or group of slot 1, tiers follow rarity.
return function(T)
    local L = T.L
    T.eq(L.AllowedAffixes({ profile = "weapon", affixes = {} }, "slot1"), { "FLAME", "FROST", "STORM", "VITALITY" })
    T.eq(L.AllowedAffixes({ profile = "weapon", affixes = { slot1 = "FLAME" } }, "slot2"), { "VITALITY" })
    T.eq(L.AllowedAffixes({ profile = "body", affixes = { slot1 = "RESIST_FIRE" } }, "slot2"),
        { "VITALITY", "AGILITY", "VIGILANCE" })
    T.eq(L.AllowedAffixes({ profile = "ring", affixes = {} }, "slot1"),
        { "VITALITY", "RESIST_FIRE", "RESIST_COLD", "RESIST_LIGHTNING", "VIGILANCE", "FOCUS" })
    T.eq(L.AllowedAffixes({ profile = "focus", affixes = {} }, "slot1"),
        { "VITALITY", "RESIST_FIRE", "RESIST_COLD", "RESIST_LIGHTNING", "FOCUS" })
    for r, tier in ipairs({ 0, 1, 2, 2, 3 }) do T.eq(L.AffixTier("slot1", r), tier, "slot 1 tier at rarity " .. r) end
    for r, tier in ipairs({ 0, 0, 0, 1, 1 }) do T.eq(L.AffixTier("slot2", r), tier, "slot 2 tier at rarity " .. r) end

    local h = T.New()
    h:Rich()
    local mail = h:Item(h.host, "chainmail")
    h:Req("upgradeTo", { item = mail, target = 5 })
    T.eq(h:Req("reforge", { item = mail }).reason, "badAffix", "a choice is required")
    T.eq(h:Req("reforge", { item = mail, affix = "FLAME" }).reason, "badAffix", "weapon affix on armour")
    T.ok(h:Req("reforge", { item = mail, affix = "RESIST_FIRE" }).ok)
    local r = h:Req("reforge", { item = mail })
    T.eq(r.reason, "needTech", "rare needs technology II")
    T.eq(r.params, { 2 })
    h:Tech(4)
    T.ok(h:Req("reforge", { item = mail }).ok, "to rare: no choice")
    T.eq(h:Req("reforge", { item = mail, affix = "RESIST_COLD" }).reason, "badAffix", "same group")
    T.ok(h:Req("reforge", { item = mail, affix = "AGILITY" }).ok)
    T.ok(h:Req("reforge", { item = mail }).ok, "to legendary")
    T.eq(h:State(mail).affixes, { slot1 = "RESIST_FIRE", slot2 = "AGILITY" })
    T.eq(h:State(mail).rarity, 5)
    T.eq(h:Req("reforge", { item = mail }).reason, "legendary")
    h:Equip(h.host, "BODY", mail)
    T.eq(h:Statuses(h.host), { "EG_AFX_AGILITY_1_BODY", "EG_AFX_RESIST_FIRE_3_BODY", "EG_MS_BODY_5_BODY" },
        "masterwork slot 1, simple slot 2")
    T.eq(h:State(mail).level, 5, "reforging keeps the forging level")
    h:Clean()
end
