local MyAddOnName, NS = ...
local util = NS.Utils
-- local roster = NS.roster
local addon = _G[MyAddOnName]

local autoAdds = NS.Auto
-- local frameList = NS.frameList
local tsort = table.sort
local headerMenuName = ("%sHeaderFrame"):format(MyAddOnName)
local healthBarName = ("%sHealthFrame"):format(MyAddOnName)
local powerBarName = ("%sPowerFrame"):format(MyAddOnName)

local tankNameTemplate = ("%s_T_%%d"):format(MyAddOnName)
local damagerNameTemplate = ("%s_D_%%d"):format(MyAddOnName)
-- local tankIconTemplate = ("%s_T_%%s_I%d"):format(MyAddOnName)
-- local damagerIconTemplate = ("%s_D_%%s_I%d"):format(MyAddOnName)
--local assistNameTemplate = ("%s_Assist%%d"):format(MyAddOnName)
local LGIST = LibStub("LibGroupInSpecT-1.1") --A small library which keeps track of group members and keeps an up-to-date cache of their specialization and talents


--[[  Notes:

Casting spells from buttons.  You must create a frame that implements SecureButtonTemplate or a similar secure template,
and it can ONLY cast a spell on a click or hotkey, just like any other button.

    Using SecureUnitButtonTemplate but SecureActionButtonTemplate has beeter notes and is similar

    Ref for helth bar:  https://us.forums.blizzard.com/en/wow/t/custom-health-resource-bar/236455/2
    
]]


--------- SUPPORTING FUNCTIONS --------------

function addon:yesnoBox(msg, callback)                          -- Yes No conformation window
    
    
 
    StaticPopupDialogs[MyAddOnName.."_YESNOBOX"] = {
        text = msg,
        button1 = "Yes",
        button2 = "No",
        OnAccept = function(self, data, data2)
            callback()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = STATICPOPUP_NUMDIALOGS,
    }

    StaticPopup_Show (MyAddOnName.."_YESNOBOX")
end

local function findClassSpec(unitID)                            -- Return the class, specname and spec index based on the unit ID 
--[[
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
]]

    local returnClass,returnSpecName,specIndex

    if not addon.config.createTestData then -- if its not testdata the lookup the cached info for the unit
        local guid = UnitGUID(unitID) -- find a units GUID
        local info = guid and LGIST:GetCachedInfo(guid) -- Use the LGIST library to ;look at the cach for the group and extracts the spec- https://www.curseforge.com/wow/addons/libgroupinspect

        if info and info.spec_index and info.class then
            -- print("Class:Spec is ",info.class,info.spec_index)
            returnClass = info.class  -- WE now know the class e.g. "MAGE"
            specIndex=info.spec_index  -- and we know the index (1-4) of the spec
        end
    else
        returnClass = util.returnTestDataItem(unitID,"classID")     -- we already know the class and the specid for the test data so move on
        specIndex = util.returnTestDataItem(unitID,"spec")
    end

    for theClass,theSpecs in pairs(addon.specDetails) do            -- loop through the class, specid ,spec name table
        if theClass == returnClass then                            -- we fond the correct class
            returnSpecName = theSpecs[specIndex].name 
         end
    end 

    -- print("ClassSpec:",unitID,returnClass,returnSpecID,returnSpecName)
    return returnClass,specIndex,returnSpecName  -- e.g. retrun "WARRIOR",71,"Arms"
end

function addon:addDamagers()                                    -- Add damagers automatically based on priority players and class if the confiog says to.  Also called from core.lua based on the options
    local countDamagers = 0
    -- based on 
    -- 1. Priority players
    -- 2. the class and the preferred cooldows build a list


    -- Add priority players first
    for c,playerDetails in pairs(addon.dbNew.profile.priorityPlayers) do
        if playerDetails.unitName then
            -- print("PP:",playerDetails.unitName, util.hasValue(addon.config.damagers, playerDetails.unitName), addon.roster[playerDetails.unitName])

            if not util.hasValue(addon.config.damagers, playerDetails.unitName) and addon.roster[playerDetails.unitName] then  --  if they are in the roster and not already on the displayu
                tinsert(addon.config.damagers, 1, playerDetails.unitName)
                countDamagers = countDamagers + 1
                if countDamagers == addon.config.numberOfDamagers then
                    util.Print("Maximum damagers reached before full roster read")
                    return
                end
            end
        end
    end
    util.Print(countDamagers.." priority players added to dps")

    -- add in people who are in priority specs
    local theSpecIndex = 0
    local theClass = ""

    for p, unitName in pairs(addon.roster) do -- loop through the roster

        theClass,theSpecIndex,_ = findClassSpec(p) --  find spec from the index(unitID) in the roster
            for class, prioritySpec in pairs(addon.config.prioritySpecs) do
                if theClass == class and prioritySpec[theSpecIndex] and not util.hasValue(addon.config.damagers,p) then 
                    countDamagers = countDamagers + 1
                    tinsert(addon.config.damagers, 1, p)
                    if countDamagers == addon.config.numberOfDamagers then return end
                    break
                end
            end
    end
    util.Print(countDamagers.." total players  added to dps")
end

