#!/usr/bin/env lua5.4
-- Generates the data files of Enhanced Gear from the pure Lua rules and tools/data/vanilla_templates.json.
-- Run from any directory: lua5.4 tools/generate.lua. Output is byte-identical on every run.

local ROOT = ((arg and arg[0]) or "tools/generate.lua"):match("^(.*)[/\\][^/\\]*$") or "."
ROOT = ROOT .. "/.."
local SHARED = ROOT .. "/mod/Mods/EnhancedGear/ScriptExtender/Lua/Shared/"
local VANILLA_FILE = ROOT .. "/tools/data/vanilla_templates.json"
local LANGS = { "en", "uk" }
local LANG_FOLDER = { en = "English", uk = "Ukrainian" }
local META_DESCRIPTION = "Forge weapons and armour from +0 to +20 with scrap, dust, ingots and gold, raise their rarity, "
    .. "salvage or smelt materials; requires the Script Extender."

local Ids, U, E, I
local missing, outputs = {}, {}
local texts, textOrder, keyOfHandle = {}, {}, {}

local function fail(msg)
    io.stderr:write("generate.lua: error: ", msg, "\n")
    os.exit(1)
end

local function readFile(path)
    local f, err = io.open(path, "rb")
    if not f then fail(err) end
    local s = f:read("a")
    f:close()
    return s
end

