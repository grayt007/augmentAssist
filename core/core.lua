local MyAddOnName, NS = ...

NS.Utils = {}
NS.Auto = {}
NS.ClassColors = {}

local classColors = NS.ClassColors
local autoAdds = NS.Auto -- Array of names marking which were "auto" added and which were not ""
local util = NS.Utils
-- local SpellDB = NS.spell_db

--Ugly global namespace bindings for binding.xml
-- _G[("BINDING_HEADER_%s"):format(MyAddOnName)] = MyAddOnName
-- _G[("BINDING_NAME_%s_ADDMYTARGET"):format(MyAddOnName)] = "Add current target"

--Ace3 addon application object & Libraries
-- local AceConfig = LibStub("AceConfig-3.0") -- standardized way of representing the commands available to control an addon
local AceConfigDialog = LibStub("AceConfigDialog-3.0") -- Add an option table into the Blizzard Interface Options panel.
local LibRange = LibStub("LibRangeCheck-2.0") --provides an easy way to check for ranges and get suitable range checking functions for specific ranges
local LGIST = LibStub("LibGroupInSpecT-1.1") --A small library which keeps track of group members and keeps an up-to-date cache of their specialization and talents
local addon = LibStub("AceAddon-3.0"):NewAddon(MyAddOnName, "AceConsole-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceEvent-3.0", "AceTimer-3.0")
local AceRegistry = LibStub("AceConfigRegistry-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")
local version = 0.5

local broker = LDB:NewDataObject(MyAddOnName, {
    type = "launcher",
    text = MyAddOnName,
    label = "augmentAssistLDB",
    suffix = "",
    tooltip = GameTooltip,
    value = version,
    icon = "Interface\\AddOns\\augmentAssist\\Media\\Textures\\logo",
    OnTooltipShow = function(tooltip)
        tooltip:AddDoubleLine(util.Colorize("augmentAssist", "main"), util.Colorize(version, "accent"))
        tooltip:AddLine(" ")
        tooltip:AddLine(format("%s to toggle options window.", util.Colorize("Left-click")), 1, 1, 1, false)
        tooltip:AddLine(format("%s clear buttons.", util.Colorize("Right-click")), 1, 1, 1, false)
        tooltip:AddLine(format("%s to toggle the minimap icon.", util.Colorize("Shift+Right-click")), 1, 1, 1, false)
    end,
    OnEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
        GameTooltip:ClearLines()
        self.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" then
            addon:ToggleOptions()
        elseif button == "RightButton" then

            if IsRightControlKeyDown() and addon.config.doYouWantToDebug then -- included for easy debug actions that wont by accidently triggered - change as per need
                wipe(addon.dbNew.profile.priorityPlayers)
                print("DEBUGGING ACTION:  Priority players wiped")
            end

            if IsShiftKeyDown() then
                addon:ToggleMinimapIcon()
                if addon.dbNew.profile.minimap.hide then
                    util.Print(format("Minimap icon is now hidden. Type %s %s to show it again.", util.Colorize("/auga", "accent"), util.Colorize("minimap", "accent")))
                end
                AceRegistry:NotifyChange(MyAddonName)
            
            else
                addon:clearAll()
            end
        end
    end,
    OnLeave = function()
        GameTooltip:Hide()
    end,
})


_G[MyAddOnName] = addon

addon.LibRange = LibRange
addon.Prefix = 'aa.bT'

local debugHold, debugHold2, debugHold3 = false,false,false
local testBuffs = {}
local testBuffIds = {}


local CopyTable = CopyTable
local RAID_CLASS_COLORS

local dbName = ("%sDb"):format(MyAddOnName)
local barName = ("%s.Bar"):format(MyAddOnName)
-- local instanceType
-- local featuresName = ("%s.Features"):format(MyAddOnName)
-- local appearanceName = ("%s.Appearance"):format(MyAddOnName)
-- local profilesName = ("%s.Profiles"):format(MyAddOnName)
-- local spellBuffsName = ("%s.Spells"):format(MyAddOnName)
-- local consoleName = ("%s.Console"):format(MyAddOnName)
local ctxMenuName = ("%sContextMenu"):format(MyAddOnName)

local defaultSpells = {}
local spellDetails = {
        recommended = false,
        prio = 50,
        class = "",
        enabled = false,
        source = "spell_db",
        icon = 0,
    }

 --   Build out the default ID for party and raids
local partyUnit = {}
	for i=1,MAX_PARTY_MEMBERS do
		partyUnit[i] = ("party%d"):format(i)
	end

local raidUnit = {}
	for i=1,MAX_RAID_MEMBERS do
		raidUnit[i] = ("raid%d"):format(i)
	end

--upvalues
local ipairs,pairs,unpack,floor,format,tostring,tinsert,tremove,wipe,tsort =
ipairs,pairs,unpack,floor,format,tostring,tinsert,tremove,wipe,table.sort

