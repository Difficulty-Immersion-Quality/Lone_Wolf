---@diagnostic disable: missing-parameter
--TODO: add panic attack toggle from ice mage
local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local GOON_LONE_WOLF_HPMAX_STATUS = "GOON_LONE_WOLF_HPMAX_STATUS"
local GOON_LONE_WOLF_DR_STATUS = "GOON_LONE_WOLF_DR_STATUS"
local SITOUT_VANISH_STATUS = "SITOUT_ONCOMBATSTART_APPLIER_TECHNICAL"
local DR_DESC_FLAT_STATUS = "h9fc14e28bc9a4cbfb84bf641e5a4219c01f1"
local DR_DESC_FLAT_PASSIVE = "h086dd109gcbdbg4d36gbf9cg6e402b7d1e92"
local DR_DESC_HALF = "h2377f8ab5a4f494fbae516af149a60964ffb"
local DR_DESC_THRESHOLD = "hfd2328037f8842f2a62ac858311c93ec27e3"
local DR_BOOST_HALF = "DamageReduction(All,Half)"
local DR_BOOST_FLAT_PREFIX = "DamageReduction(All,Flat,"
local DR_BOOST_THRESHOLD_PREFIX = "DamageReduction(All,Threshold,"
local statBoosts = {
    { ability = "Strength",     passive = "Goon_Lone_Wolf_Strength",     status = "GOON_LONE_WOLF_STRENGTH_STATUS" },
    { ability = "Dexterity",    passive = "Goon_Lone_Wolf_Dexterity",    status = "GOON_LONE_WOLF_DEXTERITY_STATUS" },
    { ability = "Constitution", passive = "Goon_Lone_Wolf_Constitution", status = "GOON_LONE_WOLF_CONSTITUTION_STATUS" },
    { ability = "Intelligence", passive = "Goon_Lone_Wolf_Intelligence", status = "GOON_LONE_WOLF_INTELLIGENCE_STATUS" },
    { ability = "Wisdom",       passive = "Goon_Lone_Wolf_Wisdom",       status = "GOON_LONE_WOLF_WISDOM_STATUS" },
    { ability = "Charisma",     passive = "Goon_Lone_Wolf_Charisma",     status = "GOON_LONE_WOLF_CHARISMA_STATUS" },
}

local Config = LoneWolf.Config
local config = Config.Read()

local function ApplyStatusIfMissing(charID, status, force)
    if Osi.HasActiveStatus(charID, status) == 1 then
        if not force then return end
        Osi.RemoveStatus(charID, status)
    end

    if status == GOON_LONE_WOLF_HPMAX_STATUS then
        local entityHandle = Ext.Entity.Get(charID)
        local currentHp = entityHandle.Health.Hp
        local sub
        sub = Ext.Entity.Subscribe("Health", function(health)
            health.Health.Hp = currentHp
            health:Replicate("Health")
            ---@diagnostic disable-next-line: param-type-mismatch
            Ext.Entity.Unsubscribe(sub)
        end, entityHandle)
    end

    Osi.ApplyStatus(charID, status, -1, 1)
end

local function ApplyLoneWolf(charID, force, override)
    if config.enableCoreBuffs then
        ApplyStatusIfMissing(charID, LONE_WOLF_STATUS, force)
    else
        Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
    end

    if config.enableHpMax then
        ApplyStatusIfMissing(charID, GOON_LONE_WOLF_HPMAX_STATUS, force)
    else
        Osi.RemoveStatus(charID, GOON_LONE_WOLF_HPMAX_STATUS)
    end

    if config.enableDamageReduction then
        ApplyStatusIfMissing(charID, GOON_LONE_WOLF_DR_STATUS, force)
    else
        Osi.RemoveStatus(charID, GOON_LONE_WOLF_DR_STATUS)
    end

    local first = override and override.first
    local second = override and override.second
    for _, boost in ipairs(statBoosts) do
        local selected
        if config.requirePassive then
            selected = Osi.HasPassive(charID, boost.passive) == 1
        else
            selected = boost.ability == first or boost.ability == second
        end
        if config.enableStatBoosts and selected then
            ApplyStatusIfMissing(charID, boost.status, force)
        else
            Osi.RemoveStatus(charID, boost.status)
        end
    end
end

local function RemoveLoneWolf(charID)
    Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
    Osi.RemoveStatus(charID, GOON_LONE_WOLF_HPMAX_STATUS)
    Osi.RemoveStatus(charID, GOON_LONE_WOLF_DR_STATUS)
    for _, boost in ipairs(statBoosts) do
        Osi.RemoveStatus(charID, boost.status)
    end
end

