# Enhanced Gear (Посилене спорядження)

Мод для Baldur's Gate 3 (Windows PC, Norbyte Script Extender): кування кожного окремого предмета від +0 до +20,
підвищення рідкості з вибором властивостей, розбір спорядження на матеріали і переплавка. Логіка на Lua,
вікно кузні — вбудований у Script Extender інтерфейс IMGUI.

- Повний опис мода: [docs/MOD_GUIDE.uk.md](docs/MOD_GUIDE.uk.md)
- Перевірка в грі: [docs/TESTING.uk.md](docs/TESTING.uk.md)
- Початковий план: [BG3_GEAR_PROGRESSION_PLAN.uk.md](BG3_GEAR_PROGRESSION_PLAN.uk.md)

> Стан: код зібрано і перевірено автоматично поза грою. У запущеній грі ця збірка ще не перевірялася
> (див. розділ 2 опису).

## Встановлення

1. Встановіть [Norbyte Script Extender](https://github.com/Norbyte/bg3se/releases) (`DWrite.dll` у теку `bin` гри).
2. Покладіть `EnhancedGear.pak` у `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`.
3. Увімкніть мод у BG3 Mod Manager і експортуйте порядок модів.
4. У грі: використайте Ковальський набір (видається на старті) або натисніть **F7**.

## Збірка

Потрібні Lua 5.4, .NET 8 SDK і Python 3 з Pillow (`pip install -r tools/requirements.txt`).

```sh
lua5.4 tests/run.lua        # тести на імітації гри
luacheck mod tools tests    # статичний аналіз
./tools/build.sh            # dist/EnhancedGear.pak і dist/EnhancedGear.zip
```

`tools/build.sh` сам завантажує LSLib (зафіксована версія) і збирає пакувальник `tools/LsTool`,
запускає генератор `tools/generate.lua` (Stats, шаблони предметів, локалізація, `meta.lsx` з правил у
`Shared/Rules.lua`), додає іконки і пакує все в `.pak`.

## Структура

| Шлях | Що там |
| --- | --- |
| `mod/Mods/EnhancedGear/ScriptExtender/Lua/Shared` | Баланс (`Rules.lua`), формули (`Logic.lua`), каталог статусів, тексти uk/en |
| `mod/Mods/EnhancedGear/ScriptExtender/Lua/Server` | Операції кузні з журналом, стан предметів, ефекти, нагороди |
| `mod/Mods/EnhancedGear/ScriptExtender/Lua/Client` | Вікно кузні і клавіша |
| `mod/Public`, `mod/Localization` | Згенеровані дані гри (не редагуйте вручну) |
| `tools/` | Генератор, збірка, іконки |
| `tests/` | Сценарії на імітації гри і Script Extender |
