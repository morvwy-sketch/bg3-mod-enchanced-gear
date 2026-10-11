std = "lua54"
max_line_length = 160
codes = true

-- The mod namespace is a global shared by all files of one Script Extender context.
globals = { "EG" }
read_globals = { "Ext", "Osi", "Mods", "_C", "_D", "_P" }

exclude_files = { "tools/.cache/**", "dist/**" }

files["tests/**"] = {
    globals = { "EG", "Ext", "Osi", "Mods" },
    ignore = { "432/self" }, -- simulated IMGUI methods are defined inside the window factory
}
files["tools/**"] = {
    globals = { "EG" },
}
