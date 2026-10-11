-- If the item variable gets lost, the state is restored from the campaign index.
return function(T)
    local h = T.New()
    h:Rich()
    local sword = h:Item(h.host, "longsword")
    h:Upgrade(sword, 3)
    h.w:E(sword).vars = {}
    T.eq(h:State(sword).level, 3, "restored from the index")
    T.ok(h.w:E(sword).vars[T.Ids.UserVar], "written back to the item")
    local logged = false
    for _, line in ipairs(h.w.prints) do
        if line:find("from the campaign index", 1, true) then logged = true end
    end
    T.ok(logged, "restoration is logged")
    T.eq(h:Data().index[sword].level, 3, "index mirrors the state")
    h:Clean()
end
