---@diagnostic disable: undefined-field, inject-field

local Translator = LoneWolf.Translator
local Config = LoneWolf.Config
local settings = Config.Read()
local widgets = {}
local overridesSectionUI = nil
local syncToken = 0
local DR_TYPE_OPTIONS = { "Half", "Flat", "Threshold" }
local ABILITY_OPTIONS = { "None", "Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma" }
local SLIDER_DEBOUNCE_MS = 200

local CHECKBOX_WIDGETS = {
    { widget = "enableMod",       setting = "enabled" },
    { widget = "requirePassive",  setting = "requirePassive" },
    { widget = "coreBuffs",       setting = "enableCoreBuffs" },
    { widget = "hpMax",           setting = "enableHpMax" },
    { widget = "damageReduction", setting = "enableDamageReduction" },
    { widget = "statBoosts",      setting = "enableStatBoosts" },
}

local SLIDER_WIDGETS = {
    { widget = "partyLimit",        setting = "partyLimit" },
    { widget = "hpPercent",         setting = "hpPercent" },
    { widget = "drPercent",         setting = "drPercent" },
    { widget = "abilityBonus",      setting = "abilityBonus" },
    { widget = "actionPoints",      setting = "actionPoints" },
    { widget = "bonusActionPoints", setting = "bonusActionPoints" },
    { widget = "reactionPoints",    setting = "reactionPoints" },
    { widget = "carryMultiplier",   setting = "carryMultiplier" },
}

local function SyncToServer(debounceMs)
    syncToken = syncToken + 1
    local token = syncToken
    local doSync = function()
        Config.Save(settings)
        LoneWolf.ConfigChannel:SendToServer({ settings = settings })
    end

    if debounceMs and debounceMs > 0 then
        Ext.Timer.WaitFor(debounceMs, function()
            if token == syncToken then doSync() end
        end)
    else
        doSync()
    end
end

local function GetOptionIndex(options, value)
    for i, option in ipairs(options) do
        if option == value then
            return i - 1
        end
    end
    return 0
end

local function GetAbilityOverrides()
    local vars = Ext.Vars.GetModVariables(ModuleUUID)
    vars.LoneWolfData = vars.LoneWolfData or {}
    vars.LoneWolfData.AbilityOverrides = vars.LoneWolfData.AbilityOverrides or {}
    return vars.LoneWolfData.AbilityOverrides
end

local function GetPartyMembers()
    local list = {}
    local partyMembers = Ext.Entity.GetAllEntitiesWithComponent("PartyMember")
    for _, entity in ipairs(partyMembers) do
        local name = entity.Uuid.EntityUuid
        if entity.DisplayName then
            local result = entity.DisplayName.Name:Get()
            if result ~= "" then
                name = result
            end
        end
        table.insert(list, { uuid = entity.Uuid.EntityUuid, name = name })
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

local function SavePlayerOverride(abilityOverrides, key, firstCombo, secondCombo)
    local first = ABILITY_OPTIONS[firstCombo.SelectedIndex + 1]
    local second = ABILITY_OPTIONS[secondCombo.SelectedIndex + 1]
    if first == "None" and second == "None" then
        abilityOverrides[key] = nil
    else
        abilityOverrides[key] = { first = first, second = second }
    end
    local vars = Ext.Vars.GetModVariables(ModuleUUID)
    local data = vars.LoneWolfData
    data.AbilityOverrides = abilityOverrides
    vars.LoneWolfData = data
    SyncToServer()
end

