--- @type RegisterVariableOptions
local opts = {
    Server = true,
    Client = false,
    WriteableOnServer = true,
    WriteableOnClient = false,
    Persistent = true,
    SyncToClient = false,
    SyncToServer = true,
    SyncOnWrite = false,
    DontCache = false
}
Ext.Vars.RegisterModVariable(ModuleUUID, "HasLoneWolf", opts)
Ext.Require("Server/_Core.lua")