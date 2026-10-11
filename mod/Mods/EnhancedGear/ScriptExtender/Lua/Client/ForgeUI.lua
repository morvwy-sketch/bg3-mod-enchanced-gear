-- Forge window (Script Extender IMGUI). It only shows previews computed with the shared Logic and
-- sends requests; the server re-checks everything before spending anything.
EG = EG or {}
local Ids = EG.Ids
local R = EG.Rules
local L = EG.Logic
local U = EG.Util
local I18N = EG.I18N
local Net = EG.Net
local T = function(...) return I18N.T(...) end
local UI = {}

UI.Size = { 1150, 800 }
UI.MinSize = { 860, 560 }
UI.BusyTimeout = 5000
UI.IconSize = 40
UI.CardIconSize = 64
UI.MatIconSize = 24

UI.Colors = {
    rarity = {
        { 0.86, 0.86, 0.86, 1 },
        { 0.20, 0.85, 0.30, 1 },
        { 0.30, 0.58, 1.00, 1 },
        { 0.74, 0.40, 0.98, 1 },
        { 1.00, 0.60, 0.12, 1 },
    },
    neutral = { 0.45, 0.45, 0.45, 1 },
    good = { 0.35, 0.90, 0.40, 1 },
    bad = { 1.00, 0.35, 0.30, 1 },
    gold = { 1.00, 0.80, 0.25, 1 },
    dim = { 0.55, 0.55, 0.55, 1 },
}

UI.Filters = { "all", "character", "equipped" }

local state = {
    window = nil, built = false, visible = false,
    actor = nil, header = nil, items = {}, byGuid = {}, buffer = {}, seq = nil, loading = false,
    selected = nil, filter = 1, search = "", actionTab = "upgrade", affix = nil, confirmSalvage = false,
    pending = nil, busyUntil = 0, result = nil, counter = 0, session = nil,
}
UI.State = state

local el = {} -- containers rebuilt on demand

---------------------------------------------------------------------------------------------------
-- IMGUI helpers (tolerant to small API differences between Script Extender versions)
---------------------------------------------------------------------------------------------------

local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local function set(element, key, value)
    if element then pcall(function() element[key] = value end) end
end

local function color(element, value, what)
    if element and value then pcall(function() element:SetColor(what or "Text", value) end) end
    return element
end

