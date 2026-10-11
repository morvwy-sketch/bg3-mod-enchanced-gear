-- Texts of the forge window and of the game data (item, status and passive names) in uk and en.
-- Only Latin and Cyrillic: the Script Extender IMGUI font has no other glyphs (no long dashes,
-- arrows or typographic apostrophes). tests/scenarios check every string in both languages.
EG = EG or {}
local U = EG.Util
local R = EG.Rules
local I = {}

I.Languages = { "uk", "en" }
I.Lang = "en"

local uk, en = {}, {}
I.Strings = { uk = uk, en = en }

local function add(key, ukText, enText)
    uk[key] = ukText
    en[key] = enText
end

---------------------------------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------------------------------
add("rarity.1", "Звичайна", "Common")
add("rarity.2", "Незвичайна", "Uncommon")
add("rarity.3", "Рідкісна", "Rare")
add("rarity.4", "Дуже рідкісна", "Very Rare")
add("rarity.5", "Легендарна", "Legendary")

add("profile.weapon", "Зброя", "Weapon")
add("profile.focus", "Магічний фокус", "Spellcasting Focus")
add("profile.body", "Нагрудна броня", "Body Armour")
add("profile.shield", "Щит", "Shield")
add("profile.helmet", "Головний убір", "Headwear")
add("profile.gloves", "Рукавиці", "Gloves")
add("profile.boots", "Чоботи", "Boots")
add("profile.cloak", "Плащ", "Cloak")
add("profile.amulet", "Амулет", "Amulet")
add("profile.ring", "Перстень", "Ring")

add("mat.scrap", "Металобрухт", "Scrap Metal")
add("mat.dust", "Магічний пил", "Arcane Dust")
add("mat.ingot", "Очищений злиток", "Refined Ingot")
add("mat.core", "Ядро майстра", "Master Core")
add("mat.gold", "Золото", "Gold")
add("mat.kit", "Ковальський набір", "Smithing Kit")

-- Counted forms: uk one / few / many, en one / many.
I.Counted = {
    uk = {
        scrap = { "брухт", "брухту", "брухту" },
        dust = { "пил", "пилу", "пилу" },
        ingot = { "злиток", "злитки", "злитків" },
        core = { "ядро майстра", "ядра майстра", "ядер майстра" },
        gold = { "золота", "золота", "золота" },
        kit = { "ковальський набір", "ковальські набори", "ковальських наборів" },
    },
    en = {
        scrap = { "scrap", "scrap" },
        dust = { "dust", "dust" },
        ingot = { "ingot", "ingots" },
        core = { "master core", "master cores" },
        gold = { "gold", "gold" },
        kit = { "smithing kit", "smithing kits" },
    },
}

add("affix.FLAME", "Полум'я", "Flame")
add("affix.FROST", "Мороз", "Frost")
add("affix.STORM", "Буря", "Storm")
add("affix.VITALITY", "Життєва сила", "Vitality")
add("affix.RESIST_FIRE", "Захист від вогню", "Fire Ward")
add("affix.RESIST_COLD", "Захист від холоду", "Cold Ward")
add("affix.RESIST_LIGHTNING", "Захист від блискавки", "Lightning Ward")
add("affix.RESIST_POISON", "Захист від отрути", "Poison Ward")
add("affix.AGILITY", "Спритність", "Agility")
add("affix.VIGILANCE", "Пильність", "Vigilance")
add("affix.FOCUS", "Зосередженість", "Focus")
add("affixTier.1", "проста", "basic")
add("affixTier.2", "посилена", "enhanced")
add("affixTier.3", "майстерна", "masterwork")

add("ability.Strength", "Сили", "Strength")
add("ability.Dexterity", "Спритності", "Dexterity")
add("ability.Constitution", "Статури", "Constitution")
add("ability.Intelligence", "Інтелекту", "Intelligence")
add("ability.Wisdom", "Мудрості", "Wisdom")
add("ability.Charisma", "Харизми", "Charisma")

