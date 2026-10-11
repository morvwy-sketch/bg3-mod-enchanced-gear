-- Counting, charging and granting materials and gold. The camp chest is never used.
EG = EG or {}
local Ids = EG.Ids
local Game = EG.Game
local Config = EG.Config
local U = EG.Util
local E = {}

E.Order = { "scrap", "dust", "ingot", "core", "gold" }
E.GrantOrder = { "kit", "scrap", "dust", "ingot", "core", "gold" }

function E.Template(res)
    if res == "gold" then return Ids.GoldTemplate end
    local item = Ids.Items[res]
    return item and item.template or nil
end

-- Active character first, then the rest of the party (MaterialScope = "party").
function E.Holders(actor)
    local out = { actor }
    if Config.Get("MaterialScope") == "party" then
        for _, c in ipairs(Game.Party()) do
            if c ~= actor then out[#out + 1] = c end
        end
    end
    return out
end

function E.CountOn(char)
    local b = {}
    for _, res in ipairs(E.Order) do b[res] = Game.CountTemplate(char, E.Template(res)) end
    return b
end

function E.Available(actor)
    local total = {}
    for _, res in ipairs(E.Order) do total[res] = 0 end
    for _, c in ipairs(E.Holders(actor)) do U.AddBundle(total, E.CountOn(c)) end
    return total
end

-- Removes `cost`; every removal is reported to `record` before the next one (journal).
-- Returns false if the holders did not have enough (already removed parts must be refunded).
function E.Charge(actor, cost, record)
    for _, res in ipairs(E.Order) do
        local need = cost[res] or 0
        for _, holder in ipairs(E.Holders(actor)) do
            if need <= 0 then break end
            local take = math.min(Game.CountTemplate(holder, E.Template(res)), need)
            if take > 0 then
                Game.RemoveTemplate(holder, E.Template(res), take)
                record({ char = holder, res = res, n = take })
                need = need - take
            end
        end
        if need > 0 then return false end
    end
    return true
end

function E.Refund(charges)
    for _, c in ipairs(charges or {}) do
        Game.AddTemplate(c.char, E.Template(c.res), c.n, false)
    end
end

function E.Grant(char, bundle, notify)
    for _, res in ipairs(E.GrantOrder) do
        local n = bundle and bundle[res]
        if n and n > 0 then Game.AddTemplate(char, E.Template(res), n, notify) end
    end
end

function E.PartyHasKit()
    for _, c in ipairs(Game.Party()) do
        if Game.CountTemplate(c, Ids.Items.kit.template) > 0 then return true end
    end
    return false
end

EG.Economy = E
return E
