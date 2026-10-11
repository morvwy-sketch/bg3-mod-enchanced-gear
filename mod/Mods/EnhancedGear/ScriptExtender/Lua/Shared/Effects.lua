-- Status catalog: every status and passive the mod can apply, built from Rules.lua.
-- tools/generate.lua writes it to Stats; the server only applies ids that exist here.
EG = EG or {}
local R = EG.Rules
local L = EG.Logic
local Ids = EG.Ids
local E = {}

-- Flags from the guide: not over the head, not in the combat log, survive long rest and death.
E.Flags = "DisableOverhead;DisableCombatlog;IgnoreResting;ApplyToDead"
E.HiddenFlags = "DisableOverhead;DisableCombatlog;DisablePortraitIndicator"

local function num(v)
    if math.type(v) == "float" and v == math.floor(v) then return tostring(math.floor(v)) end
    return tostring(v)
end

-- Effect atom -> BG3 boost string.
function E.AtomBoost(atom)
    local k = atom[1]
    if k == "AC" then return "AC(" .. num(atom[2]) .. ")" end
    if k == "MaxHP" then return "IncreaseMaxHP(" .. num(atom[2]) .. ")" end
    if k == "Save" then return "RollBonus(SavingThrow," .. num(atom[3]) .. "," .. atom[2] .. ")" end
    if k == "Skill" then return "Skill(" .. atom[2] .. "," .. num(atom[3]) .. ")" end
    if k == "Initiative" then return "Initiative(" .. num(atom[2]) .. ")" end
    if k == "Movement" then return "ActionResource(Movement," .. num(atom[2]) .. ",0)" end
    if k == "SpellAttack" then
        return "RollBonus(MeleeSpellAttack," .. num(atom[2]) .. ");RollBonus(RangedSpellAttack," .. num(atom[2]) .. ")"
    end
    if k == "SpellDC" then return "SpellSaveDC(" .. num(atom[2]) .. ")" end
    if k == "ReduceAll" then return "DamageReduction(All,Flat," .. num(atom[2]) .. ")" end
    if k == "Reduce" then return "DamageReduction(" .. atom[2] .. ",Flat," .. num(atom[3]) .. ")" end
    if k == "Resist" then return "Resistance(" .. atom[2] .. ",Resistant)" end
    if k == "WeaponDamage" then return "WeaponDamage(" .. atom[2] .. "," .. atom[3] .. ")" end
    if k == "Enchant" then return "WeaponEnchantment(" .. num(atom[2]) .. ");WeaponProperty(Magical)" end
    if k == "FirstHit" then return "" end
    error("unknown effect atom " .. tostring(k))
end