local function addPriorityPlayer(playerName)                   -- Add the selected user and supporting details when the mini menu option is selected
local theUnitID
local theServer = "Unknown"
local playerExists = false

    for a, priorityRec in pairs(addon.dbNew.profile.priorityPlayers) do
        if priorityRec.unitName == playerName then
                playerExists = true
                break
        end
    end

    if not playerExists then
        for unitName, id in pairs(addon.roster) do    -- find the unit ID
            -- print("APP1",unitName,id,playerName)
            if unitName == playerName then
                theUnitID = id
                break
            end
        end

        -- print("APP2:",theUnitID)

        local theClass,_,theSpecName = findClassSpec(theUnitID)
        if not addon.config.createTestData then
            _, theServer = UnitName(theUnitID)
        else
            theServer = "Nagrand"
        end

        local priorityDetails = {
            dateAdded = date("%m/%d/%y %H:%M:%S"),
            unitName = playerName,
            serverName = theServer,
            className = theClass,
            specName = theSpecName,
            comments = "",        
        }

        tinsert(addon.dbNew.profile.priorityPlayers,priorityDetails)
        util.AddDebugData(addon.dbNew.profile.priorityPlayers, "Priority players list")

        addon:updateAutofillOptionTab()
    end
end

function addon:clearIcons()                                     -- Clear the buff and aura icons
    for f, buttonFrame in pairs(self.unitButtons) do

        if buttonFrame.unitName then
            -- print("Clear:",buttonFrame.unitName)
            for b = 1,self.config.numberOfBuffIcons do  
                buttonFrame["buffIcon"..b]:SetTexture()
                buttonFrame["buffText"..b]:SetText()
            end
            for b = 1,self.config.numberOfAuraIcons do   
                buttonFrame["auraIcon"..b]:SetTexture()
                buttonFrame["auraText"..b]:SetText()
            end
        end
    end
end

function addon:updateIcons()

    for unitName, buttonFrame in pairs(self.unitButtons) do

            -- Flesh out more detail for the icons
            for count = 1,self.config.numberOfBuffIcons do
                local iconOffsetX = ((count-1) * (self.config.buttonHeight + self.config.iconSpacing)) + self.config.iconXOff
                local iconOffsetY 
                if buttonFrame.unitType == "tank" then
                    iconOffsetY = self.config.iconYOfftank
                else
                    iconOffsetY = self.config.iconYOffdps
                end

                self.unitButtons[unitName]["buffIcon"..count]:SetPoint('BOTTOMLEFT', self.unitButtons[unitName], 'BOTTOMRIGHT', iconOffsetX, iconOffsetY)
                self.unitButtons[unitName]["buffIcon"..count]:SetWidth(self.config.buttonHeight) -- use the height to make it
                self.unitButtons[unitName]["buffIcon"..count]:SetHeight(self.config.buttonHeight)
                self.unitButtons[unitName]["buffIcon"..count]:SetScale(self.config.iconSize)

                if self.config.iconBorders then self.unitButtons[unitName]["buffIcon"..count]:SetTexCoord(.1,.9,.1,.9) end

                self.unitButtons[unitName]["buffText"..count]:SetPoint('BOTTOMLEFT', self.unitButtons[unitName], 'BOTTOMRIGHT', iconOffsetX, iconOffsetY)
                self.unitButtons[unitName]["buffText"..count]:SetFont(self.config.fontName, self.config.iconfontHeight)
                self.unitButtons[unitName]["buffText"..count]:SetTextColor(unpack(self.config.fontColor))
                self.unitButtons[unitName]["buffText"..count]:SetAllPoints(self.unitButtons[unitName]["buffIcon"..count]) -- set everything the same as the icon

            end
            for count = 1,self.config.numberOfAuraIcons do
                local iconOffsetX = ((count-1) * (-self.config.buttonHeight- self.config.iconSpacing))  - self.config.iconXOff
                local iconOffsetY
                if buttonFrame.unitType == "tank" then
                    iconOffsetY = self.config.iconYOfftank
                else
                    iconOffsetY = self.config.iconYOffdps
                end

                self.unitButtons[unitName]["auraIcon"..count]:SetPoint('BOTTOMRIGHT', self.unitButtons[unitName], 'BOTTOMLEFT', iconOffsetX, iconOffsetY)
                self.unitButtons[unitName]["auraIcon"..count]:SetWidth(self.config.buttonHeight) -- use the height to make it
                self.unitButtons[unitName]["auraIcon"..count]:SetHeight(self.config.buttonHeight)
                self.unitButtons[unitName]["auraIcon"..count]:SetScale(self.config.iconSize)

                if self.config.iconBorders then self.unitButtons[unitName]["auraIcon"..count]:SetTexCoord(.1,.9,.1,.9) end

                self.unitButtons[unitName]["auraText"..count]:SetPoint('BOTTOMRIGHT', self.unitButtons[unitName], 'BOTTOMLEFT', iconOffsetX, iconOffsetY)
                self.unitButtons[unitName]["auraText"..count]:SetFont(self.config.fontName, self.config.iconfontHeight)
                self.unitButtons[unitName]["auraText"..count]:SetTextColor(unpack(self.config.fontColor))
                self.unitButtons[unitName]["auraText"..count]:SetAllPoints(self.unitButtons[unitName]["auraIcon"..count]) -- set everything the same as the icon
                
            end
    end

end

