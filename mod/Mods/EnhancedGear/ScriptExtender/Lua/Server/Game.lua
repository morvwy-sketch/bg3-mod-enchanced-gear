-- Engine adapter: every Osiris / Ext call of the server lives here.
-- The rest of the server works with plain GUID strings and tables.
EG = EG or {}
local Ids = EG.Ids
local R = EG.Rules
local U = EG.Util
local G = {}

local function truthy(v) return v == 1 or v == true end

local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

function G.Log(fmt, ...)
    Ext.Utils.Print("[EnhancedGear] " .. string.format(fmt, ...))
end

function G.Error(fmt, ...)
    Ext.Utils.PrintError("[EnhancedGear] " .. string.format(fmt, ...))
end

function G.Debug(fmt, ...)
    if EG.Config and EG.Config.Get("Debug") then G.Log(fmt, ...) end
end

---------------------------------------------------------------------------------------------------
-- Entities and characters
---------------------------------------------------------------------------------------------------

function G.Entity(guid)
    if type(guid) ~= "string" or guid == "" then return nil end
    return try(Ext.Entity.Get, guid)
end

function G.Exists(guid)
    return G.Entity(guid) ~= nil
end

function G.GuidOf(entity)
    return entity and entity.Uuid and entity.Uuid.EntityUuid or nil
end

function G.Host()
    return U.BareGuid(try(Osi.GetHostCharacter))
end

