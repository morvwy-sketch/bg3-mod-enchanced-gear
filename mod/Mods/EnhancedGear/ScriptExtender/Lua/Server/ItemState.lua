-- State of one item instance: user variable EG_ItemState on the item, mirrored in the campaign index.
-- Items the forge never touched have no state.
EG = EG or {}
local Vars = EG.Vars
local Data = EG.Data
local Game = EG.Game
local L = EG.Logic
local U = EG.Util
local S = {}

-- Stored state (normalized) or nil. Falls back to the campaign index if the variable got lost.
function S.Read(guid, info)
    local raw = Vars.GetItem(guid)
    local restored = false
    if raw == nil then
        raw = Data.Get().index[guid]
        if raw == nil then return nil end
        restored = true
        Game.Log("restoring state of %s from the campaign index", guid)
    end
    -- A broken profile can only be reset to the item's default when we know what the item is.
    if info == nil and (type(raw) ~= "table" or not L.ValidProfile(raw.profile)) then info = Game.ItemInfo(guid) end
    local state, changed = L.Normalize(U.Copy(raw), info)
    if changed or restored then S.Write(guid, state) end
    return state
end

-- Stored state or a fresh default (not saved). Second value: true when fresh.
function S.Get(guid, info)
    local state = S.Read(guid, info)
    if state then return state, false end
    return L.NewState(info), true
end

function S.Write(guid, state)
    Vars.SetItem(guid, U.Copy(state))
    Data.Update(function(d) d.index[guid] = U.Copy(state) end)
end

function S.Forget(guid)
    Vars.SetItem(guid, nil)
    Data.Update(function(d) d.index[guid] = nil end)
end

EG.ItemState = S
return S
