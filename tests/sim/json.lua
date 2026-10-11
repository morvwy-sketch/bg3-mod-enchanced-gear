-- Minimal JSON for the simulation (Ext.Json and network payload round trips).
local J = {}

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if math.type(k) ~= "integer" or k < 1 then return false end
        n = n + 1
    end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return n > 0, n
end

local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
local function esc(s)
    return (s:gsub('[%c"\\]', function(c) return escapes[c] or string.format("\\u%04x", c:byte()) end))
end

function J.encode(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then
        assert(v == v and v ~= math.huge and v ~= -math.huge, "cannot encode NaN/inf")
        if math.type(v) == "integer" then return tostring(v) end
        return string.format("%.14g", v)
    end
    if t == "string" then return '"' .. esc(v) .. '"' end
    if t == "table" then
        local arr, n = isArray(v)
        if arr then
            local parts = {}
            for i = 1, n do parts[i] = J.encode(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do
            assert(type(k) == "string" or type(k) == "number", "bad key type " .. type(k))
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = '"' .. esc(tostring(k)) .. '":' .. J.encode(v[k]) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("cannot encode " .. t)
end

function J.decode(s)
    local pos = 1
    local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
    local value
    local function str()
        local out = {}
        pos = pos + 1
        while true do
            local c = s:sub(pos, pos)
            if c == "" then error("unterminated string") end
            if c == '"' then
                pos = pos + 1
                return table.concat(out)
            end
            if c == "\\" then
                local n = s:sub(pos + 1, pos + 1)
                if n == "u" then
                    out[#out + 1] = utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16))
                    pos = pos + 6
                else
                    out[#out + 1] = ({ n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" })[n] or n
                    pos = pos + 2
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
    end
    function value()
        ws()
        local c = s:sub(pos, pos)
        if c == "{" then
            local t = {}
            pos = pos + 1
            ws()
            if s:sub(pos, pos) == "}" then
                pos = pos + 1
                return t
            end
            while true do
                ws()
                local k = str()
                ws()
                assert(s:sub(pos, pos) == ":", "expected : at " .. pos)
                pos = pos + 1
                t[k] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == "}" then return t end
                assert(d == ",", "expected , at " .. pos)
            end
        elseif c == "[" then
            local t = {}
            pos = pos + 1
            ws()
            if s:sub(pos, pos) == "]" then
                pos = pos + 1
                return t
            end
            while true do
                t[#t + 1] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == "]" then return t end
                assert(d == ",", "expected , at " .. pos)
            end
        elseif c == '"' then
            return str()
        elseif s:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif s:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif s:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        assert(num and #num > 0, "bad json at " .. pos)
        pos = pos + #num
        return math.tointeger(tonumber(num)) or tonumber(num)
    end
    local v = value()
    ws()
    assert(pos > #s, "trailing data in json")
    return v
end

return J
