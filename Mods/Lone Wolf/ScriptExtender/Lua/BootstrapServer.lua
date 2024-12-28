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

-- Track if the boosts have been applied to prevent duplication
local appliedBoosts = {}

local function applyStatBoosts(charID)
    for _, boost in ipairs(statBoosts) do
        if Osi.HasPassive(charID, boost.passive) == 1 then
            Osi.ApplyStatus(charID, boost.status, -1, 1)
        end
    end
end

local function applyLoneWolfBoosts(charID)
    if appliedBoosts[charID] then return end -- Skip if already applied

    local entityHandle = Ext.Entity.UuidToHandle(charID)
    if not entityHandle or not entityHandle.Health then return end

    local currentHp = entityHandle.Health.Hp
    local subscription

    for _, boost in ipairs(loneWolfBoosts) do
        Osi.AddBoosts(charID, boost.boost, charID, charID)
    end
    
    -- Mark that the boosts were applied
    appliedBoosts[charID] = true

    -- Ensure health stays consistent and prevent exploitation
    subscription = Ext.Entity.Subscribe("Health", function(health, _, _)
        health.Health.Hp = currentHp
        health:Replicate("Health")
        if subscription then
            Ext.Entity.Unsubscribe(subscription)
        end
    end, entityHandle)
end

--local function applyLoneWolfBoostsOnLevelUp(charID)
    -- Apply the Lone Wolf buffs
    --for _, boost in ipairs(loneWolfBoosts) do
        --Osi.AddBoosts(charID, boost.boost, charID, charID)
    --end

    -- Mark the buffs as applied for the character during level-up
    --appliedBoosts[charID] = true
--end


local function removeStatBoosts(charID)
    for _, boost in ipairs(statBoosts) do
        Osi.RemoveStatus(charID, boost.status)
    end
end

local function removeLoneWolfBoosts(charID)
    for _, boost in ipairs(loneWolfBoosts) do
        Osi.RemoveBoosts(charID, boost.boost, 0, charID, charID)
    end

    -- Mark that the boosts were removed
    appliedBoosts[charID] = nil
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

        if hasPassive and partySize <= LONE_WOLF_THRESHOLD then
            -- Apply Lone Wolf status and dummy status for boost application
            if not hasStatus then
                Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1, 1)
                Osi.ApplyStatus(charID, GOON_LONE_WOLF_SE_BUFFS, -1, 1)
            end
            applyStatBoosts(charID)
            --applyLoneWolfBoosts(charID)
        else
            -- Remove Lone Wolf status, dummy status, and boosts
            if hasStatus then
                Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
                Osi.RemoveStatus(charID, GOON_LONE_WOLF_SE_BUFFS)
            end
            removeStatBoosts(charID)
            removeLoneWolfBoosts(charID)
        end
    end
end

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function()
    --Ext.Utils.Print("Event triggered: CharacterJoinedParty")
    updateLoneWolfStatus()
end)

if Osi.HasActiveStatus(character, GOON_LONE_WOLF_SE_BUFFS) == 1 then
    applyLoneWolfBoosts(character)
end

Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function()
    --Ext.Utils.Print("Event triggered: CharacterLeftParty")
    updateLoneWolfStatus()
end)

if Osi.HasActiveStatus(character, GOON_LONE_WOLF_SE_BUFFS) == 1 then
    applyLoneWolfBoosts(character)
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    --Ext.Utils.Print("Event triggered: LevelGameplayStarted")
    updateLoneWolfStatus()
end)

if Osi.HasActiveStatus(character, GOON_LONE_WOLF_SE_BUFFS) == 1 then
    applyLoneWolfBoosts(character)
end

-- Delay makes it happen after levelup is finished.
--local function delayedUpdateLoneWolfStatus(character)
    --Ext.Utils.Print(string.format("[delayedUpdateLoneWolfStatus] Waiting to update Lone Wolf status for character: %s", character))
    --Ext.Timer.WaitFor(500, function()
        --Ext.Utils.Print("[delayedUpdateLoneWolfStatus] Event triggered: LeveledUp (Delayed)")
        --updateLoneWolfStatus()
    --end)
--end

--Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    -- Check if the character has the GOON_LONE_WOLF_SE_BUFFS status before proceeding
    --if Osi.HasActiveStatus(character, GOON_LONE_WOLF_SE_BUFFS) == 1 then
        -- Remove and reapply Lone Wolf boosts specifically for level-up
        --removeLoneWolfBoosts(character)

        --Ext.Timer.WaitFor(500, function()
            --applyLoneWolfBoostsOnLevelUp(character)
        --end)
    --end
--end)

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    Ext.Timer.WaitFor(500, function()
        updateLoneWolfStatus()
    end)
end)


-- Apply Lone Wolf Boosts when the dummy status is applied
--Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, cause, _)
    --if status == GOON_LONE_WOLF_SE_BUFFS then
        --applyLoneWolfBoosts(object)
    --end
--end)

-- Recalculate party limit when SITOUT_VANISH_STATUS is applied or removed
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, cause, _)
    if status == SITOUT_VANISH_STATUS then
        -- Recalculate party status when SITOUT_VANISH_STATUS is removed
        updateLoneWolfStatus()
    end

    if status == GOON_LONE_WOLF_SE_BUFFS then
        -- Check if the character has GOON_LONE_WOLF_SE_BUFFS before applying boosts
        if Osi.HasActiveStatus(character, GOON_LONE_WOLF_SE_BUFFS) == 1 then
            applyLoneWolfBoosts(character)
        end
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, cause, _)
    if status == SITOUT_VANISH_STATUS then
        -- Recalculate party status when SITOUT_VANISH_STATUS is removed
        updateLoneWolfStatus()
    end

    if status == GOON_LONE_WOLF_SE_BUFFS then
        -- Check if the character has GOON_LONE_WOLF_SE_BUFFS before applying boosts
        if Osi.HasActiveStatus(character, GOON_LONE_WOLF_SE_BUFFS) == 1 then
            applyLoneWolfBoosts(character)
        end
    end
end)

