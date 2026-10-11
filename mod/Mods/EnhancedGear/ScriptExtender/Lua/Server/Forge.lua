-- Forge operations. The window only previews; here everything is checked again with the same
-- formulas before anything is spent. Every spending operation goes through a journal in the
-- campaign data so that a failure in the middle never loses or duplicates resources.
EG = EG or {}
local R = EG.Rules
local L = EG.Logic
local U = EG.Util
local Game = EG.Game
local Data = EG.Data
local Config = EG.Config
local Economy = EG.Economy
local ItemState = EG.ItemState
local ItemEffects = EG.ItemEffects
local Names = EG.Names
local F = {}

F.MaxSeen = 128
F.SearchDepth = 4
F.Hooks = { names = function() end, rarity = function() end }

local seen = {}

-- Remembers the last 128 request ids per user; a repeated id is ignored.
function F.Seen(user, id)
    if id == nil then return false end
    local key = tostring(user or "local")
    local s = seen[key]
    if not s then
        s = { set = {}, order = {} }
        seen[key] = s
    end
    if s.set[id] then return true end
    s.set[id] = true
    s.order[#s.order + 1] = id
    if #s.order > F.MaxSeen then s.set[table.remove(s.order, 1)] = nil end
    return false
end

function F.Env()
    return { techTier = Data.TechTier(), cfg = Config.Get() }
end

-- The window names its character; it must be in the party, otherwise the user's or host's character acts.
function F.ResolveActor(requested, user)
    if requested and Game.IsPartyMember(requested) then return requested end
    local c = Game.UserCharacter(user)
    if c and Game.IsPartyMember(c) then return c end
    return Game.Host()
end

function F.AccessBlock(actor)
    local cfg = Config.Get()
    if not actor or not Game.IsPartyMember(actor) then return "notParty" end
    if cfg.RequireOutOfCombat and Game.InCombat(actor) then return "combat" end
    if cfg.RequireForgeKit and not Economy.PartyHasKit() then return "noKit" end
    return nil
end

---------------------------------------------------------------------------------------------------
-- Items of the party
---------------------------------------------------------------------------------------------------

-- { guid = { owner, equipped } } and a stable order: equipped first, then inventories.
function F.PartyItems()
    local out, order = {}, {}
    local party = Game.Party()
    for _, c in ipairs(party) do
        for _, slot in ipairs(R.SlotOrder) do
            local item = Game.Equipped(c)[slot]
            if item and not out[item] then
                out[item] = { owner = c, equipped = slot }
                order[#order + 1] = item
            end
        end
    end
    for _, c in ipairs(party) do
        for _, item in ipairs(Game.InventoryItems(c, F.SearchDepth)) do
            if not out[item] then
                out[item] = { owner = c }
                order[#order + 1] = item
            end
        end
    end
    return out, order
end

function F.Locate(guid)
    if not guid then return nil end
    local items = F.PartyItems()
    local where = items[guid]
    if where then return where.owner, where.equipped end
    return nil
end

function F.Context(guid, owner, slot)
    local info = Game.ItemInfo(guid)
    if not info then return nil end
    info.owner = owner
    info.ownerName = owner and Game.Name(owner) or ""
    info.equipped = slot
    local state, fresh = ItemState.Get(guid, info)
    return { guid = guid, info = info, state = state, fresh = fresh }
end

-- Serializable entry for the window.
function F.Entry(ctx)
    local info, state = ctx.info, ctx.state
    local base = state.baseName or info.name or ""
    if not state.baseName and state.level > 0 then base = base:gsub("%s%+%d+$", "") end
    return {
        guid = ctx.guid,
        name = base,
        icon = info.icon,
        owner = info.owner,
        ownerName = info.ownerName,
        profiles = L.DetectProfiles(info),
        info = {
            statsId = info.statsId, kind = info.kind, slot = info.slot, caster = info.caster, staff = info.staff,
            rarity = info.rarity, enchant = info.enchant, story = info.story, foreign = info.foreign,
            equipped = info.equipped,
        },
        state = U.Copy(state),
    }
end

function F.List()
    local items, order = F.PartyItems()
    local out = {}
    for _, guid in ipairs(order) do
        local where = items[guid]
        local ctx = F.Context(guid, where.owner, where.equipped)
        if ctx and ctx.state.profile then out[#out + 1] = F.Entry(ctx) end
    end
    return out
end

function F.Header(actor)
    local cfg = Config.Get()
    return {
        op = "header",
        actor = actor,
        actorName = actor and Game.Name(actor) or "",
        techTier = Data.TechTier(),
        have = actor and Economy.Available(actor) or {},
        block = F.AccessBlock(actor),
        cfg = {
            MaterialScope = cfg.MaterialScope, AllowStoryItemUpgrades = cfg.AllowStoryItemUpgrades,
            AllowForeignModItems = cfg.AllowForeignModItems, DevTools = cfg.DevTools,
        },
    }
end

---------------------------------------------------------------------------------------------------
-- Journal
---------------------------------------------------------------------------------------------------

local function setJournal(j)
    Data.Update(function(d) d.journal = j and U.Copy(j) or nil end)
end

-- Writes the new state and refreshes everything that depends on it.
function F.Commit(guid, state, owner)
    Names.Capture(guid, state)
    ItemState.Write(guid, state)
    local name = Names.Apply(guid, state)
    if name then F.Hooks.names({ name }) end
    ItemEffects.SyncItem(guid, state)
    local colour = ItemEffects.SyncColor(guid, state, false)
    if colour then F.Hooks.rarity({ { guid = guid, rarity = colour } }) end
    owner = owner or F.Locate(guid)
    if owner then ItemEffects.SyncCharacter(owner) end
end

-- charging -> charged. On shortage everything already taken is returned.
local function pay(actor, cost, journal)
    journal.stage = "charging"
    journal.actor = actor
    journal.charges = {}
    setJournal(journal)
    local ok = Economy.Charge(actor, cost, function(charge)
        journal.charges[#journal.charges + 1] = charge
        setJournal(journal)
    end)
    if not ok then
        Economy.Refund(journal.charges)
        setJournal(nil)
        return false
    end
    journal.stage = "charged"
    setJournal(journal)
    return true
end

-- Finishes an interrupted operation: charging -> refund; charged -> complete (paid = delivered);
-- deleting -> deliver if the item is gone, otherwise cancel.
function F.Recover()
    local j = Data.Get().journal
    if not j then return nil end
    Game.Log("finishing interrupted %s operation (stage %s)", tostring(j.op), tostring(j.stage))
    local ok, err = pcall(function()
        if j.stage == "charging" then
            Economy.Refund(j.charges)
        elseif j.stage == "charged" then
            if j.item and j.newState and Game.Exists(j.item) then F.Commit(j.item, j.newState, nil) end
            if j.output then Economy.Grant(j.actor, j.output, false) end
        elseif j.stage == "deleting" then
            if not Game.Exists(j.item) then Economy.Grant(j.actor, j.output, false) end
        end
    end)
    if not ok then Game.Error("recovery failed: %s", tostring(err)) end
    setJournal(nil)
    return j.stage
end

---------------------------------------------------------------------------------------------------
-- Operations
---------------------------------------------------------------------------------------------------

local function nameOf(ctx) return F.Entry(ctx).name end

local function upgradeOnce(actor, ctx, env)
    local check = L.CheckUpgrade(ctx, env, Economy.Available(actor))
    if not check.ok then return check end
    local newState = L.ApplyUpgrade(ctx.state, check.cost)
    local journal = { op = "upgrade", item = ctx.guid, owner = ctx.info.owner, newState = newState }
    if not pay(actor, check.cost, journal) then return { ok = false, reason = "chargeFailed" } end
    F.Commit(ctx.guid, newState, ctx.info.owner)
    setJournal(nil)
    ctx.state = newState
    return { ok = true }
end

function F.Upgrade(actor, ctx, env)
    local r = upgradeOnce(actor, ctx, env)
    if not r.ok then return r end
    return { ok = true, msg = { key = "ui.res.upgrade", params = { nameOf(ctx), ctx.state.level } } }
end

-- Step by step up to the target; already paid steps stay if resources run out.
function F.UpgradeTo(actor, ctx, env, target)
    local plan = L.UpgradePlan(ctx, env, Economy.Available(actor))
    if not plan then return L.CheckUpgrade(ctx, env, Economy.Available(actor)) end
    target = math.min(U.Int(target, plan.target), plan.target)
    local steps, stopped = 0, nil
    while ctx.state.level < target do
        local r = upgradeOnce(actor, ctx, env)
        if not r.ok then
            if steps == 0 then return r end
            stopped = r.reason
            break
        end
        steps = steps + 1
    end
    local key = stopped and "ui.res.upgradePartial" or "ui.res.upgrade"
    return { ok = true, steps = steps, msg = { key = key, params = { nameOf(ctx), ctx.state.level } } }
end

function F.Reforge(actor, ctx, env, affix)
    local check = L.CheckReforge(ctx, env, Economy.Available(actor), affix)
    if not check.ok then return check end
    local newState = L.ApplyReforge(ctx.state, check.opens and affix or nil, check.cost)
    local journal = { op = "reforge", item = ctx.guid, owner = ctx.info.owner, newState = newState }
    if not pay(actor, check.cost, journal) then return { ok = false, reason = "chargeFailed" } end
    F.Commit(ctx.guid, newState, ctx.info.owner)
    setJournal(nil)
    ctx.state = newState
    return { ok = true, msg = { key = "ui.res.reforge", params = { nameOf(ctx), { t = "rarity", v = newState.rarity } } } }
end

-- The item is deleted first, then the output is granted: at worst a reward is lost, never duplicated.
function F.Salvage(actor, ctx, env)
    local check = L.CheckSalvage(ctx, env)
    if not check.ok then return check end
    local name = nameOf(ctx)
    setJournal({ op = "salvage", item = ctx.guid, actor = actor, stage = "deleting", output = check.yield })
    Game.Delete(ctx.guid)
    ItemState.Forget(ctx.guid)
    Economy.Grant(actor, check.yield, false)
    setJournal(nil)
    return { ok = true, msg = { key = "ui.res.salvage", params = { name, { t = "bundle", v = check.yield } } } }
end

function F.Smelt(actor, env)
    local check = L.CheckSmelt(env, Economy.Available(actor))
    if not check.ok then return check end
    local journal = { op = "smelt", output = check.output }
    if not pay(actor, check.cost, journal) then return { ok = false, reason = "chargeFailed" } end
    setJournal(nil)
    Economy.Grant(actor, check.output, false)
    return { ok = true, msg = { key = "ui.res.smelt", params = { { t = "bundle", v = check.output } } } }
end

function F.SetProfile(ctx, profile)
    local check = L.CheckSetProfile(ctx, profile)
    if not check.ok then return check end
    if not check.same then
        local s = U.Copy(ctx.state)
        s.profile = profile
        s.affixes = {}
        ItemState.Write(ctx.guid, s)
        ctx.state = s
        ItemEffects.SyncItem(ctx.guid, s)
        if ctx.info.owner then ItemEffects.SyncCharacter(ctx.info.owner) end
    end
    return { ok = true, msg = { key = "ui.res.profile", params = { nameOf(ctx), { t = "profile", v = profile } } } }
end

---------------------------------------------------------------------------------------------------
-- Test tools
---------------------------------------------------------------------------------------------------

F.TestGear = { "longsword", "longsword", "quarterstaff", "dagger", "longbow", "shield", "chainmail",
    "boots_leather", "gloves_leather", "helmet_metal", "ring_gold" }

function F.GiveVanilla(char, keys)
    for _, key in ipairs(keys) do
        local ref = EG.VanillaRefs[key]
        if ref then Game.AddTemplate(char, ref.uuid, 1, true) end
    end
end

function F.ResyncAll()
    ItemEffects.SyncParty()
    local colours = ItemEffects.SyncAllColors()
    F.Hooks.names(Names.RegisterAll())
    F.Hooks.rarity(colours)
end

function F.SetTech(tier)
    tier = U.Clamp(U.Int(tier, 1), 1, #R.TechCap)
    Data.Update(function(d) d.techTier = tier end)
    return tier
end

function F.Dev(actor, req)
    if not Config.Get("DevTools") then return { ok = false, reason = "devTools" } end
    if not Game.IsPartyMember(actor) then return { ok = false, reason = "notParty" } end
    local what = req.what
    if what == "materials" then
        Economy.Grant(actor, { scrap = 20, dust = 10, ingot = 5, core = 2 }, true)
    elseif what == "gold" then
        Economy.Grant(actor, { gold = 1000 }, true)
    elseif what == "tier" then
        F.SetTech(req.tier)
    elseif what == "gear" then
        F.GiveVanilla(actor, F.TestGear)
    elseif what == "kit" then
        Economy.Grant(actor, { kit = 1 }, true)
    elseif what == "resync" then
        F.ResyncAll()
    else
        return { ok = false, reason = "error" }
    end
    return { ok = true, msg = { key = "ui.res.dev", params = {} } }
end

---------------------------------------------------------------------------------------------------
-- Entry point for window requests. Returns nil for a repeated request id.
---------------------------------------------------------------------------------------------------

local itemOps = { upgrade = true, upgradeTo = true, reforge = true, salvage = true, setProfile = true }

local function dispatch(actor, req)
    if req.op == "dev" then return F.Dev(actor, req) end
    local block = F.AccessBlock(actor)
    if block then return { ok = false, reason = block } end
    local env = F.Env()
    if req.op == "smelt" then return F.Smelt(actor, env) end
    if not itemOps[req.op] then return { ok = false, reason = "error" } end

    local owner, slot = F.Locate(req.item)
    if not owner then return { ok = false, reason = "gone" } end
    local ctx = F.Context(req.item, owner, slot)
    if not ctx then return { ok = false, reason = "gone" } end
    if not ctx.state.profile then return { ok = false, reason = "unsupported" } end
    local expect = req.expect
    if type(expect) == "table" and (expect.level ~= ctx.state.level or expect.rarity ~= ctx.state.rarity) then
        return { ok = false, reason = "stale" }
    end

    if req.op == "upgrade" then return F.Upgrade(actor, ctx, env) end
    if req.op == "upgradeTo" then return F.UpgradeTo(actor, ctx, env, req.target) end
    if req.op == "reforge" then return F.Reforge(actor, ctx, env, req.affix) end
    if req.op == "salvage" then return F.Salvage(actor, ctx, env) end
    return F.SetProfile(ctx, req.profile)
end

function F.Handle(req, user)
    if type(req) ~= "table" or F.Seen(user, req.id) then return nil end
    F.Recover()
    local actor = F.ResolveActor(req.actor, user)
    local ok, res = pcall(dispatch, actor, req)
    if ok then
        res.actor = actor
        return res
    end
    Game.Error("%s failed: %s", tostring(req.op), tostring(res))
    local stage = F.Recover()
    if stage == "charged" or stage == "deleting" then
        return { ok = true, actor = actor, msg = { key = "ui.res.dev", params = {} } }
    end
    return { ok = false, actor = actor, reason = stage == "charging" and "chargeFailed" or "error" }
end

EG.Forge = F
return F
