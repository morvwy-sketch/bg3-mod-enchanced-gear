-- Test harness: builds a simulated party, boots the real server and client bootstraps, and offers
-- helpers for requests, equipment, save/load and driving the forge window.
local T = {}

local root = (arg and arg[0] or "tests/run.lua"):match("^(.*)/tests/[^/]+$") or "."
T.root = root
T.modLua = root .. "/mod/Mods/EnhancedGear/ScriptExtender/Lua"
T.J = dofile(root .. "/tests/sim/json.lua")
T.World = dofile(root .. "/tests/sim/world.lua")

-- Pure shared modules, loaded once for the tests themselves (separate from the game contexts).
EG = {}
for _, f in ipairs({ "Ids", "Util", "Rules", "Logic", "Effects", "I18N", "Config", "VanillaRefs" }) do
    dofile(T.modLua .. "/Shared/" .. f .. ".lua")
end
T.EG = EG
T.Ids, T.U, T.R, T.L, T.E, T.I18N = EG.Ids, EG.Util, EG.Rules, EG.Logic, EG.Effects, EG.I18N

---------------------------------------------------------------------------------------------------
-- Assertions
---------------------------------------------------------------------------------------------------

local function show(v)
    if type(v) == "table" then
        local ok, s = pcall(T.J.encode, v)
        return ok and s or tostring(v)
    end
    return tostring(v)
end
T.show = show

function T.eq(actual, expected, msg)
    if not T.U.Equal(actual, expected) then
        error(string.format("%s: expected %s, got %s", msg or "mismatch", show(expected), show(actual)), 2)
    end
end

function T.ok(v, msg)
    if not v then error(msg or "assertion failed", 2) end
    return v
end

function T.has(haystack, needle, msg)
    if type(haystack) == "table" then haystack = table.concat(haystack, "\n") end
    if not tostring(haystack):find(needle, 1, true) then
        error(string.format("%s: %q not found in:\n%s", msg or "missing text", needle, tostring(haystack)), 2)
    end
end

function T.hasNot(haystack, needle, msg)
    if type(haystack) == "table" then haystack = table.concat(haystack, "\n") end
    if tostring(haystack):find(needle, 1, true) then
        error(string.format("%s: %q unexpectedly found", msg or "unexpected text", needle), 2)
    end
end

---------------------------------------------------------------------------------------------------
-- Fixtures
---------------------------------------------------------------------------------------------------

T.Gear = {
    longsword = { stats = "WPN_Longsword", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "Common",
        name = "Longsword", ref = "longsword", ["Proficiency Group"] = "Longswords;MartialWeapons" },
    longsword1 = { stats = "WPN_Longsword_1", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "Uncommon",
        name = "Longsword +1", DefaultBoosts = "WeaponEnchantment(1)" },
    longsword2 = { stats = "WPN_Longsword_2", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "Rare",
        name = "Longsword +2", DefaultBoosts = "WeaponEnchantment(2)" },
    longsword3 = { stats = "WPN_Longsword_3", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "VeryRare",
        name = "Longsword +3", DefaultBoosts = "WeaponEnchantment(3)" },
    staff = { stats = "WPN_Quarterstaff", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "Common",
        name = "Quarterstaff", ref = "quarterstaff", ["Proficiency Group"] = "Quarterstaffs;SimpleWeapons" },
    caster = { stats = "WPN_Staff_Arcane", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "Uncommon",
        name = "Arcane Staff", Boosts = "SpellSaveDC(1);RollBonus(MeleeSpellAttack,1)" },
    dagger = { stats = "WPN_Dagger", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "Common",
        name = "Dagger", ref = "dagger" },
    longbow = { stats = "WPN_Longbow", ModifierList = "Weapon", Slot = "Ranged Main Weapon", Rarity = "Common",
        name = "Longbow", ref = "longbow" },
    shield = { stats = "ARM_Shield", ModifierList = "Armor", Slot = "Melee Offhand Weapon", Rarity = "Common",
        name = "Wooden Shield", ref = "shield" },
    chainmail = { stats = "ARM_ChainMail", ModifierList = "Armor", Slot = "Breast", Rarity = "Common",
        name = "Chain Mail", ref = "chainmail" },
    boots = { stats = "ARM_Boots_Leather", ModifierList = "Armor", Slot = "Boots", Rarity = "Common",
        name = "Leather Boots", ref = "boots_leather" },
    gloves = { stats = "ARM_Gloves_Leather", ModifierList = "Armor", Slot = "Gloves", Rarity = "Common",
        name = "Leather Gloves", ref = "gloves_leather" },
    helmet = { stats = "ARM_Helmet_Metal", ModifierList = "Armor", Slot = "Helmet", Rarity = "Common",
        name = "Metal Helmet", ref = "helmet_metal" },
    cloak = { stats = "ARM_Cloak", ModifierList = "Armor", Slot = "Cloak", Rarity = "Common", name = "Travel Cloak" },
    amulet = { stats = "ARM_Amulet", ModifierList = "Armor", Slot = "Amulet", Rarity = "Uncommon", name = "Amulet" },
    ring = { stats = "ARM_Ring_Gold", ModifierList = "Armor", Slot = "Ring", Rarity = "Common", name = "Gold Ring",
        ref = "ring_gold" },
    legendary = { stats = "WPN_Legend", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "Legendary",
        name = "Sword of Legends" },
    foreign = { stats = "MOD_Blade", ModifierList = "Weapon", Slot = "Melee Main Weapon", Rarity = "Common",
        name = "Modded Blade", foreign = true },
    underwear = { stats = "ARM_Underwear", ModifierList = "Armor", Slot = "Underwear", Rarity = "Common",
        name = "Underwear" },
}

