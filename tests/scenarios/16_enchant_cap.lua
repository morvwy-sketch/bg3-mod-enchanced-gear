-- Weapon enchantment cap +3: overflow turns into first-hit damage; statuses on the weapon and wielder.
return function(T)
    local L = T.L
    local want = {
        [0] = { "1/0", "1/2", "2/3", "3/4" },
        [1] = { "1/0", "1/2", "2/3", "2/5" },
        [2] = { "1/0", "1/2", "1/4", "1/6" },
        [3] = { "0/1", "0/3", "0/5", "0/7" },
    }
    for base = 0, 3 do
        for i, m in ipairs({ 5, 10, 15, 20 }) do
            local e, f = L.WeaponBonus(m, base)
            T.eq(e .. "/" .. f, want[base][i], string.format("own +%d at +%d", base, m))
        end
    end

    local h = T.New()
    h:Tech(4)
    h:Rich()
    local sword = h:Item(h.host, "longsword1") -- uncommon by nature, own enchantment +1
    h:Req("upgradeTo", { item = sword, target = 5 })
    h:Req("upgradeTo", { item = sword, target = 10 })
    T.ok(h:Req("reforge", { item = sword }).ok, "to rare (no new slot for a naturally uncommon item)")
    h:Req("upgradeTo", { item = sword, target = 15 })
    T.ok(h:Req("reforge", { item = sword, affix = "FLAME" }).ok, "to very rare opens slot 2")
    h:Req("upgradeTo", { item = sword, target = 20 })
    local s = h:State(sword)
    T.eq(s.level, 20)
    T.eq(s.baseEnchant, 1, "own enchantment detected")
    T.eq(h:Statuses(sword), { "EG_AFX_FLAME_1", "EG_ENCH_2", "EG_FH_5" }, "statuses live on the weapon")
    T.eq(h:Statuses(h.host), {}, "nothing on the character while unequipped")
    h:Equip(h.host, "MAIN", sword)
    T.eq(h:Statuses(h.host), { "EG_WIELDER" }, "wielder status grants the first-hit passives")
    h:Unequip(h.host, "MAIN")
    T.eq(h:Statuses(h.host), {})
    T.eq(h:Statuses(sword), { "EG_AFX_FLAME_1", "EG_ENCH_2", "EG_FH_5" }, "weapon statuses stay")

    local plus3 = h:Item(h.host, "longsword3")
    h:Req("upgradeTo", { item = plus3, target = 5 })
    T.eq(h:Statuses(plus3), { "EG_FH_1" }, "+3 weapon: no extra enchantment, first hit +1")
    h:Clean()
end
