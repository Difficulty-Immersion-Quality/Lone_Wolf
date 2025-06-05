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
    for _, boost in ipairs(loneWolfBoosts) do
        Osi.AddBoosts(charID, boost.boost, charID, charID)
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
            if not vars[charID] then ApplyLoneWolf(charID) end
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
    Ext.Utils.Print("Event triggered: LevelGameplayStarted")
    CheckAndUpdateLoneWolfBoosts()
end)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function()
    Ext.Utils.Print("Event triggered: CharacterJoinedParty")
    CheckAndUpdateLoneWolfBoosts()
end)

Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function()
    Ext.Utils.Print("Event triggered: CharacterLeftParty")
    CheckAndUpdateLoneWolfBoosts()
end)

-- Delay makes it happen after levelup is finished.
local function delayedUpdateLoneWolfStatus(character)
    Ext.Timer.WaitFor(500, function()
    CheckAndUpdateLoneWolfBoosts()
    end)
end

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    Ext.Utils.Print("Event triggered: LeveledUp")
    delayedUpdateLoneWolfStatus(character)
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