function E.AtomsBoosts(atoms)
    local parts = {}
    for _, a in ipairs(atoms) do
        local b = E.AtomBoost(a)
        if b ~= "" then parts[#parts + 1] = b end
    end
    return table.concat(parts, ";")
end

local function passiveId(n) return "EG_FirstHit_" .. n end

-- First-hit damage per attack hand; the weapon used must carry the EG_FH_<n> marker.
function E.FirstHitPassive(n)
    local marker = "EG_FH_" .. n
    return {
        id = passiveId(n),
        n = n,
        properties = "OncePerTurn",
        context = "OnAttack",
        conditions = string.format(
            "IsWeaponAttack() and HasDamageEffectFlag(DamageFlags.Hit) and HasStatus('%s', GetAttackWeapon(context.Source))",
            marker),
        functors = string.format(
            "IF(IsRangedWeaponAttack()):DealDamage(%d,MainRangedWeaponDamageType);"
            .. "IF(IsMeleeWeaponAttack() and not IsOffHandAttack()):DealDamage(%d,MainMeleeWeaponDamageType);"
            .. "IF(IsMeleeWeaponAttack() and IsOffHandAttack()):DealDamage(%d,OffhandMeleeWeaponDamageType)",
            n, n, n),
    }
end

local catalog = nil

function E.Build()
    if catalog then return catalog end
    local statuses, byId = {}, {}
    local function add(s)
        assert(not byId[s.id], "duplicate status " .. s.id)
        s.flags = s.flags or E.Flags
        statuses[#statuses + 1] = s
        byId[s.id] = s
    end

    -- On the weapon.
    for n = 1, R.Weapon.enchantCap do
        add({ id = "EG_ENCH_" .. n, kind = "ench", target = "item", n = n,
            boosts = E.AtomBoost({ "Enchant", n }), icon = Ids.Items.kit.icon })
    end
    for n = 1, R.Weapon.firstHitMax do
        add({ id = "EG_FH_" .. n, kind = "fh", target = "item", n = n, boosts = "", icon = Ids.Items.kit.icon })
    end
    for _, a in ipairs(R.Affixes) do
        if a.target == "weapon" then
            for tier = 1, #a.tiers do
                add({ id = "EG_AFX_" .. a.id .. "_" .. tier, kind = "afx", target = "item", affix = a.id, tier = tier,
                    atoms = a.tiers[tier], boosts = E.AtomsBoosts(a.tiers[tier]), icon = Ids.Items.dust.icon })
            end
        end
    end

    -- On the character.
    local passives = {}
    for n = 1, R.Weapon.firstHitMax do passives[#passives + 1] = passiveId(n) end
    add({ id = Ids.Status.Wielder, kind = "wielder", target = "wearer", boosts = "",
        passives = table.concat(passives, ";"), icon = Ids.Items.kit.icon })

    for _, profile in ipairs(R.Profiles) do
        local effects = R.MilestoneEffects[profile]
        if effects then
            for _, m in ipairs(R.Milestones) do
                for _, slot in ipairs(R.ProfileSlots[profile]) do
                    add({ id = string.format("EG_MS_%s_%d_%s", profile:upper(), m, slot), kind = "ms", target = "wearer",
                        profile = profile, milestone = m, slot = slot, atoms = effects[m],
                        boosts = E.AtomsBoosts(effects[m]), icon = Ids.Items.kit.icon })
                end
            end
        end
    end

    for _, a in ipairs(R.Affixes) do
        if a.target == "wearer" then
            local slots = {}
            for _, profile in ipairs(R.Profiles) do
                if a.profiles[profile] then
                    for _, slot in ipairs(R.ProfileSlots[profile]) do slots[slot] = true end
                end
            end
            for tier = 1, #a.tiers do
                for _, slot in ipairs(R.SlotOrder) do
                    if slots[slot] then
                        add({ id = string.format("EG_AFX_%s_%d_%s", a.id, tier, slot), kind = "afx", target = "wearer",
                            affix = a.id, tier = tier, slot = slot, atoms = a.tiers[tier],
                            boosts = E.AtomsBoosts(a.tiers[tier]), icon = Ids.Items.dust.icon })
                    end
                end
            end
        end
    end

    add({ id = Ids.Status.ForgeOpen, kind = "open", target = "hidden", boosts = "", flags = E.HiddenFlags,
        icon = Ids.Items.kit.icon })

    local passiveList = {}
    for n = 1, R.Weapon.firstHitMax do passiveList[#passiveList + 1] = E.FirstHitPassive(n) end

    local wearer, item = {}, {}
    for _, s in ipairs(statuses) do
        if s.target == "wearer" then wearer[#wearer + 1] = s.id end
        if s.target == "item" then item[#item + 1] = s.id end
    end

    catalog = { statuses = statuses, byId = byId, passives = passiveList, wearerIds = wearer, itemIds = item }
    return catalog
end

function E.Exists(id)
    return E.Build().byId[id] ~= nil
end

function E.WearerIds() return E.Build().wearerIds end
function E.ItemIds() return E.Build().itemIds end

-- Every status id Logic can produce for a state, for the catalog completeness test.
function E.Produced(state)
    local out = {}
    for _, id in ipairs(L.ItemStatuses(state)) do out[#out + 1] = id end
    for _, slot in ipairs(R.SlotOrder) do
        local list, wielder = L.WearerStatuses(state, slot)
        for _, id in ipairs(list) do out[#out + 1] = id end
        if wielder then out[#out + 1] = Ids.Status.Wielder end
    end
    return out
end

EG.Effects = E
return E