local function UpdateLoneWolf(force)
    config = Config.Read()
    local vars = Ext.Vars.GetModVariables(ModuleUUID)
    vars.LoneWolfData = vars.LoneWolfData or {}
    vars.LoneWolfData.AbilityOverrides = vars.LoneWolfData.AbilityOverrides or {}

    if force then
        ---@type StatusData
        local hpStatus = Ext.Stats.Get(GOON_LONE_WOLF_HPMAX_STATUS)
        hpStatus.Boosts = "IncreaseMaxHP(" .. config.hpPercent .. "%)"
        hpStatus.DescriptionParams = tostring(config.hpPercent) .. "%"
        hpStatus:Sync()

        local drBoost = DR_BOOST_HALF
        local drParam = "50%"
        local drDescStatus = DR_DESC_HALF
        local drDescPassive = DR_DESC_HALF
        if config.drType == "Flat" then
            drBoost = DR_BOOST_FLAT_PREFIX .. tostring(config.drPercent) .. ")"
            drParam = tostring(config.drPercent)
            drDescStatus = DR_DESC_FLAT_STATUS
            drDescPassive = DR_DESC_FLAT_PASSIVE
        elseif config.drType == "Threshold" then
            drBoost = DR_BOOST_THRESHOLD_PREFIX .. tostring(config.drPercent) .. ")"
            drParam = tostring(config.drPercent)
            drDescStatus = DR_DESC_THRESHOLD
            drDescPassive = DR_DESC_THRESHOLD
        end
        ---@type StatusData
        local drStatus = Ext.Stats.Get(GOON_LONE_WOLF_DR_STATUS)
        drStatus.Boosts = drBoost
        drStatus.Description = drDescStatus
        drStatus.DescriptionParams = drParam
        drStatus:Sync()

        for _, boost in ipairs(statBoosts) do
            ---@type StatusData
            local status = Ext.Stats.Get(boost.status)
            status.Boosts = "Ability(" .. boost.ability .. "," .. config.abilityBonus ..
                ");ProficiencyBonus(SavingThrow," .. boost.ability .. ")"
            status.DescriptionParams = tostring(config.abilityBonus)
            status:Sync()
            ---@type PassiveData
            local passive = Ext.Stats.Get(boost.passive)
            passive.DescriptionParams = tostring(config.abilityBonus)
            passive:Sync()
        end
        ---@type PassiveData
        local extraHpPassive = Ext.Stats.Get("Goon_Lone_Wolf_Extra_HP")
        extraHpPassive.DescriptionParams = tostring(config.hpPercent) .. "%"
        extraHpPassive:Sync()
        ---@type PassiveData
        local extraDrPassive = Ext.Stats.Get("Goon_Lone_Wolf_Extra_DR")
        extraDrPassive.Description = drDescPassive
        extraDrPassive.DescriptionParams = drParam
        extraDrPassive:Sync()
        ---@type PassiveData
        local mainPassive = Ext.Stats.Get(LONE_WOLF_PASSIVE)
        mainPassive.DescriptionParams = tostring(config.hpPercent) .. "%;" .. tostring(config.abilityBonus) ..
            ";" .. drParam
        mainPassive:Sync()
        ---@type StatusData
        local mainStatus = Ext.Stats.Get(LONE_WOLF_STATUS)
        local coreBoosts = {}
        if config.actionPoints > 0 then
            table.insert(coreBoosts, "ActionResource(ActionPoint," .. config.actionPoints .. ",0)")
        end
        if config.bonusActionPoints > 0 then
            table.insert(coreBoosts, "ActionResource(BonusActionPoint," .. config.bonusActionPoints .. ",0)")
        end
        if config.reactionPoints > 0 then
            table.insert(coreBoosts, "ActionResource(ReactionActionPoint," .. config.reactionPoints .. ",0)")
        end
        if config.carryMultiplier > 0 then
            table.insert(coreBoosts, "CarryCapacityMultiplier(" .. tostring(config.carryMultiplier) .. ")")
        end
        mainStatus.Boosts = table.concat(coreBoosts, ";")
        mainStatus.DescriptionParams = tostring(config.hpPercent) .. "%;" .. tostring(config.abilityBonus) ..
            ";" .. drParam
        mainStatus:Sync()
    end

    local validPlayers = {}
    for _, entry in ipairs(Osi.DB_Players:Get(nil)) do
        local guid = string.sub(entry[1], -36)
        if Osi.HasActiveStatus(guid, SITOUT_VANISH_STATUS) == 0 then
            table.insert(validPlayers, guid)
        else
            -- make sure these mfs don't get buffs, since stat buffs are useful out of combat too.
            RemoveLoneWolf(guid)
        end
    end

    local partySize = #validPlayers
    for _, guid in ipairs(validPlayers) do
        local eligible = config.enabled
            and (config.partyLimit <= 0 or partySize <= config.partyLimit)
            and (not config.requirePassive or Osi.HasPassive(guid, LONE_WOLF_PASSIVE) == 1)
        if eligible then
            ApplyLoneWolf(guid, force, vars.LoneWolfData.AbilityOverrides[guid])
        else
            RemoveLoneWolf(guid)
        end
    end
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    UpdateLoneWolf(true)
end)
Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function()
    UpdateLoneWolf()
end)
Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function(character)
    RemoveLoneWolf(character)
    UpdateLoneWolf()
end)

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    if Osi.IsPlayer(character) == 1 then
        Ext.Timer.WaitFor(500, UpdateLoneWolf)
    end
end)

local pendingUpdateToken = 0
LoneWolf.ConfigChannel:SetHandler(function()
    pendingUpdateToken = pendingUpdateToken + 1
    local token = pendingUpdateToken
    Ext.Timer.WaitFor(50, function()
        if token == pendingUpdateToken then
            UpdateLoneWolf(true)
        end
    end)
end)

-- sit this one out compat
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, cause, _)
    if status == SITOUT_VANISH_STATUS then
        UpdateLoneWolf()
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, cause, _)
    if status == SITOUT_VANISH_STATUS then
        UpdateLoneWolf()
    end
end)
