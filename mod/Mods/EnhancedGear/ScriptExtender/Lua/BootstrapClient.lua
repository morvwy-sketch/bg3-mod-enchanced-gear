-- Client entry point (Script Extender): the forge window and the toggle key.
EG = EG or {}
EG.Context = "client"

for _, file in ipairs({
    "Shared/Ids.lua", "Shared/Util.lua", "Shared/Rules.lua", "Shared/Logic.lua", "Shared/Effects.lua",
    "Shared/I18N.lua", "Shared/Config.lua", "Shared/Vars.lua", "Shared/Net.lua", "Shared/VanillaRefs.lua",
    "Client/ForgeUI.lua", "Client/Main.lua",
}) do
    Ext.Require(file)
end

EG.Vars.Register()
EG.ClientMain.Init()
