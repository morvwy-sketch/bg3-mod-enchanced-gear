-- The forge window in English: F7, milestone preview, upgrade to +N, profile choice, smelting tab.
return function(T)
    local h = T.New({ lang = "en" })
    h:Tech(4)
    h:Rich()
    local mail = h:Item(h.host, "chainmail")
    local staff = h:Item(h.host, "staff")
    h:Key("F7")
    T.eq(h:Window().Open, true, "F7 opens the window")
    T.eq(h:Window().Label, "Enhanced Gear Forge")
    T.has(h:Texts(), "Forge technology: Tier IV (up to +20)")
    T.has(h:Texts(), "Character: Tav")

    h:Click("Chain Mail", "selectable")
    h:Upgrade(mail, 4)
    T.has(h:Texts(), "Forging +4  >>  +5")
    T.has(h:Texts(), "New effect: +5 maximum hit points")
    h:Press(h:Exact("button", "Upgrade to +5"))
    T.eq(h:State(mail).level, 5)
    T.has(h:Texts(), "Chain Mail: forging +5.")
    T.has(h:Texts(), "Rarity ceiling reached: raise the rarity to continue.")
    T.eq(h:Exact("button", "Upgrade", 2).Disabled, true, "the action button, not the tab")

    h:Click("Quarterstaff", "selectable")
    T.has(h:Texts(), "Profile:")
    local combo
    for _, c in ipairs(h:Elements("combo")) do
        if (c.Label or ""):find("profile", 1, true) then combo = c end
    end
    T.ok(combo, "profile choice shown")
    T.eq(combo.Options, { "Weapon", "Spellcasting Focus" })
    combo.SelectedIndex = 1
    combo.OnChange(combo)
    h:Pump()
    T.eq(h:State(staff).profile, "focus")
    T.has(h:Texts(), "Quarterstaff: profile Spellcasting Focus.")
    h:Upgrade(staff)
    T.hasNot(h:Texts(), "Profile:", "no choice after the first investment")

    T.has(h:Texts(), "Smelts surplus into a more valuable material.")
    T.has(h:Texts(), "Recipe: 6 scrap, 2 dust, 100 gold >> 1 ingot")
    local ingots = h:Count(h.host, "ingot")
    h:Press(h:Exact("button", "Smelt an ingot"))
    T.eq(h:Count(h.host, "ingot"), ingots + 1)
    T.has(h:Texts(), "Smelted: 1 ingot.")
    h:Clean()
end