add("skill.Perception", "Сприйняття", "Perception")
add("skill.Athletics", "Атлетика", "Athletics")
add("skill.SleightOfHand", "Спритність рук", "Sleight of Hand")
add("skill.Stealth", "Скритність", "Stealth")
add("skill.Acrobatics", "Акробатика", "Acrobatics")
add("skill.Insight", "Проникливість", "Insight")

-- Damage types: "with" form (шкода вогнем) and "to" form (опір вогню).
add("dmgWith.Fire", "вогнем", "fire")
add("dmgWith.Cold", "холодом", "cold")
add("dmgWith.Lightning", "блискавкою", "lightning")
add("dmgWith.Poison", "отрутою", "poison")
add("dmgTo.Fire", "вогню", "fire")
add("dmgTo.Cold", "холоду", "cold")
add("dmgTo.Lightning", "блискавці", "lightning")
add("dmgTo.Poison", "отруті", "poison")

---------------------------------------------------------------------------------------------------
-- Effect atoms
---------------------------------------------------------------------------------------------------
add("atom.AC", "+{1} РЗ", "+{1} AC")
add("atom.MaxHP", "+{1} до макс. здоров'я", "+{1} maximum hit points")
add("atom.Save", "+{2} до рятівних кидків {1}", "+{2} to {1} saving throws")
add("atom.Skill", "+{2} {1}", "+{2} {1}")
add("atom.Initiative", "+{1} до ініціативи", "+{1} initiative")
add("atom.Movement", "+{1} м руху", "+{1} m movement speed")
add("atom.SpellAttack", "+{1} до кидків атаки заклинанням", "+{1} to spell attack rolls")
add("atom.SpellDC", "+{1} до складності порятунку від заклинань", "+{1} spell save DC")
add("atom.ReduceAll", "уся отримана шкода -{1}", "all damage taken reduced by {1}")
add("atom.Reduce", "шкода {1} -{2}", "{1} damage taken reduced by {2}")
add("atom.Resist", "опір {1}", "resistance to {1} damage")
add("atom.WeaponDamage", "+{1} шкоди {2}", "+{1} {2} damage")
add("atom.Enchant", "зачарування +{1} (атака і шкода)", "enchantment +{1} (attack and damage)")
add("atom.FirstHit", "+{1} шкоди при першому влучанні цією зброєю за хід",
    "+{1} damage on the first hit with this weapon each turn")

---------------------------------------------------------------------------------------------------
-- Block reasons
---------------------------------------------------------------------------------------------------
add("reason.unsupported", "Цей тип предметів не підтримується.", "This item type is not supported.")
add("reason.story", "Сюжетні предмети захищені.", "Story items are protected.")
add("reason.max", "Досягнуто максимального кування.", "Maximum forging reached.")
add("reason.rarityCap", "Досягнуто стелі рідкості: підвищте рідкість, щоб продовжити.",
    "Rarity ceiling reached: raise the rarity to continue.")
add("reason.techCap", "Технологія кузні ще недостатня: просуньтеся сюжетом.",
    "Forge technology is not high enough yet: advance the story.")
add("reason.profileCap", "Цей предмет не можна кувати далі.", "This item cannot be forged any further.")
add("reason.resources", "Бракує матеріалів або золота.", "Not enough materials or gold.")
add("reason.legendary", "Предмет уже легендарний.", "The item is already legendary.")
add("reason.needTech", "Потрібна технологія кузні рівня {1}.", "Requires forge technology tier {1}.")
add("reason.equipped", "Спершу зніміть предмет.", "Unequip the item first.")
add("reason.foreign", "Предмети інших модів не можна розбирати.", "Items from other mods cannot be salvaged.")
add("reason.combat", "Кузнею не можна користуватися в бою.", "The forge cannot be used in combat.")
add("reason.noKit", "Потрібен ковальський набір у загоні.", "A Smithing Kit is required in the party.")
add("reason.stale", "Предмет змінився, вікно оновлено.", "The item has changed; the window was refreshed.")
add("reason.gone", "Предмет більше недоступний.", "The item is no longer available.")
add("reason.badAffix", "Оберіть допустиму властивість.", "Choose a valid property.")
add("reason.chargeFailed", "Не вдалося списати матеріали; нічого не змінено.",
    "Could not take the materials; nothing was changed.")
