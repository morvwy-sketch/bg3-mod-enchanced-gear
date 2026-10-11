-- Texts: both languages complete, font-safe, placeholders filled, generated loca consistent.
return function(T)
    local I, U = T.I18N, T.U
    for k in pairs(I.Strings.en) do T.ok(I.Strings.uk[k], "uk missing " .. k) end
    for k in pairs(I.Strings.uk) do T.ok(I.Strings.en[k], "en missing " .. k) end
    for _, lang in ipairs({ "uk", "en" }) do
        for k, v in pairs(I.Strings[lang]) do
            T.ok(v ~= "", lang .. " empty " .. k)
            T.ok(U.IsFontSafe(v), lang .. " not font-safe: " .. k)
        end
        I.SetLanguage(lang)
        for k in pairs(I.Strings.en) do
            T.ok(not I.T(k, 1, 2, 3, 4):find("{%d}"), "placeholder left in " .. k)
        end
        for _, p in ipairs(T.R.Profiles) do
            for _, m in ipairs(T.R.Milestones) do
                local s = I.Atoms(T.L.MilestoneAtoms(p, m, 0))
                T.ok(s ~= "" and U.IsFontSafe(s), "effect text " .. p .. m)
            end
        end
        for _, a in ipairs(T.R.Affixes) do
            for tier = 1, 3 do T.ok(U.IsFontSafe(I.AffixDescription(a.id, tier)), a.id) end
        end
    end
    I.SetLanguage("uk")
    T.eq(I.Bundle({ scrap = 1, ingot = 3, core = 5, gold = 2 }), "1 брухт, 3 злитки, 5 ядер майстра, 2 золота")
    T.eq(I.CountedL("uk", "ingot", 11), "11 злитків")
    T.eq(I.CountedL("uk", "ingot", 21), "21 злиток")
    T.eq(I.CountedL("uk", "ingot", 22), "22 злитки")
    T.eq(I.Atom({ "Save", "Wisdom", 1 }), "+1 до рятівних кидків Мудрості")
    T.eq(I.Reason("needTech", { 3 }), "Потрібна технологія кузні рівня III.")
    I.SetLanguage("en")
    T.eq(I.Bundle({ ingot = 1, core = 2 }), "1 ingot, 2 master cores")
    T.eq(U.FontSafe("Кільчастий — обладунок’s → «x»"), "Кільчастий - обладунок's -> \"x\"")

    local function handles(lang)
        local f = assert(io.open(T.root .. "/mod/Localization/" .. lang .. "/EnhancedGear.xml"))
        local set, n = {}, 0
        for h, text in f:read("a"):gmatch('contentuid="([^"]+)" version="1">(.-)</content>') do
            set[h] = text
            n = n + 1
        end
        f:close()
        return set, n
    end
    local en, nEn = handles("English")
    local uk, nUk = handles("Ukrainian")
    T.eq(nEn, nUk, "same number of strings")
    for h in pairs(en) do T.ok(uk[h], "uk loca missing " .. h) end
    T.eq(en[U.Handle("lang.marker")], "en")
    T.eq(uk[U.Handle("lang.marker")], "uk")
    for _, file in ipairs({ "Stats/Generated/Data/EG_Statuses.txt", "Stats/Generated/Data/EG_Passives.txt",
        "RootTemplates/_merged.lsx" }) do
        local f = assert(io.open(T.root .. "/mod/Public/EnhancedGear/" .. file))
        for h in f:read("a"):gmatch("(h%x+g%x+g%x+g%x+g%x+)") do T.ok(en[h], file .. " uses a missing handle " .. h) end
        f:close()
    end
end
