-- Client wiring: toggle key, names and rarity colours from the server, client console commands.
EG = EG or {}
local Ids = EG.Ids
local U = EG.Util
local I18N = EG.I18N
local Config = EG.Config
local Net = EG.Net
local ForgeUI = EG.ForgeUI
local CM = {}

local function log(fmt, ...) Ext.Utils.Print("[EnhancedGear] " .. string.format(fmt, ...)) end

-- The character this client controls right now.
function CM.Controlled()
    local ok, list = pcall(Ext.Entity.GetAllEntitiesWithComponent, "ClientControl")
    if ok and list then
        for _, e in pairs(list) do
            local guid = e.Uuid and e.Uuid.EntityUuid
            if guid then return guid end
        end
    end
    return nil
end

function CM.ResolveLanguage()
    local ok, marker = pcall(Ext.Loca.GetTranslatedString, U.Handle("lang.marker"), "")
    local game = (ok and marker == "uk") and "uk" or "en"
    return I18N.SetLanguage(I18N.Resolve(Config.Get("Language"), game))
end

function CM.OnPush(msg)
    if msg.op == "names" then
        for _, e in ipairs(msg.entries or {}) do
            pcall(Ext.Loca.UpdateTranslatedString, e.handle, e.text)
        end
    elseif msg.op == "rarity" then
        for _, e in ipairs(msg.entries or {}) do
            pcall(function()
                local entity = Ext.Entity.Get(e.guid)
                if entity and entity.Value then entity.Value.Rarity = e.rarity end
            end)
        end
    else
        ForgeUI.OnPush(msg)
    end
end

function CM.RequestNames()
    pcall(Net.SendToServer, Ids.Channels.request, { op = "names" })
end

-- !eg_rarity: what this client sees for the items of the open forge list.
function CM.DumpRarity()
    local items = ForgeUI.State.items or {}
    if #items == 0 then log("open the forge first: the list is empty") end
    for _, item in ipairs(items) do
        local ok, value = pcall(function() return Ext.Entity.Get(item.guid).Value.Rarity end)
        log("%s | %s | forge rarity %d | engine colour %s", item.guid, U.FontSafe(item.name or ""), item.state.rarity,
            ok and tostring(value) or "?")
    end
end

function CM.Init()
    Config.Load()
    CM.ResolveLanguage()
    Net.Init()
    Net.On(Ids.Channels.push, CM.OnPush)

    Ext.Events.KeyInput:Subscribe(function(e)
        if e.Event == "KeyDown" and not e.Repeat and tostring(e.Key) == Config.Get("ToggleKey") then
            ForgeUI.Toggle(CM.Controlled())
        end
    end)
    Ext.Events.SessionLoaded:Subscribe(function()
        CM.ResolveLanguage()
        log("client loaded (language %s, forge key %s)", I18N.Lang, Config.Get("ToggleKey"))
    end)
    -- Name strings live only in memory: ask for them after every load.
    pcall(function()
        Ext.Events.GameStateChanged:Subscribe(function(e)
            if tostring(e.ToState) == "Running" then CM.RequestNames() end
        end)
    end)

    Ext.RegisterConsoleCommand("eg_ui", function() ForgeUI.Toggle(CM.Controlled()) end)
    Ext.RegisterConsoleCommand("eg_rarity", function() CM.DumpRarity() end)
end

EG.ClientMain = CM
return CM
