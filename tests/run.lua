-- Runs every scenario in tests/scenarios on the simulated game: lua5.4 tests/run.lua [filter]
local root = (arg and arg[0] or "tests/run.lua"):match("^(.*)/tests/[^/]+$") or "."
local T = dofile(root .. "/tests/lib.lua")
local filter = arg and arg[1]

local files = {}
local p = assert(io.popen('ls "' .. root .. '/tests/scenarios"'))
for name in p:lines() do
    if name:match("%.lua$") and (not filter or name:find(filter, 1, true)) then files[#files + 1] = name end
end
p:close()
table.sort(files)

local failed = 0
for _, name in ipairs(files) do
    local chunk = assert(loadfile(root .. "/tests/scenarios/" .. name))
    local ok, err = xpcall(function() chunk()(T) end, debug.traceback)
    if ok then
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name .. "\n" .. tostring(err))
    end
end

if failed > 0 then
    print(string.format("%d of %d scenarios failed", failed, #files))
    os.exit(1)
end
print(string.format("%d scenarios passed", #files))