function addon:findUnitBuffs(unitId)                           --  Loop through all the buffs and auras for the person in each button 
    local buffCounter = 0
    local auraCounter = 0
    -- local foundBuff,foundAura = 0
    local buffIDList = {}
    local auraIDList = {}
    local emptyBuffs = {
        buffID = 0,
        buffExpiry = 0,
        spellID = ""
    }

    -- For the sake of clarity I am calling buffs the spells I put on players and Auras what other people put on them
    if self.config.createTestData then 
        for c,iconList in pairs(addon.testAuraList) do
            if c == unitId then
                auraCounter = 0
                for d,auras in pairs(iconList) do
                    auraCounter = auraCounter + 1
                    auraIDList[auraCounter] = CopyTable(emptyBuffs)
                    auraIDList[auraCounter].buffID = auras.buffID
                    auraIDList[auraCounter].buffExpiry = auras.buffExpiry 
                    auraIDList[auraCounter].spellID = 0
                    -- if unitId == 1013 then print("BO:",d,auras.buffID,iconList[1].buffID,iconList[2].buffID) end
                end
            end
        end
        return buffIDList,buffCounter,auraIDList, auraCounter
    end

    for i = 1, 40 do
        local spellName, spellIcon, _, _, _, buffExpTime,_,_,_,spellID = UnitBuff(unitId,i,'HELPFUL')

        if spellID then
            local somethingFound = false
            for v,k in pairs(self.config.buffNames) do  -- Buffs I put on people (Prescience, ebon might etc)
                if spellName == k then 
                    buffCounter = buffCounter + 1
                    buffIDList[buffCounter] = CopyTable(emptyBuffs)
                    somethingFound=true
                    
                    buffIDList[buffCounter].buffID = spellIcon
                    buffIDList[buffCounter].buffExpiry = buffExpTime
                    buffIDList[buffCounter].spellID = spellID
                end
            end

            if not somethingFound then  -- if this one was not a buff then check if its an AUra we want ot display e.g. one of their cooldowns
                for v,k in pairs(self.config.auraNames) do  -- Cooldowns and auras other people put on my choosen team members (Army of the dead, Power Infusion etc )
                    if spellName == k then 
                        auraCounter = auraCounter + 1
                        auraIDList[auraCounter] = CopyTable(emptyBuffs)
                        auraIDList[auraCounter].buffID = spellIcon
                        auraIDList[auraCounter].buffExpiry = buffExpTime
                        auraIDList[auraCounter].spellID = spellID
                    end
                end
            end
        else
            break
        end

        -- add in some code to buble the buffs by order and duration
    end

    return buffIDList,buffCounter,auraIDList,auraCounter
end

function addon:createTestData()                                -- create the test players and buffs.  r
    local theRole,specName 

    -- Clean out the existing data
    util.AddDebugData(self.roster,"The roster before test data")
	wipe(addon.roster)
    addon:clearAll()

    -- process this the same as we do ion updateRoster()
    local playerName = util.unitname('player')
	local playerGUID = UnitGUID('player')
	if self.config.includePlayer then
		addon.roster[playerName] = 'player'
	end

    -- create the test roster   
    util.AddDebugData(addon.testData, "Processing test data")

    for c,testData in pairs(addon.testData) do
        addon.roster[testData.name] = testData.unitID

        _, specName, _, _, theRole = GetSpecializationInfoForClassID(testData.classIndex,testData.spec) -- note that the class is the class index https://warcraft.wiki.gg/wiki/ClassId

        -- print("Test:",c,testData.classIndex,testData.spec,theRole)
        if theRole == 'TANK' and self.config.autoAddTanks then
            tinsert(self.config.tanks,testData.name)
        end

        -- create test Auras so they are different each time
        local countBuffs = 0
       -- wipe(addon.testBuffList)  -- No longer required
        local Icons = {}


        for i, spellRecord in ipairs(addon.spell_db[testData.classID]) do
                local guess =  math.random(17)
                if guess == 3 then                                   -- Do we want this one ?  jsut get a different one it does matter which one.  6 just gives approxiatly 3 icons
                    local buffFields = {
                        buffID = 0,
                        buffExpiry = 0,
                        spellID = "",
                    }

                    buffFields.buffID = spellRecord.icon
                    buffFields.buffExpiry = ( GetTime() + 45 + math.random(45) )

                    countBuffs = countBuffs + 1                     -- we want no more than three but 0-3 is OK
                    Icons[countBuffs] = buffFields

                    -- if countBuffs == 1 then print("AA:",countBuffs,Icons[1].buffID) end
                    -- if countBuffs == 2 then print("AA:",countBuffs,Icons[1].buffID, Icons[2].buffID) end
                end
            if countBuffs == 3 then break end
        end
        addon.testAuraList[testData.unitID] = Icons
    end

    if self.config.autofillDPS then
        addon:addDamagers()
    end


    self:updateConfig()
end

--------- HEADER FRAME AND MENUS -------------

local groupSelection,unitNames = {},{}
function addon:showHeaderMenu()                                -- Display the headermenu when the frame is rigt clicked

    self:updateRoster()

    wipe(groupSelection)
    wipe(unitNames)
    local unitNames = util.keys(self.roster)
    util.AddDebugData(self.roster, "Current roster before header menu- showHeader()")

    -- Build the list of damagers so you can pick from it

    tsort(unitNames)
    for _, unitName in ipairs(unitNames) do
        local name = util.decoratedName(unitName)
        tinsert(groupSelection, {
            text = name,
            checked = function() return util.hasValue(self.config.damagers, unitName) end,
            func = function(this, arg1, arg2, checked)
                if checked then
                    tremove(self.config.damagers, util.tableIndex(self.config.damagers, unitName))
                    autoAdds[unitName] = nil
                    this.checked = false
                else
                    tinsert(self.config.damagers, unitName)
                    autoAdds[unitName] = nil
                    this.checked = true
                end
                self:updateConfig()
            end,
        })
    end


    self.headerMenu = {
        {text = 'Select Spell Targets',
            isTitle = true,
            notCheckable = true,
        },
        {text = 'DPS: AutoFill',
        notCheckable = true,
        func = function()
            self:addDamagers()
            self:updateConfig()
        end,
        },
        {text = 'DPS: Select people',
            hasArrow = true,
            notCheckable = true,
            menuList = groupSelection,
        },
        {text = 'DPS: Add current target',
        notCheckable = true,
        func = function()
            self:addMyTargetToDPS()
            self:updateConfig()
        end,
        },
        {text = 'Tanks: Add current target',
        notCheckable = true,
        func = function()
            self:addMyTargetToTanks()
            self:updateConfig()
        end,
        },
        {text = 'Clear all',
            notCheckable = true,
            func = function() self:clearAll() end,
        },
        {text = 'Add party',
            notCheckable = true,
            func = function() self:addParty() end,
        },
        {text = 'Configuration',
            isTitle = true,
            notCheckable = true,
        },
        -- {text = 'Invert display',
        -- notCheckable = true,
        -- func = function()
        --     self:invertDisplay()
        -- end,
        -- },
        {text = 'Open options panel',
            notCheckable = true,
            func = function() addon:ToggleOptions() end, -- InterfaceOptionsFrame_OpenToCategory(self.optionsBaseFrame) end,
        },
        {text = 'Test data On/Off',
        notCheckable = true,
        func = function() 
                self.config.createTestData = not self.config.createTestData
                if self.config.createTestData then 
                    self:createTestData() 
                else 
                    addon:clearIcons()
                    addon:onUpdate()
                    addon:updateRoster()
                end
            end,
         },

    }

    -- Make the menu appear at the cursor:
    util.AddDebugData(self.headerMenu, "Display menu - function addon:showHeaderMenu()")
    EasyMenu(self.headerMenu, self.contextMenu, "cursor", 0 , 0, "MENU")
