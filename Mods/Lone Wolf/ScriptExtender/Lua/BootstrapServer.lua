local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS" 
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply

local loneWolfStatBoosts = {
    Goon_Lone_Wolf_Strength = "Ability(Strength,4);ProficiencyBonus(SavingThrow,Strength)",
    Goon_Lone_Wolf_Dexterity = "Ability(Dexterity,4);ProficiencyBonus(SavingThrow,Dexterity)",
    Goon_Lone_Wolf_Constitution = "Ability(Constitution,4);ProficiencyBonus(SavingThrow,Constitution)",
    Goon_Lone_Wolf_Intelligence = "Ability(Intelligence,4);ProficiencyBonus(SavingThrow,Intelligence)",
    Goon_Lone_Wolf_Wisdom = "Ability(Wisdom,4);ProficiencyBonus(SavingThrow,Wisdom)",
    Goon_Lone_Wolf_Charisma = "Ability(Charisma,4);ProficiencyBonus(SavingThrow,Charisma)"
}

local loneWolfBoosts = {
    ExtraHP = "IncreaseMaxHP(30%)",
    DamageReduction = "DamageReduction(All,Half)",
}


-- Function to update Lone Wolf status for all party members
local function UpdateLoneWolfStatus()
    local partyMembers = Osi.DB_PartyMembers:Get(nil)
    local partySize = #partyMembers -- Count total party members

    Ext.Utils.Print(string.format("Total party members: %d", partySize))

    for _, member in pairs(partyMembers) do
        local charID = member[1]
        local displayName = Osi.GetDisplayName(charID) -- Fetch the display name of the character
        Ext.Utils.Print(string.format("Character ID: %s | Name: %s", charID, displayName))
    end

    -- Apply or remove the status based on party size and passive prerequisite
    for _, member in pairs(partyMembers) do
        local charID = member[1]
        Ext.Utils.Print(string.format("Processing character: %s", charID))

        -- Check if character has the Lone Wolf passive
        local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE)
        if hasPassive == 1 then -- Explicitly check if passive exists
            Ext.Utils.Print(string.format("Character %s has the Lone Wolf passive.", charID))
        else
            Ext.Utils.Print(string.format("Character %s does not have the Lone Wolf passive.", charID))
        end

        -- If character has the Lone Wolf passive, apply the status if party size is <= threshold
        if hasPassive == 1 then
            if partySize <= LONE_WOLF_THRESHOLD then
                -- Check if Lone Wolf status is not active, then apply it
                if Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 0 then
                    Ext.Utils.Print(string.format("Applying Lone Wolf status to %s", charID))
                    Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1)
                    for boostName, boost in pairs(loneWolfBoosts) do
                        Ext.Utils.Print(string.format("Applying %s boost to %s", boostName, charID))
                        Osi.AddBoosts(charID, boost, charID, charID)
                    end
        
                else
                    Ext.Utils.Print(string.format("Lone Wolf status already active on %s", charID))
                end

                for passive, boost in pairs(loneWolfStatBoosts) do
                    if Osi.HasPassive(charID, passive) == 1 then
                        Ext.Utils.Print(string.format("Applying boost for passive %s to %s", passive, charID))
                        Osi.AddBoosts(charID, boost, charID, charID)
                    end
                end
            else
                -- If the party size exceeds the threshold, remove the status
                if Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1 then
                    Ext.Utils.Print(string.format("Removing Lone Wolf status from %s (party size exceeded threshold)", charID))
                    Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
                    for boostName, boost in pairs(loneWolfBoosts) do
                        Ext.Utils.Print(string.format("Removing %s boost from %s", boostName, charID))
                        Osi.RemoveBoosts(charID, boost, 0, charID, charID)
                    end
                    for passive, boost in pairs(loneWolfStatBoosts) do
                        Ext.Utils.Print(string.format("Removing boost for passive %s from %s", passive, charID))
                        Osi.RemoveBoosts(charID, boost, 0, charID, charID)
                    end
                end
            end
        else
            -- If character doesn't have the Lone Wolf passive, remove the status
            if Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1 then
                Ext.Utils.Print(string.format("Removing Lone Wolf status from %s (missing passive)", charID))
                Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
                for boostName, boost in pairs(loneWolfBoosts) do
                    Ext.Utils.Print(string.format("Removing %s boost from %s", boostName, charID))
                    Osi.RemoveBoosts(charID, boost, 0, charID, charID)
                end
                for passive, boost in pairs(loneWolfStatBoosts) do
                    Ext.Utils.Print(string.format("Removing boost for passive %s from %s", passive, charID))
                    Osi.RemoveBoosts(charID, boost, 0, charID, charID)
                end
            end
        end
    end
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

-- Function to update Lone Wolf status after a delay after levelling up, copium that it works
local function DelayedUpdateLoneWolfStatus(character)
    Ext.Utils.Print(string.format("Waiting to update Lone Wolf status for character: %s", character))
    Ext.Timer.WaitFor(500, function()
        Ext.Utils.Print("Event triggered: LeveledUp (Delayed)")
        UpdateLoneWolfStatus()
    end)
end

-- Register listener for "LeveledUp" event
Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    Ext.Utils.Print("Event triggered: LeveledUp")
    DelayedUpdateLoneWolfStatus(character)
end)