local UnitName,UnitIsUnit,UnitGroupRolesAssigned,UnitHealth,UnitHealthMax,UnitClass,UnitGUID,UnitIsFriend,UnitIsPlayer =
UnitName,UnitIsUnit,UnitGroupRolesAssigned,UnitHealth,UnitHealthMax,UnitClass,UnitGUID,UnitIsFriend,UnitIsPlayer

local IsInGroup,GetNumGroupMembers,GetNumSubgroupMembers,GetRaidRosterInfo,GetPartyAssignment,GetRaidTargetIndex =
IsInGroup,GetNumGroupMembers,GetNumSubgroupMembers,GetRaidRosterInfo,GetPartyAssignment,GetRaidTargetIndex


---------------- LOCAL FUNCTIONS------------------------------

local function ShouldShow()                         -- Support the options to display the addon in Bungeons, Arena, party, raid etc
    local instanceType = addon.instanceType

    if addon.config.neverShow
    or instanceType == "none" and not addon.config.showInWorld
    or instanceType == "pvp" and not addon.config.showInBattleground
    or instanceType == "arena" and not addon.config.showInArena
    or instanceType == "party" and not addon.config.showInDungeon
    or instanceType == "raid" and not addon.config.showInRaid
    or instanceType == "scenario" and not addon.config.showInScenario
    then
        return false
    end

    return true
end

local function UpdateMinimapIcon()                  -- Show or hide teh minimap icon
    if addon.dbNew.profile.minimap.hide then
        LDBIcon:Hide(MyAddOnName)
    else
        LDBIcon:Show(MyAddOnName)
    end
end

-- local function ValidateBuffData()

--     for k, v in pairs(addon.dbNew.profile.buffs) do
--         if v.enabled then -- Fix for old database entries
--             v.enabled = nil
--         end

--         if (not defaultSpells[k]) and (not addon.dbNew.global.customBuffs[k]) then
--             addon.dbNew.profile.buffs[k] = nil
--         else
--             if v.custom then
--                 if v.parent and not addon.dbNew.global.customBuffs[v.parent] then
--                     v.custom = nil
--                 elseif not addon.dbNew.global.customBuffs[k] then
--                     v.custom = nil
--                 end
--             end

--             if v.parent then -- child found
--                 -- Fix for updating parent info or updating a child to a non-parent
--                 if defaultSpells[k] and not defaultSpells[k].parent then
--                     v.parent = nil
--                 else
--                     -- Fix for switching an old parent to a child
--                     if v.children then
--                         v.children = nil
--                     end

--                     if v.UpdateChildren then
--                         v.UpdateChildren = nil
--                     end

--                     local parent = addon.dbNew.profile.buffs[v.parent]

--                     if not parent.children then
--                         parent.children = {}
--                     end

--                     parent.children[k] = true

--                     if not parent.UpdateChildren then
--                         parent.UpdateChildren = UpdateChildren
--                     end

--                     -- Give child the same fields as parent
--                     for key, val in pairs(parent) do
--                         if key ~= "children" and key ~= "UpdateChildren" then
--                             if type(val) == "table" then
--                                 addon.dbNew.profile.buffs[k][key] = CopyTable(val)
--                             else
--                                 addon.dbNew.profile.buffs[k][key] = val
--                             end
--                         end
--                     end
--                 end
--             else
--                 InsertTestBuff(k)
--             end

--             -- Check to see if any children were deleted and update DB accordingly
--             if v.children then
--                 for child in pairs(v.children) do
--                     local childData = defaultSpells[child]
--                     if not childData or not childData.parent or childData.parent ~= k then
--                         v.children[child] = nil
--                     end
--                 end

--                 if next(v.children) == nil then
--                     v.children = nil
--                     if v.UpdateChildren then
--                         v.UpdateChildren = nil
--                     end
--                 end
--             end
--         end
--     end
    
-- end
---------------- SETUP FUNCTIONS------------------------------

