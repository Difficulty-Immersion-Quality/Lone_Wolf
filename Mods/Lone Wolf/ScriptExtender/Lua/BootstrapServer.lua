local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply
local statBoosts = {
        { passive = "Goon_Lone_Wolf_Strength", status = "GOON_LONE_WOLF_STRENGTH_STATUS" },
        { passive = "Goon_Lone_Wolf_Dexterity", status = "GOON_LONE_WOLF_DEXTERITY_STATUS" },
        { passive = "Goon_Lone_Wolf_Constitution", status = "GOON_LONE_WOLF_CONSTITUTION_STATUS" },
        { passive = "Goon_Lone_Wolf_Intelligence", status = "GOON_LONE_WOLF_INTELLIGENCE_STATUS" },
        { passive = "Goon_Lone_Wolf_Wisdom", status = "GOON_LONE_WOLF_WISDOM_STATUS" },
        { passive = "Goon_Lone_Wolf_Charisma", status = "GOON_LONE_WOLF_CHARISMA_STATUS" },
    }
local loneWolfBoosts = {
    { status = "GOON_LONE_WOLF_STATUS", boost = "IncreaseMaxHP(30%)" },
    { status = "GOON_LONE_WOLF_STATUS", boost = "DamageReduction(All,Half)" },
}

local function ApplyStatBoosts(charID)
    for _, boost in ipairs(statBoosts) do
        if Osi.HasPassive(charID, boost.passive) == 1 then
            Osi.ApplyStatus(charID, boost.status, -1, 1)
        end
    end
end

local function ApplyloneWolfBoosts(charID)
    for _, boost in ipairs(statBoosts) do
        if Osi.HasActiveStatus(charID, boost.status) == 1 then
            Osi.ApplyBoost(charID, boost.boost)
        end
    end
end

local function RemoveStatBoosts(charID)
    for _, boost in ipairs(statBoosts) do
        Osi.RemoveStatus(charID, boost.status, charID)
    end
end

local function UpdateLoneWolfStatus()
    local partyMembers = Osi.DB_PartyMembers:Get(nil)
    local Players = Osi.DB_Players:Get(nil)
    local validPartyMembers = {}

    -- Identify valid players in the party
    for _, member in pairs(partyMembers) do
        local charID = member[1]
        for _, playerEntry in pairs(Players) do
            if charID == playerEntry[1] then
                table.insert(validPartyMembers, charID)
                Ext.Utils.Print(string.format("[DEBUG] Valid player: %s", charID))
            end
        end
    end

    local partySize = #validPartyMembers

    -- Process each valid party member
    for _, charID in pairs(validPartyMembers) do
        local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE) == 1
        local hasStatus = Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1

        Ext.Utils.Print(string.format("[DEBUG] Processing character: %s", charID))
        Ext.Utils.Print(string.format("[DEBUG] Has Lone Wolf Passive: %s, Party Size: %d, Threshold: %d", tostring(hasPassive), partySize, LONE_WOLF_THRESHOLD))

        if hasPassive and partySize <= LONE_WOLF_THRESHOLD then
            -- Apply Lone Wolf buffs
            if not hasStatus then
                Ext.Utils.Print(string.format("[DEBUG] Applying Lone Wolf status to %s", charID))
                Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1, 1)
            end

            -- Apply each boost
            for _, boost in ipairs(loneWolfBoosts) do
                if not Osi.HasActiveStatus(charID, boost.status) then
                    Ext.Utils.Print(string.format("[DEBUG] Applying boost %s with %s to %s", boost.status, boost.boost, charID))
                    Osi.ApplyStatus(charID, boost.status, -1, 1)
                    -- Optionally, directly apply the boost (if supported):
                    -- Osi.ApplyBoost(charID, boost.boost)
                end
            end

            ApplyStatBoosts(charID)
            ApplyloneWolfBoosts(charID)
        else
            -- Remove Lone Wolf buffs
            if hasStatus then
                Ext.Utils.Print(string.format("[DEBUG] Removing Lone Wolf status from %s", charID))
                Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
            end

            for _, boost in ipairs(loneWolfBoosts) do
                if Osi.HasActiveStatus(charID, boost.status) then
                    Ext.Utils.Print(string.format("[DEBUG] Removing boost %s from %s", boost.status, charID))
                    Osi.RemoveStatus(charID, boost.status)
                end
            end

            RemoveStatBoosts(charID)
        end
    end

    Ext.Utils.Print("[UpdateLoneWolfStatus] Update complete.")
end




Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function()
    Ext.Utils.Print("Event triggered: CharacterJoinedParty")
    UpdateLoneWolfStatus()
end)

Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function()
    Ext.Utils.Print("Event triggered: CharacterLeftParty")
    UpdateLoneWolfStatus()
end)

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    Ext.Utils.Print("Event triggered: LevelGameplayStarted")
    UpdateLoneWolfStatus()
end)

---Delay makes it happen after levelup is finished.
local function DelayedUpdateLoneWolfStatus(character)
    Ext.Utils.Print(string.format("[DelayedUpdateLoneWolfStatus] Waiting to update Lone Wolf status for character: %s", character))
    Ext.Timer.WaitFor(500, function()
        Ext.Utils.Print("[DelayedUpdateLoneWolfStatus] Event triggered: LeveledUp (Delayed)")
        UpdateLoneWolfStatus()
    end)
end

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    Ext.Utils.Print("Event triggered: LeveledUp")
    DelayedUpdateLoneWolfStatus(character)
end)