-- A failure while charging refunds everything already taken; a journal left in a save is finished on load.
return function(T)
    local h = T.New()
    local sword = h:Item(h.host, "longsword")
    h:Give(h.host, { gold = 100 })
    local before = h:Bundle()
    h.w.fail.TemplateRemoveFrom = { n = 2 } -- scrap goes through, gold fails
    local r = h:Req("upgrade", { item = sword })
    T.eq(r.ok, false)
    T.eq(r.reason, "chargeFailed")
    T.eq(h:Bundle(), before, "scrap refunded")
    T.eq(h:State(sword), nil, "item unchanged")
    T.eq(h:Data().journal, nil, "journal closed")
    T.ok(#h.w.errors >= 1, "the failure is logged")
    h.w.errors = {}
    T.ok(h:Req("upgrade", { item = sword }).ok, "the next attempt works")

    h.S.Data.Update(function(d)
        d.journal = { op = "upgrade", stage = "charging", actor = h.host,
            charges = { { char = h.host, res = "scrap", n = 2 } } }
    end)
    local scrap = h:Count(h.host, "scrap")
    h:Reload()
    T.eq(h:Count(h.host, "scrap"), scrap + 2, "charges refunded on load")
    T.eq(h:Data().journal, nil)
    h:Clean()
end
