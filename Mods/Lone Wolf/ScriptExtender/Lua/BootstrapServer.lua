local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply

-- Function to update Lone Wolf status for all party members
local function UpdateLoneWolfStatus()
    local partyMembers = Osi.DB_PartyMembers:Get(nil)
    local partySize = #partyMembers -- Count total party members

    Ext.Utils.Print(string.format("Total party members: %d", partySize))

    -- Loop through all party members
    for _, member in pairs(partyMembers) do
        local charID = member[1]
        Ext.Utils.Print(string.format("Processing character: %s", charID))

        -- Check if character has the Lone Wolf passive
        local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE) == 1
        local hasStatus = Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1

        if hasPassive then
            Ext.Utils.Print(string.format("Character %s has the Lone Wolf passive.", charID))

            -- Apply or remove status based on party size
            if partySize <= LONE_WOLF_THRESHOLD then
                if not hasStatus then
                    Ext.Utils.Print(string.format("Applying Lone Wolf status to %s", charID))
                    Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1) -- Apply status indefinitely
                else
                    Ext.Utils.Print(string.format("Lone Wolf status already active on %s", charID))
                end
            else
                if hasStatus then
                    Ext.Utils.Print(string.format("Removing Lone Wolf status from %s (party size exceeded threshold)", charID))
                    Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
                end
            end
        else
            if hasStatus then
                Ext.Utils.Print(string.format("Removing Lone Wolf status from %s (missing passive)", charID))
                Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
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