add("reason.profileLocked", "Профіль можна змінити лише до першого покращення.",
    "The profile can only be changed before the first upgrade.")
add("reason.notParty", "Персонаж не в загоні.", "The character is not in the party.")
add("reason.devTools", "Тестові дії вимкнено в налаштуваннях.", "Test actions are disabled in the settings.")
add("reason.error", "Помилка операції; нічого не змінено.", "The operation failed; nothing was changed.")

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
add("ui.title", "Кузня посиленого спорядження", "Enhanced Gear Forge")
add("ui.character", "Персонаж: {1}", "Character: {1}")
add("ui.tech", "Технологія кузні: Рівень {1} (до +{2})", "Forge technology: Tier {1} (up to +{2})")
add("ui.materials", "Матеріали", "Materials")
add("ui.scope.party", "(увесь загін)", "(whole party)")
add("ui.scope.character", "(лише цей персонаж)", "(this character only)")
add("ui.tab.forge", "Кузня", "Forge")
add("ui.tab.smelt", "Переплавка", "Smelting")
add("ui.tab.test", "Тест", "Test")
add("ui.filter.all", "Усі речі загону", "All party items")
add("ui.filter.character", "Лише цей персонаж", "This character only")
add("ui.filter.equipped", "Лише екіпіровані", "Equipped only")
add("ui.search", "Пошук предмета...", "Search item...")
add("ui.refresh", "Оновити", "Refresh")
add("ui.loading", "Завантаження...", "Loading...")
add("ui.empty", "Немає підтримуваного спорядження.", "No supported equipment.")
add("ui.noMatch", "Нічого не знайдено.", "Nothing found.")
add("ui.equipped", "екіпіровано", "equipped")
add("ui.inventory", "в інвентарі", "in inventory")
add("ui.select", "Оберіть предмет зі списку ліворуч.", "Select an item from the list on the left.")
add("ui.progress", "Кування +{1} з +{2}", "Forging +{1} of +{2}")
add("ui.milestones", "Рубежі:", "Milestones:")
add("ui.ceiling", "Стеля +{1}, обмежує {2}", "Ceiling +{1}, limited by {2}")
add("ui.ceilingMax", "Стеля +{1} (максимум)", "Ceiling +{1} (maximum)")
add("ui.limiter.tech", "технологія кузні", "forge technology")
add("ui.limiter.profile", "профіль предмета", "the item profile")
add("ui.limiter.rarity", "рідкість", "rarity")
add("ui.ownEnchant", "власне зачарування +{1}", "own enchantment +{1}")
add("ui.profile", "Профіль:", "Profile:")
add("ui.profileHint", "Профіль можна змінити лише до першого покращення.",
    "The profile can only be changed before the first upgrade.")
add("ui.effects", "Ефекти кування", "Forging effects")
add("ui.noEffects", "Поки немає ефектів: перший рубіж +5.", "No effects yet: the first milestone is +5.")
add("ui.nextMilestone", "Наступний рубіж +{1}: {2}", "Next milestone +{1}: {2}")
add("ui.effectsHint", "Ефекти діють, поки предмет екіпіровано.", "Effects apply while the item is equipped.")
add("ui.affixEffect", "{1} ({2}): {3}", "{1} ({2}): {3}")
add("ui.act.upgrade", "Покращення", "Upgrade")
add("ui.act.rarity", "Рідкість", "Rarity")
add("ui.act.salvage", "Розбір", "Salvage")
add("ui.upLine", "Кування +{1}  >>  +{2}", "Forging +{1}  >>  +{2}")
add("ui.newEffect", "Новий ефект: {1}", "New effect: {1}")
add("ui.progressTo", "Прогрес до +{1}: ще {2} крок(ів); бойовий ефект змінюється на рубежах.",
    "Progress to +{1}: {2} more step(s); combat effects change at milestones.")