function addon:OnInitialize()                       -- MyAddOnName_LOADED(MyAddOnName)

	--Addon wide data structures
	self.roster = {} 
    -- self.testBuffList = {}
    self.testAuraList = {}
	self.damagers = {}
	self.tanks = {}
	-- self.buttonWidth = 0
	self.postCombatCalls = {}                                               -- validate the requirement and appraoch
    self.numGroupMembers = GetNumGroupMembers()
    -- self.overlays = {}      -- Check id we need this
    -- self.priority = {}
    -- self.units = {}         -- Check id we need this
    -- self.assistFrames = {}  -- Check id we need this
    -- self.damagerFrames = {} -- Check id we need this

	local defaultSettings = {
		profile = {
			welcomeMessage = true,
			minimap = {hide = false, },
			bars = {},
			buffs = {},
            spells = {},
            priorityPlayers = {},
			config = util.deepcopy(self.defaultConfig),
		},
		global = {
			customBuffs = {},
		},
	}

	self.dbNew = LibStub("AceDB-3.0"):New(dbName, defaultSettings, true)  --  New DB  https://www.wowace.com/projects/ace3/pages/ace-db-3-0-tutorial 

    LDBIcon:Register("augmentAssist", broker, self.dbNew.profile.minimap) -- 3rd parameter is where to store the  hide/show + location of button 

    addon:loadSpellData()
    ValidateSpellIds()

    if not self.registered then                                         
        self.dbNew.RegisterCallback(self, "OnProfileChanged", "FullRefresh")
        self.dbNew.RegisterCallback(self, "OnProfileCopied", "FullRefresh")
        self.dbNew.RegisterCallback(self, "OnProfileReset", "FullRefresh")

        self:Options()
        self.registered = true
    end

    if self.dbNew.profile.welcomeMessage then
        util.Print(format("Type %s or %s to open the options panel or %s for more commands.", util.Colorize("/auga", "accent"), util.Colorize("/augmentAssist", "accent"), util.Colorize("/auga help", "accent")))
    end

    self.dbNew.profile.config.createTestData = false

 	self.hide = false --managed by addon based on whether or not the player is in a group and we auto-hide out of group

    -- https://wowwiki-archive.fandom.com/wiki/Creating_a_slash_command
    SLASH_auga1 = "/auga"
    SLASH_auga2 = "/augmentAssist"
    function SlashCmdList.auga(msg)
        if msg == "help" or msg == "?" then
             util.Print("Command List")
             print(format("%s or %s: Toggles the options panel.", util.Colorize("/augmentAssist", "accent"), util.Colorize("/auga", "accent")))
             print(format("%s %s: Resets current profile to default settings. This does not remove any custom auras.", util.Colorize("/auga", "accent"), util.Colorize("reset", "value")))
             print(format("%s %s: Toggles the minimap icon.", util.Colorize("/auga", "accent"), util.Colorize("minimap", "value")))
        elseif msg == "reset" or msg == "default" then
             self.dbNew:ResetProfile()
        elseif msg == "minimap" then
             self:ToggleMinimapIcon()
        else
             self:ToggleOptions()
        end
    end

end

function ValidateSpellIds()
    for spellId in pairs(defaultSpells) do
        if type(spellId) == "number" then
            if not C_Spell.DoesSpellExist(spellId) then
                defaultSpells[spellId] = nil
                addon.dbNew.profile.buffs[spellId] = nil
                addon.dbNew.global.customBuffs[spellId] = nil
                addon:Print(format("Spell ID %s is invalid. If you haven't made any manual code changes, please report this to the author.", util.Colorize(spellId)))
            end
        end
    end

    for spellId in pairs(addon.dbNew.profile.buffs) do
        if type(spellId) == "number" then
            if not C_Spell.DoesSpellExist(spellId) then
                addon.dbNew.profile.buffs[spellId] = nil
                addon.dbNew.global.customBuffs[spellId] = nil
                addon:Print(format("Spell ID %s is invalid and has been removed.", util.Colorize(spellId)))
            end
        end
    end

    -- for spellId in pairs(addon.dbNew.global.customBuffs) do
    --     if type(spellId) == "number" then
    --         if not C_Spell.DoesSpellExist(spellId) then
    --             addon.dbNew.global.customBuffs[spellId] = nil
    --             addon:Print(format("Spell ID %s is invalid and has been removed.", util.Colorize(spellId)))
    --         end
    --     end
    -- end
end

function addon:OnEnable() -- PLAYER_LOGIN
	--Register us as receivers of our AceComm messages - use this when we implement functionality for the addon to talk to otherpeopl;e using the same addon
	-- self:RegisterComm(self.Prefix, 'targetReceiver')
	
	--If SharedMedia is loaded, share our media
	if IsAddOnLoaded("SharedMedia") then
		local lib = LibStub("LibSharedMedia-3.0")
		lib:Register(lib.MediaType.STATUSBAR, barName, ([=[Interface\Addons\%s\media\barTex]=]):format(MyAddOnName))
	end

	RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS

	if not next(classColors) then
		for k,v in pairs(RAID_CLASS_COLORS) do
			classColors[k]=v
		end
		classColors["UNKNOWN"] = {r=0.8,g=0.8,b=0.8,colorStr="ffcccccc"}
	end

	-- This call in turn handles changes to augmentAssist.config and config GUI construction
	self:OnProfileChanged(nil, self.dbNew, self.dbNew:GetCurrentProfile())

	-- Event registration
	self:RegisterEvent('GROUP_ROSTER_UPDATE')
	self:RegisterEvent('GROUP_JOINED')
	self:RegisterEvent('PLAYER_ROLES_ASSIGNED')
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- process chat commands
    -- addon:RegisterChatCommand("auga", "ChatCommand")

	-- Setup timers to trigger updates
	self.repeatingTimer = self:ScheduleRepeatingTimer('onUpdate', self.config.updateInterval)

	-- Range checks setup
	if LibRange then
		if self.config.fadeOutOfRange then
			self.friendOutOfRangeChecker = LibRange:GetFriendMinChecker(self.config.friendRange)
		end
		LibRange.RegisterCallback(self,"CHECKERS_CHANGED", "rangeCheckUpdate")
	end

	if LGIST then
		LGIST.RegisterCallback(self,"GroupInSpecT_Update", "roleUpdated")
	end

	-- Update our shown state
	self:updateEnabled()

	-- Setup the user interface, and fire events which don't on their own at log in
	self:buildUI()