T.ForeignMod = "f0f0f0f0-1111-4222-8333-444455556666"

local function loadLoca(w, lang)
    local folder = lang == "uk" and "Ukrainian" or "English"
    local f = assert(io.open(root .. "/mod/Localization/" .. folder .. "/EnhancedGear.xml", "r"))
    local text = f:read("a")
    f:close()
    local unescape = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }
    for handle, value in text:gmatch('<content contentuid="([^"]+)" version="%d+">(.-)</content>') do
        w.baseLoca[handle] = value:gsub("&(%a+);", unescape)
    end
end

local function loadKnownStatuses(w)
    local f = assert(io.open(root .. "/mod/Public/EnhancedGear/Stats/Generated/Data/EG_Statuses.txt", "r"))
    for id in f:read("a"):gmatch('new entry "([^"]+)"') do w.knownStatuses[id] = true end
    f:close()
end

local H = {}
H.__index = H

function T.New(opts)
    opts = opts or {}
    local w = T.World.new(T.J)
    local h = setmetatable({ w = w, opts = opts, T = T, n = 0, tpl = {} }, H)
    loadLoca(w, opts.lang or "en")
    loadKnownStatuses(w)
    h:Fixtures()
    h.host = w:AddChar({ name = "Tav", party = true, user = 1, controlled = true })
    h.comp = w:AddChar({ name = "Shadowheart", party = true, user = 1 })
    w.p.host = h.host
    w.p.players = { h.host, h.comp }
    w.p.level = opts.level or "TST_Sandbox" -- no region reward unless a test asks for one
    if opts.configText then
        w.p.files["EnhancedGear/config.json"] = opts.configText
    elseif opts.config then
        local cfg = T.EG.Util.Copy(T.EG.Config.Defaults)
        for k, v in pairs(opts.config) do cfg[k] = v end
        w.p.files["EnhancedGear/config.json"] = T.EG.Config.Serialize(cfg)
    end
    if opts.boot ~= false then h:Boot() end
    return h
end

function H:Fixtures()
    local w = self.w
    for key, item in pairs(T.Ids.Items) do
        w:AddTemplate(item.template, { statsId = item.stats, handle = T.U.Handle("item." .. key .. ".name"),
            stack = key ~= "kit", icon = item.icon })
        w.stats[item.stats] = { ModifierList = "Object", Rarity = "Common" }
        self.tpl[key] = item.template
    end
    w:AddTemplate(T.Ids.GoldTemplate, { statsId = "OBJ_Goldpile", name = "Gold", stack = true })
    w.stats.OBJ_Goldpile = { ModifierList = "Object" }
    self.tpl.gold = T.Ids.GoldTemplate
    w:AddTemplate("b0b0b0b0-0000-4000-8000-00000000ba90", { statsId = "OBJ_Bag", name = "Pouch", bag = true })
    w.stats.OBJ_Bag = { ModifierList = "Object" }
    self.tpl.bag = "b0b0b0b0-0000-4000-8000-00000000ba90"
    w.mods[T.ForeignMod] = { Info = { Name = "OtherMod", Author = "Somebody" } }
    for key, g in pairs(T.Gear) do
        local stat = {}
        for k, v in pairs(g) do
            if k ~= "stats" and k ~= "name" and k ~= "ref" and k ~= "foreign" then stat[k] = v end
        end
        if g.foreign then stat.ModId = T.ForeignMod end
        w.stats[g.stats] = stat
        local tpl = g.ref and T.EG.VanillaRefs[g.ref] and T.EG.VanillaRefs[g.ref].uuid or w:Guid()
        w:AddTemplate(tpl, { statsId = g.stats, name = g.name })
        self.tpl[key] = tpl
    end
