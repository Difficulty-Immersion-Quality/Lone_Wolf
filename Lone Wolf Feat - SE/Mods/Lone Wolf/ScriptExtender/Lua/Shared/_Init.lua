-- Lone Wolf shared initialization
LoneWolf = LoneWolf or {}
Ext.Require("Shared/Config.lua")
Ext.Require("Shared/Translator.lua")

---@diagnostic disable-next-line: undefined-field
LoneWolf.ConfigChannel = Ext.Net.CreateChannel(ModuleUUID, "LoneWolf_ConfigChanged")

---@diagnostic disable-next-line: redundant-parameter
Ext.Vars.RegisterModVariable(ModuleUUID, "LoneWolfData", {
    Server = true,
    Client = true,
    WriteableOnServer = true,
    WriteableOnClient = true,
    SyncToClient = true,
    SyncToServer = true
})
