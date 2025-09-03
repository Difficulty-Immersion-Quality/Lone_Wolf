local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local GOON_LONE_WOLF_SE_BUFFS = "GOON_LONE_WOLF_SE_BUFFS"
local PartyLimit = 2
local SITOUT_VANISH_STATUS = "SITOUT_ONCOMBATSTART_APPLIER_TECHNICAL"

local statBoosts = {
    { passive = "Goon_Lone_Wolf_Strength", status = "GOON_LONE_WOLF_STRENGTH_STATUS" },
    { passive = "Goon_Lone_Wolf_Dexterity", status = "GOON_LONE_WOLF_DEXTERITY_STATUS" },
    { passive = "Goon_Lone_Wolf_Constitution", status = "GOON_LONE_WOLF_CONSTITUTION_STATUS" },
    { passive = "Goon_Lone_Wolf_Intelligence", status = "GOON_LONE_WOLF_INTELLIGENCE_STATUS" },
    { passive = "Goon_Lone_Wolf_Wisdom", status = "GOON_LONE_WOLF_WISDOM_STATUS" },
    { passive = "Goon_Lone_Wolf_Charisma", status = "GOON_LONE_WOLF_CHARISMA_STATUS" },
}

local loneWolfBoosts = {
    { boost = "IncreaseMaxHP(30%)" },
    { boost = "DamageReduction(All,Half)" },
}

local function LoneWolfVars()
    local vars = Ext.Vars.GetModVariables(ModuleUUID)
    vars.LoneWolf = vars.LoneWolf or {}
    return vars.LoneWolf
end

local function ApplyLoneWolf(charID)
    Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1, 1)
    Osi.ApplyStatus(charID, GOON_LONE_WOLF_SE_BUFFS, -1, 1)
    for _, boost in ipairs(statBoosts) do
        if Osi.HasPassive(charID, boost.passive) == 1 then
            Osi.ApplyStatus(charID, boost.status, -1, 1)
        end
    end

    -- Preserve HP before applying boosts
    local entityHandle = Ext.Entity.Get(charID)
    if entityHandle and entityHandle.Health then
        local currentHp = entityHandle.Health.Hp
        local subscription
        for _, boost in ipairs(loneWolfBoosts) do
            Osi.AddBoosts(charID, boost.boost, charID, charID)
        end
        subscription = Ext.Entity.Subscribe("Health", function(health, _, _)
            -- Wait a bit longer after the engine's update before restoring HP
            Ext.Timer.WaitFor(100, function()
                health.Health.Hp = currentHp
                health:Replicate("Health")
                if subscription then
                    Ext.Entity.Unsubscribe(subscription)
                end
            end)
        end, entityHandle)
    else
        -- Fallback if entity/health not found
        for _, boost in ipairs(loneWolfBoosts) do
            Osi.AddBoosts(charID, boost.boost, charID, charID)
        end
    end

    LoneWolfVars()[charID] = true
end

local function RemoveLoneWolf(charID)
    Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
    Osi.RemoveStatus(charID, GOON_LONE_WOLF_SE_BUFFS)
    for _, boost in ipairs(statBoosts) do
        Osi.RemoveStatus(charID, boost.status)
    end
    for _, boost in ipairs(loneWolfBoosts) do
        Osi.RemoveBoosts(charID, boost.boost, 0, charID, charID)
    end
    LoneWolfVars()[charID] = nil
end

local function CheckAndUpdateLoneWolfBoosts()
    local vars = LoneWolfVars()
    local players = Osi.DB_Players:Get(nil) or {}
    local valid = {}
    for _, entry in pairs(players) do
        local charID = entry[1]
        if Osi.HasActiveStatus(charID, SITOUT_VANISH_STATUS) == 0 then
            table.insert(valid, charID)
        end
    end
    local partySize = #valid
    for _, charID in ipairs(valid) do
        local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE) == 1
        if hasPassive and partySize <= PartyLimit then
            ApplyLoneWolf(charID) -- Always reapply boosts
        else
            if vars[charID] then RemoveLoneWolf(charID) end
        end
    end
    -- Clean up anyone not in party
    for charID in pairs(vars) do
        if not table.find(valid, charID) then RemoveLoneWolf(charID) end
    end
end

function table.find(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    -- Ext.Utils.Print("Event triggered: LevelGameplayStarted")
    CheckAndUpdateLoneWolfBoosts()
end)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function()
    -- Ext.Utils.Print("Event triggered: CharacterJoinedParty")
    CheckAndUpdateLoneWolfBoosts()
end)

Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function()
    -- Ext.Utils.Print("Event triggered: CharacterLeftParty")
    CheckAndUpdateLoneWolfBoosts()
end)

-- Delay makes it happen after levelup is finished.
local function delayedUpdateLoneWolfStatus(character)
    Ext.Timer.WaitFor(500, function()
    CheckAndUpdateLoneWolfBoosts()
    end)
end

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    if Osi.IsPlayer(character) == 1 then
        -- Ext.Utils.Print("Event triggered: LeveledUp (player)")
        delayedUpdateLoneWolfStatus(character)
    end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, cause, _)
    if status == GOON_LONE_WOLF_SE_BUFFS or status == SITOUT_VANISH_STATUS then
        CheckAndUpdateLoneWolfBoosts(object)
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, cause, _)
    if status == GOON_LONE_WOLF_SE_BUFFS or status == SITOUT_VANISH_STATUS then
        CheckAndUpdateLoneWolfBoosts(object)
    end
end)