-- Active party (DB_Players), host first.
function G.Party()
    local out, seen = {}, {}
    local function push(g)
        g = U.BareGuid(g)
        if g and not seen[g] then
            seen[g] = true
            out[#out + 1] = g
        end
    end
    push(G.Host())
    local rows = try(function() return Osi.DB_Players:Get(nil) end) or {}
    for _, row in ipairs(rows) do push(row[1]) end
    return out
end

function G.IsPartyMember(guid)
    if not guid then return false end
    return truthy(try(Osi.IsPartyMember, guid, 1))
end

function G.InCombat(guid)
    return truthy(try(Osi.IsInCombat, guid))
end

function G.IsBoss(guid) return truthy(try(Osi.IsBoss, guid)) end
function G.IsSummon(guid) return truthy(try(Osi.IsSummon, guid)) end
function G.Level(guid) return try(Osi.GetLevel, guid) or 1 end

function G.IsEnemyOfHost(guid)
    local host = G.Host()
    return host ~= nil and truthy(try(Osi.IsEnemy, guid, host))
end

function G.Name(guid)
    local handle = try(Osi.GetDisplayName, guid)
    if type(handle) ~= "string" or handle == "" then return "" end
    return try(Ext.Loca.GetTranslatedString, handle, handle) or handle
end

function G.UserCharacter(user)
    if user == nil then return nil end
    return U.BareGuid(try(Osi.GetCurrentCharacter, user))
end

function G.CharacterUser(guid)
    local e = G.Entity(guid)
    if not e then return nil end
    local id = try(function() return e.UserReservedFor.UserID end)
        or try(function() return e.PartyMember.UserID end)
    return id
end

---------------------------------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------------------------------

function G.Equipped(guid)
    local out = {}
    for _, key in ipairs(R.SlotOrder) do
        local item = U.BareGuid(try(Osi.GetEquippedItem, guid, R.SlotEngine[key]))
        if item and item ~= "" then out[key] = item end
    end
    return out
end

-- Items in all inventories of a holder, including nested bags (up to maxDepth levels).
function G.InventoryItems(holder, maxDepth)
    local out, seen = {}, {}
    local function walk(e, depth)
        local owner = e and e.InventoryOwner
        if not owner then return end
        for _, inv in pairs(owner.Inventories or {}) do
            local container = inv.InventoryContainer
            for _, slot in pairs(container and container.Items or {}) do
                local item = slot.Item
                local g = G.GuidOf(item)
                if g and not seen[g] then
                    seen[g] = true
                    out[#out + 1] = g
                    if depth < maxDepth then walk(item, depth + 1) end
                end
            end
        end
    end
    walk(G.Entity(holder), 0)
    return out
end

function G.Template(guid)
    return U.BareGuid(try(Osi.GetTemplate, guid))
end

function G.IsStoryItem(guid)
    return truthy(try(Osi.IsStoryItem, guid))
end

local vanillaModules = U.Set({
    "991c9c7a-fb80-40cb-8f0d-b92d4e80e9b1", -- Gustav
    "28ac9ce2-2aba-8cda-b3b5-6e922f71b6b8", -- GustavDev
    "ed539163-bb70-431b-96a7-f5b2eda5376b", -- Shared
    "3d0c5ff8-c95d-c907-ff3e-34b204f1c630", -- SharedDev
    "9dff4c3b-fda7-43de-a763-ce1383039999", -- Engine
    "630daa32-70f8-3da5-41b9-154fe8410236", -- MainUI
})
local vanillaNames = U.Set({ "Gustav", "GustavDev", "GustavX", "Shared", "SharedDev", "Engine", "MainUI", "Honour",
    "HonourX", "ModBrowser" })

function G.IsForeignMod(modId)
    if type(modId) ~= "string" or modId == "" or vanillaModules[modId] or modId == Ids.ModuleUUID then return false end
    local info = try(function() return Ext.Mod.GetMod(modId).Info end)
    if info then
        local author = tostring(info.Author or "")
        local name = tostring(info.Name or "")
        if author == "LS" or author:find("Larian", 1, true) or vanillaNames[name] or name:find("^DiceSet") then
            return false
        end
    end
    return true
end

local function statField(stat, key)
    return try(function() return stat[key] end)
end

-- Everything Logic needs to know about an item, plus display data.
function G.ItemInfo(guid)
    local e = G.Entity(guid)
    if not e then return nil end
    local statsId = try(function() return e.Data.StatsId end) or try(Osi.GetStatString, guid)
    local info = { guid = guid, statsId = statsId, name = G.Name(guid), story = G.IsStoryItem(guid) }
    info.icon = try(function() return e.Icon.Icon end) or try(function() return e.GameObjectVisual.Icon end) or ""
    info.nameHandle = G.NameHandle(guid)
    local stat = statsId and try(Ext.Stats.Get, statsId, nil, false)
    if not stat then return info end
    local modifier = statField(stat, "ModifierList")
    info.kind = (modifier == "Weapon" and "weapon") or (modifier == "Armor" and "armor") or nil
    info.slot = statField(stat, "Slot")
    info.rarity = R.StatsRarity[statField(stat, "Rarity") or ""] or 1
    local boosts = tostring(statField(stat, "Boosts") or "") .. ";" .. tostring(statField(stat, "DefaultBoosts") or "")
    info.caster = boosts:find("SpellSaveDC", 1, true) ~= nil or boosts:find("SpellAttack", 1, true) ~= nil
    local enchant = 0
    for n in boosts:gmatch("WeaponEnchantment%((%d+)%)") do enchant = math.max(enchant, tonumber(n)) end
    info.enchant = enchant
    local prof = tostring(statField(stat, "Proficiency Group") or "")
    info.staff = info.kind == "weapon" and (prof:find("Quarterstaff", 1, true) ~= nil or statsId:find("Quarterstaff", 1, true) ~= nil)
    info.foreign = G.IsForeignMod(statField(stat, "OriginalModId") or statField(stat, "ModId"))
    return info
end

---------------------------------------------------------------------------------------------------
-- Templates (materials and gold are stackable template items)
---------------------------------------------------------------------------------------------------

function G.CountTemplate(holder, template)
    return try(Osi.TemplateIsInInventory, template, holder) or 0
end

function G.AddTemplate(holder, template, count, notify)
    if count <= 0 then return end
    Osi.TemplateAddTo(template, holder, count, notify and 1 or 0)
end

function G.RemoveTemplate(holder, template, count)
    if count <= 0 then return end
    Osi.TemplateRemoveFrom(template, holder, count)
end

function G.Delete(item)
    Osi.RequestDelete(item)
end

---------------------------------------------------------------------------------------------------
-- Statuses
---------------------------------------------------------------------------------------------------

function G.ApplyStatus(obj, status)
    Osi.ApplyStatus(obj, status, -1, 1, obj)
end

function G.RemoveStatus(obj, status)
    Osi.RemoveStatus(obj, status)
end

function G.HasStatus(obj, status)
    return truthy(try(Osi.HasActiveStatus, obj, status))
end

---------------------------------------------------------------------------------------------------
-- Names and rarity colour of one item instance
---------------------------------------------------------------------------------------------------

function G.NameHandle(item)
    local e = G.Entity(item)
    return e and try(function() return e.DisplayName.NameKey.Handle.Handle end) or nil
end

function G.SetLoca(handle, text)
    try(Ext.Loca.UpdateTranslatedString, handle, text)
end

function G.GetLoca(handle)
    if not handle then return nil end
    return try(Ext.Loca.GetTranslatedString, handle, "")
end

-- Same technique as "Preemptively Label Containers": a per-instance handle on DisplayName.
function G.SetNameHandle(item, handle)
    local e = G.Entity(item)
    if not e or not e.DisplayName then return false end
    if e.DisplayName.NameKey.Handle.Handle ~= handle then
        e.DisplayName.NameKey.Handle.Handle = handle
        e:Replicate("DisplayName")
    end
    return true
end

-- Engine colour scale 0..4. Clients redraw only after a Health update ("Fallen Mark As Read").
function G.GetRarity(item)
    local e = G.Entity(item)
    return e and try(function() return e.Value.Rarity end) or nil
end

function G.SetRarity(item, value, refresh)
    local e = G.Entity(item)
    if not e or not e.Value then return false end
    e.Value.Rarity = value
    e:Replicate("Value")
    if refresh then
        if not e.Health then e:CreateComponent("Health") end
        e:Replicate("Health")
    end
    return true
end

---------------------------------------------------------------------------------------------------
-- Misc
---------------------------------------------------------------------------------------------------

function G.Notify(guid, text)
    if not guid then return end
    if not pcall(Osi.ShowNotification, guid, text) then pcall(Osi.OpenMessageBox, guid, text) end
end

function G.After(ms, fn)
    return Ext.Timer.WaitFor(ms, fn)
end

function G.Now()
    return Ext.Utils.MonotonicTime()
end

EG.Game = G
return G