end

function H:Boot()
    local w = self.w
    w:ResetRuntime()
    self.SE = w:Context("server", T.modLua)
    self.CE = w:Context("client", T.modLua)
    assert(loadfile(T.modLua .. "/BootstrapServer.lua", "t", self.SE))()
    assert(loadfile(T.modLua .. "/BootstrapClient.lua", "t", self.CE))()
    self.S, self.C = self.SE.EG, self.CE.EG
    w:FireEvent("server", "SessionLoaded")
    w:FireEvent("client", "SessionLoaded")
    if self.loaded then w:FireOsiris("SavegameLoaded") end
    w:FireOsiris("LevelGameplayStarted", w.p.level, 0)
    w:Pump()
    w:FireEvent("client", "GameStateChanged", { FromState = "LoadSession", ToState = "Running" })
    w:Pump()
    w:Advance(10)
end

function H:Pump() self.w:Pump() end
function H:Advance(ms) self.w:Advance(ms) end

---------------------------------------------------------------------------------------------------
-- World helpers
---------------------------------------------------------------------------------------------------

function H:Item(holder, key, opts)
    local g = self.w:Spawn(holder or self.host, self.tpl[key], 1)
    if opts and opts.story then self.w:E(g).story = true end
    return g
end

function H:Give(char, bundle)
    for res, n in pairs(bundle) do self.w:Give(char, self.tpl[res], n) end
end

function H:Count(char, res) return self.w:Count(char, self.tpl[res]) end

function H:Total(res)
    local n = 0
    for _, c in ipairs(self.w.p.players) do n = n + self:Count(c, res) end
    return n
end

function H:Bundle(char)
    local b = {}
    for _, res in ipairs({ "scrap", "dust", "ingot", "core", "gold" }) do
        b[res] = char and self:Count(char, res) or self:Total(res)
    end
    return b
end

function H:Equip(char, slot, item)
    self.w:Equip(char, slot, item)
    self.w:QueueOsiris("Equipped", "Item_" .. item, "Char_" .. char)
    self:Pump()
    self:Advance(200)
end

function H:Unequip(char, slot)
    local item = self.w:E(char).equipped[slot]
    self.w:Unequip(char, slot)
    self.w:QueueOsiris("Unequipped", "Item_" .. item, "Char_" .. char)
    self:Pump()
    self:Advance(200)
end

function H:Statuses(guid)
    local e = self.w:E(guid)
    return e and T.U.Keys(e.statuses) or {}
end

function H:State(item) return self.S.ItemState.Read(item) end
function H:Data() return self.S.Data.Get() end

function H:Tech(n)
    self:Console("server", "eg_tier " .. n)
end

