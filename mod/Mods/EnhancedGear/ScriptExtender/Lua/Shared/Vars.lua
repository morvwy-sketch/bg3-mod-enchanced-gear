-- Script Extender variables: per-item state (user variable) and campaign data (mod variable).
-- Both are server-only and saved with the game. SE copies tables on read, so every change must
-- be written back by assigning the whole table.
EG = EG or {}
local Ids = EG.Ids
local V = {}

local opts = { Server = true, Client = false, WriteableOnServer = true, WriteableOnClient = false,
    Persistent = true, SyncToClient = false, SyncToServer = false }

-- Must run in both bootstraps before a save is loaded, with identical settings.
function V.Register()
    Ext.Vars.RegisterUserVariable(Ids.UserVar, opts)
    Ext.Vars.RegisterModVariable(Ids.ModuleUUID, Ids.ModVar, opts)
end

local function entity(guid)
    if not guid then return nil end
    local ok, e = pcall(Ext.Entity.Get, guid)
    if ok then return e end
    return nil
end

function V.GetItem(guid)
    local e = entity(guid)
    if not e or not e.Vars then return nil end
    return e.Vars[Ids.UserVar]
end

function V.SetItem(guid, value)
    local e = entity(guid)
    if not e or not e.Vars then return false end
    e.Vars[Ids.UserVar] = value
    return true
end

function V.GetMod()
    local mv = Ext.Vars.GetModVariables(Ids.ModuleUUID)
    return mv and mv[Ids.ModVar] or nil
end

function V.SetMod(value)
    local mv = Ext.Vars.GetModVariables(Ids.ModuleUUID)
    if not mv then return false end
    mv[Ids.ModVar] = value
    return true
end

EG.Vars = V
return V