end

function addon:OnDisable()
	self:UnregisterEvent('PLAYER_ROLES_ASSIGNED')
	self:UnregisterEvent('UNIT_PET')
	self:UnregisterEvent('GROUP_JOINED')
	self:UnregisterEvent('GROUP_ROSTER_UPDATE')
	if self.repeatingTimer then self:CancelTimer(self.repeatingTimer) end

	if LibRange and LibRange.UnregisterCallback then
		LibRange.UnregisterCallback(self,"CHECKERS_CHANGED")
	end
	if LGIST and LGIST.UnregisterCallback then
		LGIST.UnregisterCallback(self,"GroupInSpecT_Update")
	end
	AceRegistry:NotifyChange(MyAddOnName)
end

function addon:__updateFrameState(stateCall)
	return function()
		if self.headerFrame then
			self.headerFrame[stateCall](self.headerFrame)
			if self.tankButtons then
				for _, buttonFrame in pairs(self.tankButtons) do
					buttonFrame[stateCall](buttonFrame)
				end
			end
		end
	end
end

function addon:updateEnabled()

	if (self.hide or not ShouldShow()) then
		self:registerPostCombatCall(self:__updateFrameState('Hide'))
		self.enabled = false
	else
		self:registerPostCombatCall(self:__updateFrameState('Show'))
		self.enabled = true
		self:Enable()
	end
end

function addon:buildUI()

	if self.optionsBaseFrame then return end
    self.contextMenu = CreateFrame("Frame", ctxMenuName, UIParent, "UIDropDownMenuTemplate")
    
    if self.dbNew.profile.welcomeMessage2 then 
        print("Here")
        self.welcomeImage = CreateFrame("Frame", 'welcomeImageFrame' , UIParent) 
        self.welcomeImage:SetPoint("CENTER")
        -- self.welcomeImage:SetAllPoints()
        self.welcomeImage:SetSize(512,512)

        local bg = self.welcomeImage:CreateTexture()
        bg:SetAllPoints(self.welcomeImage)
        bg:SetTexture("Interface\\AddOns\\augmentAssist\\Media\\Textures\\WelcomePicture")
        -- bg:SetTexCoord(0, 1, 0, 1)
        bg:Show()

        local btn = CreateFrame("Button", nil, self.welcomeImage, "UIPanelButtonTemplate")
        btn:SetText("Close")
        btn.Text:SetTextColor(1, 1, 1)
        btn:SetWidth(100)
        btn:SetHeight(30)
        btn:SetPoint("BOTTOM", 190, 23)
        btn.Left:SetDesaturated(true)
        btn.Right:SetDesaturated(true)
        btn.Middle:SetDesaturated(true)
        btn:SetScript("OnClick", function()
            self.welcomeImage:Hide()
        end)
        self.welcomeImage:Show()
        self.dbNew.profile.welcomeMessage2 = false
    end

end

function addon:OnProfileChanged(eventName, db, newProfile)

	self.config = self.dbNew.profile.config

	if self.config then

		--Unversioned databases are set to v. 1
		if self.config.dbVersion == nil then self.config.dbVersion = 1 end

		--Handle database version checking and upgrading if necessary
		local startVersion = self.config.dbVersion
		self:upgradeDatabase(self.config)
		if startVersion ~= self.config.dbVersion then
			print(("%s configuration database upgraded from v.%s to v.%s"):format(MyAddOnName,startVersion,self.config.dbVersion))
		end

	end

	self:updateRoster()
	self:updateConfig()

end