end

function addon:showAssistFrameMenu(playerName,theRole)      -- mini menu when right clicking on a player button

    local idx,idxBottom,idxTop
    
    if theRole == "tank" then
        idx = util.tableIndex(self.config.tanks, playerName)
        idxTop = #self.config.tanks 
        idxBottom = 1
    else
        idx = util.tableIndex(self.config.damagers, playerName)
        idxBottom =  #self.config.damagers
        idxTop=1
    end

        
     local assistMenu = {
        {text = 'Move up',
            notCheckable = true,
            disabled = idx==idxTop,
            func = function()
                -- print ("Menu:",idx,idxBottom,idxTop)
                if theRole == "tank" then
                    tinsert(self.config.tanks,idx+1,(tremove(self.config.tanks,idx)))                   
                else
                    tinsert(self.config.damagers,idx-1,(tremove(self.config.damagers,idx)))
                end
                self:updateConfig()
            end,
        },
        {text = 'Move down',
            notCheckable = true,
            disabled = idx == idxBottom,
            func = function()
                -- print ("Menu:",idx,idxBottom,idxTop)
                if theRole == "tank" then
                    tinsert(self.config.tanks,idx-1,(tremove(self.config.tanks,idx))) -- tanks will move in the opposite direction
                else
                    tinsert(self.config.damagers,idx+1,(tremove(self.config.damagers,idx)))
                end
                self:updateConfig()
            end,
        },
        {text = 'Save to Priority list',
            notCheckable = true,
            func = function()
            addPriorityPlayer(playerName)
        end,
        },
        {text = 'Delete',
            notCheckable = true,
            func = function()
                if theRole == "tank" then
                    tremove(self.config.tanks,idx)            
                else
                    tremove(self.config.damagers,idx)
                end
                self:updateConfig()
            end,
        },
    }

    EasyMenu(assistMenu, self.contextMenu, "cursor", 0 , 0, "MENU")
end

function addon:createHeaderFrame()                          -- build the main addon frame

    if not self.headerFrame then

        self.headerFrame = CreateFrame('Frame', headerMenuName, UIParent, BackdropTemplateMixin and "BackdropTemplate")
        util.AddDebugData(self.headerFrame, "Creating the header frame")

        self.headerFrame.texture = self.headerFrame:CreateTexture()
        self.headerFrame.text = self.headerFrame:CreateFontString(nil, 'OVERLAY')

        self.headerFrame:EnableMouse(true)
        self.headerFrame:SetMovable(true)
        self.headerFrame:RegisterForDrag('LeftButton')

        self.headerFrame:SetScript("OnDragStart", function()
                if self.config.headerUnlocked then 
                    self.headerFrame:StartMoving() 
                end
            end)

        self.headerFrame:SetScript("OnDragStop",
            function()
                self.headerFrame:StopMovingOrSizing()
                self.config.headerAnchor = {self.headerFrame:GetPoint()}
                self.config.headerAnchor[2] = 'UIParent'
            end
        )

        self.headerFrame:SetScript("OnMouseUp",
            function(_, button)
                if button == 'RightButton' then
                    self:showHeaderMenu()
                end
            end
        )

        self.headerFrame.fadeOut = self.headerFrame:CreateAnimationGroup()
        local fadeOut = self.headerFrame.fadeOut:CreateAnimation('Alpha')
        fadeOut:SetDuration(0.5)
        fadeOut:SetStartDelay(0.5)
		fadeOut:SetToAlpha(-1 * self.config.headerColor[4])
        self.headerFrame.fadeOut:SetScript('OnFinished', function() self.headerFrame:SetAlpha(0) end)

        self.headerFrame.fadeIn = self.headerFrame:CreateAnimationGroup()
        local fadeIn = self.headerFrame.fadeIn:CreateAnimation('Alpha')
        fadeIn:SetDuration(0.3)
		fadeIn:SetToAlpha(self.config.headerColor[4])
        self.headerFrame.fadeIn:SetScript('OnFinished', function() self.headerFrame:SetAlpha(self.config.headerColor[4]) end)

        util.AddDebugData(1, "Creating the health and power bar")
        addon:initaliseHealthBar(self.headerFrame)

    else
        self.headerFrame:ClearAllPoints()
    end

    self.headerFrame:SetWidth(self.config.buttonWidth + (2 * self.config.buttonHeight))  -- button plus 2 icons that are square based on height

    

    self.headerFrame:SetHeight(self.config.headerHeight)
    self.headerFrame:SetPoint(unpack(self.config.headerAnchor))
    self.headerFrame:SetBackdrop(self.config.headerBackdrop)
    self.headerFrame:SetBackdropColor(0.15, 0.15, 0.15)

    self.headerFrame.texture:SetAllPoints(self.headerFrame)
    self.headerFrame.texture:SetTexture(self.config.headerTexture)
    self.headerFrame.texture:SetVertexColor(unpack(self.config.headerColor))

    self.headerFrame.text:SetFont(self.config.fontName, self.config.fontHeight,"")
    self.headerFrame.text:SetTextColor(unpack(self.config.fontColor))
    self.headerFrame.text:SetAllPoints(self.headerFrame)
    self.headerFrame.text:SetText(MyAddOnName)

    if self.config.hideAddonName then self.headerFrame.text:Hide() end

    if self.config.autoHideHeader then
        self.headerFrame:SetScript('OnEnter', function()
            if self.headerFrame.fadeOut:IsPlaying() then self.headerFrame.fadeOut:Stop() end
            if self.headerFrame:GetAlpha() < self.config.headerColor[4] then
                self.headerFrame.fadeIn:Play()
            end
        end)
        self.headerFrame:SetScript('OnLeave', function()
            if self.headerFrame.fadeIn:IsPlaying() then self.headerFrame.fadeIn:Stop() end
            if #(util.keys(self.unitButtons)) > 0 then
                self.headerFrame.fadeOut:Play()
            else
                self.headerFrame:SetAlpha(self.config.headerColor[4])
            end
        end)
    else
        self.headerFrame:SetScript('OnEnter', nil)
        self.headerFrame:SetScript('OnLeave', nil)
    end

    self.headerFrame:Show()
    self.headerFrame:SetAlpha(self.config.headerColor[4])