local function clear(container)
    if not container then return end
    local children = try(function() return container.Children end) or {}
    local list = {}
    for _, c in ipairs(children) do list[#list + 1] = c end
    for _, c in ipairs(list) do pcall(function() c:Destroy() end) end
end

local function text(parent, label, col, sameLine)
    local t = parent:AddText(U.FontSafe(label))
    color(t, col)
    if sameLine then set(t, "SameLine", true) end
    return t
end

local function separatorText(parent, label)
    local s = try(function() return parent:AddSeparatorText(U.FontSafe(label)) end)
    if s then return s end
    parent:AddSeparator()
    return text(parent, label, UI.Colors.gold)
end

local function button(parent, label, onClick, disabled, sameLine)
    local b = parent:AddButton(U.FontSafe(label))
    b.OnClick = function() if not b.Disabled then onClick() end end
    set(b, "Disabled", disabled and true or false)
    if sameLine then set(b, "SameLine", true) end
    return b
end

local function image(parent, icon, size, border)
    if not icon or icon == "" then return nil end
    local img = try(function() return parent:AddImage(icon, { size, size }) end)
    if img and border then set(img, "Border", border) end
    return img
end

-- Icon in a rarity frame with a soft background; clicking it selects the item.
local function iconButton(parent, id, icon, size, rarity, onClick)
    local frame = rarity > 1 and UI.Colors.rarity[rarity] or UI.Colors.neutral
    local soft = { frame[1], frame[2], frame[3], rarity > 1 and 0.22 or 0.10 }
    local b = try(function() return parent:AddImageButton("##" .. id, icon, { size, size }) end)
    if b then
        b.OnClick = onClick
        color(b, soft, "Button")
        color(b, { frame[1], frame[2], frame[3], 0.40 }, "ButtonHovered")
        color(b, frame, "Border")
        pcall(function() b:SetStyle("FrameBorderSize", 2) end)
        return b
    end
    return image(parent, icon, size, frame)
end

local function rarityColor(r) return UI.Colors.rarity[r] or UI.Colors.rarity[1] end

---------------------------------------------------------------------------------------------------
-- Data helpers
---------------------------------------------------------------------------------------------------

local function now()
    return try(Ext.Utils.MonotonicTime) or 0
end

function UI.Env()
    local h = state.header or {}
    return { techTier = h.techTier or 1, cfg = h.cfg or {} }
end

function UI.Have()
    return (state.header and state.header.have) or {}
end

function UI.Busy()
    return state.pending ~= nil and now() < state.busyUntil
end

function UI.Blocked()
    return state.header ~= nil and state.header.block ~= nil
end

function UI.DisplayName(item)
    local name = U.FontSafe(item.name or "")
    if item.state.level > 0 then name = name .. " +" .. item.state.level end
    return name
end

function UI.Selected()
    return state.selected and state.byGuid[state.selected] or nil
end

function UI.FormatParam(p)
    if type(p) == "table" then
        if p.t == "rarity" then return I18N.Rarity(p.v) end
        if p.t == "bundle" then return I18N.Bundle(p.v) end
        if p.t == "profile" then return I18N.Profile(p.v) end
    end
    return U.FontSafe(tostring(p))
end

function UI.MessageText(msg)
    local params = {}
    for i, p in ipairs(msg.params or {}) do params[i] = UI.FormatParam(p) end
    return T(msg.key, table.unpack(params))
end

local function costLines(parent, cost)
    local have = UI.Have()
    text(parent, T("ui.cost"))
    for _, res in ipairs(L.Resources) do
        local need = cost and cost[res]
        if need and need > 0 then
            local h = have[res] or 0
            local icon = Ids.Items[res] and Ids.Items[res].icon
            local img = image(parent, icon, UI.MatIconSize)
            text(parent, T("ui.costLine", I18N.Material(res), need, h), h >= need and UI.Colors.good or UI.Colors.bad,
                img ~= nil)
        end
    end
end

-- Filter, search, group by owner (window's character first), equipped first, then by name.
function UI.VisibleGroups()
    local query = U.Lower(U.Trim(state.search))
    local filter = UI.Filters[state.filter] or "all"
    local groups, byOwner = {}, {}
    for _, item in ipairs(state.items) do
        local keep = (filter ~= "character" or item.owner == state.actor)
            and (filter ~= "equipped" or item.info.equipped ~= nil)
            and (query == "" or U.Lower(UI.DisplayName(item)):find(query, 1, true) ~= nil)
        if keep then
            local g = byOwner[item.owner or ""]
            if not g then
                g = { owner = item.owner, name = item.ownerName or "", items = {} }
                byOwner[item.owner or ""] = g
                groups[#groups + 1] = g
            end
            g.items[#g.items + 1] = item
        end
    end
    local slotIndex = {}
    for i, s in ipairs(R.SlotOrder) do slotIndex[s] = i end
    for _, g in ipairs(groups) do
        table.sort(g.items, function(a, b)
            local ea, eb = slotIndex[a.info.equipped or ""], slotIndex[b.info.equipped or ""]
            if (ea ~= nil) ~= (eb ~= nil) then return ea ~= nil end
            if ea and eb and ea ~= eb then return ea < eb end
            local na, nb = U.Lower(a.name), U.Lower(b.name)
            if na ~= nb then return na < nb end
            return a.guid < b.guid
        end)
    end
    table.sort(groups, function(a, b)
        if (a.owner == state.actor) ~= (b.owner == state.actor) then return a.owner == state.actor end
        return U.Lower(a.name) < U.Lower(b.name)
    end)
    return groups
end

---------------------------------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------------------------------

function UI.Send(op, fields, blocking)
    state.counter = state.counter + 1
    if not state.session then state.session = tostring(math.floor(now()) % 1000000) .. "-" .. tostring(math.random(1000, 9999)) end
    local req = fields or {}
    req.op = op
    req.id = state.session .. "-" .. state.counter
    req.actor = state.actor
    if blocking then
        state.pending = req.id
        state.busyUntil = now() + UI.BusyTimeout
        local id = req.id
        local wait = Ext.Timer.WaitForRealtime or Ext.Timer.WaitFor
        pcall(wait, UI.BusyTimeout, function()
            if state.pending == id then
                state.pending = nil
                UI.RenderCard()
                UI.RenderSmelt()
            end
        end)
    end
    Net.SendToServer(Ids.Channels.request, req)
    return req.id
end

function UI.RequestList()
    state.loading = true
    UI.Send("list", {}, false)
end

local function itemRequest(op, item, fields)
    fields = fields or {}
    fields.item = item.guid
    fields.expect = { level = item.state.level, rarity = item.state.rarity }
    UI.Send(op, fields, true)
    UI.RenderCard()
end

---------------------------------------------------------------------------------------------------
-- Header
---------------------------------------------------------------------------------------------------

function UI.RenderHeader()
    local root = el.header
    if not root then return end
    clear(root)
    local h = state.header
    if not h then
        text(root, T("ui.loading"), UI.Colors.dim)
        return
    end
    text(root, T("ui.character", h.actorName or ""))
    text(root, "|", UI.Colors.dim, true)
    text(root, T("ui.tech", U.Roman(h.techTier), R.TechCap[h.techTier] or 5), nil, true)
    local first = true
    for _, res in ipairs(L.Resources) do
        local icon = Ids.Items[res] and Ids.Items[res].icon
        local img = image(root, icon, UI.MatIconSize)
        if img and not first then set(img, "SameLine", true) end
        local label = string.format("%s: %d", I18N.Material(res), (h.have and h.have[res]) or 0)
        text(root, label, res == "gold" and UI.Colors.gold or nil, img ~= nil or not first)
        first = false
    end
    local scope = (h.cfg and h.cfg.MaterialScope == "character") and "ui.scope.character" or "ui.scope.party"
    text(root, T(scope), UI.Colors.dim, true)
    if h.block then text(root, I18N.Reason(h.block), UI.Colors.bad) end
end

---------------------------------------------------------------------------------------------------
-- Item list
---------------------------------------------------------------------------------------------------

function UI.Select(guid)
    if state.selected ~= guid then
        state.selected = guid
        state.affix = nil
        state.confirmSalvage = false
    end
    UI.RenderList()
    UI.RenderCard()
end

function UI.RenderList()
    local root = el.list
    if not root then return end
    clear(root)
    if #state.items == 0 then
        text(root, state.loading and T("ui.loading") or T("ui.empty"), UI.Colors.dim)
        return
    end
    local groups = UI.VisibleGroups()
    if #groups == 0 then
        text(root, T("ui.noMatch"), UI.Colors.dim)
        return
    end
    for _, g in ipairs(groups) do
        separatorText(root, g.name)
        for _, item in ipairs(g.items) do
            local s = item.state
            local selectIt = function() UI.Select(item.guid) end
            local icon = iconButton(root, item.guid, item.icon, UI.IconSize, s.rarity, selectIt)
            local line2 = table.concat({ I18N.Rarity(s.rarity), I18N.Profile(s.profile),
                item.info.equipped and T("ui.equipped") or T("ui.inventory") }, " | ")
            local row = root:AddSelectable(UI.DisplayName(item) .. "\n" .. U.FontSafe(line2) .. "##" .. item.guid)
            set(row, "Selected", item.guid == state.selected)
            if icon then set(row, "SameLine", true) end
            row.OnClick = selectIt
            if s.rarity > 1 then color(row, rarityColor(s.rarity)) end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Item card
---------------------------------------------------------------------------------------------------

local function renderEffects(root, item)
    local s = item.state
    separatorText(root, T("ui.effects"))
    local current = L.CurrentEffects(s)
    local any = false
    for _, atom in ipairs(current.atoms) do
        text(root, I18N.Atom(atom), UI.Colors.good)
        any = true
    end
    for _, a in ipairs(current.affixes) do
        text(root, T("ui.affixEffect", I18N.Affix(a.id), I18N.AffixTierName(a.tier), I18N.Atoms(a.atoms)), UI.Colors.good)
        any = true
    end
    if not any then text(root, T("ui.noEffects"), UI.Colors.dim) end
    local nextM = L.NextMilestone(s.level)
    if nextM then
        local atoms = L.MilestoneAtoms(s.profile, nextM, s.baseEnchant)
        text(root, T("ui.nextMilestone", nextM, I18N.Atoms(atoms)), UI.Colors.gold)
    end
    text(root, T("ui.effectsHint"), UI.Colors.dim)
end

local function renderUpgrade(root, item)
    local s, env, have = item.state, UI.Env(), UI.Have()
    local check = L.CheckUpgrade(item, env, have)
    local blocked = UI.Busy() or UI.Blocked()
    if s.level < R.MaxLevel then text(root, T("ui.upLine", s.level, s.level + 1)) end
    if check.cost then
        local nextLevel = s.level + 1
        if L.IsMilestone(nextLevel) then
            text(root, T("ui.newEffect", I18N.Atoms(L.MilestoneAtoms(s.profile, nextLevel, s.baseEnchant))), UI.Colors.good)
        else
            local m = L.NextMilestone(s.level)
            text(root, T("ui.progressTo", m, m - s.level), UI.Colors.dim)
        end
        costLines(root, check.cost)
    end
    if not check.ok then text(root, I18N.Reason(check.reason, check.params), UI.Colors.bad) end
    button(root, T("ui.upgrade"), function() itemRequest("upgrade", item) end, blocked or not check.ok)
    local plan = L.UpgradePlan(item, env, have)
    if plan then
        button(root, T("ui.upgradeTo", plan.target), function()
            itemRequest("upgradeTo", item, { target = plan.target })
        end, blocked or plan.affordable == 0, true)
        text(root, T("ui.totalTo", plan.target, I18N.Bundle(plan.cost)), UI.Colors.dim)
    end
end

local function renderRarity(root, item)
    local s, env, have = item.state, UI.Env(), UI.Have()
    local check = L.CheckReforge(item, env, have, state.affix)
    local blocked = UI.Busy() or UI.Blocked()
    if s.rarity >= 5 then
        text(root, I18N.Reason("legendary"), UI.Colors.bad)
        return
    end
    local nr = s.rarity + 1
    text(root, T("ui.rarityLine", I18N.Rarity(s.rarity), I18N.Rarity(nr), R.RarityCap[nr]), rarityColor(nr))
    if check.opens then
        text(root, T("ui.opensSlot", check.opens == "slot1" and 1 or 2))
        text(root, T("ui.chooseAffix"))
        local tier = L.AffixTier(check.opens, nr)
        for _, id in ipairs(check.affixes or {}) do
            local label = T("ui.affixChoice", I18N.Affix(id), I18N.AffixDescription(id, tier))
            local opt = root:AddSelectable(U.FontSafe(label) .. "##affix" .. id)
            set(opt, "Selected", state.affix == id)
            opt.OnClick = function()
                state.affix = id
                UI.RenderCard()
            end
        end
    else
        text(root, T("ui.strengthens"), UI.Colors.dim)
    end
    if check.cost then costLines(root, check.cost) end
    if not check.ok then text(root, I18N.Reason(check.reason, check.params), UI.Colors.bad) end
    button(root, T("ui.reforge"), function()
        itemRequest("reforge", item, { affix = check.opens and state.affix or nil })
    end, blocked or not check.ok)
end

local function renderSalvage(root, item)
    local check = L.CheckSalvage(item, UI.Env())
    local blocked = UI.Busy() or UI.Blocked()
    if check.ok then
        text(root, T("ui.salvageGet"))
        for _, res in ipairs(L.Resources) do
            local n = check.yield[res]
            if n and n > 0 then
                local img = image(root, Ids.Items[res] and Ids.Items[res].icon, UI.MatIconSize)
                text(root, string.format("%s: %d", I18N.Material(res), n), UI.Colors.good, img ~= nil)
            end
        end
        if check.refunded then text(root, T("ui.salvageRefund"), UI.Colors.dim) end
        text(root, T("ui.salvageWarn"), UI.Colors.bad)
    else
        text(root, I18N.Reason(check.reason, check.params), UI.Colors.bad)
    end
    if not state.confirmSalvage then
        button(root, T("ui.salvage"), function()
            state.confirmSalvage = true
            UI.RenderCard()
        end, blocked or not check.ok)
    else
        button(root, T("ui.salvageConfirm"), function()
            state.confirmSalvage = false
            itemRequest("salvage", item)
        end, blocked or not check.ok)
        button(root, T("ui.cancel"), function()
            state.confirmSalvage = false
            UI.RenderCard()
        end, false, true)
    end
end

function UI.RenderCard()
    local root = el.card
    if not root then return end
    clear(root)
    local item = UI.Selected()
    if not item then
        text(root, T("ui.select"), UI.Colors.dim)
        return
    end
    local s, env = item.state, UI.Env()

    local icon = iconButton(root, "card" .. item.guid, item.icon, UI.CardIconSize, s.rarity, function() end)
    local title = text(root, UI.DisplayName(item), rarityColor(s.rarity), icon ~= nil)
    set(title, "Font", "Large")
    local where = item.info.equipped and T("ui.equipped") or T("ui.inventory")
    text(root, string.format("%s | %s | %s (%s)", I18N.Profile(s.profile), I18N.Rarity(s.rarity),
        U.FontSafe(item.ownerName or ""), where), UI.Colors.dim)

    local cap, limiter = L.Ceiling(item, env)
    local bar = root:AddProgressBar()
    set(bar, "Value", s.level / R.MaxLevel)
    set(bar, "Overlay", U.FontSafe(T("ui.progress", s.level, R.MaxLevel)))

    text(root, T("ui.milestones"))
    for _, m in ipairs(R.Milestones) do
        local col = (s.level >= m and UI.Colors.good) or (m <= cap and UI.Colors.gold) or UI.Colors.dim
        text(root, "+" .. m, col, true)
    end
    if cap >= R.MaxLevel then
        text(root, T("ui.ceilingMax", cap), UI.Colors.dim, true)
    else
        text(root, T("ui.ceiling", cap, T("ui.limiter." .. limiter)), UI.Colors.dim, true)
    end
    if s.profile == "weapon" and (s.baseEnchant or 0) > 0 then
        text(root, T("ui.ownEnchant", s.baseEnchant), UI.Colors.dim)
    end

    -- Profile choice: only for items with two profiles and before the first investment.
    if item.profiles and #item.profiles > 1 and not L.Invested(s) then
        text(root, T("ui.profile"))
        local combo = root:AddCombo("##profile" .. item.guid)
        set(combo, "SameLine", true)
        local options, selected = {}, 0
        for i, p in ipairs(item.profiles) do
            options[i] = U.FontSafe(I18N.Profile(p))
            if p == s.profile then selected = i - 1 end
        end
        set(combo, "Options", options)
        set(combo, "SelectedIndex", selected)
        set(combo, "Disabled", UI.Busy() or UI.Blocked())
        combo.OnChange = function()
            local p = item.profiles[(combo.SelectedIndex or 0) + 1]
            if p and p ~= item.state.profile then itemRequest("setProfile", item, { profile = p }) end
        end
        text(root, T("ui.profileHint"), UI.Colors.dim)
    end

    renderEffects(root, item)

    root:AddSeparator()
    local tabs = { { "upgrade", "ui.act.upgrade" }, { "rarity", "ui.act.rarity" }, { "salvage", "ui.act.salvage" } }
    for i, tab in ipairs(tabs) do
        -- "##tab" keeps ImGui ids unique: in English the tab and the action share the label "Upgrade"/"Salvage".
        local b = button(root, T(tab[2]) .. "##tab" .. tab[1], function()
            state.actionTab = tab[1]
            state.confirmSalvage = false
            UI.RenderCard()
        end, false, i > 1)
        if state.actionTab == tab[1] then color(b, { 0.30, 0.45, 0.70, 1 }, "Button") end
    end
    if state.actionTab == "rarity" then
        renderRarity(root, item)
    elseif state.actionTab == "salvage" then
        renderSalvage(root, item)
    else
        renderUpgrade(root, item)
    end
    if UI.Busy() then text(root, T("ui.waiting"), UI.Colors.dim) end
end

---------------------------------------------------------------------------------------------------
-- Smelting and test tabs
---------------------------------------------------------------------------------------------------

function UI.RenderSmelt()
    local root = el.smelt
    if not root then return end
    clear(root)
    local check = L.CheckSmelt(UI.Env(), UI.Have())
    text(root, T("ui.smelt.desc"))
    text(root, T("ui.smelt.recipe", I18N.Bundle(R.Smelt.cost), I18N.Bundle(R.Smelt.output)), UI.Colors.gold)
    text(root, T("ui.smelt.tier", U.Roman(R.Smelt.tech)), UI.Colors.dim)
    costLines(root, check.cost)
    if not check.ok then text(root, I18N.Reason(check.reason, check.params), UI.Colors.bad) end
    button(root, T("ui.smelt.button"), function()
        UI.Send("smelt", {}, true)
        UI.RenderSmelt()
    end, UI.Busy() or UI.Blocked() or not check.ok)
end

function UI.RenderTest()
    local root = el.test
    if not root then return end
    clear(root)
    text(root, T("ui.test.hint"), UI.Colors.dim)
    local dev = function(what, extra)
        return function()
            local f = extra or {}
            f.what = what
            UI.Send("dev", f, false)
        end
    end
    button(root, T("ui.test.materials"), dev("materials"))
    button(root, T("ui.test.gold"), dev("gold"), false, true)
    text(root, T("ui.test.tier"))
    local current = state.header and state.header.techTier or 1
    for tier = 1, #R.TechCap do
        local b = button(root, T("ui.test.tierButton", U.Roman(tier), R.TechCap[tier]), dev("tier", { tier = tier }),
            false, true)
        if tier == current then color(b, { 0.20, 0.55, 0.25, 1 }, "Button") end
    end
    button(root, T("ui.test.gear"), dev("gear"))
    button(root, T("ui.test.kit"), dev("kit"), false, true)
    button(root, T("ui.test.resync"), dev("resync"), false, true)
end

function UI.RenderResult()
    local root = el.result
    if not root then return end
    clear(root)
    local r = state.result
    if r then text(root, r.text, r.ok and UI.Colors.good or UI.Colors.bad) end
end

function UI.RenderAll()
    UI.RenderHeader()
    UI.RenderList()
    UI.RenderCard()
    UI.RenderSmelt()
    UI.UpdateTestTab()
    UI.RenderResult()
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------

function UI.UpdateTestTab()
    local wanted = state.header ~= nil and state.header.cfg ~= nil and state.header.cfg.DevTools == true
    if wanted and not el.testTab then
        el.testTab = el.tabs:AddTabItem(U.FontSafe(T("ui.tab.test")))
        el.test = el.testTab:AddGroup("test")
        UI.RenderTest()
    elseif not wanted and el.testTab then
        pcall(function() el.testTab:Destroy() end)
        el.testTab, el.test = nil, nil
    elseif wanted then
        UI.RenderTest()
    end
end

function UI.Build()
    if state.built then return end
    local w = Ext.IMGUI.NewWindow(U.FontSafe(T("ui.title")))
    state.window = w
    set(w, "Closeable", true)
    w.OnClose = function()
        state.visible = false
        set(w, "Open", false)
    end
    pcall(function() w:SetSize(UI.Size, "FirstUseEver") end)
    pcall(function() w:SetSizeConstraints(UI.MinSize) end)
    local vp = try(Ext.IMGUI.GetViewportSize)
    if vp and vp[1] and vp[2] then
        pcall(function() w:SetPos({ math.max(0, (vp[1] - UI.Size[1]) / 2), math.max(0, (vp[2] - UI.Size[2]) / 2) }, "FirstUseEver") end)
    end

    el.header = w:AddGroup("header")
    w:AddSeparator()
    el.tabs = w:AddTabBar("tabs")
    local forgeTab = el.tabs:AddTabItem(U.FontSafe(T("ui.tab.forge")))
    local layout = forgeTab:AddTable("layout", 2)
    pcall(function() layout:AddColumn("list", "WidthFixed", 400) end)
    pcall(function() layout:AddColumn("card", "WidthStretch") end)
    local row = layout:AddRow()
    local left = row:AddCell()
    local right = row:AddCell()

    local filter = left:AddCombo("##filter")
    local options = {}
    for i, f in ipairs(UI.Filters) do options[i] = U.FontSafe(T("ui.filter." .. f)) end
    set(filter, "Options", options)
    set(filter, "SelectedIndex", state.filter - 1)
    filter.OnChange = function()
        state.filter = (filter.SelectedIndex or 0) + 1
        UI.RenderList()
    end
    local search = left:AddInputText("##search", "")
    set(search, "Hint", U.FontSafe(T("ui.search")))
    search.OnChange = function()
        state.search = search.Text or ""
        UI.RenderList()
    end
    button(left, T("ui.refresh"), function() UI.RequestList() end, false, true)
    el.list = left:AddChildWindow("items")
    el.card = right:AddChildWindow("card")

    local smeltTab = el.tabs:AddTabItem(U.FontSafe(T("ui.tab.smelt")))
    el.smelt = smeltTab:AddGroup("smelt")

    w:AddSeparator()
    el.result = w:AddGroup("result")
    state.built = true
    UI.RenderAll()
end

function UI.Open(actor)
    if actor then state.actor = actor end
    UI.Build()
    state.visible = true
    set(state.window, "Open", true)
    set(state.window, "Visible", true)
    UI.RequestList()
    UI.Send("names", {}, false)
    UI.RenderAll()
end

function UI.Close()
    state.visible = false
    if state.window then
        set(state.window, "Open", false)
        set(state.window, "Visible", false)
    end
end

function UI.Toggle(actor)
    if state.visible then UI.Close() else UI.Open(actor or state.actor) end
end

function UI.IsOpen() return state.visible end

---------------------------------------------------------------------------------------------------
-- Messages from the server
---------------------------------------------------------------------------------------------------

function UI.OnPush(msg)
    local op = msg.op
    if op == "open" then
        UI.Open(msg.actor)
    elseif op == "header" then
        if msg.actor then state.actor = msg.actor end
        state.header = msg
        UI.RenderHeader()
        UI.RenderCard()
        UI.RenderSmelt()
        if el.tabs then UI.UpdateTestTab() end
    elseif op == "list" then
        if msg.part == 1 or msg.seq ~= state.seq then
            state.buffer = {}
            state.seq = msg.seq
        end
        for _, item in ipairs(msg.items or {}) do state.buffer[#state.buffer + 1] = item end
        if msg.part >= msg.parts then
            state.items = state.buffer
            state.buffer = {}
            state.byGuid = {}
            for _, item in ipairs(state.items) do state.byGuid[item.guid] = item end
            if state.selected and not state.byGuid[state.selected] then
                state.selected = nil
                state.confirmSalvage = false
            end
            state.loading = false
            UI.RenderList()
            UI.RenderCard()
        end
    elseif op == "result" then
        if msg.id == state.pending then state.pending = nil end
        if msg.ok then
            state.result = { ok = true, text = msg.msg and UI.MessageText(msg.msg) or T("ui.res.dev") }
            state.affix = nil
        else
            state.result = { ok = false, text = I18N.Reason(msg.reason, msg.params) }
        end
        state.confirmSalvage = false
        UI.RenderResult()
        UI.RenderCard()
        UI.RenderSmelt()
    end
end

EG.ForgeUI = UI
return UI