function addon:loadSpellData()
    local newdb = false
    local trackedCooldown = false
    local augmentSpell = false
    local theSpellID, theAura, theClass, theIcon,theSpell
    local spellSubTable = {}
    local evokerClass = "EVOKER"
    local recommendedAura = false
    -- local evokerSubTable = {}

    for class,auraList in pairs(addon.spell_db) do                 -- Withthin the data is a list of classes and the auras/cooldows that we care about 	["WARRIOR"] = {
        for spell,spellRecords in pairs(auraList) do               -- Within the classes is a list of spellRecords SOURCE DATA FROM OMNICD:   ["class"]="WARRIOR",["type"]="defensive",["buff"]=236273,["spec"]=true,["name"]="Duel",["duration"]=60,["icon"]=1455893,["spellID"]=236273, },
            for auraField, auraData in  pairs(spellRecords) do    -- Within the spells is a list of fields and data elements.   e.g.  ["type"] with a auraData of "defensive"
                -- CONVERT TO OUT CURRENT INTERNAL FORMAT:  [48707] = { class = "DEATHKNIGHT", prio = 50, recommended = true, enabled=true },  --Anti-Magic Shell
                
                -- grab the base data fields
                if (auraField == "type" and auraData == "offensive") then trackedCooldown = true end
                if auraField == "spellID" then theSpellID = auraData end
                if auraField == "buff" then theAura = auraData end
                if auraField == "class" then theClass = auraData end
                if auraField == "name" then theSpell = auraData end
                if auraField == "icon" then theIcon = auraData end   
                if (auraField == "type" and auraData == "augment") then augmentSpell = true end
            end

            -- If its a cooldown we want to track then build out the table to add
            if trackedCooldown then  -- is it one of the cooldowns/auras we care about ?
                defaultSpells[theSpellID] = CopyTable(spellDetails)
                
                for c,auraID in pairs(self.dbNew.profile.config.recommendedAuras) do
                    if theAura == auraID then recommendedAura = true end
                end

                defaultSpells[theSpellID].recommended=recommendedAura
                if recommendedAura then
                     defaultSpells[theSpellID].prio = 5  -- highest priority is 1.  it determines which two cooldowns and buffs will show
                     defaultSpells[theSpellID].enabled = true
                 else
                    defaultSpells[theSpellID].prio = 20
                    defaultSpells[theSpellID].enabled = false
                end
                defaultSpells[theSpellID].class = theClass
                defaultSpells[theSpellID].icon = theIcon


                -- print("BB ", theClass, defaultSpells[theSpellID].enabled, defaultSpells[theSpellID].prio,defaultSpells[theSpellID].recommended)

            end

            -- if its an augment spell grab those and save them in ther profile to populate the drop downs
            if augmentSpell then
                -- Make sure the Evoker specif spells are loaded as well in an additional table
                if evokerClass == theClass and not self.dbNew.profile.spells[theSpellID] then
                    self.dbNew.profile.spells[theSpellID] = theSpell
                end
            end

            -- Clease the holding variables
            theSpellID = 0
            theIcon = 0
            theClass=""
            trackedCooldown = false
            augmentSpell = false
            recommendedAura = false
        end 
    end

    -- If the current profile doesn't have any spells and buffs saved use default list and save it
    if next(self.dbNew.profile.buffs) == nil then
        for k, v in pairs(defaultSpells) do
            self.dbNew.profile.buffs[k] = {}

            for key, val in pairs(v) do
                    self.dbNew.profile.buffs[k][key] = val
            end
        end

        newdb = true
        -- ValidateBuffData()
    end
    
    return newdb
end

----------- SUPPORTING FUNCTIONS -----------------------

function addon:rangeCheckUpdate()
	if self.config.fadeOutOfRange then
		self.friendOutOfRangeChecker = LibRange:GetFriendMinChecker(self.config.friendRange)
	end
end

function addon:roleUpdated(_,unit,guid,info)
	if self.config.includeSpecTanks then
		local name = info and info.name
		local role = info and info.spec_role

		if name then util.AddDebugData(role, "Role updated - "..name) end

		--Unit = player unique ID e.g. "Player-3283-03444B342"

		if name and unit and self.roster[name] and role and role == 'TANK' then
			if not util.hasValue(self.config.tanks,name) then -- if the tanks table does not already have this name
				tinsert(self.config.tanks,name)
				
			end
		end
	end
end