end

----------- TANK AND DAMAGER BUTTON CREATION AND MANAGEMENT --------------

function addon:linkButtonSpells(buttonFrame,barType)        -- link the spells to each button

    if barType=="HB" then     -- 0 is unit action buttons, 1 is the player health and power bars

        -- print("setting healthbar spell")
        if self.config.allowModifierNone and self.config.myClickSpell then 
            buttonFrame:SetAttribute("spell-buff1", self.config.myClickSpell)
        end
        if self.config.allowModifierShift and self.config.myClickSpellShift then 
            buttonFrame:SetAttribute("shift-spell-buff1", self.config.myClickSpellShift)
        end 
        if self.config.allowModifierAlt and self.config.myClickSpellAlt then 
            buttonFrame:SetAttribute("alt-spell-buff1", self.config.myClickSpellAlt)
        end 
    else
    
        -- print("setting button spell")
        if buttonFrame.unitType == "tank" then
            if self.config.allowModifierNone and self.config.tankClickSpell then 
                buttonFrame:SetAttribute("spell-buff1", self.config.tankClickSpell)
            end
            if self.config.allowModifierShift and self.config.tankClickSpellShift then 
                buttonFrame:SetAttribute("shift-spell-buff1", self.config.tankClickSpellShift)
            end 
            if self.config.allowModifierAlt and self.config.tankClickSpellAlt then 
                buttonFrame:SetAttribute("alt-spell-buff1", self.config.tankClickSpellAlt)
            end 
        end

        if buttonFrame.unitType == "damager" then
            if self.config.allowModifierNone and self.config.damagerClickSpell then 
                buttonFrame:SetAttribute("spell-buff1", self.config.damagerClickSpell)
            end
            if self.config.allowModifierShift and self.config.damagerClickSpellShift then 
                buttonFrame:SetAttribute("shift-spell-buff1", self.config.damagerClickSpellShift)
            end 
            if self.config.allowModifierAlt and self.config.damagerClickSpellAlt then 
                buttonFrame:SetAttribute("alt-spell-buff1", self.config.damagerClickSpellAlt)
            end 
        end

    end

end

function addon:formatRaidIcon(buttonFrame)                  -- link spells to the tank and dps buttons plus special spells to your healthbar
    local raidIconPos = self.config.raidiconanchor[self.config.raidiconpos]
    local raidIconSize = self.config.raidiconsize * self.config.buttonHeight

    if not buttonFrame then
        for key,buttonFrame in pairs(self.unitButtons) do
            buttonFrame.raidIcon:ClearAllPoints()
            buttonFrame.raidIcon:SetPoint(raidIconPos, buttonFrame, raidIconPos, 0, 0)
            buttonFrame.raidIcon:SetHeight(raidIconSize)
            buttonFrame.raidIcon:SetWidth(raidIconSize)
        end
    else
        buttonFrame.raidIcon:SetPoint(raidIconPos, buttonFrame, raidIconPos, 0, 0)
        buttonFrame.raidIcon:SetHeight(raidIconSize)
        buttonFrame.raidIcon:SetWidth(raidIconSize)
    end

end

function addon:setupButtonFunctionality(buttonFrame, unitID, unitName, unitType, menuCall)
    --Hide all buttons on creation to not show changes while they are happening
    --buttonFrame:Hide()

    -- if self.config.createTestData then return end

    util.AddDebugData(unitName, "Setup button functionality - function setupButtonFunctionality()")

    --Set us up as a secure button
    buttonFrame:SetAttribute('unitName',unitName)
    buttonFrame:SetAttribute('unitID', unitID)
    buttonFrame:SetAttribute('unit', unitID)  -- do I need this for mouseover to work ?
    buttonFrame.unitID = unitID -- check this *********

    if not self.config.createTestData then 
        buttonFrame:SetAttribute("type", "spell")                        -- make left click button cast a spell
        buttonFrame:SetAttribute("*helpbutton1", "buff1")                -- With any modifiers (*). For friendly targets (helpbutton) as apposed to harmbutton.  for left clicks (1)  
        addon:linkButtonSpells(buttonFrame,"BF")
        SecureUnitButton_OnLoad(buttonFrame, unitID) -- template has the target unit and open menu functionality
    end

    --Right click menu stuff
    buttonFrame:SetScript("OnMouseUp",
        function(_, button)
            if button == 'RightButton' then
                if not IsModifierKeyDown() then self[menuCall](self, unitName, unitType) end -- calling a function taht is specified in a variable name. 
            end
        end
    )