local function RebuildOverridesSection()
    local ui = overridesSectionUI
    if not ui then return end
    local children = ui.Children
    for _, child in ipairs(children) do child:Destroy() end

    local note = ui:AddText(Translator:translate("AbilityOverridesNote"))
    note.TextWrapPos = 0

    local refreshBtn = ui:AddButton(Translator:translate("Button_RefreshParty"))
    refreshBtn.OnClick = function() RebuildOverridesSection() end

    local players = GetPartyMembers()
    if #players == 0 then
        ui:AddText(Translator:translate("AbilityOverridesEmpty"))
        return
    end

    local abilityOverrides = GetAbilityOverrides()
    local tableObj = ui:AddTable("LoneWolfAbilityOverrides", 4)
    tableObj.Borders = true
    tableObj.RowBg = true
    tableObj:AddColumn(Translator:translate("OverridesHeader_Name"), "WidthStretch", 1.0)
    tableObj:AddColumn(Translator:translate("OverridesHeader_First"), "WidthFixed", 180)
    tableObj:AddColumn(Translator:translate("OverridesHeader_Second"), "WidthFixed", 180)
    tableObj:AddColumn("", "WidthFixed", 70)

    local header = tableObj:AddRow()
    header.Headers = true
    header:AddCell():AddText(Translator:translate("OverridesHeader_Name"))
    header:AddCell():AddText(Translator:translate("OverridesHeader_First"))
    header:AddCell():AddText(Translator:translate("OverridesHeader_Second"))
    header:AddCell():AddText("")

    for _, player in ipairs(players) do
        local row = tableObj:AddRow()
        row:AddCell():AddText(player.name)

        local key = player.uuid
        local playerOverride = abilityOverrides[key] or {}
        local firstVal = playerOverride.first or "None"
        local secondVal = playerOverride.second or "None"

        local firstCombo = row:AddCell():AddCombo("##LW_First_" .. player.uuid)
        firstCombo.Options = ABILITY_OPTIONS
        firstCombo.SelectedIndex = GetOptionIndex(ABILITY_OPTIONS, firstVal)
        firstCombo.Disabled = settings.requirePassive

        local secondCombo = row:AddCell():AddCombo("##LW_Second_" .. player.uuid)
        secondCombo.Options = ABILITY_OPTIONS
        secondCombo.SelectedIndex = GetOptionIndex(ABILITY_OPTIONS, secondVal)
        secondCombo.Disabled = settings.requirePassive

        firstCombo.OnChange = function() SavePlayerOverride(abilityOverrides, key, firstCombo, secondCombo) end
        secondCombo.OnChange = function() SavePlayerOverride(abilityOverrides, key, firstCombo, secondCombo) end

        local clearBtn = row:AddCell():AddButton(Translator:translate("OverridesButton_Clear"))
        clearBtn.Disabled = settings.requirePassive
        clearBtn.OnClick = function()
            firstCombo.SelectedIndex = 0
            secondCombo.SelectedIndex = 0
            SavePlayerOverride(abilityOverrides, key, firstCombo, secondCombo)
        end
    end
end

local function RefreshUI()
    for _, binding in ipairs(CHECKBOX_WIDGETS) do
        widgets[binding.widget].Checked = settings[binding.setting]
    end
    for _, binding in ipairs(SLIDER_WIDGETS) do
        widgets[binding.widget].Value = { settings[binding.setting], 0, 0, 0 }
    end
    widgets.drType.SelectedIndex = GetOptionIndex(DR_TYPE_OPTIONS, settings.drType)
    RebuildOverridesSection()
end

if not Mods.BG3MCM then
    Ext.Log.Print(Translator:translate("Warn_MCMNotFound"))
    return
end

