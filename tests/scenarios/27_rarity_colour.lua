-- Rarity colour of the instance: Value.Rarity on the 0..4 scale plus the Health redraw trick.
return function(T)
    local h = T.New()
    h:Tech(4)
    h:Rich()
    local mail, other = h:Item(h.host, "chainmail"), h:Item(h.host, "chainmail")
    h:Req("upgradeTo", { item = mail, target = 5 })
    T.eq(h.w:E(mail).rarityValue, 0, "unchanged before reforging")
    h:Req("reforge", { item = mail, affix = "VITALITY" })
    local e = h.w:E(mail)
    T.eq(e.rarityValue, 1, "uncommon = 1 on the engine scale")
    T.ok(e.health, "Health component added for the redraw")
    local value, health = false, false
    for _, r in ipairs(h.w.replicated) do
        if r.guid == mail and r.name == "Value" then value = true end
        if r.guid == mail and r.name == "Health" then health = true end
    end
    T.ok(value and health, "Value and Health replicated")
    T.eq(e.clientRarity, 1, "clients were told")
    T.eq(h.w:E(other).rarityValue, 0, "the other copy keeps its colour")
    h:Req("reforge", { item = mail })
    T.eq(h.w:E(mail).rarityValue, 2, "rare = 2")

    local amulet = h:Item(h.host, "amulet") -- uncommon by nature
    h:Upgrade(amulet, 1)
    T.eq(h.w:E(amulet).rarityValue, 1)
    T.eq(h.w:E(amulet).health, nil, "only items whose rarity the forge raised")

    h.w:E(mail).rarityValue = 0
    h:Reload()
    T.eq(h.w:E(mail).rarityValue, 2, "written again on load")
    local function writes()
        local n = 0
        for _, r in ipairs(h.w.replicated) do
            if r.guid == mail and r.name == "Value" then n = n + 1 end
        end
        return n
    end
    local before = writes()
    h:Advance(3000)
    T.ok(writes() > before, "sent again after 3 s")

    h:Console("server", "eg_cleanup")
    T.eq(h.w:E(mail).rarityValue, 0, "cleanup restores the natural colour")

    local h2 = T.New({ config = { ExperimentalRarityColor = false } })
    h2:Rich()
    local m2 = h2:Item(h2.host, "chainmail")
    h2:Req("upgradeTo", { item = m2, target = 5 })
    h2:Req("reforge", { item = m2, affix = "VITALITY" })
    T.eq(h2.w:E(m2).rarityValue, 0, "disabled by the setting")
    local h3 = T.New({ config = { RarityColorRefresh = false } })
    h3:Rich()
    local m3 = h3:Item(h3.host, "chainmail")
    h3:Req("upgradeTo", { item = m3, target = 5 })
    h3:Req("reforge", { item = m3, affix = "VITALITY" })
    T.eq(h3.w:E(m3).rarityValue, 1)
    T.eq(h3.w:E(m3).health, nil, "no Health trick when disabled")
    h:Clean()
    h2:Clean()
    h3:Clean()
end
