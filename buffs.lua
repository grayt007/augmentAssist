local MyAddOnName, NS = ...
local util = NS.Utils
local addon = _G[MyAddOnName]



function addon:clearIcons()
    for unitName, buttonFrame in pairs(self.unitButtons) do
        for b = 1,self.config.numberOfBuffIcons do   
            buttonFrame["buffIcon"..b]:SetTexture()
        end
        for b = 1,self.config.numberOfAuraIcons do   
            buttonFrame["AuraIcon"..b]:SetTexture()
        end
    end
end


function addon:updateIcons()

    for unitName, buttonFrame in pairs(self.unitButtons) do

            -- Flesh out more detail for the icons
            for count = 1,self.config.numberOfBuffIcons do
                local iconOffsetX = ((count-1) * (self.config.buttonHeight + self.config.iconSpacing)) + self.config.iconXOff
                local iconOffsetY = self.config.iconYOff

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
                local iconOffsetY = self.config.iconYOff

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

function addon:findUnitBuffs(unitId)  --  Loop through all the buffs and auras for the person in each button 
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


