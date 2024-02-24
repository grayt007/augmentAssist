local MyAddOnName,NS = ...
local addon = _G[MyAddOnName]

local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT

--Runs in application namespace
setfenv(1, addon)

--This table should be serializable.  INdented means not in the options file yet
defaultConfig = {

    -- General
    --Applies to all text
        fontName = STANDARD_TEXT_FONT, 
        fontHeight = 11, 
        fontColor = {1,1,1},
    -- userDisabled = false,
    hideOutOfGroup = false,
    autoHideHeader = false,
    createTestData = false,
    doYouHaveDevTool = true,
    doYouWantToDebug = true,

    welcomeMessage = true,
    welcomeMessage2 = true,


    showTooltip = true,
    neverShow = false,
    showInWorld = true,
    showInArena = false,
    showInBattleground = false,
    showInRaid = true,
    showInDungeon = true,
    showInScenario = false,
    maxGroupSize = 40,
    minGroupSize = 0,

    --Header frame configuration
    hideAddonName = false,
    headerHeight = 15,
    headerAnchor = {'CENTER', 0, 0},
    headerTexture = ([=[Interface\Addons\%s\media\barTex]=]):format(MyAddOnName),
    headerColor = {0.24, 0.24, 0.24, 1.0},
        headerBackdrop = {
        bgFile = [=[Interface\Tooltips\UI-Tooltip-Background]=],
        insets = {top = -1, left = -1, bottom = -1, right = -1}
        },
    headerUnlocked = true,

    addhealthbar = false,
    addpowerbar = false,
    healthbaroffset = 0,
    powerbaroffset = 0,

    buttonHeight = 25,
    buttonWidth = 150, 
    buttonTexture = ([=[Interface\Addons\%s\media\barTex]=]):format(MyAddOnName),
    buttonBackdrop = {
       bgFile = [=[Interface\Tooltips\UI-Tooltip-Background]=],
       insets = {top = -1, left = -1, bottom = -1, right = -1}
    },
    buttonBackdropColor = {0.15, 0.15, 0.15},
    colorFriendlyButtonsByClass = true,
    friendlyButtonColor = {0.44, 0.37, 0.62, 0.9},
    tankButtonColor = {0.44, 0.37, 0.62, 0.9},
    damagerButtonColor = {0.44, 0.37, 0.00, 0.9},
    missingColor = {0.1, 0.1, 0.1, 0},
        myButtonColor = {0.35, 0.70, 0.42, 0.9},
    tankButtonAnchor = {'BOTTOMLEFT', 'TOPLEFT', -2},
    damagerButtonAnchor = { 'TOPLEFT','BOTTOMLEFT', 2},
    fadeOutOfRange = true,
    friendRange = 25, -- v3
    outOfRangeAlphaOffset = 0.5,
    spacingOffset = 1, 

    raidiconsize = 0.6,
    displayraidicon = true,
    raidiconanchor = {'LEFT','RIGHT','TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT'},
    raidiconpos = 2,


    --Icon configuration
    numberOfBuffIcons = 3,
    numberOfAuraIcons = 2,
    leftIconAnchor = {'TOPLEFT','TOPRIGHT',2},
    rightIconAnchor = {'TOPRIGHT','TOPLEFT',-2},
    iconSize = 1.0,
    iconBorders = false,
    iconXOff = 1,
    iconYOfftank = 1,
    iconYOffdps = 1,
    iconSpacing = 1,
    iconfontHeight = 14,
    showCooldownSpiral = false,
    showCooldownNumbers = true,
    cooldownNumberScale = 1,
    cooldowntrigger = 90,

    --Features
    purgeAutoAdds = true,
    autoAddTanks = true,
    includeSpecTanks = true, --or only include tanks marked as role tanks
    includePlayer = true,
    includePlayerAsTank = true,
    includePlayerAsDamager = true,
    invertDisplay = false,

    -- Add in spells for modifier clicks later **************************************************
    allowModifierNone = true,
    tankClickSpell = 360827,
    damagerClickSpell = 409311,

    allowModifierShift = false,
    tankClickSpellShift = 360827,
    damagerClickSpellShift = 409311,

    allowModifierAlt = false,
    tankClickSpellAlt = 360827,
    damagerClickSpellAlt = 409311,

    buffNames = {"Prescience","Blistering Scales","Ebon Might","Obsidian Scales"},
    auraNames = {"Blessing of the Bronze","Well Fed"},
    recommendedAuras = {152279, 42650, 288613, 19574, 375087, 1122, 12472, 190319, 321507, 191427, 102560,123904, 31884, 10060, 191634, 114050, 114051 },
    prioritySpecs =    {
        ["DEATHKNIGHT"] =   { false, false,     3, false},
        ["DEMONHUNTER"] =   { false, false, false, false},
        ["DRUID"] =         { false, false, false, false},
        ["EVOKER"] =        { false, false, false, false},
        ["HUNTER"] =        { false, false, false, false},
        ["MAGE"] =          {   1  ,    2 , false, false},
        ["MONK"] =          { false, false, false, false},
        ["PALADIN"] =       { false, false, false, false},
        ["PRIEST"] =        { false, false, false, false},
        ["ROGUE"] =         { false, false, false, false},
        ["SHAMAN"] =        { false, false, false, false},
        ["WARLOCK"] =       { false,     2, false, false},
        ["WARRIOR"] =       { false, false, false, false},
    },

    numberOfDamagers = 5,
    numberOfTanks = 2,

    --Processing and efficiency
    updateInterval = 0.1,

    --We persist tables between UI loads
    tanks = {},
    damagers = {},

    --Will these ever change?  Here just in case.
    raidIcons = {  --{{Name, texturePath},}
        {'Star',[[Interface\TargetingFrame\UI-RaidTargetingIcon_1]]},
        {'Circle',[[Interface\TargetingFrame\UI-RaidTargetingIcon_2]]},
        {'Diamond',[[Interface\TargetingFrame\UI-RaidTargetingIcon_3]]},
        {'Triangle',[[Interface\TargetingFrame\UI-RaidTargetingIcon_4]]},
        {'Moon',[[Interface\TargetingFrame\UI-RaidTargetingIcon_5]]},
        {'Square',[[Interface\TargetingFrame\UI-RaidTargetingIcon_6]]},
        {'Cross',[[Interface\TargetingFrame\UI-RaidTargetingIcon_7]]},
        {'Skull',[[Interface\TargetingFrame\UI-RaidTargetingIcon_8]]},
    },
}