end

function addon:createUnitButtons(unitType)                  -- create the player buttons for tanks and damagers
    --For each tank create their button and record the details in the unitButtons array along with the overlays 
    
    local localUnitTable = {}

    -- local headerFrame = self.headerFrame
    local unitTable = {}
    
    local anchorFrame
    local width = self.config.buttonWidth
    self.buttonWidth = width-self.config.spacingOffset

    if unitType == "tank" then
        util.AddDebugData(self.config.tanks, "Adding "..unitType.." -createunitButtons()")
        unitTable = self.config.tanks
        anchorFrame  = self.HealthBar
    else
        util.AddDebugData(self.config.damagers, "Adding "..unitType.." -createUnitButtons()")
        unitTable = self.config.damagers
        anchorFrame = self.headerFrame
    end

    --Clean out button structure
    if self.unitButtons then
        for unitName, buttonFrame in pairs(self.unitButtons) do
            if buttonFrame.unitType == unitType then
                self.unitButtons[unitName] = {}
                buttonFrame:Hide()
            end
        end
    else
        self.unitButtons = {}
    end

    wipe(localUnitTable)
    
    for _, unitName in ipairs(unitTable) do
        --Is the name being added in the raid or party ?
        -- util.AddDebugData(unitName, "Checking if player in roster -createUnitButtons()")
        if self.roster[unitName] then 
            tinsert(localUnitTable, unitName) 
            util.AddDebugData(unitName, "inserting into local table to process -createUnitButtons()")
        end
    end

    util.AddDebugData(localUnitTable, "Looping through unit table looking for name -createUnitButtons()")

    for i, unitName in ipairs(localUnitTable) do

        local unitID = self.roster[unitName]
        -- util.AddDebugData(unitID, "UnitID for "..unitName.." -createUnitButtons()") -- unitID is player|pet| etc

        if unitID then

            -- make sure the frame name is unique
            local tempFrameName
            local buttonAnchorPoint, headerAnchorPoint, verticalOffset
            local buttonOffset = 0

            if unitType == "tank" then
                tempFrameName = tankNameTemplate:format(i)   
                buttonAnchorPoint, headerAnchorPoint, verticalOffset = unpack(self.config.tankButtonAnchor)
            else
                tempFrameName = damagerNameTemplate:format(i)
                buttonAnchorPoint, headerAnchorPoint, verticalOffset = unpack(self.config.damagerButtonAnchor)
            end
           
            local unitFrameName = tempFrameName

    
            -- If a button exists then reset it to defaults.  IF not, create it
            if _G[unitFrameName] then
                util.AddDebugData(unitFrameName, "REUSING button frame -createUnitButtons()")
                self.unitButtons[unitFrameName] = _G[unitFrameName]
                self.unitButtons[unitFrameName]:ClearAllPoints()
                self.unitButtons[unitFrameName].texture:ClearAllPoints()
                self.unitButtons[unitFrameName].fontString:ClearAllPoints()
                self.unitButtons[unitFrameName].raidIcon:ClearAllPoints()
                for count = 1,self.config.numberOfAuraIcons do 
                    self.unitButtons[unitFrameName]["auraIcon"..count]:ClearAllPoints()
                end
                for count = 1,self.config.numberOfBuffIcons do 
                    self.unitButtons[unitFrameName]["buffIcon"..count]:ClearAllPoints()
                end
                self.unitButtons[unitFrameName]:Show()
            else
                util.AddDebugData(unitFrameName, "CREATING button frame -createUnitButtons()")

                -- create the main button for this player using their name as the key
                self.unitButtons[unitFrameName] = CreateFrame("Button", unitFrameName, UIParent, BackdropTemplateMixin and "BackdropTemplate, SecureUnitButtonTemplate")
                self.unitButtons[unitFrameName].texture = self.unitButtons[unitFrameName]:CreateTexture()
                self.unitButtons[unitFrameName].fontString = self.unitButtons[unitFrameName]:CreateFontString(nil, 'OVERLAY')

                -- Create the icon and buff textures to be used later
                for count = 1,self.config.numberOfBuffIcons do
                    self.unitButtons[unitFrameName]["buffIcon"..count] = self.unitButtons[unitFrameName]:CreateTexture("buffIcon"..count, 'OVERLAY')
                    self.unitButtons[unitFrameName]["buffText"..count] = self.unitButtons[unitFrameName]:CreateFontString("buffText"..count, "OVERLAY", "GameFontNormal")
                end
                for count = 1,self.config.numberOfAuraIcons do
                    self.unitButtons[unitFrameName]["auraIcon"..count] = self.unitButtons[unitFrameName]:CreateTexture("auraIcon"..count, 'OVERLAY')
                    self.unitButtons[unitFrameName]["auraText"..count] = self.unitButtons[unitFrameName]:CreateFontString("auraText"..count, "OVERLAY", "GameFontNormal") -- name was nil
                end

                -- Create a texture for raidicons
                self.unitButtons[unitFrameName].raidIcon = self.unitButtons[unitFrameName]:CreateTexture('RaidIcon', "OVERLAY", nil)

                 -- Create a texture for having agro
                self.unitButtons[unitFrameName].aggro = self.unitButtons[unitFrameName]:CreateTexture('Aggro', "OVERLAY", nil)

            end

            self.unitButtons[unitFrameName].unitType = unitType -- Added to the button detail to be used later

            -- Configure the button
            if i == 1 then 
                buttonOffset = self.config.buttonHeight 
            end -- the first player button needs to be set differently

            self.unitButtons[unitFrameName]:SetPoint(buttonAnchorPoint, anchorFrame, headerAnchorPoint,buttonOffset , verticalOffset)
            self.unitButtons[unitFrameName]:SetWidth(self.buttonWidth)
            self.unitButtons[unitFrameName]:SetHeight(self.config.buttonHeight)

            -- main button
            self.unitButtons[unitFrameName]:SetBackdrop(self.config.buttonBackdrop)
			self.unitButtons[unitFrameName]:SetBackdropColor(unpack(self.config.buttonBackdropColor))
            self.unitButtons[unitFrameName].texture:SetPoint('TOP', self.unitButtons[unitFrameName], 'TOP')
            self.unitButtons[unitFrameName].texture:SetPoint('BOTTOM', self.unitButtons[unitFrameName], 'BOTTOM')
            self.unitButtons[unitFrameName].texture:SetPoint('LEFT', self.unitButtons[unitFrameName], 'LEFT')
            self.unitButtons[unitFrameName].texture:SetWidth(self.buttonWidth)
            self.unitButtons[unitFrameName].texture:SetTexture(self.config.buttonTexture)
            self.unitButtons[unitFrameName].texture:SetVertexColor(unpack(self.config.friendlyButtonColor))
            self.unitButtons[unitFrameName].fontString:SetFont(self.config.fontName, self.config.fontHeight)
            self.unitButtons[unitFrameName].fontString:SetTextColor(unpack(self.config.fontColor))
            self.unitButtons[unitFrameName].fontString:SetAllPoints(self.unitButtons[unitFrameName])

            -- Flesh out more detail for the icons
            for count = 1,self.config.numberOfBuffIcons do
                local iconOffsetX = ((count-1) * (self.config.buttonHeight + self.config.iconSpacing)) + self.config.iconXOff
                local iconOffsetY 
                if unitType == "tank" then
                    iconOffsetY = self.config.iconYOfftank
                else
                    iconOffsetY = self.config.iconYOffdps
                end

                self.unitButtons[unitFrameName]["buffText"..count]:Hide()
                self.unitButtons[unitFrameName]["buffIcon"..count]:Hide()

                self.unitButtons[unitFrameName]["buffIcon"..count]:SetPoint('BOTTOMLEFT', self.unitButtons[unitFrameName], 'BOTTOMRIGHT', iconOffsetX, iconOffsetY)
                self.unitButtons[unitFrameName]["buffIcon"..count]:SetWidth(self.config.buttonHeight) -- use the height to make it
                self.unitButtons[unitFrameName]["buffIcon"..count]:SetHeight(self.config.buttonHeight)

                self.unitButtons[unitFrameName]["buffText"..count]:SetPoint('BOTTOMLEFT', self.unitButtons[unitFrameName], 'BOTTOMRIGHT', iconOffsetX, iconOffsetY)
                self.unitButtons[unitFrameName]["buffText"..count]:SetFont(self.config.fontName, self.config.iconfontHeight)
                self.unitButtons[unitFrameName]["buffText"..count]:SetTextColor(unpack(self.config.fontColor))
                self.unitButtons[unitFrameName]["buffText"..count]:SetAllPoints(self.unitButtons[unitFrameName]["buffIcon"..count]) -- set everything the same as the icon

            end

            for count = 1,self.config.numberOfAuraIcons do
                local iconOffsetX = ((count-1) * (-self.config.buttonHeight- self.config.iconSpacing))  - self.config.iconXOff
                local iconOffsetY 
                if unitType == "tank" then
                    iconOffsetY = self.config.iconYOfftank
                else
                    iconOffsetY = self.config.iconYOffdps
                end

                -- print("Offset:",unitFrameName,iconOffsetX,count-1, self.config.buttonHeight, self.config.iconSpacing, self.config.iconXOff)
                self.unitButtons[unitFrameName]["auraText"..count]:Hide()
                self.unitButtons[unitFrameName]["auraIcon"..count]:Hide()

                self.unitButtons[unitFrameName]["auraIcon"..count]:SetPoint('BOTTOMRIGHT', self.unitButtons[unitFrameName], 'BOTTOMLEFT', iconOffsetX, iconOffsetY)
                self.unitButtons[unitFrameName]["auraIcon"..count]:SetWidth(self.config.buttonHeight) -- use the height to make it
                self.unitButtons[unitFrameName]["auraIcon"..count]:SetHeight(self.config.buttonHeight)

                self.unitButtons[unitFrameName]["auraText"..count]:SetPoint('BOTTOMRIGHT', self.unitButtons[unitFrameName], 'BOTTOMLEFT', iconOffsetX, iconOffsetY)
                self.unitButtons[unitFrameName]["auraText"..count]:SetFont(self.config.fontName, self.config.iconfontHeight)
                self.unitButtons[unitFrameName]["auraText"..count]:SetTextColor(unpack(self.config.fontColor))
                self.unitButtons[unitFrameName]["auraText"..count]:SetAllPoints(self.unitButtons[unitFrameName]["auraIcon"..count])

            end

            addon:formatRaidIcon(self.unitButtons[unitFrameName])

            -- FORMAT THE AGGRO TEXTURE
            self.unitButtons[unitFrameName].aggro:SetPoint('TOP', self.unitButtons[unitFrameName], 'TOP')
            self.unitButtons[unitFrameName].aggro:SetWidth(self.buttonWidth)
            self.unitButtons[unitFrameName].aggro:SetHeight(self.config.buttonHeight * 0.1)
			self.unitButtons[unitFrameName].aggro:SetColorTexture(1 ,0 ,0 )  -- make is RED 
            self.unitButtons[unitFrameName].aggro:Hide()

            util.AddDebugData(unitName, "Button drawn for player -createUnitButtons()")

            -- When your solo and you want your name twice you need to have slightly different name for your character 
            if IsInGroup() then
                self:setupButtonFunctionality(self.unitButtons[unitFrameName], unitID, unitName, unitType,  'showAssistFrameMenu')
            else
                if not self.config.createTestData then unitName = unitName.."*" end
                self:setupButtonFunctionality(self.unitButtons[unitFrameName], unitID, unitName, unitType, 'showAssistFrameMenu')
            end

            anchorFrame = self.unitButtons[unitFrameName]

        end

        util.AddDebugData(anchorFrame,"Button details")

    end

    self:updateEnabled()

    --Decide whether or not to show the header frame (logic in the OnLeave function)
    if self.config.autoHideHeader then
        self.headerFrame:GetScript('OnLeave')()
    end
