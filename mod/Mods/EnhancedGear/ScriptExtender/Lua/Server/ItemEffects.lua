-- Puts effects on characters and items. Never "adds a bonus": the desired set of statuses is
-- computed from scratch and compared with what is there, so repeated syncs cannot stack bonuses.
EG = EG or {}
local Ids = EG.Ids
local R = EG.Rules
local L = EG.Logic
local U = EG.Util
local Game = EG.Game
local Data = EG.Data
local Config = EG.Config
local Effects = EG.Effects
local ItemState = EG.ItemState
local IE = {}

local function sync(obj, desired, universe)
    local applied, removed = 0, 0
    for _, id in ipairs(universe) do
        local has = Game.HasStatus(obj, id)
        if desired[id] and not has then
            Game.ApplyStatus(obj, id)
            applied = applied + 1
        elseif has and not desired[id] then
            Game.RemoveStatus(obj, id)
            removed = removed + 1
        end
    end
    return applied, removed
end

function IE.SyncItem(item, state)
    if state == nil then state = ItemState.Read(item) end
    local desired = U.Set(state and L.ItemStatuses(state) or {})
    return sync(item, desired, Effects.ItemIds())
end

-- Desired statuses of a character from what is equipped in each slot.
function IE.Desired(char)
    local desired, wielder = {}, false
    for slot, item in pairs(Game.Equipped(char)) do
        local state = ItemState.Read(item)
        if state then
            local list, w = L.WearerStatuses(state, slot)
            for _, id in ipairs(list) do desired[id] = true end
            wielder = wielder or w
            IE.SyncItem(item, state)
        end
    end
    if wielder then desired[Ids.Status.Wielder] = true end
    return desired
end

function IE.SyncCharacter(char)
    if not char or not Game.Exists(char) then return 0, 0 end
    return sync(char, IE.Desired(char), Effects.WearerIds())
end

function IE.SyncParty()
    for _, c in ipairs(Game.Party()) do IE.SyncCharacter(c) end
end

---------------------------------------------------------------------------------------------------
-- Rarity colour of the instance (only for items whose rarity the forge raised)
---------------------------------------------------------------------------------------------------

function IE.ColorFor(state)
    if not Config.Get("ExperimentalRarityColor") or state.rarity <= state.baseRarity then return nil end
    return R.EngineRarity[state.rarity]
end

-- Returns the written engine value or nil.
function IE.SyncColor(item, state, force)
    local want = IE.ColorFor(state)
    if want == nil or not Game.Exists(item) then return nil end
    if not force and Game.GetRarity(item) == want then return nil end
    Game.SetRarity(item, want, Config.Get("RarityColorRefresh"))
    return want
end

function IE.SyncAllColors()
    local out = {}
    for guid, state in pairs(Data.Get().index) do
        local v = IE.SyncColor(guid, state, true)
        if v then out[#out + 1] = { guid = guid, rarity = v } end
    end
    return out
end

---------------------------------------------------------------------------------------------------
-- !eg_cleanup: remove every status of the mod, restore names and colours. Item data stays.
---------------------------------------------------------------------------------------------------

function IE.Cleanup()
    local count = 0
    for _, c in ipairs(Game.Party()) do
        local _, removed = sync(c, {}, Effects.WearerIds())
        count = count + removed
    end
    for guid, state in pairs(Data.Get().index) do
        if Game.Exists(guid) then
            local _, removed = sync(guid, {}, Effects.ItemIds())
            count = count + removed
            EG.Names.Restore(guid, state)
            if state.rarity > state.baseRarity then
                Game.SetRarity(guid, R.EngineRarity[state.baseRarity], Config.Get("RarityColorRefresh"))
            end
        end
    end
    return count
end

EG.ItemEffects = IE
return IE
