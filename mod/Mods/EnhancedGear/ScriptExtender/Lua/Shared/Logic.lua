-- Pure formulas: caps, prices, effects, block reasons, salvage, migration of item state.
-- Used identically by the server (authoritative) and the forge window (preview only).
EG = EG or {}
local R = EG.Rules
local U = EG.Util
local L = {}

L.StateVersion = 1
L.Resources = { "scrap", "dust", "ingot", "core", "gold" }

local function fail(reason, extra)
    local r = extra or {}
    r.ok = false
    r.reason = reason
    return r
end

local function okResult(extra)
    local r = extra or {}
    r.ok = true
    return r
end

---------------------------------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------------------------------

-- info.kind: "weapon" | "armor"; info.slot: stats Slot; info.caster: has SpellSaveDC/SpellAttack; info.staff.
function L.DetectProfiles(info)
    if not info then return nil end
    if info.kind == "weapon" then
        if info.caster then return { "focus", "weapon" } end
        if info.staff then return { "weapon", "focus" } end
        return { "weapon" }
    elseif info.kind == "armor" then
        local p = R.ArmorSlotProfile[info.slot or ""]
        if p then return { p } end
    end
    return nil
end

function L.ValidProfile(profile)
    return R.ProfileGroup[profile] ~= nil
end

---------------------------------------------------------------------------------------------------
-- Item state
---------------------------------------------------------------------------------------------------

function L.NewState(info)
    local profiles = L.DetectProfiles(info)
    local rarity = U.Clamp(U.Int(info and info.rarity, 1), 1, 5)
    return {
        v = L.StateVersion,
        level = 0,
        rarity = rarity,
        baseRarity = rarity,
        profile = profiles and profiles[1] or nil,
        affixes = {},
        spent = {},
        baseEnchant = U.Clamp(U.Int(info and info.enchant, 0), 0, R.Weapon.enchantCap),
    }
end

-- Brings any stored state (old versions, damaged data) to the current schema. Returns state, changed.
function L.Normalize(state, info)
    local before = U.Copy(state)
    if type(state) ~= "table" then state = L.NewState(info) end
    local s = state
    s.level = U.Clamp(U.Int(s.level, 0), 0, R.MaxLevel)
    s.rarity = U.Clamp(U.Int(s.rarity, info and info.rarity or 1), 1, 5)
    s.baseRarity = U.Clamp(U.Int(s.baseRarity, s.rarity), 1, 5)
    if s.baseRarity > s.rarity then s.rarity = s.baseRarity end
    s.baseEnchant = U.Clamp(U.Int(s.baseEnchant, info and info.enchant or 0), 0, R.Weapon.enchantCap)

    local allowed = L.DetectProfiles(info)
    if allowed then
        if not U.Contains(allowed, s.profile) then s.profile = allowed[1] end
    elseif not L.ValidProfile(s.profile) then
        s.profile = nil
    end

    if type(s.spent) ~= "table" then s.spent = {} end
    local spent = {}
    for _, k in ipairs(L.Resources) do
        local v = U.Int(s.spent[k], 0)
        if v > 0 then spent[k] = v end
    end
    s.spent = spent

    if type(s.affixes) ~= "table" then s.affixes = {} end
    local affixes = {}
    for _, slot in ipairs(R.AffixSlots) do
        local id = s.affixes[slot]
        local def = R.AffixById[id or ""]
        if def and s.profile and def.profiles[s.profile] then affixes[slot] = id end
    end
    if affixes.slot1 and affixes.slot2 then
        local a, b = R.AffixById[affixes.slot1], R.AffixById[affixes.slot2]
        if a.id == b.id or a.group == b.group then affixes.slot2 = nil end
    end
    s.affixes = affixes

    if s.baseName ~= nil and type(s.baseName) ~= "string" then s.baseName = nil end
    if s.nameHandle ~= nil and type(s.nameHandle) ~= "string" then s.nameHandle = nil end
    s.v = L.StateVersion
    return s, not U.Equal(before, s)
end

-- Anything invested? (Profile can only be changed before the first investment.)
function L.Invested(state)
    return state.level > 0 or state.rarity > state.baseRarity or not U.BundleEmpty(state.spent)
end

---------------------------------------------------------------------------------------------------
-- Milestones and effects
---------------------------------------------------------------------------------------------------

function L.Milestone(level)
    local m = 0
    for _, v in ipairs(R.Milestones) do
        if level >= v then m = v end
    end
    return m
end

function L.NextMilestone(level)
    for _, v in ipairs(R.Milestones) do
        if v > level then return v end
    end
    return nil
end