add("ui.cost", "Вартість:", "Cost:")
add("ui.costLine", "{1}: потрібно {2}, є {3}", "{1}: need {2}, have {3}")
add("ui.upgrade", "Покращити", "Upgrade")
add("ui.upgradeTo", "Покращити до +{1}", "Upgrade to +{1}")
add("ui.totalTo", "Разом до +{1}: {2}", "Total to +{1}: {2}")
add("ui.rarityLine", "{1}  >>  {2} (стеля +{3})", "{1}  >>  {2} (ceiling +{3})")
add("ui.opensSlot", "Відкриває слот властивості {1}", "Opens property slot {1}")
add("ui.strengthens", "Наявні властивості посилюються", "Existing properties get stronger")
add("ui.chooseAffix", "Оберіть властивість:", "Choose a property:")
add("ui.affixChoice", "{1}: {2}", "{1}: {2}")
add("ui.reforge", "Перекувати", "Reforge")
add("ui.salvageGet", "Ви отримаєте:", "You will receive:")
add("ui.salvageRefund", "(включно з поверненням вкладених матеріалів)", "(including a refund of invested materials)")
add("ui.salvageWarn", "Предмет буде знищено.", "The item will be destroyed.")
add("ui.salvage", "Розібрати", "Salvage")
add("ui.salvageConfirm", "Підтвердити розбір", "Confirm salvage")
add("ui.cancel", "Скасувати", "Cancel")
add("ui.waiting", "Очікування сервера...", "Waiting for the server...")
add("ui.res.upgrade", "{1}: кування +{2}.", "{1}: forging +{2}.")
add("ui.res.upgradePartial", "{1}: кування +{2}. Далі бракує матеріалів або золота.",
    "{1}: forging +{2}. Not enough materials or gold to continue.")
add("ui.res.reforge", "{1}: рідкість {2}.", "{1}: rarity {2}.")
add("ui.res.salvage", "{1} розібрано: {2}.", "{1} salvaged: {2}.")
add("ui.res.smelt", "Виплавлено: {1}.", "Smelted: {1}.")
add("ui.res.profile", "{1}: профіль {2}.", "{1}: profile {2}.")
add("ui.res.dev", "Готово.", "Done.")
add("ui.smelt.desc", "Переплавляє надлишок у цінніший матеріал.", "Smelts surplus into a more valuable material.")
add("ui.smelt.recipe", "Рецепт: {1} >> {2}", "Recipe: {1} >> {2}")
add("ui.smelt.button", "Виплавити злиток", "Smelt an ingot")
add("ui.smelt.tier", "Доступно з технології кузні {1}.", "Available from forge technology {1}.")
add("ui.test.hint", "Інструменти для тестування. Набір і стан поза боєм не потрібні.",
    "Testing tools. No kit or out-of-combat state required.")
add("ui.test.materials", "+20 брухту, +10 пилу, +5 злитків, +2 ядра", "+20 scrap, +10 dust, +5 ingots, +2 cores")
add("ui.test.gold", "+1000 золота", "+1000 gold")
add("ui.test.tier", "Технологія кузні:", "Forge technology:")
add("ui.test.tierButton", "{1} (+{2})", "{1} (+{2})")
add("ui.test.gear", "Видати тестове спорядження", "Give test equipment")
add("ui.test.kit", "Видати ковальський набір", "Give a smithing kit")
add("ui.test.resync", "Перерахувати всі ефекти", "Recalculate all effects")
add("ui.slot", "Слот {1}", "Slot {1}")

