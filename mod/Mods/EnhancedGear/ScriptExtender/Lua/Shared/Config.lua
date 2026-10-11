-- config.json in %LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\EnhancedGear\.
-- Invalid JSON, unknown keys and values of the wrong type are ignored (defaults apply).
EG = EG or {}
local U = EG.Util
local C = {}

C.Path = "EnhancedGear/config.json"
C.Version = 2

C.Order = {
    "Language", "RequireOutOfCombat", "RequireForgeKit", "MaterialScope", "TechTierOverride",
    "AllowStoryItemUpgrades", "AllowForeignModItems", "KillLoot", "KillLootMultiplier", "BossRewards",
    "RegionRewards", "GrantStarterKit", "ExperimentalRarityColor", "RarityColorRefresh", "ExperimentalRename",
    "ToggleKey", "DevTools", "Debug", "ConfigVersion",
}

C.Defaults = {
    Language = "auto",
    RequireOutOfCombat = true,
    RequireForgeKit = true,
    MaterialScope = "party",
    TechTierOverride = 0,
    AllowStoryItemUpgrades = true,
    AllowForeignModItems = false,
    KillLoot = true,
    KillLootMultiplier = 1.0,
    BossRewards = true,
    RegionRewards = true,
    GrantStarterKit = true,
    ExperimentalRarityColor = true,
    RarityColorRefresh = true,
    ExperimentalRename = true,
    ToggleKey = "F7",
    DevTools = true,
    Debug = false,
    ConfigVersion = C.Version,
}

C.Choices = {
    Language = { auto = true, uk = true, en = true },
    MaterialScope = { party = true, character = true },
}

-- Keys the game uses by default; the forge never takes them.
C.ReservedKeys = U.Set({ "F1", "F2", "F3", "F4", "F5", "F8", "F9", "F10", "ESCAPE", "ESC", "RETURN", "ENTER",
    "KP_ENTER", "SPACE", "TAB" })

C.Current = U.Copy(C.Defaults)

function C.NormalizeKey(key)
    key = U.Trim(key):upper()
    if key == "" or C.ReservedKeys[key] then return C.Defaults.ToggleKey end
    return key
end

-- Returns a complete valid config and whether it differs from `raw` (needs saving).
function C.Validate(raw)
    local cfg = U.Copy(C.Defaults)
    if type(raw) ~= "table" then return cfg, true end
    for key, default in pairs(C.Defaults) do
        local v = raw[key]
        if type(v) == type(default) then
            if C.Choices[key] then
                if C.Choices[key][v] then cfg[key] = v end
            elseif key == "TechTierOverride" then
                cfg[key] = U.Clamp(U.Int(v, 0), 0, 4)
            elseif key == "KillLootMultiplier" then
                cfg[key] = U.Clamp(v, 0, 10)
            elseif key == "ToggleKey" then
                cfg[key] = C.NormalizeKey(v)
            else
                cfg[key] = v
            end
        end
    end
    -- Migration: up to 0.1.x the window used F10, which hides the game UI.
    local version = U.Int(raw.ConfigVersion, 1)
    if version < 2 and (type(raw.ToggleKey) ~= "string" or raw.ToggleKey:upper() == "F10") then
        cfg.ToggleKey = "F7"
    end
    cfg.ConfigVersion = C.Version
    local changed = false
    for key in pairs(C.Defaults) do
        if raw[key] ~= cfg[key] then changed = true end
    end
    return cfg, changed
end

local function jsonValue(v)
    if type(v) == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
            return string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif type(v) == "number" and math.type(v) == "float" then
        local s = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", ".0")
        return s
    end
    return tostring(v)
end

-- Stable key order so the file stays readable for players.
function C.Serialize(cfg)
    local lines = {}
    for i, key in ipairs(C.Order) do
        lines[#lines + 1] = string.format('  "%s": %s%s', key, jsonValue(cfg[key]), i < #C.Order and "," or "")
    end
    return "{\n" .. table.concat(lines, "\n") .. "\n}\n"
end

-- io: { load = fn(path) -> string|nil, save = fn(path, text), parse = fn(text) -> table }
function C.Load(io)
    io = io or C.DefaultIO()
    local text = io.load(C.Path)
    local raw, parsed = nil, false
    if text and text ~= "" then
        local ok, res = pcall(io.parse, text)
        if ok and type(res) == "table" then raw, parsed = res, true end
    end
    local cfg, changed = C.Validate(raw)
    -- A broken file is left alone so the player can fix it; a missing or outdated one is (re)written.
    if (not text or text == "") or (parsed and changed) then
        pcall(io.save, C.Path, C.Serialize(cfg))
    end
    C.Current = cfg
    return cfg
end

function C.DefaultIO()
    return {
        load = function(path) return Ext.IO.LoadFile(path) end,
        save = function(path, text) Ext.IO.SaveFile(path, text) end,
        parse = function(text) return Ext.Json.Parse(text) end,
    }
end

function C.Get(key)
    if key then return C.Current[key] end
    return C.Current
end

EG.Config = C
return C