function addon:updateRoster()

    if self.config.createTestData then return end

	wipe(autoAdds)
	for _, v in ipairs(self.config.tanks) do autoAdds[v] = false end

	wipe(self.tanks or {})
	wipe(self.damagers or {})
	wipe(self.roster) 

	local playerName = util.unitname('player')
	local playerGUID = UnitGUID('player')
	if self.config.includePlayer then
		self.roster[playerName] = 'player'
	end
 
    if IsInGroup() then
            for i=1,GetNumGroupMembers() do                                                     -- for all hte members of the party or raid
                local unitID = raidUnit[i]
                local notMe = not UnitIsUnit('player',unitID)
                local unitName = util.unitname(unitID)
                local guid = UnitGUID(unitID)
                local role, assignedRole

                if unitName and not util.hasValue(self.roster,unitID) then                      -- if the unit does not already exist
                    if notMe then self.roster[unitName] = unitID end             
                                                                                                -- Add teh unit to the roster
                    if IsInRaid() then                                                          -- If its a raid get whoever is a tank.  IF its a dungeon get whoever LFG madde a tank.  Failing that look at peoples specs
                         _,_,_,_,_,_,_,_,_,role,_, assignedRole = GetRaidRosterInfo(i)          -- role = 'MAINTANK|MAINASSIST', assignedRole = 'TANK|HEALER|DAMAGER|NONE'
                    else
                        assignedRole = UnitGroupRolesAssigned(unitID)                           -- TANK, HEALER, DAMAGER, NONE for dungeon finder
                    end

                    local info = guid and LGIST:GetCachedInfo(guid)                             -- if they are close we can get extra cached information 
                    
                    if self.config.autoAddTanks and ((self.config.includeSpecTanks and (info and info.spec_role and info.spec_role == 'TANK')) or
                         assignedRole == "maintank" or assignedRole == "mainassist" or assignedRole == "TANK" or role == "TANK") then
                        tinsert(self.config.tanks,unitName)                                     -- save it incase we restart or reload the UI
                        tinsert(self.tanks,unitName)                                            -- whats in the overall roster of tanks
                    elseif not IsInRaid() and self.config.autofillDPS then                      -- If its not a raid and we want to autofill the DPS
                        tinsert(self.config.damagers,unitName)                                  --assignedRole == "DAMAGER" or "HEALER" but we only do this for groups - raids we control it ourselves
                        tinsert(self.damagers,unitName)                                         -- whats in the overall roster of damagers
                    end
                end

            end

        -- if IsInRaid() then -- raid
        --     for i=1,GetNumGroupMembers() do
        --         local unitID = raidUnit[i]
        --         local notMe = not UnitIsUnit('player',unitID)
        --         local unitName = util.unitname(unitID)
        --         local guid = UnitGUID(unitID)

        --         if unitName and not util.hasValue(self.roster,unitID) then -- if the unit does not already exist
        --             if notMe then self.roster[unitName] = unitID end
        --             local _,_,_,_,_,_,_,_,_,role,_, assignedRole = GetRaidRosterInfo(i) -- role = 'MAINTANK|MAINASSIST', assignedRole = 'TANK|HEALER|DAMAGER|NONE'
        --             local info = guid and LGIST:GetCachedInfo(guid)
                    
        --             if (self.config.includeSpecTanks and (info and info.spec_role and info.spec_role == 'TANK')) or
        --                  assignedRole == "maintank" or assignedRole == "mainassist" or role == "TANK" then
        --                 tinsert(self.config.tanks,unitName)
        --                 tinsert(self.tanks,unitName)        -- whats in the overall roster of tanks
        --             end
        --         end
        --     end
        -- else -- party
        --     for i=1,GetNumSubgroupMembers() do
        --         local unitID = partyUnit[i]
        --         local notMe = not UnitIsUnit('player',unitID)
        --         local unitName = util.unitname(unitID)
        --         local guid = UnitGUID(unitID)

        --         if unitName and not util.hasValue(self.roster,unitID) then -- if the unit does not already exist
        --             if notMe then self.roster[unitName] = unitID end

        --             local role,assignedRole
        --             assignedRole = UnitGroupRolesAssigned(unitID)  -- TANK, HEALER, DAMAGER, NONE

        --             local info = guid and LGIST:GetCachedInfo(guid)
                    
        --             if (self.config.includeSpecTanks and (info and info.spec_role and info.spec_role == 'TANK')) or
        --             assignedRole == "TANK" then
        --                 tinsert(self.config.tanks,unitName) -- What we display
        --                 tinsert(self.tanks,unitName)        -- whats in the overall roster of tanks
        --             else
        --                 tinsert(self.config.damagers,unitName)   --assignedRole == "DAMAGER" but we only do this for groups - raids we control it ourselves
        --                 tinsert(self.damagers,unitName)        -- whats in the overall roster of damagers
        --             end
        --         end
        --     end
        -- end

        -- inserts done, remove duplicates
        self.config.tanks = util.unique(self.config.tanks)
        self.config.damagers = util.unique(self.config.damagers)
        self.tanks = util.unique(self.tanks)
        self.damagers = util.unique(self.damagers)

        --Purge targets we previously auto-added but are now missing
        -- if self.config.purgeAutoAdds then
        -- 	for unitName,currentAdd in pairs(autoAdds) do
        -- 		if not currentAdd then
        -- 			tremove(self.config.targets, util.tableIndex(self.config.targets, unitName))
        -- 		end
        -- 	end
        -- end
        -- if self.config.autoAddTanks then
        --     self:addTanks(true)
        -- end

        if self.config.autofillDPS then
            addon:addDamagers()
        end

        if self.hide then -- if you in  group then dont hide 
            self.hide = false
            self:updateEnabled()
        end
    else -- solo
        -- util.AddDebugData(self.dbNew.profile.config.hideOutOfGroup, "We are solo")
        if self.config.hideOutOfGroup then
            if not self.hide then
                self.hide = true
                self:updateEnabled()
            end
        else
            -- add the player as specified checking that they dont aleady exist
            if playerName and not self.config.includePlayerAsTank and util.hasValue(self.config.tanks,playerName) then
                tremove(self.config.tanks,util.tableIndex(self.config.tanks, playerName)) 
            else
                if playerName and self.config.includePlayerAsTank and not util.hasValue(self.config.tanks,playerName) then 
                    tinsert(self.config.tanks,playerName) 
                end
                if playerName and self.config.includePlayerAsTank and not util.hasValue(self.config.tanks,playerName) then 
                    tinsert(self.tanks,playerName) 
                end
                if playerName and self.config.includePlayerAsDamager and not util.hasValue(self.config.damagers,playerName) then
                        tinsert(self.damagers,playerName)
                end
                if playerName and self.config.includePlayerAsDamager and not util.hasValue(self.config.damagers,playerName) then
                    tinsert(self.config.damagers,playerName) 
                end
                self.hide = false
                self:updateEnabled()
            end
        end
    end
    
	if self.contextMenu and self.contextMenu:IsShown() then self.contextMenu:Hide() end

	self:updateConfig()
