-- Save/load: state, effects, names and colours are restored without duplicates; one-time rewards stay paid.
return function(T)
    local h = T.New({ level = "WLD_Main_A" })
    h:Tech(4)
    h:Rich()
    local mail = h:Item(h.host, "chainmail")
    h:Req("upgradeTo", { item = mail, target = 5 })
    h:Req("reforge", { item = mail, affix = "VITALITY" })
    h:Req("upgradeTo", { item = mail, target = 10 })
    h:Equip(h.host, "BODY", mail)
    local bundle = h:Bundle()
    local kits = h:Count(h.host, "kit")

    h:Reload()
    T.eq(h:State(mail).level, 10, "level kept")
    T.eq(h:Statuses(h.host), { "EG_AFX_VITALITY_1_BODY", "EG_MS_BODY_10_BODY" }, "effects without duplicates")
    local handle = h.w:E(mail).handle
    T.eq(h.w.loca.server[handle], "Chain Mail +10", "server re-registered the name")
    T.eq(h.w.loca.client[handle], "Chain Mail +10", "client received the name")
    T.eq(h.w:E(mail).rarityValue, 1, "colour kept")
    T.eq(h:Bundle(), bundle, "region reward not paid twice")
    T.eq(h:Count(h.host, "kit"), kits, "starter kit not given twice")

    h:Reload()
    T.eq(h:Statuses(h.host), { "EG_AFX_VITALITY_1_BODY", "EG_MS_BODY_10_BODY" }, "second load")
    h:Clean()
end
