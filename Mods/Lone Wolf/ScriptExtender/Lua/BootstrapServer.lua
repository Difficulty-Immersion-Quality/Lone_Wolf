local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive"
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply

-- Function to update Lone Wolf status for all party members
local function UpdateLoneWolfStatus()
    local partyMembers = Osi.DB_PartyMembers:Get(nil)
    local partySize = #partyMembers -- Count total party members

    Ext.Utils.Print(string.format("Total party members: %d", partySize))

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
                    Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1) -- Apply status for 99999 seconds
                else
                    Ext.Utils.Print(string.format("Lone Wolf status already active on %s", charID))
                end
            else
                -- If the party size exceeds the threshold, remove the status
                if Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1 then
                    Ext.Utils.Print(string.format("Removing Lone Wolf status from %s (party size exceeded threshold)", charID))
                    Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
                end
            end
        else
            -- If character doesn't have the Lone Wolf passive, remove the status
            if Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1 then
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

-- Optional: Check for level up and apply
Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    Ext.Utils.Print("Event triggered: LeveledUp")
    UpdateLoneWolfStatus()
end)