MCM.InsertModMenuTab(Translator:translate("TabName"), function(tabHeader)
    tabHeader:AddText(Translator:translate("Info_Intro"))
    tabHeader:AddSeparator()

    local generalHeader = tabHeader:AddCollapsingHeader(Translator:translate("Header_General"))
    generalHeader.DefaultOpen = true

    widgets.enableMod = generalHeader:AddCheckbox(Translator:translate("Checkbox_EnableMod"), settings.enabled)
    widgets.enableMod.OnChange = function(chk)
        settings.enabled = chk.Checked
        SyncToServer()
    end

    widgets.partyLimit = generalHeader:AddSliderInt(Translator:translate("Slider_PartyLimit"), settings.partyLimit, 0,
        10)
    widgets.partyLimit:Tooltip():AddText(Translator:translate("Tooltip_PartyLimit"))
    widgets.partyLimit.OnChange = function(slider)
        settings.partyLimit = slider.Value[1]
        SyncToServer(SLIDER_DEBOUNCE_MS)
    end

    widgets.requirePassive = generalHeader:AddCheckbox(Translator:translate("Checkbox_RequirePassive"),
        settings.requirePassive)
    widgets.requirePassive:Tooltip():AddText(Translator:translate("Tooltip_RequirePassive"))
    widgets.requirePassive.OnChange = function(chk)
        settings.requirePassive = chk.Checked
        SyncToServer()
        RebuildOverridesSection()
    end

    local effectsHeader = tabHeader:AddCollapsingHeader(Translator:translate("Header_Effects"))
    effectsHeader.DefaultOpen = true

    widgets.coreBuffs = effectsHeader:AddCheckbox(Translator:translate("Checkbox_CoreBuffs"),
        settings.enableCoreBuffs)
    widgets.coreBuffs.OnChange = function(chk)
        settings.enableCoreBuffs = chk.Checked
        SyncToServer()
    end

    widgets.hpMax = effectsHeader:AddCheckbox(Translator:translate("Checkbox_HpMax"), settings.enableHpMax)
    widgets.hpMax.OnChange = function(chk)
        settings.enableHpMax = chk.Checked
        SyncToServer()
    end

    widgets.damageReduction = effectsHeader:AddCheckbox(Translator:translate("Checkbox_DamageReduction"),
        settings.enableDamageReduction)
    widgets.damageReduction.OnChange = function(chk)
        settings.enableDamageReduction = chk.Checked
        SyncToServer()
    end

    widgets.statBoosts = effectsHeader:AddCheckbox(Translator:translate("Checkbox_StatBoosts"),
        settings.enableStatBoosts)
    widgets.statBoosts.OnChange = function(chk)
        settings.enableStatBoosts = chk.Checked
        SyncToServer()
    end

    widgets.hpPercent = effectsHeader:AddSliderInt(Translator:translate("Slider_HpPercent"), settings.hpPercent, 0,
        100)
    widgets.hpPercent:Tooltip():AddText(Translator:translate("Tooltip_HpPercent"))
    widgets.hpPercent.OnChange = function(slider)
        settings.hpPercent = slider.Value[1]
        SyncToServer(SLIDER_DEBOUNCE_MS)
    end

    widgets.drType = effectsHeader:AddCombo(Translator:translate("Dropdown_DrType"))
    widgets.drType.Options = DR_TYPE_OPTIONS
    widgets.drType.SelectedIndex = GetOptionIndex(DR_TYPE_OPTIONS, settings.drType)
    widgets.drType:Tooltip():AddText(Translator:translate("Tooltip_DrType"))
    widgets.drType.OnChange = function(combo)
        settings.drType = DR_TYPE_OPTIONS[combo.SelectedIndex + 1]
        SyncToServer()
    end

    widgets.drPercent = effectsHeader:AddSliderInt(Translator:translate("Slider_DrPercent"), settings.drPercent, 0,
        100)
    widgets.drPercent:Tooltip():AddText(Translator:translate("Tooltip_DrPercent"))
    widgets.drPercent.OnChange = function(slider)
        settings.drPercent = slider.Value[1]
        SyncToServer(SLIDER_DEBOUNCE_MS)
    end

    widgets.abilityBonus = effectsHeader:AddSliderInt(Translator:translate("Slider_AbilityBonus"),
        settings.abilityBonus, 0, 10)
    widgets.abilityBonus:Tooltip():AddText(Translator:translate("Tooltip_AbilityBonus"))
    widgets.abilityBonus.OnChange = function(slider)
        settings.abilityBonus = slider.Value[1]
        SyncToServer(SLIDER_DEBOUNCE_MS)
    end

    local coreHeader = effectsHeader:AddCollapsingHeader(Translator:translate("Header_CoreBuffs"))
    coreHeader.DefaultOpen = false

    widgets.actionPoints = coreHeader:AddSliderInt(Translator:translate("Slider_ActionPoints"), settings
        .actionPoints, 0, 5)
    widgets.actionPoints:Tooltip():AddText(Translator:translate("Tooltip_ActionPoints"))
    widgets.actionPoints.OnChange = function(slider)
        settings.actionPoints = slider.Value[1]
        SyncToServer(SLIDER_DEBOUNCE_MS)
    end

    widgets.bonusActionPoints = coreHeader:AddSliderInt(Translator:translate("Slider_BonusActionPoints"),
        settings.bonusActionPoints, 0, 5)
    widgets.bonusActionPoints:Tooltip():AddText(Translator:translate("Tooltip_BonusActionPoints"))
    widgets.bonusActionPoints.OnChange = function(slider)
        settings.bonusActionPoints = slider.Value[1]
        SyncToServer(SLIDER_DEBOUNCE_MS)
    end

    widgets.reactionPoints = coreHeader:AddSliderInt(Translator:translate("Slider_ReactionPoints"),
        settings.reactionPoints, 0, 5)
    widgets.reactionPoints:Tooltip():AddText(Translator:translate("Tooltip_ReactionPoints"))
    widgets.reactionPoints.OnChange = function(slider)
        settings.reactionPoints = slider.Value[1]
        SyncToServer(SLIDER_DEBOUNCE_MS)
    end

    widgets.carryMultiplier = coreHeader:AddSlider(Translator:translate("Slider_CarryMultiplier"),
        settings.carryMultiplier, 0.0, 10.0)
    widgets.carryMultiplier:Tooltip():AddText(Translator:translate("Tooltip_CarryMultiplier"))
    widgets.carryMultiplier.OnChange = function(slider)
        settings.carryMultiplier = slider.Value[1]
        SyncToServer(SLIDER_DEBOUNCE_MS)
    end

    tabHeader:AddSeparator()
    overridesSectionUI = tabHeader:AddCollapsingHeader(Translator:translate("Header_AbilityOverrides"))
    overridesSectionUI.DefaultOpen = false
    RebuildOverridesSection()

    tabHeader:AddSeparator()
    local resetButton = tabHeader:AddButton(Translator:translate("Button_Reset"))
    resetButton.OnClick = function()
        settings = Config.ApplyDefaults({})
        SyncToServer()
        RefreshUI()
    end
end)