function H:Console(side, line)
    local parts = {}
    for p in line:gmatch("%S+") do parts[#parts + 1] = p end
    local fn = assert(self.w.commands[side][parts[1]], "no console command " .. parts[1])
    fn(parts[1], table.unpack(parts, 2))
    self:Pump()
end

-- Request through the client network channel, like the window does. Returns the result message.
function H:Req(op, fields)
    self.n = self.n + 1
    local req = fields or {}
    req.op = op
    req.id = req.id or ("test-" .. self.n)
    req.actor = req.actor or self.host
    self.C.Net.SendToServer(T.Ids.Channels.request, req)
    self:Pump()
    return self:LastResult()
end

-- Items of the last list the server sent for a "list" request.
function H:List(actor)
    local start = #self.w.inbox
    self:Req("list", { actor = actor })
    local items = {}
    for i = start + 1, #self.w.inbox do
        local m = self.w.inbox[i]
        if m.op == "list" then
            if m.part == 1 then items = {} end
            for _, it in ipairs(m.items) do items[#items + 1] = it end
        end
    end
    return items
end

function H.Entry(list, guid)
    for _, it in ipairs(list) do
        if it.guid == guid then return it end
    end
    return nil
end

function H:LastResult()
    for i = #self.w.inbox, 1, -1 do
        if self.w.inbox[i].op == "result" then return self.w.inbox[i] end
    end
    return nil
end

function H:Upgrade(item, times)
    for _ = 1, times or 1 do
        local r = self:Req("upgrade", { item = item })
        T.ok(r and r.ok, "upgrade failed: " .. show(r))
    end
end

function H:Rich(char)
    self:Give(char or self.host, { scrap = 500, dust = 300, ingot = 100, core = 10, gold = 50000 })
end

function H:Save() return T.J.decode(T.J.encode(self.w.p)) end

function H:Reload(snapshot)
    self.w.p = T.J.decode(T.J.encode(snapshot or self:Save()))
    self.loaded = true
    self:Boot()
end

function H:Errors()
    return self.w.errors
end

function H:Clean(msg)
    if #self.w.errors > 0 then error((msg or "errors were logged") .. ":\n" .. table.concat(self.w.errors, "\n"), 2) end
    if #self.w.unknownStatus > 0 then
        error("unknown statuses applied: " .. table.concat(self.w.unknownStatus, ", "), 2)
    end
end

---------------------------------------------------------------------------------------------------
-- Window helpers
---------------------------------------------------------------------------------------------------

function H:Window()
    return self.w.windows[#self.w.windows]
end

local function walk(el, fn)
    if not el or rawget(el, "_destroyed") then return end
    fn(el)
    for _, c in ipairs(rawget(el, "_children")) do walk(c, fn) end
end

function H:Elements(kind)
    local out = {}
    walk(self:Window(), function(el)
        if not kind or rawget(el, "_kind") == kind then out[#out + 1] = el end
    end)
    return out
end

-- Visible labels of text-like elements ("##id" suffixes removed).
function H:Texts()
    local out = {}
    walk(self:Window(), function(el)
        local kind = rawget(el, "_kind")
        local label = rawget(el, "_p").Label
        if (kind == "text" or kind == "septext" or kind == "button" or kind == "selectable") and label then
            out[#out + 1] = (label:gsub("##.*$", ""))
        elseif kind == "progress" and rawget(el, "_p").Overlay then
            out[#out + 1] = rawget(el, "_p").Overlay
        end
    end)
    return out
end

function H:Find(kind, needle)
    for _, el in ipairs(self:Elements(kind)) do
        local label = rawget(el, "_p").Label or ""
        if label:find(needle, 1, true) then return el end
    end
    return nil
end

function H:Button(needle) return self:Find("button", needle) end

function H:Click(needle, kind)
    local el = self:Find(kind or "button", needle)
    T.ok(el, "no " .. (kind or "button") .. " with " .. needle)
    T.ok(not el.Disabled, (kind or "button") .. " is disabled: " .. needle)
    el.OnClick(el)
    self:Pump()
    return el
end

-- Exact label match (without "##id"); index picks among duplicates.
function H:Exact(kind, label, index)
    local n = 0
    for _, el in ipairs(self:Elements(kind)) do
        if ((rawget(el, "_p").Label or ""):gsub("##.*$", "")) == label then
            n = n + 1
            if n == (index or 1) then return el end
        end
    end
    return nil
end

function H:Press(el)
    T.ok(el, "element not found")
    T.ok(not el.Disabled, "element is disabled: " .. tostring(el.Label))
    el.OnClick(el)
    self:Pump()
end

function H:Key(key)
    self.w:FireEvent("client", "KeyInput", { Event = "KeyDown", Key = key, Repeat = false })
    self:Pump()
end

-- Using the smithing kit: the template's use action applies the hidden status to the user.
function H:UseKit(char)
    char = char or self.host
    local e = self.w:E(char)
    e.statuses[T.Ids.Status.ForgeOpen] = true
    self.w:QueueOsiris("StatusApplied", char, T.Ids.Status.ForgeOpen, char, 0)
    self:Pump()
end

function H:Lang(lang)
    self.C.I18N.SetLanguage(lang)
end

return T
