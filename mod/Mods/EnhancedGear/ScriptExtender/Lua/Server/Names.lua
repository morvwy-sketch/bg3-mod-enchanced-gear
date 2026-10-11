-- "Chain Mail +19": a per-instance localization handle (<original>_EG_<item guid>).
-- Such strings live only in memory, so they are registered again on every load.
EG = EG or {}
local Ids = EG.Ids
local Game = EG.Game
local Data = EG.Data
local Config = EG.Config
local N = {}

function N.OriginalHandle(handle)
    if type(handle) ~= "string" then return nil end
    local i = handle:find(Ids.NameSuffix, 1, true)
    if i then return handle:sub(1, i - 1) end
    return handle
end

function N.InstanceHandle(guid, state)
    return state.nameHandle .. Ids.NameSuffix .. guid
end

function N.Text(state)
    return string.format("%s +%d", state.baseName, state.level)
end

-- Remember the original name before the first rename. Returns true if the state changed.
function N.Capture(guid, state)
    if state.nameHandle and state.baseName then return false end
    local original = N.OriginalHandle(Game.NameHandle(guid))
    state.nameHandle = state.nameHandle or original
    local text = original and Game.GetLoca(original)
    if not text or text == "" then text = Game.Name(guid) end
    state.baseName = state.baseName or text
    return true
end

local function renamable(state)
    return Config.Get("ExperimentalRename") and state.level > 0 and type(state.nameHandle) == "string"
        and type(state.baseName) == "string" and state.baseName ~= ""
end

-- Registers the string and points the item at it. Returns { handle, text } for the clients.
function N.Apply(guid, state)
    if not renamable(state) then return nil end
    local entry = { handle = N.InstanceHandle(guid, state), text = N.Text(state) }
    Game.SetLoca(entry.handle, entry.text)
    if Game.Exists(guid) then Game.SetNameHandle(guid, entry.handle) end
    return entry
end

function N.Restore(guid, state)
    if state.nameHandle and Game.Exists(guid) then Game.SetNameHandle(guid, state.nameHandle) end
end

-- Every forged item of the campaign (also outside the party), for load and for clients.
function N.RegisterAll()
    local entries = {}
    for guid, state in pairs(Data.Get().index) do
        if Config.Get("ExperimentalRename") then
            local e = N.Apply(guid, state)
            if e then entries[#entries + 1] = e end
        else
            N.Restore(guid, state)
        end
    end
    table.sort(entries, function(a, b) return a.handle < b.handle end)
    return entries
end

EG.Names = N
return N
