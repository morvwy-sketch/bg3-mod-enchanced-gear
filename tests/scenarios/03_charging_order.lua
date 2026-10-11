-- Resources are taken from the acting character first, then from the rest of the party;
-- MaterialScope "character" uses only the acting character.
return function(T)
    local h = T.New()
    local sword = h:Item(h.host, "longsword")
    local scrap = h:Count(h.host, "scrap")
    h:Give(h.comp, { scrap = 10, gold = 100 })
    h:Give(h.host, { gold = 10 })
    h:Upgrade(sword) -- 1 scrap, 20 gold
    T.eq(h:Count(h.host, "scrap"), scrap - 1, "scrap from the acting character")
    T.eq(h:Count(h.host, "gold"), 0, "acting character's gold first")
    T.eq(h:Count(h.comp, "gold"), 90, "the rest from the companion")
    T.eq(h:Count(h.comp, "scrap"), 10, "companion scrap untouched")

    local h2 = T.New({ config = { MaterialScope = "character" } })
    local s2 = h2:Item(h2.host, "longsword")
    h2:Give(h2.comp, { scrap = 50, gold = 1000 })
    local r = h2:Req("upgrade", { item = s2 })
    T.eq(r.reason, "resources", "companion gold is not used")
    T.eq(h2:Count(h2.comp, "gold"), 1000, "nothing taken")
    local r2 = h2:Req("upgrade", { item = s2, actor = h2.comp })
    T.ok(r2.ok, "the companion can pay for itself")
    T.eq(h2:Count(h2.comp, "gold"), 980, "charged from the companion")
    h:Clean()
    h2:Clean()
end