end

function addon:FullRefresh()
    --self:UpdateBarOptionsTable()
    addon:AddTabsToOptions()
    UpdateMinimapIcon()
end

function addon:onUpdate() -- THE MAIN REALTIME UPDATE FUNCTION 
	if not InCombatLockdown() then
		if self.updateConfigPostCombat then self:__updateConfig() end

		for _, call in ipairs(self.postCombatCalls) do call() end
		wipe(self.postCombatCalls or {})
		if not self.enabled then self:Disable() end
	end

	if not self.enabled then return end

    local width = (addon.config.buttonWidth)

    for _, buttonFrame in pairs(self.unitButtons) do

        local unitName = buttonFrame.unitID and util.unitname(buttonFrame.unitID)

        if unitName then

            buttonFrame.unitName = unitName

            -- button colors and names
            local r,g,b,a
            if self.config.colorFriendlyButtonsByClass and (self.config.createTestData or UnitIsPlayer(buttonFrame.unitID)) then
                local stdClassName

                if self.config.createTestData then 
                    stdClassName = util.returnTestDataItem(unitName,"classID") 
                else
                    _, stdClassName = UnitClass(buttonFrame.unitID)
                end

                local classColor = RAID_CLASS_COLORS[stdClassName]
                if classColor then
                    r,g,b,a = classColor.r, classColor.g, classColor.b, self.config.friendlyButtonColor[4]
                else
                    r,g,b,a = unpack(self.config.friendlyButtonColor)
                end
            else
                r,g,b,a = unpack(self.config.friendlyButtonColor)
            end

            -- Apply test data
            if not self.config.createTestData then
                if self.config.fadeOutOfRange and (self.friendOutOfRangeChecker and not self.friendOutOfRangeChecker(buttonFrame.unitID)) and not UnitIsUnit(buttonFrame.unitID,'player') then
                    a = max(0.1, a - self.config.outOfRangeAlphaOffset)
                end
            end

            -- change the width of the textture to refelct thye units health
            local newWidth = util.getNewHealth(buttonFrame.unitID)
            buttonFrame.texture:SetWidth(newWidth * width)

            -- reset color or name - check if we can do this better
            buttonFrame.texture:SetVertexColor(r,g,b,a)
            buttonFrame.fontString:SetText(unitName)
            
            --Add a raiud icon
			if buttonFrame.raidIcon then
                if self.config.displayraidicon then
                    local iconIdx = GetRaidTargetIndex(buttonFrame.unitID)
                    if iconIdx then
                        buttonFrame.raidIcon:SetTexture(self.config.raidIcons[iconIdx][2])
                        buttonFrame.raidIcon:Show()
                    else
                        buttonFrame.raidIcon:Hide()
                    end
                else
                    buttonFrame.raidIcon:Hide()
                end
			end

            if not self.config.createTestData then
                if UnitThreatSituation(buttonFrame.unitID) == 3 then
                    buttonFrame.aggro:Show()
                else
                    buttonFrame.aggro:Hide()
                end
            end

            -- add all the auras and buffs
            local activeBuffList,buffCount,activeAuraList,auraCount = addon:findUnitBuffs(buttonFrame.unitID)
            local spellIconNumber
        
            for b = 1,self.config.numberOfBuffIcons do
                buttonFrame["buffIcon"..b]:Hide()
                buttonFrame["buffText"..b]:Hide()
            end
            if buffCount then
                for b = 1,self.config.numberOfBuffIcons do      -- , buffDetails in pairs(activeBuffList) do 

                    if b <= buffCount then
                        buttonFrame["buffIcon"..b]:SetTexture(activeBuffList[b].buffID )
                        buttonFrame["buffIcon"..b]:SetScale(self.config.iconSize)

                        if self.config.iconBorders then buttonFrame["buffIcon"..b]:SetTexCoord(.1,.9,.1,.9) end

                        buttonFrame["buffText"..b]:SetText(util.cooldown(activeBuffList[b].buffExpiry))
                        buttonFrame["buffIcon"..b]:Show()
                        buttonFrame["buffText"..b]:Show()
                    end
                end
            end
            if auraCount then
                for b = 1,self.config.numberOfAuraIcons do  -- , auraDetails in pairs(activeAuraList) do 
                    buttonFrame["auraIcon"..b]:Hide()
                    buttonFrame["auraText"..b]:Hide()
                    if b <= auraCount  then
                        buttonFrame["auraIcon"..b]:SetTexture(activeAuraList[b].buffID)
                        buttonFrame["auraIcon"..b]:SetScale(self.config.iconSize)

                        if self.config.iconBorders then buttonFrame["auraIcon"..b]:SetTexCoord(.1,.9,.1,.9) end

                        buttonFrame["auraText"..b]:SetText(util.cooldown(activeAuraList[b].buffExpiry))
                        buttonFrame["auraIcon"..b]:Show()
                        buttonFrame["auraText"..b]:Show()
                    end
                end
            else
                buttonFrame["auraIcon1"]:Hide()
                buttonFrame["auraText1"]:Hide()
                if buttonFrame.raidIcon then buttonFrame.raidIcon:Hide() end
            end
        end
    end
