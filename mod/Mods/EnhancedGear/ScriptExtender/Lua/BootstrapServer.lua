-- Server entry point (Script Extender). Load order matters: shared modules first.
EG = EG or {}
EG.Context = "server"

for _, file in ipairs({
    "Shared/Ids.lua", "Shared/Util.lua", "Shared/Rules.lua", "Shared/Logic.lua", "Shared/Effects.lua",
    "Shared/I18N.lua", "Shared/Config.lua", "Shared/Vars.lua", "Shared/Net.lua", "Shared/VanillaRefs.lua",
    "Server/Game.lua", "Server/Data.lua", "Server/ItemState.lua", "Server/Economy.lua", "Server/Names.lua",
    "Server/ItemEffects.lua", "Server/Forge.lua", "Server/Loot.lua", "Server/Main.lua",
}) do
    Ext.Require(file)
end

EG.Vars.Register()
EG.ServerMain.Init()
