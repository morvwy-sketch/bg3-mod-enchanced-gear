-- A repeated request id is ignored; a stale window state is rejected.
return function(T)
    local h = T.New()
    h:Rich()
    local sword = h:Item(h.host, "longsword")
    local gold = h:Total("gold")
    h:Req("upgrade", { item = sword, id = "dup-1" })
    local results = 0
    for _, m in ipairs(h.w.inbox) do if m.op == "result" then results = results + 1 end end
    h:Req("upgrade", { item = sword, id = "dup-1" })
    local results2 = 0
    for _, m in ipairs(h.w.inbox) do if m.op == "result" then results2 = results2 + 1 end end
    T.eq(results2, results, "no reply to the repeated request")
    T.eq(h:State(sword).level, 1, "executed once")
    T.eq(gold - h:Total("gold"), 20, "charged once")
    local r = h:Req("upgrade", { item = sword, expect = { level = 0, rarity = 1 } })
    T.eq(r.reason, "stale", "the window saw an old state")
    T.eq(h:State(sword).level, 1)
    for i = 1, 130 do h:Req("smelt", { id = "filler-" .. i }) end -- every operation id is remembered
    T.ok(h:Req("upgrade", { item = sword, id = "dup-1" }).ok, "old ids are forgotten after 128 requests")
    h:Clean()
end
