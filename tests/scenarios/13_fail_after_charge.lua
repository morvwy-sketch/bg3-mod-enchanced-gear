-- A failure after payment completes the operation (paid = delivered) without charging twice.
return function(T)
    local h = T.New()
    h:Rich()
    local sword = h:Item(h.host, "longsword")
    local before = h:Bundle()
    h.w.fail.Replicate = { n = 1 } -- the rename after payment fails once
    local r = h:Req("upgrade", { item = sword })
    T.ok(r.ok, "recovered operation reported as done")
    T.eq(h:State(sword).level, 1, "upgrade completed by recovery")
    T.eq(before.gold - h:Bundle().gold, 20, "charged once")
    T.eq(h:Data().journal, nil)
    T.ok(#h.w.errors >= 1, "logged")
    h.w.errors = {}

    local target = h:State(sword)
    target.level = 2
    h.S.Data.Update(function(d)
        d.journal = { op = "upgrade", stage = "charged", item = sword, actor = h.host, charges = {}, newState = target }
    end)
    h:Reload()
    T.eq(h:State(sword).level, 2, "charged journal completed on load")
    T.eq(h:Data().journal, nil)

    h:Tech(2)
    h.S.Data.Update(function(d)
        d.journal = { op = "smelt", stage = "charged", actor = h.host, charges = {}, output = { ingot = 1 } }
    end)
    local ingots = h:Count(h.host, "ingot")
    h:Reload()
    T.eq(h:Count(h.host, "ingot"), ingots + 1, "paid smelting delivered on load")
    h:Clean()
end
