-- Server wiring: game events, window requests, console commands.
EG = EG or {}
local Ids = EG.Ids
local U = EG.Util
local Game = EG.Game
local Data = EG.Data
local Config = EG.Config
local I18N = EG.I18N
local Net = EG.Net
local Economy = EG.Economy
local ItemEffects = EG.ItemEffects
local Effects = EG.Effects
local Names = EG.Names
local Forge = EG.Forge
local Loot = EG.Loot
local M = {}

M.Chunk = 40 -- list entries per message, keeps payloads small
M.SyncDelay = 150 -- equip/unequip events within this window are merged
M.ColourRetry = 3000

local pending = {}
local seq = 0

local function push(user, data) Net.SendToUser(user, Ids.Channels.push, data) end
local function broadcast(data) Net.Broadcast(Ids.Channels.push, data) end

local function chunks(list, size)
    local out = {}
    for i = 1, #list, size do
        local part = {}
        for j = i, math.min(i + size - 1, #list) do part[#part + 1] = list[j] end
        out[#out + 1] = part
    end
    if #out == 0 then out[1] = {} end
    return out
end

-- "auto": the marker string exists only in the loca file of the game language.
function M.ResolveLanguage()
    local marker = Game.GetLoca(U.Handle("lang.marker"))
    return I18N.SetLanguage(I18N.Resolve(Config.Get("Language"), marker == "uk" and "uk" or "en"))
end

function M.SendNames(entries, user)
    if #entries == 0 then return end
    for _, part in ipairs(chunks(entries, M.Chunk)) do
        local msg = { op = "names", entries = part }
        if user ~= nil then push(user, msg) else broadcast(msg) end
    end
end

function M.SendRarity(entries)
    if entries and #entries > 0 then broadcast({ op = "rarity", entries = entries }) end
end

-- Header first, then the item list in parts of 40.
function M.SendState(actor, user)
    push(user, Forge.Header(actor))
    seq = seq + 1
    local parts = chunks(Forge.List(), M.Chunk)
    for i, part in ipairs(parts) do
        push(user, { op = "list", seq = seq, part = i, parts = #parts, actor = actor, items = part })
    end
end

function M.OnRequest(req, user)
    if type(req) ~= "table" then return end
    if req.op == "list" then
        M.SendState(Forge.ResolveActor(req.actor, user), user)
        return
    elseif req.op == "names" then
        M.SendNames(Names.RegisterAll(), user)
        return
    end
    local res = Forge.Handle(req, user)
    if res == nil then return end
    push(user, { op = "result", id = req.id, ok = res.ok, reason = res.reason, params = res.params, msg = res.msg,
        item = req.item })
    M.SendState(res.actor, user)
end

function M.OpenFor(char)
    char = U.BareGuid(char)
    if not char then return end
    push(Game.CharacterUser(char), { op = "open", actor = char })
end

function M.ScheduleSync(char)
    char = U.BareGuid(char)
    if not char or pending[char] then return end
    pending[char] = true
    Game.After(M.SyncDelay, function()
        pending[char] = nil
        ItemEffects.SyncCharacter(char)
    end)
end

-- Level or save loaded: recover, rewards, effects, names and colours (colours again a bit later,
-- when clients have loaded the level).
function M.OnWorldReady(level)
    M.ResolveLanguage()
    Data.Migrate()
    Forge.Recover()
    if level then Loot.OnLevelStarted(level) end
    ItemEffects.SyncParty()
    M.SendNames(Names.RegisterAll())
    M.SendRarity(ItemEffects.SyncAllColors())
    Game.After(M.ColourRetry, function() M.SendRarity(ItemEffects.SyncAllColors()) end)
end

function M.Dump()
    local d = Data.Get()
    Game.Log("forge technology %d, %d forged items, journal: %s", Data.TechTier(d), U.Count(d.index),
        d.journal and tostring(d.journal.op) or "none")
    for _, guid in ipairs(U.Keys(d.index)) do
        local s = d.index[guid]
        Game.Log("  %s | %s +%d | rarity %d (base %d) | engine colour %s | profile %s | affixes %s, %s",
            guid, tostring(s.baseName), s.level, s.rarity, s.baseRarity, tostring(Game.GetRarity(guid)),
            tostring(s.profile), tostring(s.affixes.slot1), tostring(s.affixes.slot2))
    end
    for _, c in ipairs(Game.Party()) do
        local list = {}
        for _, id in ipairs(Effects.WearerIds()) do
            if Game.HasStatus(c, id) then list[#list + 1] = id end
        end
        Game.Log("  %s: %s", Game.Name(c), #list > 0 and table.concat(list, ", ") or "-")
    end
end

local giveKeys = { scrap = true, dust = true, ingot = true, core = true, gold = true }

function M.Give(what, n)
    n = math.max(1, U.Int(tonumber(n), 10))
    local bundle = {}
    if what == "all" then
        for k in pairs(giveKeys) do bundle[k] = n end
    elseif giveKeys[what] then
        bundle[what] = n
    else
        Game.Log("usage: !eg_give <scrap|dust|ingot|core|gold|all> [count]")
        return
    end
    Economy.Grant(Game.Host(), bundle, true)
end

function M.RegisterCommands()
    local function cmd(name, fn)
        Ext.RegisterConsoleCommand(name, function(_, ...)
            local ok, err = pcall(fn, ...)
            if not ok then Game.Error("%s: %s", name, tostring(err)) end
        end)
    end
    cmd("eg_forge", function() M.OpenFor(Game.Host()) end)
    cmd("eg_kit", function() Economy.Grant(Game.Host(), { kit = 1 }, true) end)
    cmd("eg_give", M.Give)
    cmd("eg_tier", function(n) Game.Log("forge technology set to %d", Forge.SetTech(tonumber(n))) end)
    cmd("eg_testswords", function() Forge.GiveVanilla(Game.Host(), { "longsword", "longsword" }) end)
    cmd("eg_testgear", function() Forge.GiveVanilla(Game.Host(), Forge.TestGear) end)
    cmd("eg_dump", M.Dump)
    cmd("eg_resync", function()
        Forge.ResyncAll()
        Game.Log("all effects recalculated")
    end)
    cmd("eg_cleanup", function() Game.Log("cleanup: removed %d statuses", ItemEffects.Cleanup()) end)
end

function M.Init()
    Config.Load()
    M.ResolveLanguage()
    Net.Init()
    Net.On(Ids.Channels.request, M.OnRequest)
    Forge.Hooks.names = function(entries) M.SendNames(entries) end
    Forge.Hooks.rarity = function(entries) M.SendRarity(entries) end

    local function on(event, arity, fn)
        Ext.Osiris.RegisterListener(event, arity, "after", function(...)
            local ok, err = pcall(fn, ...)
            if not ok then Game.Error("%s: %s", event, tostring(err)) end
        end)
    end
    on("LevelGameplayStarted", 2, function(level) M.OnWorldReady(level) end)
    on("SavegameLoaded", 0, function() M.OnWorldReady(nil) end)
    on("Equipped", 2, function(_, char) M.ScheduleSync(char) end)
    on("Unequipped", 2, function(_, char) M.ScheduleSync(char) end)
    on("CharacterJoinedParty", 1, M.ScheduleSync)
    on("Resurrected", 1, M.ScheduleSync)
    on("LongRestFinished", 0, function() ItemEffects.SyncParty() end)
    -- The smithing kit applies a hidden status to the user; we remove it at once and open the window.
    on("StatusApplied", 4, function(obj, status)
        if status == Ids.Status.ForgeOpen then
            Game.RemoveStatus(U.BareGuid(obj), status)
            M.OpenFor(obj)
        end
    end)
    on("Died", 1, function(char) Loot.OnDied(U.BareGuid(char)) end)

    M.RegisterCommands()
    Ext.Events.SessionLoaded:Subscribe(function()
        M.ResolveLanguage()
        Game.Log("server loaded (language %s)", I18N.Lang)
    end)
end

EG.ServerMain = M
return M
