local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply
local isUpdating = false -- Prevent recursive calls

local loneWolfStatBoosts = {
    Goon_Lone_Wolf_Strength = functionOsi.ApplyStatus(charID, GOON_LONE_WOLF_STRENGTH_STATUS, -1, 1),
    Goon_Lone_Wolf_Dexterity = Osi.ApplyStatus(charID, GOON_LONE_WOLF_DEXTERITY_STATUS, -1, 1),
    Goon_Lone_Wolf_Constitution = Osi.ApplyStatus(charID, GOON_LONE_WOLF_CONSTITUTION_STATUS, -1, 1),
    Goon_Lone_Wolf_Intelligence = Osi.ApplyStatus(charID, GOON_LONE_WOLF_INTELLIGENCE_STATUS, -1, 1),
    Goon_Lone_Wolf_Wisdom = Osi.ApplyStatus(charID, GOON_LONE_WOLF_WISDOM_STATUS, -1, 1),
    Goon_Lone_Wolf_Charisma = Osi.ApplyStatus(charID, GOON_LONE_WOLF_CHARISMA_STATUS, -1, 1)
}

local loneWolfBoosts = {
    ExtraHP = "IncreaseMaxHP(30%)",
    DamageReduction = "DamageReduction(All,Half)",
}

-- Function to update Lone Wolf status for all party members
local function UpdateLoneWolfStatus()
    if isUpdating then
        Ext.Utils.Print("[UpdateLoneWolfStatus] Update already in progress. Skipping.")
        return
    end

    isUpdating = true
    Ext.Utils.Print("[UpdateLoneWolfStatus] Starting update...")

    local partyMembers = Osi.DB_PartyMembers:Get(nil)
    local partySize = #partyMembers -- Count total party members

    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Total party members: %d", partySize))

    -- Loop through all party members
    for _, member in pairs(partyMembers) do
        local charID = member[1]
        Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Processing character: %s", charID))

        -- Check if character has the Lone Wolf passive
        local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE) == 1
        local hasStatus = Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1

        if hasPassive and partySize <= LONE_WOLF_THRESHOLD then
            -- Apply status and boosts
            if not hasStatus then
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Applying Lone Wolf status to %s", charID))
                Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1, 1) -- Apply status indefinitely
            end

            for boostName, boost in pairs(loneWolfBoosts) do
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Ensuring %s boost is applied to %s", boostName, charID))
                Osi.AddBoosts(charID, boost, charID, charID)
            end

            for passive, boost in pairs(loneWolfStatBoosts) do
                if Osi.HasPassive(charID, passive) == 1 then
                    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Applying stat boost for passive %s to %s", passive, charID))
                    Osi.AddBoosts(charID, boost, charID, charID)
                end
            end
        else
            -- Remove status and boosts if criteria are not met
            if hasStatus then
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Removing Lone Wolf status from %s", charID))
                Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
            end

            for boostName, boost in pairs(loneWolfBoosts) do
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Removing %s boost from %s", boostName, charID))
                Osi.RemoveBoosts(charID, boost, 0, charID, charID)
            end

            for passive, boost in pairs(loneWolfStatBoosts) do
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Removing stat boost for passive %s from %s", passive, charID))
                Osi.RemoveBoosts(charID, boost, 0, charID, charID)
            end
        end
    end

    Ext.Utils.Print("[UpdateLoneWolfStatus] Update complete.")
    isUpdating = false
end


-- Event: Party size changes
Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function()
    Ext.Utils.Print("Event triggered: CharacterJoinedParty")
    UpdateLoneWolfStatus()
end)

Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function()
    Ext.Utils.Print("Event triggered: CharacterLeftParty")
    UpdateLoneWolfStatus()
end)

-- Event: Gameplay starts
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    Ext.Utils.Print("Event triggered: LevelGameplayStarted")
    UpdateLoneWolfStatus()
end)

-- Function to update Lone Wolf status after a delay for level-ups
local function DelayedUpdateLoneWolfStatus(character)
    Ext.Utils.Print(string.format("[DelayedUpdateLoneWolfStatus] Waiting to update Lone Wolf status for character: %s", character))
    Ext.Timer.WaitFor(500, function()
        Ext.Utils.Print("[DelayedUpdateLoneWolfStatus] Event triggered: LeveledUp (Delayed)")
        UpdateLoneWolfStatus()
    end)
end

-- Register listener for "LeveledUp" event
Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    Ext.Utils.Print("Event triggered: LeveledUp")
    DelayedUpdateLoneWolfStatus(character)
end)
