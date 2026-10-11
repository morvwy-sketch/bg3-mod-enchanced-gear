-- Material sources: starter kit and region rewards once, technology never decreases, bosses once,
-- corpses only of hostile non-party non-summon enemies.
return function(T)
    local h = T.New({ level = "TUT_Avernus_C" })
    T.eq(h:Count(h.host, "kit"), 1, "starter kit")
    T.eq(h:Count(h.host, "scrap"), 3 + 4, "starter scrap + prologue reward")
    T.eq(h:Count(h.host, "dust"), 1)
    T.eq(#h.w.notes, 2, "two notifications")
    T.has(h.w.notes[1].text .. h.w.notes[2].text, "Forge:")

    local function enter(level)
        h.w.p.level = level
        h.w:QueueOsiris("LevelGameplayStarted", level, 0)
        h:Pump()
    end
    enter("SCL_Main_A")
    T.eq(h:Data().techTier, 2, "act II raises technology")
    local dust = h:Count(h.host, "dust")
    enter("WLD_Main_A")
    T.eq(h:Data().techTier, 2, "never decreases")
    enter("SCL_Main_A")
    T.eq(h:Count(h.host, "dust"), dust + 2, "act I paid once, act II not again")

    h.S.Loot.Random = function(a) if a then return a end return 0 end -- every roll succeeds, minimum amount
    local boss = h.w:AddChar({ name = "Boss", enemy = true, boss = true, level = 8 })
    local core = h:Count(h.host, "core")
    h.w:QueueOsiris("Died", boss)
    h:Pump()
    T.eq(h:Count(h.host, "core"), core + 1, "boss reward")
    T.eq(h.w:Count(boss, h.tpl.scrap), 1, "corpse loot: scrap")
    T.eq(h.w:Count(boss, h.tpl.dust), 1, "corpse loot: dust")
    T.eq(h.w:Count(boss, h.tpl.ingot), 1, "corpse loot: ingot from level 7")
    h.w:QueueOsiris("Died", boss)
    h:Pump()
    T.eq(h:Count(h.host, "core"), core + 1, "a boss pays once")
    T.eq(h.w:Count(boss, h.tpl.scrap), 1, "a corpse is filled once")

    local weak = h.w:AddChar({ name = "Goblin", enemy = true, level = 2 })
    local summon = h.w:AddChar({ name = "Imp", enemy = true, summon = true })
    local neutral = h.w:AddChar({ name = "Merchant", level = 9 })
    for _, c in ipairs({ weak, summon, neutral, h.comp }) do h.w:QueueOsiris("Died", c) end
    h:Pump()
    T.eq(h.w:Count(weak, h.tpl.scrap), 1, "weak enemy: scrap")
    T.eq(h.w:Count(weak, h.tpl.dust), 0, "dust only from level 3")
    T.eq(h.w:Count(summon, h.tpl.scrap), 0, "summons give nothing")
    T.eq(h.w:Count(neutral, h.tpl.scrap), 0, "non-hostile gives nothing")

    local h2 = T.New({ level = "WLD_Main_A", config = { RegionRewards = false, GrantStarterKit = false } })
    T.eq(h2:Count(h2.host, "scrap"), 0, "rewards disabled")
    T.eq(h2:Count(h2.host, "kit"), 0)
    h:Clean()
    h2:Clean()
end