---------------------------------------------------------------------------------------------------
-- Game texts (generated into Localization/*.xml)
---------------------------------------------------------------------------------------------------
add("item.scrap.desc", "Уламки зброї та обладунків. Основний матеріал кузні для перших рівнів кування.",
    "Bits of broken weapons and armour. The forge's basic material for the early forging levels.")
add("item.dust.desc", "Залишки чарів, вилучені з магічних речей. Потрібен для кування з +6 і підвищення рідкості.",
    "Residue of enchantments drawn from magic items. Needed for forging from +6 and for raising rarity.")
add("item.ingot.desc", "Чистий метал для високих рівнів кування (з +11) і підвищення рідкості.",
    "Pure metal for the high forging levels (from +11) and for raising rarity.")
add("item.core.desc", "Рідкісне серце могутньої магії. Потрібне для кування +20 і Легендарної рідкості.",
    "The rare heart of powerful magic. Needed for forging +20 and for Legendary rarity.")
add("item.kit.desc", "Відкриває кузню посиленого спорядження поза боєм. Не витрачається. Кузню також відкриває клавіша F7.",
    "Opens the Enhanced Gear forge outside combat. Not consumed. The F7 key opens the forge too.")
add("status.ms.name", "Кування: {1} +{2}", "Forging: {1} +{2}")
add("status.afx.name", "Властивість кузні: {1} ({2})", "Forge property: {1} ({2})")
add("status.ench.name", "Кута зброя +{1}", "Forged Weapon +{1}")
add("status.ench.desc", "Зачарування +{1}: бонус до кидків атаки і шкоди цією зброєю. Зброя вважається магічною.",
    "Enchantment +{1}: bonus to attack and damage rolls with this weapon. The weapon counts as magical.")
add("status.fh.name", "Куте лезо: перше влучання +{1}", "Forged Edge: first hit +{1}")
add("status.fh.desc", "+{1} шкоди при першому влучанні цією зброєю за хід.",
    "+{1} damage on the first hit with this weapon each turn.")
add("status.wielder.name", "Майстерність кутої зброї", "Forged Weapon Mastery")
add("status.wielder.desc", "Раз за хід перше влучання кутою зброєю завдає додаткової шкоди того ж типу, що й зброя.",
    "Once per turn the first hit with a forged weapon deals extra damage of the weapon's type.")
add("status.open.name", "Кузня", "Forge")
add("status.open.desc", "Відкриває вікно кузні.", "Opens the forge window.")
add("status.whileEquipped", "Діє, поки предмет екіпіровано.", "Applies while the item is equipped.")
add("passive.fh.name", "Куте лезо", "Forged Edge")
add("passive.fh.desc", "Раз за хід: перше влучання зброєю з бонусом першого влучання +{1} завдає {1} додаткової шкоди того ж типу, що й зброя.",
    "Once per turn: the first hit with a weapon that has a first-hit bonus of +{1} deals {1} extra damage of the weapon's type.")
-- Present only in the loca file of the game language: lets the mod detect Ukrainian without engine settings.
add("lang.marker", "uk", "en")

add("note.region", "Кузня: знахідки регіону - {1}.", "Forge: regional finds - {1}.")
add("note.boss", "Кузня: трофеї переможеного боса - {1}.", "Forge: trophies from a defeated boss - {1}.")
add("note.starter", "Кузня: отримано ковальський набір і {1}. Використайте набір або натисніть {2}.",
    "Forge: received a smithing kit and {1}. Use the kit or press {2}.")

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------

function I.SetLanguage(lang)
    if I.Strings[lang] then I.Lang = lang end
    return I.Lang
end

function I.TL(lang, key, ...)
    local s = (I.Strings[lang] and I.Strings[lang][key]) or en[key] or key
    if select("#", ...) > 0 then s = U.Format(s, { ... }) end
    return s
end

function I.T(key, ...)
    return I.TL(I.Lang, key, ...)
end

function I.Has(key)
    return en[key] ~= nil
end

local function pluralIndex(lang, n)
    n = math.abs(math.floor(n))
    if lang == "uk" then
        if n % 10 == 1 and n % 100 ~= 11 then return 1 end
        if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 12 or n % 100 > 14) then return 2 end
        return 3
    end
    return n == 1 and 1 or 2
end

function I.CountedL(lang, mat, n)
    local forms = I.Counted[lang] and I.Counted[lang][mat] or I.Counted.en[mat]
    if not forms then return tostring(n) .. " " .. mat end
    return tostring(n) .. " " .. forms[pluralIndex(lang, n)]
end

function I.Counted_(mat, n) return I.CountedL(I.Lang, mat, n) end

local bundleOrder = { "kit", "scrap", "dust", "ingot", "core", "gold" }

-- "9 брухту, 2 пилу, 220 золота"
function I.BundleL(lang, bundle)
    local parts = {}
    for _, k in ipairs(bundleOrder) do
        local v = bundle and bundle[k]
        if v and v > 0 then parts[#parts + 1] = I.CountedL(lang, k, v) end
    end
    return table.concat(parts, ", ")
end

function I.Bundle(bundle) return I.BundleL(I.Lang, bundle) end

local function num(v)
    if math.type(v) == "float" and v == math.floor(v) then return tostring(math.floor(v)) end
    return tostring(v)
end

function I.AtomL(lang, atom)
    local kind = atom[1]
    local T = function(key, ...) return I.TL(lang, key, ...) end
    if kind == "Save" then
        return T("atom.Save", T("ability." .. atom[2]), num(atom[3]))
    elseif kind == "Skill" then
        return T("atom.Skill", T("skill." .. atom[2]), num(atom[3]))
    elseif kind == "Reduce" then
        return T("atom.Reduce", T("dmgWith." .. atom[2]), num(atom[3]))
    elseif kind == "Resist" then
        return T("atom.Resist", T("dmgTo." .. atom[2]))
    elseif kind == "WeaponDamage" then
        return T("atom.WeaponDamage", atom[2], T("dmgWith." .. atom[3]))
    end
    return T("atom." .. kind, num(atom[2]))
end

function I.Atom(atom) return I.AtomL(I.Lang, atom) end

function I.AtomsL(lang, atoms, sep)
    local parts = {}
    for _, a in ipairs(atoms or {}) do parts[#parts + 1] = I.AtomL(lang, a) end
    return table.concat(parts, sep or "; ")
end

function I.Atoms(atoms, sep) return I.AtomsL(I.Lang, atoms, sep) end

function I.Reason(reason, params)
    if reason == "needTech" and params and params[1] then
        return I.T("reason.needTech", U.Roman(params[1]))
    end
    return I.T("reason." .. tostring(reason))
end

function I.Rarity(r) return I.T("rarity." .. tostring(r)) end
function I.Profile(p) return I.T("profile." .. tostring(p)) end
function I.Material(m) return I.T("mat." .. tostring(m)) end
function I.Affix(id) return I.T("affix." .. tostring(id)) end
function I.AffixTierName(t) return I.T("affixTier." .. tostring(t)) end

function I.AffixDescription(id, tier)
    local def = R.AffixById[id]
    if not def then return "" end
    return I.Atoms(def.tiers[tier])
end

-- "auto" -> uk when the game runs in Ukrainian.
function I.Resolve(setting, gameLanguage)
    if setting == "uk" or setting == "en" then return setting end
    local g = U.Lower(gameLanguage or "")
    if g:find("ukr", 1, true) or g == "uk" or g == "uk-ua" or g:find("україн", 1, true) then return "uk" end
    return "en"
end

-- Every string key of both languages, for tests.
function I.AllKeys()
    return U.Keys(en)
end

EG.I18N = I
return I
