local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply
local isUpdating = false -- Prevent recursive calls

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

    for _, boost in ipairs(statBoosts) do
        if Osi.HasPassive(charID, boost.passive) == 1 then
            Osi.ApplyStatus(charID, boost.status, -1, 1) -- Apply status indefinitely
        else
            Osi.RemoveStatus(charID, boost.status) -- Remove status if passive is not present
        end
    end
end

local loneWolfBoosts = {
    ExtraHP = "IncreaseMaxHP(30%)",
    DamageReduction = "DamageReduction(All,Half)",
}

-- Function to check if a character has a specific tag
local function CharacterHasTag(charID, tag)
    if not charID or not tag then
        Ext.Utils.PrintError("[CharacterHasTag] Invalid arguments: charID or tag is nil.")
        return false
    end

    local isTagged = Osi.IsTagged(charID, tag) == 1
    Ext.Utils.Print(string.format("[CharacterHasTag] Character %s has tag %s: %s", charID, tag, tostring(isTagged)))
    return isTagged
end

-- Function to remove Lone Wolf-related statuses from a character
local function RemoveLoneWolfStatuses(charID)
    local statuses = {
        "GOON_LONE_WOLF_STATUS",
        "GOON_LONE_WOLF_STRENGTH_STATUS",
        "GOON_LONE_WOLF_DEXTERITY_STATUS",
        "GOON_LONE_WOLF_CONSTITUTION_STATUS",
        "GOON_LONE_WOLF_INTELLIGENCE_STATUS",
        "GOON_LONE_WOLF_WISDOM_STATUS",
        "GOON_LONE_WOLF_CHARISMA_STATUS",
    }

    for _, status in ipairs(statuses) do
        if Osi.HasActiveStatus(charID, status) == 1 then
            Ext.Utils.Print(string.format("[RemoveLoneWolfStatuses] Removing status %s from %s", status, charID))
            Osi.RemoveStatus(charID, status)
        else
            Ext.Utils.Print(string.format("[RemoveLoneWolfStatuses] Status %s not active on %s", status, charID))
        end
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

        for _, member in pairs(partyMembers) do
            local charID = member[1]
            if not CharacterHasTag(charID, "OCS_ObjectCharacter") then
                table.insert(validPartyMembers, charID)
            else
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Excluding character %s due to tag OCS_ObjectCharacter", charID))
            end
        end

        local partySize = #validPartyMembers
        Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Total valid party members: %d", partySize))

        for _, charID in ipairs(validPartyMembers) do
            Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Processing character: %s", charID))

            local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE) == 1
            local hasStatus = Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1

            if hasPassive and partySize <= LONE_WOLF_THRESHOLD then
                if not hasStatus then
                    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Applying Lone Wolf status to %s", charID))
                    Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1, 1)
                end

                for boostName, boost in pairs(loneWolfBoosts) do
                    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Ensuring %s boost is applied to %s", boostName, charID))
                    Osi.AddBoosts(charID, boost, charID, charID)
                end

                ApplyStatBoosts(charID)
            else
                if hasStatus then
                    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Removing Lone Wolf status from %s", charID))
                    Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
                end

                for boostName, boost in pairs(loneWolfBoosts) do
                    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Removing %s boost from %s", boostName, charID))
                    Osi.RemoveBoosts(charID, boost, 0, charID, charID)
                end

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
