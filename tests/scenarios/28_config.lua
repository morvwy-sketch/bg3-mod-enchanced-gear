-- config.json: defaults written, broken files left alone, wrong types ignored, key migration, overrides.
return function(T)
    local path = "EnhancedGear/config.json"
    local h = T.New()
    local cfg = T.J.decode(T.ok(h.w.p.files[path], "written on first run"))
    T.eq(cfg.ToggleKey, "F7")
    T.eq(cfg.ConfigVersion, 2)
    T.eq(cfg.DevTools, true)
    T.eq(cfg.MaterialScope, "party")
    T.eq(cfg.KillLootMultiplier, 1.0)

    local h2 = T.New({ configText = "{ broken" })
    T.eq(h2.w.p.files[path], "{ broken", "invalid JSON is not overwritten")
    T.eq(h2.S.Config.Get("ToggleKey"), "F7", "defaults apply")

    local h3 = T.New({ configText = '{"RequireForgeKit": "no", "MaterialScope": "galaxy", "KillLootMultiplier": 2.5,'
        .. ' "Foo": 1, "ConfigVersion": 2}' })
    T.eq(h3.S.Config.Get("RequireForgeKit"), true, "wrong type ignored")
    T.eq(h3.S.Config.Get("MaterialScope"), "party", "unknown value ignored")
    T.eq(h3.S.Config.Get("KillLootMultiplier"), 2.5)
    T.eq(h3.S.Config.Get("Foo"), nil, "unknown key ignored")

    local h4 = T.New({ configText = '{"ToggleKey": "F10", "ConfigVersion": 1}' })
    T.eq(h4.C.Config.Get("ToggleKey"), "F7", "0.1 config: F10 becomes F7")
    T.eq(T.J.decode(h4.w.p.files[path]).ToggleKey, "F7", "file updated")
    T.eq(T.J.decode(h4.w.p.files[path]).ConfigVersion, 2)
    local h5 = T.New({ configText = '{"ToggleKey": "TAB", "ConfigVersion": 2}' })
    T.eq(h5.C.Config.Get("ToggleKey"), "F7", "game keys are never taken")
    local h6 = T.New({ config = { ToggleKey = "F6" } })
    h6:Key("F7")
    T.eq(h6:Window(), nil, "F7 is free when another key is configured")
    h6:Key("F6")
    T.eq(h6:Window().Open, true, "custom key opens the forge")

    local h7 = T.New({ config = { TechTierOverride = 3, RequireForgeKit = false, GrantStarterKit = false } })
    T.eq(h7.S.Data.TechTier(), 3, "technology override")
    local sword = h7:Item(h7.host, "longsword")
    h7:Rich()
    T.ok(h7:Req("upgrade", { item = sword }).ok, "no kit needed when RequireForgeKit is false")
    T.eq(h7:Count(h7.host, "kit"), 0)
    for _, x in ipairs({ h, h2, h3, h4, h5, h6, h7 }) do x:Clean() end
end
