-- Simulated game world, Osiris and Script Extender (v32-like) for the tests.
-- The server and the client run in separate Lua environments that share this world, like the
-- two contexts of the real game. Everything the game would persist lives in world.p.
local World = {}
World.__index = World

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end
World.copy = copy

local function bare(s)
    if type(s) ~= "string" then return s end
    if #s > 36 then
        local tail = s:sub(-36)
        if tail:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then return tail end
    end
    return s
end
World.bare = bare

local function set(list)
    local out = {}
    for _, v in ipairs(list) do out[v] = true end
    return out
end

World.SlotByEngine = {
    ["Melee Main Weapon"] = "MAIN", ["Melee Offhand Weapon"] = "OFF", ["Ranged Main Weapon"] = "RMAIN",
    ["Ranged Offhand Weapon"] = "ROFF", ["Breast"] = "BODY", ["Helmet"] = "HELMET", ["Gloves"] = "GLOVES",
    ["Boots"] = "BOOTS", ["Cloak"] = "CLOAK", ["Amulet"] = "AMULET", ["Ring"] = "RING1", ["Ring2"] = "RING2",
    ["Underwear"] = "UNDERWEAR", ["VanityBody"] = "VANITYBODY", ["VanityBoots"] = "VANITYBOOTS",
}

function World.new(J)
    local w = setmetatable({}, World)
    w.J = J
    w.p = { entities = {}, players = {}, host = nil, modvars = {}, level = "WLD_Main_A", files = {}, nextId = 1 }
    w.templates, w.stats, w.mods, w.baseLoca, w.knownStatuses = {}, {}, {}, {}, {}
    w.clock = 0
    w.fail = {}
    w:ResetRuntime()
    return w
end

-- Everything that does not survive a save/load: Lua state, loca strings, timers, network, windows.
function World:ResetRuntime()
    self.loca = { server = copy(self.baseLoca), client = copy(self.baseLoca) }
    self.timers, self.timerSeq = {}, 0
    self.listeners, self.osirisQueue = {}, {}
    self.handlers = { server = {}, client = {} }
    self.events = { server = {}, client = {} }
    self.commands = { server = {}, client = {} }
    self.userVars = { server = {}, client = {} }
    self.modVarsRegistered = { server = {}, client = {} }
    self.bus = { toServer = {}, toClient = {} }
    self.inbox, self.windows, self.prints, self.errors = {}, {}, {}, {}
    self.notes, self.replicated, self.unknownStatus = {}, {}, {}
    self.clientUser = 1
end

function World:Guid()
    local n = self.p.nextId
    self.p.nextId = n + 1
    return string.format("%08x-0000-4000-8000-%012d", 0xE6000000 + n, n)
end

---------------------------------------------------------------------------------------------------
-- Entities
---------------------------------------------------------------------------------------------------

function World:E(guid) return self.p.entities[bare(guid)] end

function World:AddChar(o)
    local g = self:Guid()
    self.p.entities[g] = { kind = "char", guid = g, name = o.name, level = o.level or 5, party = o.party or false,
        enemy = o.enemy or false, boss = o.boss or false, summon = o.summon or false, user = o.user,
        controlled = o.controlled or false, combat = false, inv = {}, equipped = {}, statuses = {}, vars = {},
        handle = "hCHAR_" .. g }
    self.baseLoca["hCHAR_" .. g] = o.name
    self.loca.server["hCHAR_" .. g] = o.name
    self.loca.client["hCHAR_" .. g] = o.name
    return g
end

-- def: { statsId, name, handle?, stack, icon }
function World:AddTemplate(guid, def)
    def.handle = def.handle or ("hTPL_" .. def.statsId)
    self.templates[guid] = def
    if def.name then
        self.baseLoca[def.handle] = def.name
        self.loca.server[def.handle] = self.loca.server[def.handle] or def.name
        self.loca.client[def.handle] = self.loca.client[def.handle] or def.name
    end
end

local engineRarity = { Common = 0, Uncommon = 1, Rare = 2, VeryRare = 3, Legendary = 4 }