function L.IsMilestone(level)
    return U.Contains(R.Milestones, level)
end

-- Forged enchantment and first-hit bonus for a weapon milestone; overflow above the +3 cap becomes first-hit damage.
function L.WeaponBonus(milestone, baseEnchant)
    local def = R.Weapon.milestones[milestone]
    if not def then return 0, 0 end
    local room = math.max(0, R.Weapon.enchantCap - (baseEnchant or 0))
    local enchant = math.min(def.enchant, room)
    local firstHit = math.min(def.firstHit + (def.enchant - enchant), R.Weapon.firstHitMax)
    return enchant, firstHit
end

function L.MilestoneAtoms(profile, milestone, baseEnchant)
    if milestone == 0 or not profile then return {} end
    if profile == "weapon" then
        local e, fh = L.WeaponBonus(milestone, baseEnchant)
        local out = {}
        if e > 0 then out[#out + 1] = { "Enchant", e } end
        if fh > 0 then out[#out + 1] = { "FirstHit", fh } end
        return out
    end
    local t = R.MilestoneEffects[profile]
    return U.Copy(t and t[milestone] or {})
end

function L.AffixTier(slot, rarity)
    local t = R.AffixTier[slot]
    return t and t[rarity] or 0
end

-- Affixes that currently do something: { slot, id, tier, def }.
function L.ActiveAffixes(state)
    local out = {}
    for _, slot in ipairs(R.AffixSlots) do
        local id = state.affixes and state.affixes[slot]
        local def = id and R.AffixById[id]
        local tier = L.AffixTier(slot, state.rarity)
        if def and tier > 0 then
            out[#out + 1] = { slot = slot, id = id, tier = tier, def = def }
        end
    end
    return out
end

-- Statuses that live on the item itself (weapon enchantment, first-hit marker, elemental affixes).
function L.ItemStatuses(state)
    local out = {}
    if not state or not state.profile then return out end
    if state.profile == "weapon" then
        local e, fh = L.WeaponBonus(L.Milestone(state.level), state.baseEnchant)
        if e > 0 then out[#out + 1] = "EG_ENCH_" .. e end
        if fh > 0 then out[#out + 1] = "EG_FH_" .. fh end
    end
    for _, a in ipairs(L.ActiveAffixes(state)) do
        if a.def.target == "weapon" then out[#out + 1] = "EG_AFX_" .. a.id .. "_" .. a.tier end
    end
    table.sort(out)
    return out
end

-- Statuses for the character wearing the item in `slotKey`; second value: needs EG_WIELDER.
function L.WearerStatuses(state, slotKey)
    local out = {}
    if not state or not state.profile or not U.Contains(R.ProfileSlots[state.profile], slotKey) then
        return out, false
    end
    local m = L.Milestone(state.level)
    local wielder = false
    if state.profile == "weapon" then
        local _, fh = L.WeaponBonus(m, state.baseEnchant)
        wielder = fh > 0
    elseif m > 0 then
        out[#out + 1] = string.format("EG_MS_%s_%d_%s", state.profile:upper(), m, slotKey)
    end
    for _, a in ipairs(L.ActiveAffixes(state)) do
        if a.def.target == "wearer" then
            out[#out + 1] = string.format("EG_AFX_%s_%d_%s", a.id, a.tier, slotKey)
        end
    end
    table.sort(out)
    return out, wielder
end

-- Everything the item gives right now, for display: { atoms = {...}, affixes = {...} }.
function L.CurrentEffects(state)
    local atoms = L.MilestoneAtoms(state.profile, L.Milestone(state.level), state.baseEnchant)
    local affixes = {}
    for _, a in ipairs(L.ActiveAffixes(state)) do
        affixes[#affixes + 1] = { id = a.id, tier = a.tier, atoms = U.Copy(a.def.tiers[a.tier]) }
    end
    return { atoms = atoms, affixes = affixes }
end

---------------------------------------------------------------------------------------------------
-- Costs
---------------------------------------------------------------------------------------------------

function L.StepCost(profile, toLevel, rarity)
    local row = R.Steps[toLevel]
    if not row then return nil end
    local cheap = R.CheapProfiles[profile]
    local cost = {}
    for _, mat in ipairs({ "scrap", "dust", "ingot", "core" }) do
        local v = row[mat]
        if v and v > 0 then
            if mat == "scrap" and cheap then v = U.CeilPct(v, R.CheapPct) end
            cost[mat] = v
        end
    end
    local gold = row.gold or 0
    if cheap then gold = U.CeilPct(gold, R.CheapPct) end
    gold = U.CeilPct(gold, R.RarityGoldPct[rarity] or 100)
    if gold > 0 then cost.gold = gold end
    return cost
end

function L.ReforgeCost(profile, toRarity)
    local def = R.Reforge[toRarity]
    if not def then return nil end
    local cost = U.Copy(def.cost)
    if R.CheapProfiles[profile] and cost.gold then cost.gold = U.CeilPct(cost.gold, R.CheapPct) end
    return cost
end

function L.CanAfford(have, cost)
    for k, v in pairs(cost or {}) do
        if (have and have[k] or 0) < v then return false end
    end
    return true
end

function L.Missing(have, cost)
    local out = {}
    for k, v in pairs(cost or {}) do
        local h = have and have[k] or 0
        if h < v then out[k] = v - h end
    end
    return out
end

---------------------------------------------------------------------------------------------------
-- Ceiling and operations
---------------------------------------------------------------------------------------------------

function L.ProfileCap(item)
    local statsId = item.info and item.info.statsId
    local named = statsId and R.NamedItemCaps[statsId]
    if named then return named end
    if item.state.baseRarity >= 5 then return R.NaturalLegendaryCap end
    return R.MaxLevel
end

function L.TechCap(env)
    return R.TechCap[U.Clamp(U.Int(env and env.techTier, 1), 1, #R.TechCap)]
end

-- Lowest of rarity, forge technology and profile caps. On a tie we name the limit money cannot
-- remove: technology first, then profile, then rarity.
function L.Ceiling(item, env)
    local tech = L.TechCap(env)
    local profile = L.ProfileCap(item)
    local rarity = R.RarityCap[item.state.rarity] or R.MaxLevel
    local cap = math.min(tech, profile, rarity)
    local limiter = (tech == cap and "tech") or (profile == cap and "profile") or "rarity"
    return cap, limiter
end

local function cfgValue(env, key, default)
    local cfg = env and env.cfg
    if cfg == nil or cfg[key] == nil then return default end
    return cfg[key]
end

local function upgradeBlock(item, env)
    local s = item.state
    if not s.profile then return "unsupported" end
    if item.info and item.info.story and not cfgValue(env, "AllowStoryItemUpgrades", true) then return "story" end
    if s.level >= R.MaxLevel then return "max" end
    local cap, limiter = L.Ceiling(item, env)
    if s.level >= cap then return limiter .. "Cap" end
    return nil
end

function L.CheckUpgrade(item, env, have)
    local block = upgradeBlock(item, env)
    if block then return fail(block) end
    local s = item.state
    local cost = L.StepCost(s.profile, s.level + 1, s.rarity)
    local res = { cost = cost, toLevel = s.level + 1, milestone = L.IsMilestone(s.level + 1) }
    if not L.CanAfford(have, cost) then return fail("resources", res) end
    return okResult(res)
end

-- "Upgrade to +N": up to the next milestone or the ceiling. Steps are executed one by one.
function L.UpgradePlan(item, env, have)
    if upgradeBlock(item, env) then return nil end
    local s = item.state
    local cap = L.Ceiling(item, env)
    local target = math.min(L.NextMilestone(s.level) or R.MaxLevel, cap)
    if target <= s.level then return nil end
    local total, budget, affordable = {}, U.Copy(have or {}), 0
    local stillAffordable = true
    for lvl = s.level + 1, target do
        local c = L.StepCost(s.profile, lvl, s.rarity)
        U.AddBundle(total, c)
        if stillAffordable and L.CanAfford(budget, c) then
            U.AddBundle(budget, c, -1)
            affordable = affordable + 1
        else
            stillAffordable = false
        end
    end
    return { target = target, steps = target - s.level, cost = total, affordable = affordable }
end

function L.SlotOpenedBy(newRarity)
    for slot, r in pairs(R.AffixSlotOpensAt) do
        if r == newRarity then return slot end
    end
    return nil
end

function L.AllowedAffixes(state, slot)
    local out = {}
    if not state.profile then return out end
    local other = nil
    for _, s in ipairs(R.AffixSlots) do
        if s ~= slot and state.affixes and state.affixes[s] then other = R.AffixById[state.affixes[s]] end
    end
    for _, a in ipairs(R.Affixes) do
        if a.profiles[state.profile] and not (other and (other.id == a.id or other.group == a.group)) then
            out[#out + 1] = a.id
        end
    end
    return out
end

function L.CheckReforge(item, env, have, affixId)
    local s = item.state
    if not s.profile then return fail("unsupported") end
    if item.info and item.info.story and not cfgValue(env, "AllowStoryItemUpgrades", true) then return fail("story") end
    if s.rarity >= 5 then return fail("legendary") end
    local newRarity = s.rarity + 1
    local def = R.Reforge[newRarity]
    local cost = L.ReforgeCost(s.profile, newRarity)
    local opens = L.SlotOpenedBy(newRarity)
    local res = { cost = cost, toRarity = newRarity, opens = opens, newCap = R.RarityCap[newRarity],
        affixes = opens and L.AllowedAffixes(s, opens) or nil }
    if (U.Int(env and env.techTier, 1)) < def.tech then
        res.params = { def.tech }
        return fail("needTech", res)
    end
    if opens and not U.Contains(res.affixes, affixId) then return fail("badAffix", res) end
    if not L.CanAfford(have, cost) then return fail("resources", res) end
    return okResult(res)
end

function L.SalvageYield(state)
    local out = U.Copy(R.Salvage.base[state.rarity] or R.Salvage.base[1])
    local pct = R.Salvage.scrapPct[state.profile]
    if pct then out.scrap = U.FloorPct(out.scrap or 0, pct) end
    local bonus = R.Salvage.bonusDust[state.profile]
    if bonus then out.dust = (out.dust or 0) + bonus end
    local refunded = false
    for _, mat in ipairs(R.Salvage.refund) do
        local back = U.FloorPct(state.spent and state.spent[mat] or 0, R.Salvage.refundPct)
        if back > 0 then
            out[mat] = (out[mat] or 0) + back
            refunded = true
        end
    end
    return U.CleanBundle(out), refunded
end

function L.CheckSalvage(item, env)
    local s = item.state
    local info = item.info or {}
    if not s.profile then return fail("unsupported") end
    if info.story then return fail("story") end
    if info.equipped then return fail("equipped") end
    if info.foreign and not cfgValue(env, "AllowForeignModItems", false) then return fail("foreign") end
    local yield, refunded = L.SalvageYield(s)
    return okResult({ yield = yield, refunded = refunded })
end

function L.CheckSmelt(env, have)
    local res = { cost = U.Copy(R.Smelt.cost), output = U.Copy(R.Smelt.output) }
    if U.Int(env and env.techTier, 1) < R.Smelt.tech then
        res.params = { R.Smelt.tech }
        return fail("needTech", res)
    end
    if not L.CanAfford(have, res.cost) then return fail("resources", res) end
    return okResult(res)
end

function L.CheckSetProfile(item, profile)
    local allowed = L.DetectProfiles(item.info)
    if not allowed or not U.Contains(allowed, profile) then return fail("unsupported") end
    if item.state.profile == profile then return okResult({ same = true }) end
    if L.Invested(item.state) then return fail("profileLocked") end
    return okResult()
end

function L.ApplyUpgrade(state, cost)
    local s = U.Copy(state)
    s.level = math.min(s.level + 1, R.MaxLevel)
    s.spent = U.AddBundle(s.spent or {}, cost)
    return s
end

function L.ApplyReforge(state, affixId, cost)
    local s = U.Copy(state)
    s.rarity = math.min(s.rarity + 1, 5)
    local opens = L.SlotOpenedBy(s.rarity)
    s.affixes = s.affixes or {}
    if opens and affixId then s.affixes[opens] = affixId end
    s.spent = U.AddBundle(s.spent or {}, cost)
    return s
end

---------------------------------------------------------------------------------------------------
-- Campaign helpers
---------------------------------------------------------------------------------------------------

function L.TechForLevel(levelName)
    return R.TechByLevel[levelName or ""] or 0
end

-- rng(): float in [0,1); rng(a, b): integer in [a, b] (same contract as math.random).
function L.RollKillLoot(enemyLevel, multiplier, rng)
    rng = rng or math.random
    local out = {}
    for _, row in ipairs(R.Loot.kill) do
        if (enemyLevel or 1) >= row.minLevel then
            local chance = row.chance * (multiplier or 1)
            if rng() * 100 < chance then
                out[row.mat] = (out[row.mat] or 0) + rng(row.min, row.max)
            end
        end
    end
    return out
end

-- Total price from +0 to a milestone with the minimal reforges in between (docs and tests).
function L.MilestoneTotal(profile, milestone)
    local state = { level = 0, rarity = 1, baseRarity = 1, profile = profile, affixes = {}, spent = {} }
    local total = {}
    for lvl = 1, milestone do
        while R.RarityCap[state.rarity] < lvl do
            U.AddBundle(total, L.ReforgeCost(profile, state.rarity + 1))
            state.rarity = state.rarity + 1
        end
        U.AddBundle(total, L.StepCost(profile, lvl, state.rarity))
    end
    return total, state.rarity
end

EG.Logic = L
return L
