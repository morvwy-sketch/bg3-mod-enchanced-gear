-- Small helpers shared by server, client, generator and tests. No game API here.
EG = EG or {}
local U = {}

function U.Copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = U.Copy(x) end
    return out
end

function U.Equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not U.Equal(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

function U.Clamp(x, lo, hi)
    if type(x) ~= "number" or x ~= x then return lo end
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

function U.Int(x, default)
    if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return default end
    return math.floor(x)
end

-- ceil(value * pct / 100) in integers: avoids 220 * 1.3 = 286.00000000000006 -> 287.
function U.CeilPct(value, pct)
    return (value * pct + 99) // 100
end

function U.FloorPct(value, pct)
    return (value * pct) // 100
end

function U.Keys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

function U.Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function U.Contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

function U.Set(list)
    local out = {}
    for _, v in ipairs(list) do out[v] = true end
    return out
end

function U.Format(template, params)
    params = params or {}
    return (template:gsub("{(%d+)}", function(i)
        local v = params[tonumber(i)]
        if v == nil then return "" end
        return tostring(v)
    end))
end

-- Resource bundles: { scrap = 3, gold = 20 }.
function U.AddBundle(into, add, mult)
    mult = mult or 1
    for k, v in pairs(add or {}) do
        into[k] = (into[k] or 0) + v * mult
    end
    return into
end

function U.CleanBundle(b)
    local out = {}
    for k, v in pairs(b or {}) do
        if type(v) == "number" and v > 0 then out[k] = v end
    end
    return out
end

function U.BundleEmpty(b)
    for _, v in pairs(b or {}) do
        if v > 0 then return false end
    end
    return true
end

-- Cyrillic-aware lower case for search ("Меч" matches "меч").
local function lowerCode(c)
    if c >= 0x41 and c <= 0x5A then return c + 32 end
    if c >= 0x410 and c <= 0x42F then return c + 0x20 end
    if c >= 0x400 and c <= 0x40F then return c + 0x50 end
    if c == 0x490 then return 0x491 end
    return c
end

function U.Lower(s)
    s = tostring(s or "")
    local ok, out = pcall(function()
        local parts = {}
        for _, c in utf8.codes(s) do parts[#parts + 1] = utf8.char(lowerCode(c)) end
        return table.concat(parts)
    end)
    if ok then return out end
    return s:lower()
end

-- The Script Extender IMGUI font only has Latin and Cyrillic glyphs; anything else renders as "?".
local fontMap = {
    [0x2018] = "'", [0x2019] = "'", [0x02BC] = "'", [0x201B] = "'", [0x2032] = "'", [0x0060] = "'",
    [0x201C] = '"', [0x201D] = '"', [0x201E] = '"', [0x00AB] = '"', [0x00BB] = '"',
    [0x2013] = "-", [0x2014] = "-", [0x2012] = "-", [0x2015] = "-", [0x2212] = "-", [0x2010] = "-", [0x2011] = "-",
    [0x2026] = "...", [0x2192] = "->", [0x2190] = "<-", [0x00D7] = "x", [0x00A0] = " ", [0x202F] = " ",
    [0x2009] = " ", [0x00B7] = "-", [0x2022] = "-",
}

function U.FontSafeCode(c)
    if c == 9 or c == 10 then return true end
    if c >= 0x20 and c <= 0x7E then return true end
    if c >= 0x400 and c <= 0x4FF then return true end
    return false
end

function U.FontSafe(s)
    s = tostring(s or "")
    local ok, out = pcall(function()
        local parts = {}
        for _, c in utf8.codes(s) do
            if U.FontSafeCode(c) then
                parts[#parts + 1] = utf8.char(c)
            elseif fontMap[c] then
                parts[#parts + 1] = fontMap[c]
            end
        end
        return table.concat(parts)
    end)
    if ok then return out end
    return (s:gsub("[\128-\255]", ""))
end

function U.IsFontSafe(s)
    local ok, res = pcall(function()
        for _, c in utf8.codes(s) do
            if not U.FontSafeCode(c) then return false end
        end
        return true
    end)
    return ok and res
end

-- Stable 128-bit hash (four FNV-1a lanes) used for deterministic localization handles.
function U.Hash128Hex(str)
    local lanes = { 0x811C9DC5, 0x01000193, 0x9E3779B9, 0x7F4A7C15 }
    for lane = 1, 4 do
        local h = lanes[lane]
        for i = 1, #str do
            h = h ~ str:byte(i)
            h = (h * 16777619 + lane) & 0xFFFFFFFF
        end
        h = h ~ (#str * 2654435761 & 0xFFFFFFFF)
        h = (h * 16777619) & 0xFFFFFFFF
        lanes[lane] = h
    end
    return string.format("%08x%08x%08x%08x", lanes[1], lanes[2], lanes[3], lanes[4])
end

-- Localization handle: h + 32 hex digits split like a GUID with "g" separators.
function U.Handle(key)
    local x = U.Hash128Hex("EnhancedGear:" .. key)
    return "h" .. x:sub(1, 8) .. "g" .. x:sub(9, 12) .. "g" .. x:sub(13, 16) .. "g" .. x:sub(17, 20) .. "g" .. x:sub(21, 32)
end

-- Template GUIDs from Osiris look like "Name_<guid>"; the bare GUID is the last 36 characters.
function U.BareGuid(s)
    if type(s) ~= "string" then return nil end
    if #s >= 36 then
        local tail = s:sub(-36)
        if tail:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then return tail end
    end
    return s
end

function U.Roman(n)
    return ({ "I", "II", "III", "IV", "V" })[n] or tostring(n)
end

function U.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

EG.Util = U
return U
