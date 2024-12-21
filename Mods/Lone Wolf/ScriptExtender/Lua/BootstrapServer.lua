local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local LONE_WOLF_SE_BUFFS = "GOON_LONE_WOLF_SE_BUFFS"
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply
local isUpdating = false -- Prevent recursive calls

local OCS_OBJECT_CHARACTER_TAG = "OCS_ObjectCharacter"  -- Or your UUID if it's defined as a tag
local SPECIAL_UUID = "0c506445-fba0-404c-a169-41af0912e618"  -- The UUID to check for

-- Function to check if a character has the OCS tag or the special UUID tag
local function CharacterHasTagByUUID(charID, tag)
    if not charID or not tag then
        Ext.Utils.PrintError("[CharacterHasTagByUUID] Invalid arguments: charID or tag is nil.")
        return false
    end

    -- Check if the character has the specified tag or the special UUID
    if Osi.IsTagged(charID, tag) == 1 or Osi.IsTagged(charID, SPECIAL_UUID) == 1 then
        return true
    end

    return false
end


-- Function to apply stat boosts dynamically
local function ApplyStatBoosts(charID)
    local statBoosts = {
        { passive = "Goon_Lone_Wolf_Strength", status = "GOON_LONE_WOLF_STRENGTH_STATUS" },
        { passive = "Goon_Lone_Wolf_Dexterity", status = "GOON_LONE_WOLF_DEXTERITY_STATUS" },
        { passive = "Goon_Lone_Wolf_Constitution", status = "GOON_LONE_WOLF_CONSTITUTION_STATUS" },
        { passive = "Goon_Lone_Wolf_Intelligence", status = "GOON_LONE_WOLF_INTELLIGENCE_STATUS" },
        { passive = "Goon_Lone_Wolf_Wisdom", status = "GOON_LONE_WOLF_WISDOM_STATUS" },
        { passive = "Goon_Lone_Wolf_Charisma", status = "GOON_LONE_WOLF_CHARISMA_STATUS" },
    }

    -- Handle stat boosts based on passives and statuses
    for _, boost in ipairs(statBoosts) do
        if Osi.HasPassive(charID, boost.passive) == 1 then
            -- Apply status if passive exists
            Osi.ApplyStatus(charID, boost.status, -1, 1) -- Apply status indefinitely
        else
            -- Remove status if passive doesn't exist
            Osi.RemoveStatus(charID, boost.status)
        end
    end
end

local function RemoveLoneWolfStatuses(charID)
    local statuses = {
        "GOON_LONE_WOLF_STATUS",
        "GOON_LONE_WOLF_STRENGTH_STATUS",
        "GOON_LONE_WOLF_DEXTERITY_STATUS",
        "GOON_LONE_WOLF_CONSTITUTION_STATUS",
        "GOON_LONE_WOLF_INTELLIGENCE_STATUS",
        "GOON_LONE_WOLF_WISDOM_STATUS",
        "GOON_LONE_WOLF_CHARISMA_STATUS",
        "GOON_LONE_WOLF_SE_BUFFS" -- Add buffs status to be removed here
    }

    -- Handle removal of status effects and buffs
    for _, status in ipairs(statuses) do
        if Osi.HasActiveStatus(charID, status) == 1 then
            Ext.Utils.Print(string.format("[RemoveLoneWolfStatuses] Removing status %s from %s", status, charID))
            Osi.RemoveStatus(charID, status)
        else
            Ext.Utils.Print(string.format("[RemoveLoneWolfStatuses] Status %s not active on %s", status, charID))
        end
    end

    -- Remove Lone Wolf related buffs if present
    local extraBoosts = {
        { effect = "IncreaseMaxHP(30%)", boost = "IncreaseMaxHP(30%)" },
        { effect = "DamageReduction(All,Half)", boost = "DamageReduction(All,Half)" },
    }

    for _, extraBoost in ipairs(extraBoosts) do
        Osi.RemoveBoosts(charID, extraBoost.boost, 0, charID, charID)
    end
end


-- Function to update Lone Wolf status for all party members
local function UpdateLoneWolfStatus()
    if isUpdating then
        Ext.Utils.Print("[UpdateLoneWolfStatus] Update already in progress. Skipping.")
        return
    end

    isUpdating = true
    Ext.Utils.Print("[UpdateLoneWolfStatus] Starting update...")

    local success, errorMessage = pcall(function()
        local partyMembers = Osi.DB_PartyMembers:Get(nil)
        local validPartyMembers = {}

        -- Debug print the party members
        Ext.Utils.Print("[UpdateLoneWolfStatus] Party Members: ")
        for _, member in pairs(partyMembers) do
            Ext.Utils.Print(string.format("  - %s", member[1]))
        end

        -- Use the simplified tag-based exclusion
        for _, member in pairs(partyMembers) do
            local charID = member[1]
            -- Use the tag-based exclusion instead of DB_CharacterTags lookup
            if not CharacterHasTagByUUID(charID, OCS_OBJECT_CHARACTER_TAG) then
                table.insert(validPartyMembers, charID)
            else
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Excluding character %s due to tag %s", charID, OCS_OBJECT_CHARACTER_TAG))
            end
        end

        -- Debug print valid party members
        Ext.Utils.Print("[UpdateLoneWolfStatus] Valid Party Members: ")
        for _, charID in ipairs(validPartyMembers) do
            Ext.Utils.Print(string.format("  - %s", charID))
        end

        local partySize = #validPartyMembers
        Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Total valid party members: %d", partySize))

        -- Apply or remove Lone Wolf status based on party size and conditions
        for _, charID in ipairs(validPartyMembers) do
            Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Processing character: %s", charID))

            local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE) == 1
            local hasStatus = Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1

            if hasPassive and partySize <= LONE_WOLF_THRESHOLD then
                if not hasStatus then
                    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Applying Lone Wolf status to %s", charID))
                    Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1, 1)
                end

                ApplyStatBoosts(charID)
            else
                if hasStatus then
                    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Removing Lone Wolf status from %s", charID))
                    Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
                end

                -- Explicitly remove the Lone Wolf SE Buffs status and its associated boosts
                RemoveLoneWolfStatuses(charID)
            end
        end
    end)

    if not success then
        Ext.Utils.PrintError("[UpdateLoneWolfStatus] Error occurred: " .. errorMessage)
    end

    Ext.Utils.Print("[UpdateLoneWolfStatus] Update complete.")
    isUpdating = false
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
