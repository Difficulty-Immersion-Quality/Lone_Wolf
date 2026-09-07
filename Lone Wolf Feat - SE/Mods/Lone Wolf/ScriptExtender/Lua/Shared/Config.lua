---@diagnostic disable: undefined-field

LoneWolf.Config = LoneWolf.Config or {}
local Config = LoneWolf.Config

Config.FILE = "LoneWolfConfig.json"
Config.default = {
    enabled = true,
    partyLimit = 2,
    requirePassive = true,
    enableCoreBuffs = true,
    enableHpMax = true,
    enableDamageReduction = true,
    enableStatBoosts = true,
    hpPercent = 30,
    drPercent = 50,
    drType = "Half",
    abilityBonus = 4,
    actionPoints = 1,
    bonusActionPoints = 1,
    reactionPoints = 1,
    carryMultiplier = 2.0,
}

function Config.ApplyDefaults(cfg)
    local data = {}
    for key, value in pairs(Config.default) do
        if cfg[key] ~= nil then
            data[key] = cfg[key]
        else
            data[key] = value
        end
    end
    return data
end

function Config.Read()
    local file = Ext.IO.LoadFile(Config.FILE)
    if not file or file == "" then
        local fresh = Config.ApplyDefaults({})
        Ext.IO.SaveFile(Config.FILE, Ext.Json.Stringify(fresh))
        return fresh
    end

    local parsed = Ext.Json.Parse(file)
    return Config.ApplyDefaults(parsed)
end

function Config.Save(cfg)
    Ext.IO.SaveFile(Config.FILE, Ext.Json.Stringify(cfg))
end

return Config
