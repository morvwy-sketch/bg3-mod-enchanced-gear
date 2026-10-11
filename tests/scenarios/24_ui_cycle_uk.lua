-- Full cycle through the forge window in Ukrainian: kit, list, card, upgrade, waiting state, reforge, salvage.
return function(T)
    local h = T.New({ lang = "uk" })
    h:Tech(4)
    h:Rich()
    local mail = h:Item(h.host, "chainmail")
    h:Item(h.comp, "longsword")
    h:UseKit(h.host)
    local win = T.ok(h:Window(), "window created")
    T.eq(win.Open, true, "opened by the smithing kit")
    T.eq(h.w:E(h.host).statuses[T.Ids.Status.ForgeOpen], nil, "hidden status removed")
    local texts = h:Texts()
    T.has(texts, "Персонаж: Tav")
    T.has(texts, "Технологія кузні: Рівень IV (до +20)")
    T.has(texts, "Металобрухт: 503")
    T.has(texts, "(увесь загін)")
    T.has(texts, "Shadowheart", "items grouped by owner")
    T.has(texts, "Оберіть предмет зі списку ліворуч.")

    h:Click("Chain Mail", "selectable")
    texts = h:Texts()
    T.has(texts, "Нагрудна броня | Звичайна | Tav (в інвентарі)")
    T.has(texts, "Кування +0 з +20")
    T.has(texts, "Стеля +5, обмежує рідкість")
    T.has(texts, "Наступний рубіж +5: +5 до макс. здоров'я")
    T.has(texts, "Прогрес до +5: ще 5 крок(ів); бойовий ефект змінюється на рубежах.")
    T.has(texts, "Металобрухт: потрібно 1, є 503")
    T.has(texts, "Разом до +5: 9 брухту, 220 золота")

    local up = h:Exact("button", "Покращити")
    up.OnClick(up) -- the reply is not delivered yet
    T.eq(h:Exact("button", "Покращити").Disabled, true, "buttons wait for the server")
    T.has(h:Texts(), "Очікування сервера...")
    h:Pump()
    T.eq(h:Exact("button", "Покращити").Disabled, false, "enabled after the result")
    T.has(h:Texts(), "Chain Mail: кування +1.")
    T.eq(h:State(mail).level, 1)

    local handler = h.w.handlers.server[T.Ids.Channels.request]
    h.w.handlers.server[T.Ids.Channels.request] = function() end
    h:Press(h:Exact("button", "Покращити"))
    T.eq(h:Exact("button", "Покращити").Disabled, true, "no reply yet")
    h:Advance(5000)
    T.eq(h:Exact("button", "Покращити").Disabled, false, "unlocked after 5 s without a reply")
    h.w.handlers.server[T.Ids.Channels.request] = handler

    h:Press(h:Exact("button", "Покращити до +5"))
    T.eq(h:State(mail).level, 5)
    T.has(h:Texts(), "Chain Mail +5")
    T.has(h:Texts(), "+5 до макс. здоров'я")

    h:Press(h:Exact("button", "Рідкість"))
    T.has(h:Texts(), "Звичайна  >>  Незвичайна (стеля +10)")
    T.has(h:Texts(), "Відкриває слот властивості 1")
    T.eq(h:Exact("button", "Перекувати").Disabled, true, "choose a property first")
    T.has(h:Texts(), "Оберіть допустиму властивість.")
    h:Click("Життєва сила: +5 до макс. здоров'я", "selectable")
    h:Press(h:Exact("button", "Перекувати"))
    T.eq(h:State(mail).rarity, 2)
    T.eq(h:State(mail).affixes.slot1, "VITALITY")
    T.has(h:Texts(), "Chain Mail: рідкість Незвичайна.")
    T.has(h:Texts(), "Життєва сила (проста): +5 до макс. здоров'я")

    local dagger = h:Item(h.host, "dagger")
    h:Press(h:Exact("button", "Оновити"))
    h:Click("Dagger", "selectable")
    h:Press(h:Exact("button", "Розбір"))
    T.has(h:Texts(), "Ви отримаєте:")
    T.has(h:Texts(), "Предмет буде знищено.")
    h:Press(h:Exact("button", "Розібрати"))
    h:Press(h:Exact("button", "Скасувати"))
    T.ok(h.w:E(dagger), "cancelled")
    h:Press(h:Exact("button", "Розібрати"))
    h:Press(h:Exact("button", "Підтвердити розбір"))
    T.ok(not h.w:E(dagger), "salvaged")
    T.has(h:Texts(), "Dagger розібрано: 2 брухту.")

    local search = h:Elements("input")[1]
    search.Text = "MAIL"
    search.OnChange(search)
    T.has(h:Texts(), "Chain Mail +5")
    T.hasNot(h:Texts(), "Longsword", "search filters")
    search.Text = ""
    search.OnChange(search)
    local filter = h:Elements("combo")[1]
    filter.SelectedIndex = 2
    filter.OnChange(filter)
    T.has(h:Texts(), "Нічого не знайдено.", "nothing equipped")
    filter.SelectedIndex = 0
    filter.OnChange(filter)

    local count = #h:Elements()
    h:Press(h:Exact("button", "Оновити"))
    h:Press(h:Exact("button", "Оновити"))
    T.eq(#h:Elements(), count, "content is not duplicated")
    h:Key("F7")
    T.eq(h:Window().Open, false, "F7 closes")
    h:Key("F7")
    T.eq(h:Window().Open, true, "F7 opens")
    T.eq(#h.w.windows, 1, "one window only")
    for _, t in ipairs(h:Texts()) do T.ok(T.U.IsFontSafe(t), "font-safe: " .. t) end
    h:Clean()
end