--[[

Preferred specs {252,577,63,260,263,262}

GetSpecializationInfo() - The prioritySpecsNew is class and the spec number (SPEC 1, SPEC 2, SPEC 3, SPEC 4) that we want NOT the specID (250,268 etc) as shown below.

CLASS           SPEC 1              SPEC 2              SPEC 3              SPEC 4
---------------------------------------------------------------------------------------------
DEATHKNIGHT 	250 Blood 	        251 Frost 	        252 Unholy
DEMONHUNTER 	577 Havoc 	        581 Vengeance 
DRUID           102 Balance 	    103 Feral 	        104 Guardian 	    105 Restoration
EVOKER 	        1467 Devastation 	1468 Preservation 	1473 Augmentation
HUNTER 	        253 Beast Mastery 	254 Marksmanship 	255 Survival
MAGE 	        62  Arcane 	        63 	Fire 	        64 	Frost
MONK 	        268 Brewmaster 	    270 Mistweaver 	    269 Windwalker
PALADIN 	    65 	Holy 	        66 	Protection 	    70 	Retribution
PRIEST 	        256 Discipline 	    257 Holy 	        258 Shadow
Rogue 	        259 Assassination 	260 Outlaw 	        261 Subtlety
SHAMAN 	        262 Elemental 	    263 Enhancement     264 Restoration 
WARLOCK 	    265 Affliction 	    266 Demonology 	    267 Destruction
WARRIOR 	    71 	Arms 	        72 	   Fury 	    73 	Protection 	


Recommendations for auras
    DEATHKNIGHT: 152279,42650,
    HUNTER: 288613,19574,
    EVOKER: 375087,
    WARLOCK: 1122,
    MAGE: 12472,190319, 321507,
    DEMONHUNTER: 191472
    DRUID: 102560
    MoNK: 123904
    PALADIN: 31884
    PRIEST: 10060
    SHAMAN:  191634, 114050, 114051
]]--



--[[
Database version migration logic.

migrationPaths = { [dbVersion] = function(config) ... end, }

dbVersion is an incremented integer.

Functions should update config in-place to update from the previous integer
version.  Updates are automatically cascaded across multiple versions when
needed.
]]--

currentDbVersion = 1

migrationPaths = {
    [3] = function(config)
    		if config.classRangeChecks then config.classRangeChecks = nil end
    		if config.autoUpdateORA2 then config.autoUpdateORA2 = nil end
    		if config.fontName == "Fonts\\FRIZQT__.TTF" then config.fontName = STANDARD_TEXT_FONT end
    		if config.autoUpdateMainAssists or config.autoUpdateTanks or config.autoUpdateORA3 then
    			config.autoAddTargets = true
    			if config.autoUpdateMainAssists then
    				config.includeRaidAssists = true
    			end
    			if config.autoUpdateTanks or config.autoUpdateORA3 then
    				--config.includeRaidTanks = true
    				--config.includeRoleTanks = true
    				config.includeSpecTanks = true
    				--config.includeORA3 = true
    			end
    		end
    		config.autoUpdateMainAssists = nil; config.autoUpdateTanks = nil; config.autoUpdateORA3 = nil
    		config.enemyRange = config.enemyRange or 30
    		config.friendRange = config.friendRange or 30
    	end,
}
