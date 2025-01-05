local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local GOON_LONE_WOLF_SE_BUFFS = "GOON_LONE_WOLF_SE_BUFFS" -- Dummy status for boost application
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply
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

local function applyStatBoosts(charID)
    for _, boost in ipairs(statBoosts) do
        if Osi.HasPassive(charID, boost.passive) == 1 then
            Osi.ApplyStatus(charID, boost.status, -1, 1)
        end
    end
end

local function applyLoneWolfBoosts(charID)
    -- Check if the status is already applied
    if Osi.HasActiveStatus(charID, GOON_LONE_WOLF_SE_BUFFS) == 0 then
        return -- Status is not active, no boost application
    end

    local entityHandle = Ext.Entity.UuidToHandle(charID)
    if not entityHandle or not entityHandle.Health then return end

    local currentHp = entityHandle.Health.Hp
    local subscription

    for _, boost in ipairs(loneWolfBoosts) do
        Osi.AddBoosts(charID, boost.boost, charID, charID)
    end

    -- Ensure health remains consistent and prevent exploitation
    subscription = Ext.Entity.Subscribe("Health", function(health, _, _)
        health.Health.Hp = currentHp
        health:Replicate("Health")
        if subscription then
            Ext.Entity.Unsubscribe(subscription)
        end
    end, entityHandle)
end

local function removeStatBoosts(charID)
    for _, boost in ipairs(statBoosts) do
        Osi.RemoveStatus(charID, boost.status)
    end
end

local function removeLoneWolfBoosts(charID)
    for _, boost in ipairs(loneWolfBoosts) do
        Osi.RemoveBoosts(charID, boost.boost, 0, charID, charID)    
    end
end

local function updateLoneWolfStatus()
    local Players = Osi.DB_Players:Get(nil)
    local validPlayers = {}

    -- Identify valid players
    for _, playerEntry in pairs(Players) do
        local charID = playerEntry[1]
        if Osi.HasActiveStatus(charID, SITOUT_VANISH_STATUS) == 0 then
            table.insert(validPlayers, charID)
        end
    end

    local partySize = #validPlayers

    -- Process each valid player
    for _, charID in pairs(validPlayers) do
        local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE) == 1
        local hasStatus = Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1
        Ext.Utils.Print(string.format("[DEBUG] Processing character: %s", charID))
        Ext.Utils.Print(string.format("[DEBUG] Has Lone Wolf Passive: %s, Party Size: %d, Threshold: %d", tostring(hasPassive), partySize, LONE_WOLF_THRESHOLD))

        if hasPassive and partySize <= LONE_WOLF_THRESHOLD then
            -- Apply Lone Wolf status and dummy status for boost application
            if not hasStatus then
                Ext.Utils.Print(string.format("[DEBUG] Applying Lone Wolf status to %s", charID))
                Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1, 1)
                Osi.ApplyStatus(charID, GOON_LONE_WOLF_SE_BUFFS, -1, 1)
            end
            applyStatBoosts(charID)
        else
            -- Remove Lone Wolf status, dummy status, and boosts
            if hasStatus then
                Ext.Utils.Print(string.format("[DEBUG] Removing Lone Wolf status from %s", charID))
                Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
                Osi.RemoveStatus(charID, GOON_LONE_WOLF_SE_BUFFS)
            end
            removeStatBoosts(charID)
            removeLoneWolfBoosts(charID)
        end
    end
    --Ext.Utils.Print("[updateLoneWolfStatus] Update complete.")
end

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function()
    --Ext.Utils.Print("Event triggered: CharacterJoinedParty")
    updateLoneWolfStatus()
end)

Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function()
    --Ext.Utils.Print("Event triggered: CharacterLeftParty")
    updateLoneWolfStatus()
end)

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    -- Update Lone Wolf status for all players
    updateLoneWolfStatus()
    
    -- Reapply Lone Wolf boosts for characters with GOON_LONE_WOLF_SE_BUFFS
    local Players = Osi.DB_Players:Get(nil)
    for _, playerEntry in pairs(Players) do
        local charID = playerEntry[1]
        if Osi.HasActiveStatus(charID, GOON_LONE_WOLF_SE_BUFFS) == 1 then
            removeLoneWolfBoosts(charID)
            applyLoneWolfBoosts(charID)
        end
    end
end)


-- Delay makes it happen after levelup is finished.
local function delayedUpdateLoneWolfStatus(character)
    --Ext.Utils.Print(string.format("[delayedUpdateLoneWolfStatus] Waiting to update Lone Wolf status for character: %s", character))
    Ext.Timer.WaitFor(500, function()
        --Ext.Utils.Print("[delayedUpdateLoneWolfStatus] Event triggered: LeveledUp (Delayed)")
        updateLoneWolfStatus()
    end)
end

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    --Ext.Utils.Print("Event triggered: LeveledUp")
    delayedUpdateLoneWolfStatus(character)
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, cause, _)
    if status == SITOUT_VANISH_STATUS then
        updateLoneWolfStatus()
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, cause, _)
    if status == SITOUT_VANISH_STATUS then
        updateLoneWolfStatus()
    end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, cause, _)
    if status == GOON_LONE_WOLF_SE_BUFFS then
        applyLoneWolfBoosts(object)
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, cause, _)
    if status == GOON_LONE_WOLF_SE_BUFFS then
        removeLoneWolfBoosts(object)
    end
end)