end

--------- HEALTH AND RESOURCE BAR ---------------------------


function addon:CreateHealthBar(previous)                    -- Create StatusBar with a text overlay
    local barAnchorPoint, headerAnchorPoint, verticalOffset
    local height = addon.config.buttonHeight
    local width = (addon.config.buttonWidth + (2 * height)) 

    -- create the main button for this player using their name as the key
    addon.HealthBar = CreateFrame("Button", healthBarName, UIParent, BackdropTemplateMixin and "BackdropTemplate, SecureUnitButtonTemplate")
	addon.HealthBar:SetSize(width, height)

    addon.HealthBar:SetBackdrop(self.config.buttonBackdrop)
    addon.HealthBar:SetBackdropColor(unpack(self.config.buttonBackdropColor))

    addon.HealthBar.texture = addon.HealthBar:CreateTexture()
    addon.HealthBar.texture:SetPoint('TOP', addon.HealthBar, 'TOP')
    addon.HealthBar.texture:SetPoint('BOTTOM', addon.HealthBar, 'BOTTOM')
    addon.HealthBar.texture:SetPoint('LEFT', addon.HealthBar, 'LEFT')
    addon.HealthBar.texture:SetWidth(width)
    addon.HealthBar.texture:SetTexture(self.config.buttonTexture)
    addon.HealthBar.texture:SetVertexColor(0.2, 0.8, 0.4)     --unpack(self.config.friendlyButtonColor))

    barAnchorPoint, headerAnchorPoint, verticalOffset = unpack(addon.config.tankButtonAnchor)

    addon.HealthBar:SetPoint(barAnchorPoint, previous, headerAnchorPoint)

	addon.HealthBar.Text = addon.HealthBar:CreateFontString()
	addon.HealthBar.Text:SetFontObject(GameFontNormal)
	addon.HealthBar.Text:SetPoint("CENTER")
	addon.HealthBar.Text:SetJustifyH("CENTER")
	addon.HealthBar.Text:SetJustifyV("CENTER")
    addon.HealthBar.Text:SetFont(self.config.fontName, self.config.fontHeight)
    addon.HealthBar.Text:SetTextColor(unpack(self.config.fontColor))


    addon.HealthBar:SetAttribute('unitName','player')
    addon.HealthBar:SetAttribute('unitID', 'player')
    addon.HealthBar:SetAttribute('unit', 'player')      -- do I need this for mouseover to work ?
    addon.HealthBar:SetAttribute("type", "spell")                        -- make left click button cast a spell
    addon.HealthBar:SetAttribute("*helpbutton1", "buff1")                -- With any modifiers (*). For friendly targets (helpbutton) as apposed to harmbutton.  for left clicks (1)  

    addon:linkButtonSpells(addon.HealthBar,"HB")
    SecureUnitButton_OnLoad(addon.HealthBar, 'player')    
    
