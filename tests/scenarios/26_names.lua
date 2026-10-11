-- "+N" names: per-instance handle registered on the server and the clients; cleanup restores.
return function(T)
    local h = T.New()
    h:Rich()
    local a, b = h:Item(h.host, "longsword"), h:Item(h.host, "longsword")
    h:Upgrade(a, 2)
    local handle = h.w:E(a).handle
    T.eq(handle, "hTPL_WPN_Longsword" .. T.Ids.NameSuffix .. a, "original handle + _EG_ + item guid")
    T.eq(h.w.loca.server[handle], "Longsword +2")
    T.eq(h.w.loca.client[handle], "Longsword +2", "clients received the string")
    T.eq(h.w:E(b).handle, "hTPL_WPN_Longsword", "the other copy keeps its name")
    T.eq(h:State(a).baseName, "Longsword")
    T.eq(h:State(a).nameHandle, "hTPL_WPN_Longsword")
    local replicated = false
    for _, r in ipairs(h.w.replicated) do
        if r.guid == a and r.name == "DisplayName" then replicated = true end
    end
    T.ok(replicated, "DisplayName replicated")

    h.w.loca.client[handle] = nil
    h.w:FireEvent("client", "GameStateChanged", { ToState = "Running" })
    h:Pump()
    T.eq(h.w.loca.client[handle], "Longsword +2", "the client asks for names after a load")

    h:Console("server", "eg_cleanup")
    T.eq(h.w:E(a).handle, "hTPL_WPN_Longsword", "cleanup restores the original name")
    T.eq(h:State(a).level, 2, "cleanup keeps the item data")
    h:Console("server", "eg_resync")
    T.eq(h.w:E(a).handle, handle, "resync renames again")

    local h2 = T.New({ config = { ExperimentalRename = false } })
    h2:Rich()
    local c = h2:Item(h2.host, "longsword")
    h2:Upgrade(c, 1)
    T.eq(h2.w:E(c).handle, "hTPL_WPN_Longsword", "renaming disabled")
    h:Clean()
    h2:Clean()
end
