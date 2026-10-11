-- Campaign data (mod variable "EnhancedGear"): forge technology, one-time rewards already given,
-- the operation journal and a backup index of every forged item's state.
EG = EG or {}
local Vars = EG.Vars
local L = EG.Logic
local U = EG.Util
local D = {}

D.Version = 1

function D.Empty()
    return { v = D.Version, techTier = 1, regions = {}, bosses = {}, killed = {}, kitGranted = false,
        journal = nil, index = {} }
end

-- Old or damaged data -> current schema. Returns data, changed.
function D.Normalize(raw)
    local d = D.Empty()
    if type(raw) ~= "table" then return d, true end
    d.techTier = U.Clamp(U.Int(raw.techTier, 1), 1, 4)
    for _, key in ipairs({ "regions", "bosses", "killed" }) do
        if type(raw[key]) == "table" then
            for k, v in pairs(raw[key]) do
                if v then d[key][tostring(k)] = true end
            end
        end
    end
    d.kitGranted = raw.kitGranted == true
    if type(raw.journal) == "table" and type(raw.journal.op) == "string" then d.journal = U.Copy(raw.journal) end
    if type(raw.index) == "table" then
        for guid, state in pairs(raw.index) do
            if type(guid) == "string" and type(state) == "table" then
                d.index[guid] = (L.Normalize(U.Copy(state), nil))
            end
        end
    end
    return d, not U.Equal(raw, d)
end

function D.Get()
    return (D.Normalize(Vars.GetMod()))
end

function D.Put(d)
    Vars.SetMod(U.Copy(d))
end

-- Read-modify-write; SE hands out copies, so the whole table is written back.
function D.Update(fn)
    local d = D.Get()
    local res = fn(d)
    D.Put(d)
    return res
end

function D.Migrate()
    local d, changed = D.Normalize(Vars.GetMod())
    if changed then D.Put(d) end
    return d
end

function D.TechTier(d)
    local override = EG.Config.Get("TechTierOverride")
    if type(override) == "number" and override >= 1 then return override end
    return (d or D.Get()).techTier
end

EG.Data = D
return D