end

function addon:UpdateHealth()                               -- Update the health bar
    local width = (addon.config.buttonWidth + (2 * addon.config.buttonHeight)) 
	-- local health = UnitHealth('player')
    -- local healthMax = UnitHealthMax('player')
    -- local newWidth

    local newWidth = util.getNewHealth('player') 

    addon.HealthBar.texture:SetWidth(newWidth * width)

    if not self.config.displaybartext then
        self.HealthBar.Text:SetText()
    else
        local currentHealth = newWidth * 100
	    self.HealthBar.Text:SetText("Health:"..math.floor(currentHealth).."%")
    end
end

function addon:showHealthBar(bar)

    if bar=="health" then
        local status = self.config.addhealthbar
        if status then
            self.HealthBar:RegisterUnitEvent("UNIT_HEALTH",'player')              -- register the events to be used (UNIT_HEALTH_FREQUENT only exists in old versions these days
            self.HealthBar:RegisterUnitEvent("UNIT_MAXHEALTH",'player')
            self.HealthBar:SetHeight(addon.config.buttonHeight)
            self.HealthBar:Show()
        else
            self.HealthBar:UnregisterEvent("UNIT_HEALTH")              -- register the events to be used (UNIT_HEALTH_FREQUENT only exists in old versions these days
            self.HealthBar:UnregisterEvent("UNIT_MAXHEALTH")
            self.HealthBar:SetHeight(1)
            self.HealthBar:Hide()
        end
    end

end

function addon:initaliseHealthBar(headerFrame)
 
        addon:CreateHealthBar(headerFrame)
        util.AddDebugData(self.HealthBar, "Healthbar")

        self.HealthBar:SetScript("OnEvent", function(self, event, ...)
            local unit = ...                                -- For events starting with UNIT_ the first parameter is the unit
            if unit ~= "player" then                        -- We"re only updating the player status ATM
                return                                      -- So ignore any other unit
            end
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then         -- Fired when health changes
                addon:UpdateHealth()
            end
        end)
        
        addon:UpdateHealth()

end