local function output(path, content)
    outputs[#outputs + 1] = { path = path, content = content }
end

local function writeOutputs()
    for _, o in ipairs(outputs) do
        os.execute(("mkdir -p '%s'"):format(o.path:match("^(.*)/[^/]+$")))
        local f, err = io.open(o.path, "wb")
        if not f then fail(err) end
        f:write(o.content)
        f:close()
        print("wrote " .. o.path:sub(#ROOT + 2))
    end
end

local function isGuid(s)
    return type(s) == "string"
        and s:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function luaString(s)
    return '"' .. (s:gsub('[\\"]', "\\%0")) .. '"'
end

local XML_ESCAPE = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }
local function xml(s)
    return (tostring(s):gsub('[&<>"]', XML_ESCAPE))
end

-- Integers without a decimal point; other numbers in their shortest form (0.05, 0.1, 0.5).
local function num(v)
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%g", v)
end

local function indent(level, s)
    return string.rep("    ", level) .. s
end

local function attr(id, typ, value)
    return ('<attribute id="%s" type="%s" value="%s" />'):format(id, typ, xml(value))
end

-- Minimal JSON decoder (objects, arrays, strings, numbers, literals) for tools/data.
local function decodeJson(text)
    local pos = 1
    local function failAt(msg) error(msg .. " at byte " .. pos, 0) end
    local function skip() pos = text:find("[^ \t\r\n]", pos) or (#text + 1) end
    local ESCAPE = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

    local function str()
        pos = pos + 1
        local parts = {}
        while true do
            local c = text:sub(pos, pos)
            if c == "" then failAt("unterminated string") end
            if c == '"' then
                pos = pos + 1
                return table.concat(parts)
            elseif c == "\\" then
                local e = text:sub(pos + 1, pos + 1)
                if e == "u" then
                    local cp = tonumber(text:sub(pos + 2, pos + 5), 16)
                    if not cp then failAt("bad \\u escape") end
                    parts[#parts + 1] = utf8.char(cp)
                    pos = pos + 6
                elseif ESCAPE[e] then
                    parts[#parts + 1] = ESCAPE[e]
                    pos = pos + 2
                else
                    failAt("bad escape")
                end
            else
                parts[#parts + 1] = c
                pos = pos + 1
            end
        end
    end

    local function value()
        skip()
        local c = text:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local obj = {}
            skip()
            if text:sub(pos, pos) == "}" then
                pos = pos + 1
                return obj
            end
            while true do
                skip()
                if text:sub(pos, pos) ~= '"' then failAt("expected a string key") end
                local k = str()
                skip()
                if text:sub(pos, pos) ~= ":" then failAt("expected ':'") end
                pos = pos + 1
                obj[k] = value()
                skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d == "}" then return obj end
                if d ~= "," then failAt("expected ',' or '}'") end
            end
        elseif c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if text:sub(pos, pos) == "]" then
                pos = pos + 1
                return arr
            end
            while true do
                arr[#arr + 1] = value()
                skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d == "]" then return arr end
                if d ~= "," then failAt("expected ',' or ']'") end
            end
        elseif c == '"' then
            return str()
        elseif text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif text:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if not number then failAt("unexpected character") end
        pos = pos + #number
        return tonumber(number)
    end

    local result = value()
    skip()
    if pos <= #text then failAt("trailing data") end
    return result
end

local function loadShared()
    EG = {}
    local function loadModule(name) return dofile(SHARED .. name .. ".lua") end
    Ids = loadModule("Ids")
    U = loadModule("Util")
    loadModule("Rules")
    loadModule("Logic")
    E = loadModule("Effects")
    I = loadModule("I18N")
    -- Every text lookup of the generator goes through here, so a missing key is reported, not silently echoed.
    local rawTL = I.TL
    I.TL = function(lang, key, ...)
        local s = I.Strings[lang] and I.Strings[lang][key]
        if s == nil or s == "" then missing[#missing + 1] = lang .. ":" .. key end
        return rawTL(lang, key, ...)
    end
end

-- Vanilla refs: keys starting with "_" are comments and are skipped.
local function loadVanilla()
    local ok, data = pcall(decodeJson, readFile(VANILLA_FILE))
    if not ok then fail(VANILLA_FILE .. ": " .. tostring(data)) end
    if type(data) ~= "table" then fail(VANILLA_FILE .. ": top level must be an object") end
    local refs, keys = {}, {}
    for k, v in pairs(data) do
        if type(k) ~= "string" then fail(VANILLA_FILE .. ": top level must be an object") end
        if k:sub(1, 1) ~= "_" then
            if type(v) ~= "table" or type(v.name) ~= "string" or not isGuid(v.uuid) then
                fail("vanilla template '" .. k .. "' needs a name and a GUID uuid")
            end
            refs[k] = v
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    return refs, keys
end

local function checkItems(refs)
    if not isGuid(Ids.ModuleUUID) then fail("Ids.ModuleUUID is not a GUID") end
    if not isGuid(Ids.IconAtlas.uuid) then fail("Ids.IconAtlas.uuid is not a GUID") end
    local seenStats, seenTemplate = {}, {}
    for _, key in ipairs(Ids.ItemOrder) do
        local item = Ids.Items[key]
        if not item then fail("Ids.ItemOrder lists unknown item '" .. key .. "'") end
        if not refs[item.parent] then
            fail("item '" .. key .. "': unknown parent template key '" .. tostring(item.parent) .. "'")
        end
        if not isGuid(item.template) then fail("item '" .. key .. "': template is not a GUID") end
        if seenStats[item.stats] or seenTemplate[item.template] then
            fail("item '" .. key .. "': duplicate stats id or template")
        end
        seenStats[item.stats], seenTemplate[item.template] = true, true
    end
end

-- Localization: one entry per key, the handle is derived from the key (Util.Handle, same as at runtime).
local function addText(key, textFn)
    local t = {}
    for _, lang in ipairs(LANGS) do t[lang] = textFn(lang) end
    if texts[key] then
        for _, lang in ipairs(LANGS) do
            if texts[key][lang] ~= t[lang] then fail("key '" .. key .. "' gets different " .. lang .. " texts") end
        end
        return
    end
    local handle = U.Handle(key)
    if keyOfHandle[handle] then
        fail("duplicate handle " .. handle .. " for '" .. key .. "' and '" .. keyOfHandle[handle] .. "'")
    end
    keyOfHandle[handle] = key
    texts[key] = t
    textOrder[#textOrder + 1] = key
end

local function withWhile(lang, text)
    local whileEquipped = I.TL(lang, "status.whileEquipped")
    if text == "" then return whileEquipped end
    return text .. ". " .. whileEquipped
end

-- Localization key and text functions of a status; the description key is always key .. ".desc".
local function statusText(s)
    local kind = s.kind
    if kind == "ms" then
        return ("status.ms.%s.%d"):format(s.profile, s.milestone),
            function(lang) return I.TL(lang, "status.ms.name", I.TL(lang, "profile." .. s.profile), s.milestone) end,
            function(lang) return withWhile(lang, I.AtomsL(lang, s.atoms)) end
    elseif kind == "afx" then
        return ("status.afx.%s.%d"):format(s.affix, s.tier),
            function(lang)
                return I.TL(lang, "status.afx.name", I.TL(lang, "affix." .. s.affix), I.TL(lang, "affixTier." .. s.tier))
            end,
            function(lang)
                local text = I.AtomsL(lang, s.atoms)
                if s.target == "wearer" then return withWhile(lang, text) end
                return text
            end
    elseif kind == "ench" or kind == "fh" then
        return ("status.%s.%d"):format(kind, s.n),
            function(lang) return I.TL(lang, "status." .. kind .. ".name", s.n) end,
            function(lang) return I.TL(lang, "status." .. kind .. ".desc", s.n) end
    elseif kind == "wielder" or kind == "open" then
        return "status." .. kind,
            function(lang) return I.TL(lang, "status." .. kind .. ".name") end,
            function(lang) return I.TL(lang, "status." .. kind .. ".desc") end
    end
    fail("unknown status kind " .. tostring(kind))
end

local function registerTexts(cat)
    addText("lang.marker", function(lang) return I.TL(lang, "lang.marker") end)
    for _, key in ipairs(Ids.ItemOrder) do
        addText("item." .. key .. ".name", function(lang) return I.TL(lang, "mat." .. key) end)
        addText("item." .. key .. ".desc", function(lang) return I.TL(lang, "item." .. key .. ".desc") end)
    end
    for _, s in ipairs(cat.statuses) do
        local key, nameFn, descFn = statusText(s)
        addText(key, nameFn)
        addText(key .. ".desc", descFn)
    end
    for _, p in ipairs(cat.passives) do
        addText("passive.fh", function(lang) return I.TL(lang, "passive.fh.name") end)
        addText("passive.fh.desc." .. p.n, function(lang) return I.TL(lang, "passive.fh.desc", p.n) end)
    end
end

local function checkCoverage()
    for _, pair in ipairs({ { "en", "uk" }, { "uk", "en" } }) do
        for _, key in ipairs(U.Keys(I.Strings[pair[1]])) do
            local other = I.Strings[pair[2]][key]
            if other == nil or other == "" then missing[#missing + 1] = pair[2] .. ":" .. key end
        end
    end
    for _, key in ipairs(textOrder) do
        for _, lang in ipairs(LANGS) do
            if texts[key][lang] == "" then missing[#missing + 1] = lang .. ":" .. key end
        end
    end
    if #missing == 0 then return end
    local seen, uniq = {}, {}
    for _, m in ipairs(missing) do
        if not seen[m] then
            seen[m] = true
            uniq[#uniq + 1] = m
        end
    end
    table.sort(uniq)
    fail("missing translations: " .. table.concat(uniq, ", "))
end

local function vanillaRefsLua(refs, keys)
    local lines = {
        "-- Generated by tools/generate.lua from tools/data/vanilla_templates.json. Do not edit.",
        "EG = EG or {}",
        "",
        "local V = {",
    }
    for _, k in ipairs(keys) do
        local field = k:match("^[%a_][%w_]*$") and k or ("[" .. luaString(k) .. "]")
        lines[#lines + 1] = ("    %s = { name = %s, uuid = %s },"):format(
            field, luaString(refs[k].name), luaString(refs[k].uuid))
    end
    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "EG.VanillaRefs = V"
    lines[#lines + 1] = "return V"
    return table.concat(lines, "\n") .. "\n"
end

local function configJson()
    return ('{\n    "RequiredVersion": %d,\n    "ModTable": "%s",\n    "FeatureFlags": [\n        "Lua"\n    ]\n}\n')
        :format(Ids.RequiredSE, Ids.ModName)
end

local function metaLsx()
    local version64 = string.format("%d", Ids.Version64())
    local info = {
        attr("Author", "LSString", Ids.Author),
        attr("CharacterCreationLevelName", "FixedString", ""),
        attr("Description", "LSString", META_DESCRIPTION),
        attr("Folder", "LSString", Ids.ModName),
        attr("LobbyLevelName", "FixedString", ""),
        attr("MD5", "LSString", ""),
        attr("MainMenuBackgroundVideo", "FixedString", ""),
        attr("MenuLevelName", "FixedString", ""),
        attr("Name", "LSString", Ids.DisplayName),
        attr("NumPlayers", "uint8", 4),
        attr("PhotoBooth", "FixedString", ""),
        attr("StartupLevelName", "FixedString", ""),
        attr("Tags", "LSString", ""),
        attr("Type", "FixedString", "Add-on"),
        attr("UUID", "FixedString", Ids.ModuleUUID),
        attr("Version64", "int64", version64),
    }
    local lines = {
        '<?xml version="1.0" encoding="utf-8"?>',
        "<save>",
        indent(1, '<version major="4" minor="0" revision="9" build="331" />'),
        indent(1, '<region id="Config">'),
        indent(2, '<node id="root">'),
        indent(3, "<children>"),
        indent(4, '<node id="Dependencies" />'),
        indent(4, '<node id="ModuleInfo">'),
    }
    for _, a in ipairs(info) do lines[#lines + 1] = indent(5, a) end
    lines[#lines + 1] = indent(5, "<children>")
    lines[#lines + 1] = indent(6, '<node id="PublishVersion">')
    lines[#lines + 1] = indent(7, attr("Version64", "int64", version64))
    lines[#lines + 1] = indent(6, "</node>")
    lines[#lines + 1] = indent(6, '<node id="Scripts" />')
    lines[#lines + 1] = indent(6, '<node id="TargetModes">')
    lines[#lines + 1] = indent(7, "<children>")
    lines[#lines + 1] = indent(8, '<node id="Target">')
    lines[#lines + 1] = indent(9, attr("Object", "FixedString", "Story"))
    lines[#lines + 1] = indent(8, "</node>")
    lines[#lines + 1] = indent(7, "</children>")
    lines[#lines + 1] = indent(6, "</node>")
    lines[#lines + 1] = indent(5, "</children>")
    lines[#lines + 1] = indent(4, "</node>")
    lines[#lines + 1] = indent(3, "</children>")
    lines[#lines + 1] = indent(2, "</node>")
    lines[#lines + 1] = indent(1, "</region>")
    lines[#lines + 1] = "</save>"
    return table.concat(lines, "\n") .. "\n"
end

local function statusesTxt(cat)
    local blocks = {}
    for _, s in ipairs(cat.statuses) do
        local key = statusText(s)
        local lines = {
            'new entry "' .. s.id .. '"',
            'type "StatusData"',
            'data "StatusType" "BOOST"',
            'data "DisplayName" "' .. U.Handle(key) .. ';1"',
            'data "Description" "' .. U.Handle(key .. ".desc") .. ';1"',
            'data "Icon" "' .. s.icon .. '"',
            'data "StackId" "' .. s.id .. '"',
        }
        if s.boosts and s.boosts ~= "" then lines[#lines + 1] = 'data "Boosts" "' .. s.boosts .. '"' end
        if s.passives then lines[#lines + 1] = 'data "Passives" "' .. s.passives .. '"' end
        lines[#lines + 1] = 'data "StatusPropertyFlags" "' .. s.flags .. '"'
        blocks[#blocks + 1] = table.concat(lines, "\n")
    end
    return table.concat(blocks, "\n\n") .. "\n"
end

local function passivesTxt(cat)
    local blocks = {}
    for _, p in ipairs(cat.passives) do
        blocks[#blocks + 1] = table.concat({
            'new entry "' .. p.id .. '"',
            'type "PassiveData"',
            'data "DisplayName" "' .. U.Handle("passive.fh") .. ';1"',
            'data "Description" "' .. U.Handle("passive.fh.desc." .. p.n) .. ';1"',
            'data "Icon" "' .. Ids.Items.kit.icon .. '"',
            'data "Properties" "' .. p.properties .. '"',
            'data "StatsFunctorContext" "' .. p.context .. '"',
            'data "Conditions" "' .. p.conditions .. '"',
            'data "StatsFunctors" "' .. p.functors .. '"',
        }, "\n")
    end
    return table.concat(blocks, "\n\n") .. "\n"
end

local function objectsTxt()
    local blocks = {}
    for _, key in ipairs(Ids.ItemOrder) do
        local item = Ids.Items[key]
        local rarity = item.rare and "Rare" or (key == "kit" and "Uncommon" or "Common")
        blocks[#blocks + 1] = table.concat({
            'new entry "' .. item.stats .. '"',
            'type "Object"',
            'data "RootTemplate" "' .. item.template .. '"',
            'data "Weight" "' .. num(item.weight) .. '"',
            'data "ValueOverride" "' .. num(item.value) .. '"',
            'data "Rarity" "' .. rarity .. '"',
            'data "Priority" "1"',
            'data "MinAmount" "1"',
            'data "MaxAmount" "1"',
        }, "\n")
    end
    return table.concat(blocks, "\n\n") .. "\n"
end

local function templatesLsx(refs)
    local lines = {
        '<?xml version="1.0" encoding="utf-8"?>',
        "<save>",
        indent(1, '<version major="4" minor="0" revision="9" build="331" />'),
        indent(1, '<region id="Templates">'),
        indent(2, '<node id="Templates">'),
        indent(3, "<children>"),
    }
    for _, key in ipairs(Ids.ItemOrder) do
        local item = Ids.Items[key]
        local rows = {
            attr("MapKey", "FixedString", item.template),
            attr("Name", "LSString", item.stats),
            attr("LevelName", "FixedString", ""),
            attr("Type", "FixedString", "item"),
            attr("ParentTemplateId", "FixedString", refs[item.parent].uuid),
            attr("Stats", "FixedString", item.stats),
            ('<attribute id="DisplayName" type="TranslatedString" handle="%s" version="1" />')
                :format(U.Handle("item." .. key .. ".name")),
            ('<attribute id="Description" type="TranslatedString" handle="%s" version="1" />')
                :format(U.Handle("item." .. key .. ".desc")),
            attr("Icon", "FixedString", item.icon),
        }
        if item.stack then rows[#rows + 1] = attr("maxStackAmount", "int32", item.stack) end
        lines[#lines + 1] = indent(4, '<node id="GameObjects">')
        for _, r in ipairs(rows) do lines[#lines + 1] = indent(5, r) end
        if key == "kit" then
            local open = {
                attr("Animation", "FixedString", ""),
                attr("Conditions", "LSString", ""),
                attr("Consume", "bool", "False"),
                attr("IsHiddenStatus", "bool", "True"),
                attr("StatsId", "FixedString", Ids.Status.ForgeOpen),
                attr("StatusDuration", "int32", 1),
            }
            lines[#lines + 1] = indent(5, "<children>")
            lines[#lines + 1] = indent(6, '<node id="OnUsePeaceActions">')
            lines[#lines + 1] = indent(7, "<children>")
            lines[#lines + 1] = indent(8, '<node id="Action">')
            lines[#lines + 1] = indent(9, attr("ActionType", "int32", 7))
            lines[#lines + 1] = indent(9, "<children>")
            lines[#lines + 1] = indent(10, '<node id="Attributes">')
            for _, a in ipairs(open) do lines[#lines + 1] = indent(11, a) end
            lines[#lines + 1] = indent(10, "</node>")
            lines[#lines + 1] = indent(9, "</children>")
            lines[#lines + 1] = indent(8, "</node>")
            lines[#lines + 1] = indent(7, "</children>")
            lines[#lines + 1] = indent(6, "</node>")
            lines[#lines + 1] = indent(5, "</children>")
        end
        lines[#lines + 1] = indent(4, "</node>")
    end
    lines[#lines + 1] = indent(3, "</children>")
    lines[#lines + 1] = indent(2, "</node>")
    lines[#lines + 1] = indent(1, "</region>")
    lines[#lines + 1] = "</save>"
    return table.concat(lines, "\n") .. "\n"
end

local function locaXml(lang)
    local rows = {}
    for _, key in ipairs(textOrder) do
        rows[#rows + 1] = { handle = U.Handle(key), text = texts[key][lang] }
    end
    table.sort(rows, function(a, b) return a.handle < b.handle end)
    local lines = { '<?xml version="1.0" encoding="utf-8"?>', "<contentList>" }
    for _, r in ipairs(rows) do
        lines[#lines + 1] = ('    <content contentuid="%s" version="1">%s</content>'):format(r.handle, xml(r.text))
    end
    lines[#lines + 1] = "</contentList>"
    return table.concat(lines, "\n") .. "\n"
end

local function main()
    loadShared()
    local refs, refKeys = loadVanilla()
    checkItems(refs)
    local cat = E.Build()
    registerTexts(cat)
    checkCoverage()

    local modDir = ROOT .. "/mod/Mods/" .. Ids.ModName
    local pubDir = ROOT .. "/mod/Public/" .. Ids.ModName
    output(SHARED .. "VanillaRefs.lua", vanillaRefsLua(refs, refKeys))
    output(modDir .. "/ScriptExtender/Config.json", configJson())
    output(modDir .. "/meta.lsx", metaLsx())
    output(pubDir .. "/Stats/Generated/Data/EG_Statuses.txt", statusesTxt(cat))
    output(pubDir .. "/Stats/Generated/Data/EG_Passives.txt", passivesTxt(cat))
    output(pubDir .. "/Stats/Generated/Data/EG_Objects.txt", objectsTxt())
    output(pubDir .. "/RootTemplates/_merged.lsx", templatesLsx(refs))
    for _, lang in ipairs(LANGS) do
        output(ROOT .. "/mod/Localization/" .. LANG_FOLDER[lang] .. "/" .. Ids.ModName .. ".xml", locaXml(lang))
    end

    print(("generate.lua: %d statuses, %d passives, %d items, %d localization strings per language")
        :format(#cat.statuses, #cat.passives, #Ids.ItemOrder, #textOrder))
    writeOutputs()
end

local ok, err = pcall(main)
if not ok then fail(tostring(err)) end