function World:Spawn(holder, tpl, amount)
    tpl = bare(tpl)
    local def = assert(self.templates[tpl], "unknown template " .. tostring(tpl))
    local stat = self.stats[def.statsId] or {}
    local g = self:Guid()
    self.p.entities[g] = { kind = "item", guid = g, template = tpl, statsId = def.statsId, amount = amount or 1,
        holder = nil, statuses = {}, vars = {}, handle = def.handle, icon = def.icon or ("Item_" .. def.statsId),
        rarityValue = engineRarity[stat.Rarity or "Common"] or 0, story = false, inv = def.bag and {} or nil }
    if holder then self:Put(g, holder) end
    return g
end

function World:Put(item, holder)
    local x, h = self:E(item), self:E(holder)
    assert(h and h.inv, "holder without inventory")
    x.holder = h.guid
    h.inv[#h.inv + 1] = x.guid
end

function World:Detach(item)
    local x = self:E(item)
    if not x or not x.holder then return end
    local h = self:E(x.holder)
    if h then
        for i, g in ipairs(h.inv) do
            if g == x.guid then
                table.remove(h.inv, i)
                break
            end
        end
        for slot, g in pairs(h.equipped or {}) do
            if g == x.guid then h.equipped[slot] = nil end
        end
    end
    x.holder = nil
end

function World:Move(item, holder)
    self:Detach(item)
    self:Put(item, holder)
end

function World:Delete(item)
    local x = self:E(item)
    if not x then return end
    self:Detach(item)
    self.p.entities[x.guid] = nil
end

function World:Equip(char, slot, item)
    local c, x = self:E(char), self:E(item)
    if x.holder ~= c.guid then self:Move(item, char) end
    c.equipped[slot] = x.guid
end

function World:Unequip(char, slot)
    self:E(char).equipped[slot] = nil
end

local function walkItems(w, holder, fn, depth)
    local h = w:E(holder)
    if not h or not h.inv or depth > 5 then return end
    for _, g in ipairs(copy(h.inv)) do
        local x = w:E(g)
        if x then
            fn(x, h)
            if x.inv then walkItems(w, g, fn, depth + 1) end
        end
    end
end

function World:Count(holder, tpl)
    tpl = bare(tpl)
    local n = 0
    walkItems(self, holder, function(x) if x.template == tpl then n = n + x.amount end end, 0)
    return n
end

function World:Give(holder, tpl, n)
    tpl = bare(tpl)
    local def = assert(self.templates[tpl], "unknown template " .. tostring(tpl))
    if def.stack then
        for _, g in ipairs(self:E(holder).inv) do
            local x = self:E(g)
            if x.template == tpl then
                x.amount = x.amount + n
                return g
            end
        end
        return self:Spawn(holder, tpl, n)
    end
    local last
    for _ = 1, n do last = self:Spawn(holder, tpl, 1) end
    return last
end

function World:Take(holder, tpl, n)
    tpl = bare(tpl)
    walkItems(self, holder, function(x)
        if n > 0 and x.template == tpl then
            local take = math.min(n, x.amount)
            x.amount = x.amount - take
            n = n - take
            if x.amount == 0 then self:Delete(x.guid) end
        end
    end, 0)
end

function World:Check(name)
    local f = self.fail[name]
    if f then
        f.n = f.n - 1
        if f.n <= 0 then
            self.fail[name] = nil
            error("simulated engine failure in " .. name)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Osiris
---------------------------------------------------------------------------------------------------

function World:QueueOsiris(name, ...)
    self.osirisQueue[#self.osirisQueue + 1] = { name = name, args = table.pack(...) }
end

function World:FireOsiris(name, ...)
    local n = select("#", ...)
    for _, l in ipairs(self.listeners[name] or {}) do
        assert(l.arity == n, string.format("listener %s registered with arity %d, event has %d", name, l.arity, n))
        l.fn(...)
    end
end

function World:Osi()
    local w = self
    local O = {}
    local function e(g) return w:E(g) end
    local function b(v) return v and 1 or 0 end
    O.GetHostCharacter = function() return w.p.host end
    O.DB_Players = { Get = function()
        local rows = {}
        for _, g in ipairs(w.p.players) do rows[#rows + 1] = { "Name_" .. g } end
        return rows
    end }
    O.IsPartyMember = function(g) local x = e(g); return b(x and x.kind == "char" and x.party) end
    O.IsInCombat = function(g) local x = e(g); return b(x and x.combat) end
    O.IsBoss = function(g) local x = e(g); return b(x and x.boss) end
    O.IsSummon = function(g) local x = e(g); return b(x and x.summon) end
    O.GetLevel = function(g) local x = e(g); return x and x.level or 1 end
    O.IsEnemy = function(a) local x = e(a); return b(x and x.enemy) end
    O.GetDisplayName = function(g) local x = e(g); return x and x.handle or nil end
    O.GetCurrentCharacter = function(user)
        for _, g in ipairs(w.p.players) do
            local x = e(g)
            if x.user == user and x.controlled then return g end
        end
        return nil
    end
    O.GetEquippedItem = function(c, slotName)
        local key = assert(World.SlotByEngine[slotName], "unknown equipment slot " .. tostring(slotName))
        local x = e(c)
        local g = x and x.equipped[key]
        if g then return "Item_" .. g end
        return nil
    end
    O.GetTemplate = function(g)
        local x = e(g)
        return x and ("Tpl_" .. x.template) or nil
    end
    O.IsStoryItem = function(g) local x = e(g); return b(x and x.story) end
    O.GetStatString = function(g) local x = e(g); return x and x.statsId end
    O.TemplateIsInInventory = function(tpl, holder) return w:Count(bare(holder), tpl) end
    O.TemplateAddTo = function(tpl, holder, n, notify)
        assert(notify ~= nil, "TemplateAddTo expects 4 arguments")
        w:Check("TemplateAddTo")
        w:Give(bare(holder), tpl, n)
    end
    O.TemplateRemoveFrom = function(tpl, holder, n)
        w:Check("TemplateRemoveFrom")
        w:Take(bare(holder), tpl, n)
    end
    O.RequestDelete = function(g) w:Delete(bare(g)) end
    O.ApplyStatus = function(obj, st, duration)
        assert(type(duration) == "number", "ApplyStatus duration")
        local x = assert(e(obj), "ApplyStatus on a missing object")
        if not w.knownStatuses[st] then w.unknownStatus[#w.unknownStatus + 1] = st end
        x.statuses[st] = true
        w:QueueOsiris("StatusApplied", obj, st, obj, 0)
    end
    O.RemoveStatus = function(obj, st)
        local x = e(obj)
        if x then x.statuses[st] = nil end
    end
    O.HasActiveStatus = function(obj, st) local x = e(obj); return b(x and x.statuses[st]) end
    O.ShowNotification = function(c, text) w.notes[#w.notes + 1] = { char = bare(c), text = text } end
    O.OpenMessageBox = O.ShowNotification
    return setmetatable(O, { __index = function(_, k) error("Osi." .. tostring(k) .. " is not simulated", 2) end })
end

---------------------------------------------------------------------------------------------------
-- Entities seen through Ext.Entity
---------------------------------------------------------------------------------------------------

function World:Proxy(guid, side)
    local w = self
    guid = bare(guid)
    local x = w.p.entities[guid]
    if not x then return nil end
    local p = { Uuid = { EntityUuid = guid } }
    p.Vars = setmetatable({}, {
        __index = function(_, k)
            assert(w.userVars[side][k], "user variable not registered: " .. tostring(k))
            return copy(x.vars[k])
        end,
        __newindex = function(_, k, v)
            assert(w.userVars[side][k], "user variable not registered: " .. tostring(k))
            assert(side == "server", "the client cannot write a server variable")
            x.vars[k] = w.J.decode(w.J.encode({ v = v })).v
        end,
    })
    if x.kind == "item" then
        p.Data = { StatsId = x.statsId }
        p.Icon = { Icon = x.icon }
        p.DisplayName = { NameKey = { Handle = setmetatable({}, {
            __index = function(_, k) if k == "Handle" then return x.handle end end,
            __newindex = function(_, k, v)
                assert(k == "Handle")
                x.handle = v
            end,
        }) } }
        p.Value = setmetatable({}, {
            __index = function(_, k) if k == "Rarity" then return side == "client" and (x.clientRarity or x.rarityValue) or x.rarityValue end end,
            __newindex = function(_, k, v)
                assert(k == "Rarity")
                if side == "client" then x.clientRarity = v else x.rarityValue = v end
            end,
        })
        if x.health then p.Health = {} end
    else
        p.UserReservedFor = { UserID = x.user }
        p.PartyMember = { UserID = x.user }
        if x.controlled then p.ClientControl = {} end
    end
    if x.inv then
        local items = {}
        for i, g in ipairs(x.inv) do items[i - 1] = { Item = w:Proxy(g, side) } end
        p.InventoryOwner = { Inventories = { { InventoryContainer = { Items = items } } } }
    end
    function p.Replicate(_, name)
        w:Check("Replicate")
        w.replicated[#w.replicated + 1] = { guid = guid, name = name }
    end
    function p.CreateComponent(self, name)
        if name == "Health" then
            x.health = true
            self.Health = {}
        end
    end
    return p
end

---------------------------------------------------------------------------------------------------
-- IMGUI (strict like SE: unknown properties raise errors)
---------------------------------------------------------------------------------------------------

local common = set({ "Label", "SameLine", "Disabled", "Visible", "OnClick", "OnChange", "OnClose", "Font", "IDContext",
    "UserData", "OnHoverEnter", "OnRightClick" })
local extra = {
    window = set({ "Open", "Closeable", "NoResize", "AlwaysAutoResize", "NoMove", "NoCollapse", "NoTitleBar" }),
    combo = set({ "Options", "SelectedIndex" }),
    input = set({ "Text", "Hint" }),
    selectable = set({ "Selected" }),
    progress = set({ "Value", "Overlay", "Size" }),
    image = set({ "Border", "Tint" }),
    imagebutton = set({ "Border", "Tint" }),
    child = set({ "Size", "Border" }),
}
local containers = set({ "window", "group", "tabbar", "tabitem", "table", "row", "cell", "child" })

function World:IMGUI()
    local w = self
    local methods = {}
    local mt = {}
    mt.__index = function(t, k)
        if k == "Children" then
            local out = {}
            for i, c in ipairs(rawget(t, "_children")) do out[i] = c end
            return out
        end
        local m = methods[k]
        if m then
            if k:match("^Add") and not containers[rawget(t, "_kind")] then
                error(k .. " is not available on " .. rawget(t, "_kind"))
            end
            return m
        end
        return rawget(t, "_p")[k]
    end
    mt.__newindex = function(t, k, v)
        local kind = rawget(t, "_kind")
        if common[k] or (extra[kind] and extra[kind][k]) then
            rawget(t, "_p")[k] = v
        else
            error(string.format("Property '%s' does not exist on %s", tostring(k), kind))
        end
    end
    local function new(kind, parent, label)
        local el = setmetatable({ _kind = kind, _children = {}, _p = { Label = label, Visible = true }, _parent = parent }, mt)
        if parent then table.insert(rawget(parent, "_children"), el) end
        return el
    end
    for name, kind in pairs({ AddGroup = "group", AddTabBar = "tabbar", AddChildWindow = "child", AddText = "text",
        AddButton = "button", AddSelectable = "selectable", AddCombo = "combo", AddSeparatorText = "septext",
        AddBulletText = "text" }) do
        methods[name] = function(self, label)
            assert(type(label) == "string", name .. " expects a string label")
            return new(kind, self, label)
        end
    end
    methods.AddSeparator = function(self) return new("separator", self, "") end
    methods.AddProgressBar = function(self) return new("progress", self, "") end
    methods.AddTabItem = function(self, label)
        assert(rawget(self, "_kind") == "tabbar", "AddTabItem outside a tab bar")
        return new("tabitem", self, label)
    end
    methods.AddTable = function(self, label, columns)
        assert(math.type(columns) == "integer", "AddTable expects a column count")
        return new("table", self, label)
    end
    methods.AddColumn = function(self) assert(rawget(self, "_kind") == "table") end
    methods.AddRow = function(self)
        assert(rawget(self, "_kind") == "table", "AddRow outside a table")
        return new("row", self, "")
    end
    methods.AddCell = function(self)
        assert(rawget(self, "_kind") == "row", "AddCell outside a row")
        return new("cell", self, "")
    end
    methods.AddInputText = function(self, label, text)
        local el = new("input", self, label)
        rawget(el, "_p").Text = text or ""
        return el
    end
    methods.AddImage = function(self, icon, size)
        assert(type(icon) == "string" and type(size) == "table", "AddImage(icon, size)")
        return new("image", self, icon)
    end
    methods.AddImageButton = function(self, label, icon, size)
        assert(type(icon) == "string" and type(size) == "table", "AddImageButton(label, icon, size)")
        local el = new("imagebutton", self, label)
        rawget(el, "_p").Icon = icon
        return el
    end
    methods.SetColor = function(self, what, value)
        assert(type(what) == "string" and type(value) == "table" and #value == 4, "SetColor(name, {r,g,b,a})")
        rawget(self, "_p")["color:" .. what] = value
    end
    methods.SetStyle = function(_, what) assert(type(what) == "string") end
    methods.SetSize = function(_, size) assert(type(size) == "table") end
    methods.SetPos = function(_, pos) assert(type(pos) == "table") end
    methods.SetSizeConstraints = function(_, size) assert(type(size) == "table") end
    methods.Destroy = function(self)
        local parent = rawget(self, "_parent")
        if parent then
            local list = rawget(parent, "_children")
            for i, c in ipairs(list) do
                if c == self then
                    table.remove(list, i)
                    break
                end
            end
        end
        rawset(self, "_destroyed", true)
    end
    return {
        NewWindow = function(title)
            local win = new("window", nil, title)
            w.windows[#w.windows + 1] = win
            return win
        end,
        GetViewportSize = function() return { 1920, 1080 } end,
    }
end

---------------------------------------------------------------------------------------------------
-- Script Extender context
---------------------------------------------------------------------------------------------------

function World:Context(side, modLua)
    local w = self
    local env = {}
    for _, k in ipairs({ "assert", "error", "ipairs", "next", "pairs", "pcall", "xpcall", "rawequal", "rawget", "rawlen",
        "rawset", "select", "setmetatable", "getmetatable", "tonumber", "tostring", "type", "print" }) do
        env[k] = _G[k]
    end
    env.string, env.table, env.math, env.utf8 = string, table, math, utf8
    env.os = { time = os.time, clock = os.clock, date = os.date }
    env._G = env
    local cache = {}
    local Ext = {}
    env.Ext = Ext
    Ext.IsServer = function() return side == "server" end
    Ext.IsClient = function() return side == "client" end
    Ext.Require = function(path)
        if cache[path] ~= nil then return cache[path] end
        local chunk = assert(loadfile(modLua .. "/" .. path, "t", env))
        local res = chunk()
        cache[path] = res == nil and true or res
        return res
    end
    local function join(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        return table.concat(parts, " ")
    end
    Ext.Utils = {
        Print = function(...) w.prints[#w.prints + 1] = side .. ": " .. join(...) end,
        PrintError = function(...) w.errors[#w.errors + 1] = side .. ": " .. join(...) end,
        MonotonicTime = function() return w.clock end,
    }
    Ext.Json = { Parse = w.J.decode, Stringify = function(v) return w.J.encode(v) end }
    Ext.IO = {
        LoadFile = function(path) return w.p.files[path] end,
        SaveFile = function(path, text)
            w.p.files[path] = text
            return true
        end,
    }
    Ext.Vars = {
        RegisterUserVariable = function(name, opts) w.userVars[side][name] = copy(opts) end,
        RegisterModVariable = function(uuid, name, opts) w.modVarsRegistered[side][uuid .. "/" .. name] = copy(opts) end,
        GetModVariables = function(uuid)
            return setmetatable({}, {
                __index = function(_, k)
                    assert(w.modVarsRegistered[side][uuid .. "/" .. k], "mod variable not registered: " .. k)
                    return copy(w.p.modvars[uuid .. "/" .. k])
                end,
                __newindex = function(_, k, v)
                    assert(w.modVarsRegistered[side][uuid .. "/" .. k], "mod variable not registered: " .. k)
                    assert(side == "server", "client cannot write mod variables")
                    w.p.modvars[uuid .. "/" .. k] = w.J.decode(w.J.encode({ v = v })).v
                end,
            })
        end,
    }
    Ext.Entity = {
        Get = function(guid) return w:Proxy(guid, side) end,
        GetAllEntitiesWithComponent = function(name)
            local out = {}
            if name == "ClientControl" then
                for _, g in ipairs(w.p.players) do
                    if w:E(g).controlled then out[#out + 1] = w:Proxy(g, side) end
                end
            end
            return out
        end,
    }
    Ext.Stats = { Get = function(name) return copy(w.stats[name]) end }
    Ext.Mod = { GetMod = function(uuid) return w.mods[uuid] end }
    Ext.Loca = {
        GetTranslatedString = function(h, fallback)
            local t = w.loca[side][h]
            if t == nil then return fallback end
            return t
        end,
        UpdateTranslatedString = function(h, text)
            w.loca[side][h] = text
            return true
        end,
    }
    Ext.Net = { CreateChannel = function(_, name)
        local ch = {}
        function ch.SetHandler(_, fn) w.handlers[side][name] = fn end
        function ch.SendToServer(_, data)
            assert(side == "client", "SendToServer on the server")
            w.bus.toServer[#w.bus.toServer + 1] = { name = name, payload = w.J.encode(data), user = w.clientUser }
        end
        function ch.SendToClient(_, data, user)
            assert(side == "server", "SendToClient on the client")
            w.bus.toClient[#w.bus.toClient + 1] = { name = name, payload = w.J.encode(data), user = user }
        end
        function ch.Broadcast(_, data)
            assert(side == "server", "Broadcast on the client")
            w.bus.toClient[#w.bus.toClient + 1] = { name = name, payload = w.J.encode(data) }
        end
        return ch
    end }
    local function event(name)
        return { Subscribe = function(_, fn)
            w.events[side][name] = w.events[side][name] or {}
            table.insert(w.events[side][name], fn)
            return #w.events[side][name]
        end }
    end
    Ext.Events = { SessionLoaded = event("SessionLoaded"), KeyInput = event("KeyInput"),
        GameStateChanged = event("GameStateChanged"), Tick = event("Tick"), ResetCompleted = event("ResetCompleted") }
    Ext.Osiris = { RegisterListener = function(name, arity, when, fn)
        assert(side == "server", "Osiris listeners exist only on the server")
        assert(when == "before" or when == "after")
        w.listeners[name] = w.listeners[name] or {}
        table.insert(w.listeners[name], { arity = arity, fn = fn })
    end }
    Ext.RegisterConsoleCommand = function(name, fn) w.commands[side][name] = fn end
    Ext.Timer = { WaitFor = function(ms, fn)
        w.timerSeq = w.timerSeq + 1
        w.timers[#w.timers + 1] = { at = w.clock + ms, fn = fn, seq = w.timerSeq }
        return w.timerSeq
    end }
    Ext.Timer.WaitForRealtime = Ext.Timer.WaitFor
    if side == "client" then Ext.IMGUI = w:IMGUI() end
    if side == "server" then env.Osi = w:Osi() end
    return env
end

function World:FireEvent(side, name, e)
    for _, fn in ipairs(self.events[side][name] or {}) do fn(e or {}) end
end

-- Delivers queued Osiris events and network messages until everything is quiet.
function World:Pump()
    for _ = 1, 100000 do
        local o = table.remove(self.osirisQueue, 1)
        if o then
            self:FireOsiris(o.name, table.unpack(o.args, 1, o.args.n))
        else
            local m = table.remove(self.bus.toServer, 1)
            if m then
                local h = self.handlers.server[m.name]
                if h then h(self.J.decode(m.payload), m.user) end
            else
                local c = table.remove(self.bus.toClient, 1)
                if not c then return end
                if c.user == nil or c.user == self.clientUser then
                    local data = self.J.decode(c.payload)
                    self.inbox[#self.inbox + 1] = data
                    local h = self.handlers.client[c.name]
                    if h then h(self.J.decode(c.payload), nil) end
                end
            end
        end
    end
    error("message loop did not settle")
end

function World:Advance(ms)
    local target = self.clock + ms
    while true do
        local best, index
        for i, t in ipairs(self.timers) do
            if t.at <= target and (not best or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then
                best, index = t, i
            end
        end
        if not best then break end
        table.remove(self.timers, index)
        self.clock = math.max(self.clock, best.at)
        best.fn()
        self:Pump()
    end
    self.clock = target
end

return World