end

function addon:registerPostCombatCall(call) tinsert(self.postCombatCalls, call) end

function addon:OnNewProfile(eventName, db, profile)

	--Set the dbVersion to the most recent, as defaults for the new profile should be up-to-date
	self.dbNew.profile.config.dbVersion = self.currentDbVersion

end

function addon:updateConfig() self.updateConfigPostCombat = true end

function addon:__updateConfig()
	self.updateConfigPostCombat = false
	self:createHeaderFrame()
    addon:showHealthBar("health")
    self:createUnitButtons("tank")
    self:createUnitButtons("damager")
end


------------- FUNCTIONS TO SUPPORT CONTEXT MENUS AND OPTIONS --------------------

function addon:addTanks(auto)

	tsort(self.config.tanks)

	for i, tankName in ipairs(self.config.tanks) do
		if not util.hasValue(self.config.tanks, tankName) then
			tinsert(self.config.tanks, i, tankName)
			autoAdds[tankName] = auto -- use 'not not auto' to cast to boolean
		end
	end
	self:updateConfig()

end

function addon:addMyTargetToDPS()

	local unitName = util.unitname('target')

	util.AddDebugData(unitName, "Adding this unit to list - function addon:addMyTargetToDPS()")

	if unitName then
		if not util.hasValue(self.config.damagers, unitName) then
			tinsert(self.config.damagers, 1, unitName)
			autoAdds[unitName] = nil --not auto added
		end
	end
	self:updateConfig()
end

function addon:addMyTargetToTanks()

	local unitName = util.unitname('target')

	util.AddDebugData(unitName, "Adding this unit - function addon:addMyTargetToTanks()")
	if unitName then
		if not util.hasValue(self.config.tanks, unitName) then
			tinsert(self.config.tanks, 1, unitName)
			util.AddDebugData(self.config.tanks, "Added this unit")
			autoAdds[unitName] = nil --not auto added
		end
	end
	self:updateConfig()
end

function addon:addParty()

	-- Add tanks and damagers for 5 man party
	local debugData = GetNumGroupMembers()
	util.AddDebugData(partyUnit, "Party members -addParty()")

	for i=0,GetNumGroupMembers() do
		local unitName = util.unitname(partyUnit[i])
		util.AddDebugData(unitName, "Adding party member "..i.." - function addon:addParty()")

		if unitName and not util.hasValue(self.config.damagers, unitName) and not util.hasValue(self.config.tanks, unitName) then
			tinsert(self.config.damagers, unitName)
		end
	end
	self:updateConfig()
end

function addon:clearAll()
	util.AddDebugData(self.config.tanks, "Pre wipe tanks and damagers from buttons")
	wipe(self.config.tanks)
	wipe(self.config.damagers)
    wipe(self.tanks)
    wipe(self.damagers)
	wipe(autoAdds)

	self:updateConfig()
	util.AddDebugData(self.config.tanks, "After wipe tanks and damagers from buttons")
end

function addon:OpenOptions()
    AceConfigDialog:Open(MyAddOnName)
    local dialog = AceConfigDialog.OpenFrames[MyAddOnName]

	util.AddDebugData(dialog, "Dialog status")

    if dialog then
        dialog:EnableResize(false)
    end
end


-- Other  supporting functions ----------------------------------


function addon:ToggleOptions()
	util.AddDebugData("augmentAssist", "ToggleOptions()")

    if AceConfigDialog.OpenFrames[MyAddOnName] then
        AceConfigDialog:Close(MyAddOnName)
        AceConfigDialog:Close(MyAddOnName.."Dialog")
    else
		util.AddDebugData(MyAddOnName, "Calling OpenOptions()")
        self:OpenOptions()
    end
end

function addon:upgradeDatabase(config)

	if config.dbVersion == self.currentDbVersion then return config
	else
		local nextVersion = config.dbVersion + 1
		local migrationCall = self.migrationPaths[nextVersion]

		if migrationCall then migrationCall(config) end

		config.dbVersion = nextVersion
		return self:upgradeDatabase(config)
	end

end

function addon:ToggleMinimapIcon()
    util.AddDebugData(self.dbNew.profile.minimap.hide, "Minimap button status")

    self.dbNew.profile.minimap.hide = not self.dbNew.profile.minimap.hide
    UpdateMinimapIcon()
end

---------------- EVENT HANDLERS ----------------------------------

function addon:GROUP_ROSTER_UPDATE() self:updateRoster() end

function addon:GROUP_JOINED() 
    self:clearAll()
    self:updateRoster() 
end

function addon:PLAYER_ROLES_ASSIGNED() if self.config.includeRoleTanks then self:updateRoster() end end

function addon:PLAYER_ENTERING_WORLD()
    self.instanceType = select(2, IsInInstance())
end

