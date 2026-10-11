-- Status catalog completeness: every status the logic can request exists (and in the generated Stats).
return function(T)
    local L, E, R = T.L, T.E, T.R
    local cat = E.Build()
    T.eq(#cat.statuses, 301, "statuses")
    T.eq(#cat.passives, 7, "passives")

    local produced, combos = {}, 0
    local function check(state)
        for _, id in ipairs(E.Produced(state)) do
            T.ok(cat.byId[id], "missing status " .. id)
            produced[id] = true
        end
        combos = combos + 1
    end
    for _, profile in ipairs(R.Profiles) do
        local sets = { {} }
        for _, a in ipairs(L.AllowedAffixes({ profile = profile, affixes = {} }, "slot1")) do
            sets[#sets + 1] = { slot1 = a }
            for _, b in ipairs(L.AllowedAffixes({ profile = profile, affixes = { slot1 = a } }, "slot2")) do
                sets[#sets + 1] = { slot1 = a, slot2 = b }
            end
            sets[#sets + 1] = { slot2 = a }
        end
        local enchants = profile == "weapon" and { 0, 1, 2, 3 } or { 0 }
        for level = 0, 20 do
            for rarity = 1, 5 do
                for _, base in ipairs(enchants) do
                    for _, affixes in ipairs(sets) do
                        check({ level = level, rarity = rarity, baseRarity = 1, profile = profile, affixes = affixes,
                            spent = {}, baseEnchant = base })
                    end
                end
            end
        end
    end
    T.ok(combos > 10000, "more than 10 000 combinations, got " .. combos)
    for _, s in ipairs(cat.statuses) do
        if s.kind ~= "open" then T.ok(produced[s.id], "status never used: " .. s.id) end
    end

    local f = assert(io.open(T.root .. "/mod/Public/EnhancedGear/Stats/Generated/Data/EG_Statuses.txt"))
    local text = f:read("a")
    f:close()
    local generated = {}
    for id in text:gmatch('new entry "([^"]+)"') do generated[id] = true end
    for _, s in ipairs(cat.statuses) do T.ok(generated[s.id], "not generated: " .. s.id .. " (run tools/generate.lua)") end
    T.eq(T.U.Count(generated), #cat.statuses, "generated Stats match the catalog")
end
