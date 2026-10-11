-- Two channels: EG_Request (window -> server) and EG_Push (server -> window).
-- Uses Ext.Net.CreateChannel (SE v22+) and falls back to the old string messages on older versions.
EG = EG or {}
local Ids = EG.Ids
local N = {}

N.Mode = nil
local channels = {}
local handlers = {}

local function hasChannels()
    return Ext.Net ~= nil and type(Ext.Net.CreateChannel) == "function"
end

local function decode(payload)
    if type(payload) == "string" then
        local ok, res = pcall(Ext.Json.Parse, payload)
        if ok then return res end
        return nil
    end
    return payload
end

local function dispatch(name, payload, user)
    local fn = handlers[name]
    local data = decode(payload)
    if fn and type(data) == "table" then
        local ok, err = pcall(fn, data, user)
        if not ok then Ext.Utils.PrintError("[EnhancedGear] net handler " .. name .. ": " .. tostring(err)) end
    end
end

-- Call once per context. Handlers: fn(data, userId).
function N.Init()
    if N.Mode then return end
    if hasChannels() then
        N.Mode = "channel"
        for _, name in pairs(Ids.Channels) do
            local ch = Ext.Net.CreateChannel(Ids.ModuleUUID, name)
            ch:SetHandler(function(data, user) dispatch(name, data, user) end)
            channels[name] = ch
        end
    else
        N.Mode = "legacy"
        for _, name in pairs(Ids.Channels) do
            Ext.RegisterNetListener(name, function(_, payload, user) dispatch(name, payload, user) end)
        end
    end
end

function N.On(name, fn)
    handlers[name] = fn
end

function N.SendToServer(name, data)
    if N.Mode == "channel" then
        channels[name]:SendToServer(data)
    else
        Ext.ClientNet.PostMessageToServer(name, Ext.Json.Stringify(data))
    end
end

function N.SendToUser(user, name, data)
    if user == nil then return N.Broadcast(name, data) end
    if N.Mode == "channel" then
        channels[name]:SendToClient(data, user)
    else
        Ext.ServerNet.PostMessageToUser(user, name, Ext.Json.Stringify(data))
    end
end

function N.Broadcast(name, data)
    if N.Mode == "channel" then
        channels[name]:Broadcast(data)
    else
        Ext.ServerNet.BroadcastMessage(name, Ext.Json.Stringify(data))
    end
end

EG.Net = N
return N
