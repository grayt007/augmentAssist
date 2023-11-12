local MyAddOnName, NS = ...
local util = NS.Utils
local addon = _G[MyAddOnName]

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local LibDialog = LibStub("LibDialog-1.0")

local GetSpellInfo = GetSpellInfo
local GetCVarBool = GetCVarBool
local SetCVar = SetCVar
local InCombatLockdown = InCombatLockdown
local CopyTable = CopyTable
local format = format
local next = next
local wipe = wipe
local pairs = pairs
local type = type
local tonumber = tonumber
local tostring = tostring
local Spell = Spell
local MAX_CLASSES = MAX_CLASSES
local CLASS_SORT_ORDER = CopyTable(CLASS_SORT_ORDER)
do
    -- Why oh why is this "sort order" table not actually sorted Blizzard?
    table.sort(CLASS_SORT_ORDER)
end
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

local spellDescriptions = {}
local optionsDisabled = {}
local defaultBarName = "DEFAULT"
-- self.dbNew.profile.spells[theSpellID]        Holds the Evolker spells for selecting when you click a button
-- 


local classIcons = {
    ["DEATHKNIGHT"] = 135771,
    ["DEMONHUNTER"] = 1260827,
    ["DRUID"] = 625999,
    ["EVOKER"] = 4574311,
    ["HUNTER"] = 626000,
    ["MAGE"] = 626001,
    ["MONK"] = 626002,
    ["PALADIN"] = 626003,
    ["PRIEST"] = 626004,
    ["ROGUE"] = 626005,
    ["SHAMAN"] = 626006,
    ["WARLOCK"] = 626007,
    ["WARRIOR"] = 626008,
}
local specialisationIcons = {
}

addon.customIcons = {
    ["Eating/Drinking"] = 134062,
    ["?"] = 134400,
    ["Cogwheel"] = 136243,
}
local customIcons = addon.customIcons

local customSpellNames = {
    [228050] = GetSpellInfo(228049),
}
local customSpellDescriptions = {
    [362486] = 353114, -- Keeper of the Grove
}
local deleteSpellDelegate = {
    buttons = {
        {
            text = YES,
            on_click = function(self)
                local spellId = tonumber(self.data)
                if not spellId then return end

                -- if self.dbNew.profile.buffs[spellId].children then
                --     for childId in pairs(self.dbNew.profile.buffs[spellId].children) do
                --         if self.dbNew.global.customBuffs[childId]
                --         and not (addon.defaultSpells[childId] and addon.defaultSpells[childId].parent == spellId) then
                --             self.dbNew.profile.buffs[childId] = nil
                --             self.dbNew.profile.buffs[spellId].children[childId] = nil
                --         end
                --     end

                --     if next(self.dbNew.profile.buffs[spellId].children) == nil then
                --         self.dbNew.profile.buffs[spellId].children = nil
                --         self.dbNew.profile.buffs[spellId].UpdateChildren = nil
                --     end
                -- end

                -- self.dbNew.global.customBuffs[spellId] = nil

                -- for id, spell in pairs(self.dbNew.global.customBuffs) do
                --     if spell.parent and spell.parent == spellId then
                --         self.dbNew.global.customBuffs[id] = nil
                --     end
                -- end

                -- if addon.defaultSpells[spellId] then
                --     -- for k, v in pairs(addon.defaultSpells[spellId]) do
                --     --     if type(v) == "table" then
                --     --         self.dbNew.profile.buffs[spellId][k] = CopyTable(v)
                --     --     else
                --     --         self.dbNew.profile.buffs[spellId][k] = v
                --     --     end
                --     -- end
                --     self.dbNew.profile.buffs[spellId][k] = v
                --     self.dbNew.profile.buffs[spellId].custom = nil
                -- else
                    -- print("SpellID:",spellId)
                    addon.dbNew.profile.buffs[spellId] = nil
                -- end

                customIcons[spellId] = nil

                -- if self.dbNew.profile.buffs[spellId] and self.dbNew.profile.buffs[spellId].children then
                --     self.dbNew.profile.buffs[spellId]:UpdateChildren()
                -- end

                addon.options.args.customSpells.args[self.data] = nil
                if AceConfigDialog.OpenFrames["augmentAssistDialog"] then
                    addon.priorityListDialog.args[self.data] = nil
                    AceRegistry:NotifyChange("augmentAssistDialog")
                end
                addon:updateAuraOptionTab()
                -- addon:RefreshOverlays()

                AceRegistry:NotifyChange("augmentAssist")
            end,
        },
        {
            text = NO,
        },
    },
    no_close_button = true,
    show_while_dead = true,
    hide_on_escape = true,
    on_show = function(self)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:Raise()
    end,
}

local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local GetSpellInfo = GetSpellInfo
local spellDescriptions = {}
local optionsDisabled = {}

local function IsDifferentDialogBar(barName)
    return addon.priorityListDialog.args.bar.name ~= barName
end

local function AddToPriorityDialog(spellIdStr, remove)  -- Add spels to the extra dialog frame 
    local list = addon.priorityListDialog.args
    local spellId = tonumber(spellIdStr) or spellIdStr
    local spell = addon.dbNew.profile.buffs[spellId]
    local spellName, _, icon = GetSpellInfo(spellId)

    if not spell then return end

    if addon.customIcons[spellId] then
        icon = addon.customIcons[spellId]
    end

    if customSpellNames[spellId] then
        spellName = customSpellNames[spellId]
    end

    if remove then
        list[spellIdStr] = nil
    else
        list[spellIdStr] = {
            name = util.Colorize(spellName or spellIdStr, spell.class) .. " [" .. spell.prio .. "]",
            image = icon,
            imageCoords = { 0.08, 0.92, 0.08, 0.92 },
            imageWidth = 16,
            imageHeight = 16,
            type = "description",
            order = spell.prio + 1,
        }
    end
end

function UpdateBuffListfromOptions()
    -- buffNames update incase they were changed

    -- Use spell names not spellID becuase we dont care which of the ?? variations of a spell it is just if one is there
    while addon.dbNew.profile.config.buffNames[1] ~= nil do
        table.remove(addon.dbNew.profile.config.buffNames)
    end

    if addon.dbNew.profile.config.allowModifierNone then
        tinsert(addon.dbNew.profile.config.buffNames,addon.dbNew.profile.spells[addon.dbNew.profile.config.tankClickSpell])
        tinsert(addon.dbNew.profile.config.buffNames,addon.dbNew.profile.spells[addon.dbNew.profile.config.damagerClickSpell])
    end
    if addon.dbNew.profile.config.allowModifierShift then
        tinsert(addon.dbNew.profile.config.buffNames,addon.dbNew.profile.spells[addon.dbNew.profile.config.tankClickSpellShift])
        tinsert(addon.dbNew.profile.config.buffNames,addon.dbNew.profile.spells[addon.dbNew.profile.config.damagerClickSpellShift])
    end
    if addon.dbNew.profile.config.allowModifierAlt then
        tinsert(addon.dbNew.profile.config.buffNames,addon.dbNew.profile.spells[addon.dbNew.profile.config.tankClickSpellAlt])
        tinsert(addon.dbNew.profile.config.buffNames,addon.dbNew.profile.spells[addon.dbNew.profile.config.damagerClickSpellAlt])
    end

    -- debug lines
    -- for c,spell in pairs(addon.dbNew.profile.config.buffNames) do
    --     print("Rec B:",c,spell)
    -- end

    -- Update the  spells liunked to he buttons
    for c, buttonFrame in pairs(addon.unitButtons) do
        addon:linkButtonSpells(buttonFrame,0)
    end


end

function UpdateAuraListFromOptions()
    -- auraNames update incase they were changed
    -- use spell names not SpellID.  We dont care what Heroism or what version of a spell is ther ejust if there is one with that name.

    while addon.dbNew.profile.config.auraNames[1] ~= nil do
        table.remove(addon.dbNew.profile.config.auraNames)
    end
    for c, spell in pairs(addon.dbNew.profile.buffs) do
        if addon.dbNew.profile.buffs[c].enabled then
            local spellName = GetSpellInfo(c)  
            tinsert(addon.dbNew.profile.config.auraNames,spellName)
        end
    end
    -- Aura lines
    -- for c,spell in pairs(addon.dbNew.profile.config.auraNames) do
    --     print("Rec A:",c,addon.dbNew.profile.config.auraNames[c],spell)
    -- end

end

local function GetClassCooldowns(class)  -- Get a list of the cooldowns and tie it to this profile
    local spells = {}
    
    if next(addon.dbNew.profile.buffs) ~= nil then
        for k, v in pairs(addon.dbNew.profile.buffs) do
            if not v.parent and (v.class == class) then
                local spellName, _, icon = GetSpellInfo(k)
                local spellIdStr = tostring(k)

                if customSpellNames[k] then
                    spellName = customSpellNames[k]
                end

                -- if addon.dbNew.profile.buffs[k].recommended then
                --     print("Found recommended spell",k)
                -- end

                local formattedName = (spellName and icon) and format("%s%s", addon:GetIconString(icon), spellName)
                    or icon and format("%s%s", addon:GetIconString(icon), k) or spellIdStr

                if spellName then
                    local id = customSpellDescriptions[k] or k
                    local spell = Spell:CreateFromSpellID(id)
                    spell:ContinueOnSpellLoad(function()
                        spellDescriptions[k] = spell:GetSpellDescription()
                    end)
                end

                spells[spellIdStr] = {
                    name = "",
                    type = "group",
                    inline = true,
                    order = v.prio,
                    args = {
                        toggle = {
                            name = spellName or (type(k) == "string" and k) or format("Invalid Spell: %s", k),
                            image = icon,
                            imageCoords = { 0.08, 0.92, 0.08, 0.92 },
                            type = "toggle",
                            order = 0,
                            width = 1.1,
                            desc = function()
                                local description = spellDescriptions[k] and spellDescriptions[k] ~= ""
                                    and spellDescriptions[k] .. "\n" or ""
                                
                                description = description
                                    .. format("\n%s %d", util.Colorize("Priority"), v.prio)
                                    .. (spellName and format("\n%s %d", util.Colorize("Spell ID"), k) or "")
                                
                                return description
                            end,
                            get = function(info)
                                if addon.dbNew.profile.buffs[k].enabled ~= false then -- for some reason there is a but cvausing it to be nil when its set to false.  Future problem to solve
                                    addon.dbNew.profile.buffs[k].enabled = true
                                end
                                return addon.dbNew.profile.buffs[k].enabled
                            end,
                            set = function(_, value)
                                addon.dbNew.profile.buffs[k].enabled = value
                                if AceConfigDialog.OpenFrames["augmentAssistDialog"] then
                                    AddToPriorityDialog(spellIdStr, not value)
                                    AceRegistry:NotifyChange("augmentAssistDialog")
                                end
                                UpdateAuraListFromOptions()
                            end,
                        },
                        -- prio = {
                        --     name = " "..v.prio,
                        --     desc = "What is the current priority of this cooldown.  Lower numbers get priority for display",
                        --     type = "description",
                        --     order = 2.5,
                        --     width = 0.3,
                        -- },
                        recommended = {
                            name = (function()
                                local recFlag = ""
                                
                                if addon.dbNew.profile.buffs[k].recommended then 
                                    recFlag = "Yes" 
                                else
                                    recFlag = "No"
                                    if addon.dbNew.profile.buffs[k].source == "custom" then
                                        recFlag = "Custom"
                                    end             
                                end

                                return recFlag
                            end),
                            desc = "Recommended by addon as a priority cooldown or Aura",
                            type = "description",
                            order = 3,
                            width = 0.3,
                        },
                        edit = {
                            name = "",
                            image = "Interface\\Buttons\\UI-OptionsButton",
                            imageWidth = 12,
                            imageHeight = 12,
                            type = "execute",
                            order = 1,
                            width = 0.2,
                            func = function()
                                local key = k
                                addon[key] = not addon[key] or nil
                            end,
                        },
                        additionalSettings = {
                            name = " ",
                            type = "group",
                            inline = true,
                            order = 4,
                            hidden = function()
                                local key = k
                                return addon[key] == nil and true or not addon[key]
                            end,
                            args = {
                                header = {
                                    name = addon:GetIconString(icon, 25) or "",
                                    type = "header",
                                    order = 0,
                                },
                                newPriority = {
                                    name = "New priority (1 is highest)",
                                    type = "input",
                                    order = 1,
                                    width = 1,
                                    get = function()
                                        return tostring(v.prio)
                                    end,
                                    set = function(_, value)
                                        addon.dbNew.profile.buffs[k].prio = tonumber(value)
                                        v.prio = tonumber(value)
                                    end,
                                },

                                space3 = {
                                    name = " ",
                                    type = "description",
                                    order = 5,
                                    width = 0.05,
                                },

                            },
                        },
                    },
                }
            end
        end
    end
    return spells
end

local function GetClasses() -- get a list of classes
    -- Get the list of classes and then cycle through those and get all the spells
    local classes = {}

    classes["MISC"] = {
        name = format("%s %s", addon.GetIconString(addon.customIcons["Cogwheel"], 15), util.Colorize(MISCELLANEOUS, "MISC")),
        order = 99,
        type = "group",
        args = GetClassCooldowns("MISC" ),
    }

    for i = 1, MAX_CLASSES do
        local className = CLASS_SORT_ORDER[i]

        classes[className] = {
            name = format("%s %s", addon:GetIconString(classIcons[className], 15), util.Colorize(LOCALIZED_CLASS_NAMES_MALE[className], className)),
            order = i,
            type = "group",
            args = GetClassCooldowns(className),
        }
    end
    return classes
end

local function GetPriorityPlayers()  -- get a list of the priority players and layout the extra detail to display
    local playerList = {}

    for i,playerRec in pairs(addon.dbNew.profile.priorityPlayers) do

            playerList[playerRec.unitName] = {
                name =  format("%s %s",addon:GetIconString(classIcons[playerRec.className], 15),util.Colorize(playerRec.unitName)),
                order = i,
                type = "group",
                hidden = function ()
                            local foundName = true
                            for idx,playerRec2 in pairs(addon.dbNew.profile.priorityPlayers) do
                                if playerRec2.unitName == playerRec.unitName then
                                    foundName = false
                                    break
                                end
                            end
                            -- print("PP:",playerRec.unitName,playerRec.unitName)
                            return foundName
                        end,
                args = {
                    logo = {
                        order = 1,
                        name = addon:GetIconString(classIcons[playerRec.className],60),
                        type = "description",
                    },
                    spaceSettingsAB = {
                        order = 10,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    playerdateAddedName = {
                        order = 11,
                        name = "Date added: "..playerRec.dateAdded,
                        type = "description",
                        width = 1.5,
                    },
                    playerName = {
                        order = 12,
                        name = "Name: "..playerRec.unitName,
                        type = "description",
                        width = 1.5,
                    },
                    Server = {
                        order = 13,
                        name = "Server: "..playerRec.serverName,
                        type = "description",
                        width = 1.5,
                    },
                    class = {
                        order = 14,
                        name = "Class: "..playerRec.className,
                        type = "description",
                        width = 1.5,
                    },
                    Specialisation = {
                        order = 15,
                        name = "Specialisation: "..playerRec.specName,
                        type = "description",
                        width = 1.5,
                    },
                    spaceSettingsAC = {
                        order = 16,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    playerDescription = {
                        order = 17,
                        name = "Player notes and comments",
                        type = "input",
                        multiline = 4,
                        width = 2,
                        get = function(info) end,
                        set = function(info, val) end,
                    },
                    spaceSettingsAA = {
                        order = 18,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    spaceSettingsAD = {
                        order = 19,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    deletePlayer = {
                        order = 20,
                        name = "Delete",
                        type = "execute",
                        width = 0.7,
                        desc = "Delete this player ",
                        confirm = true,
                        func = function() 
                            for idx,playerRec2 in pairs(addon.dbNew.profile.priorityPlayers) do
                                if playerRec2.unitName == playerRec.unitName then
                                    tremove(addon.dbNew.profile.priorityPlayers,idx)
                                    break
                                end
                            end
                            AceRegistry:NotifyChange("augmentAssist")
                            end,
                    },
                },
            }
    end
    return playerList
end

function addon:updateAuraOptionTab()

    for k, v in pairs(GetClasses()) do
        if self.options.args.bars.args.auras then
            self.options.args.bars.args.auras.args[k] = v
        end
    end
end

function addon:updateAutofillOptionTab()
    local classSpecs = {}
    local testIt

    -- util.AddDebugData(self.config.prioritySpecs,"Class Spec settings")

    for i = 1, MAX_CLASSES do
        local classKey = CLASS_SORT_ORDER[i]

        for className,specList in pairs(addon.specDetails) do
            if className == classKey then
              
                classSpecs[className] = {
                        name = format("%s %s", addon:GetIconString(classIcons[className], 15), util.Colorize(LOCALIZED_CLASS_NAMES_MALE[className], className)),
                        type = "description",
                        order  = (i*10),
                        width = 0.6,
                }
                classSpecs[className.."specName1"] = {
                        name = specList[1].name,
                        type = "toggle",
                        order = (i*10)+1 ,
                        get = function() return 
                            self.config.prioritySpecs[className][1]
                        end,
                        set = function(info, value)
                            self.config.prioritySpecs[className][1] = value 
                        end,
                        width = 0.6,
                }
                classSpecs[className.."specName2"] = {
                        name = specList[2].name,
                        type = "toggle",
                        get = function() return 
                            self.config.prioritySpecs[className][2]
                        end,
                        set = function(info, value)
                            self.config.prioritySpecs[className][2] = value 
                        end,
                        order = (i*10)+2 ,
                        width = 0.6,
                }
                if specList[3].name ~= "NONE" then
                    classSpecs[className.."specName3"] = {
                            name = specList[3].name,
                            type = "toggle",
                            get = function() return 
                                self.config.prioritySpecs[className][3]
                            end,
                            set = function(info, value)
                                self.config.prioritySpecs[className][3] = value 
                            end,
                            order = (i*10)+3 ,
                            width = 0.6,
                    }
                else
                    classSpecs[className.."specName3"] = {
                        name = "",
                        type = "description",
                        order = (i*10)+3 ,
                        width = 0.6,
                }
                end
                if specList[4].name ~= "NONE" then
                    classSpecs[className.."specName4"] = {
                            name = specList[4].name,
                            type = "toggle",
                            get = function() return 
                                self.config.prioritySpecs[className][4]
                            end,
                            set = function(info, value)
                                self.config.prioritySpecs[className][4] = value 
                            end,
                            order = (i*10)+4 ,
                            width = 0.6,
                    }
                else
                    classSpecs[className.."specName4"] = {
                        name = "",
                        type = "description",
                        order = (i*10)+4 ,
                        width = 0.6,
                }
                end
            end
        end

    end

    for k, v in pairs(classSpecs) do
        if self.options.args.bars.args.autoFill then
            self.options.args.bars.args.autoFill.args[k] = v
        end
    end
end

function addon:updatePriorityOptionTab()

    for k, v in pairs(GetPriorityPlayers()) do
        if self.options.args.bars.args.priority then
            self.options.args.bars.args.priority.args[k] = v
        end
    end
    
end

function addon:GetIconString(icon, iconSize)
    local size = iconSize or 0
    local ltTexel = 0.08 * 256
    local rbTexel = 0.92 * 256

    if not icon then
        icon = addon.customIcons["?"]
    end

    return format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t", icon, size, size, ltTexel, rbTexel, ltTexel, rbTexel)
    --            |T%s     :%d:%d:0:0:256:256:%d: %d: %d:%d|t"
--               "|T5199639: 0: 0:0:0:256:256:20:235:20:235|tPrescience"
end

function addon:CreatePriorityDialog()
    local bar = addon.dbNew.profile.bars[defaultBarName]

    local spells = {
        desc = {
            name = "This informational panel is the full list of spells currently enabled in order of priority. Any aura changes made while this panel is open will be reflected here in real time.",
            type = "description",
            order = 0,
        },
        space = {
            name = " ",
            type = "description",
            order = 0.5,
        },
    }

    -- for spellIdStr, info in pairs(GetClassCooldowns("MISC")) do
    --     local spellId = tonumber(spellIdStr) or spellIdStr
    --     if self.dbNew.profile.buffs[spellId].state.enabled then
    --         spells[spellIdStr] = {
    --             name = util.Colorize(info.args.toggle.name, "MISC") .. " [" .. info.order .. "]",
    --             image = info.args.toggle.image,
    --             imageCoords = info.args.toggle.imageCoords,
    --             imageWidth = 16,
    --             imageHeight = 16,
    --             type = "description",
    --             order = info.order + 1,
    --         }
    --     end
    -- end

    for i = 1, MAX_CLASSES do
        local className = CLASS_SORT_ORDER[i]
        for spellIdStr, info in pairs(GetClassCooldowns(className)) do
            local spellId = tonumber(spellIdStr) or spellIdStr
            if addon.dbNew.profile.buffs[spellId].enabled then
                spells[spellIdStr] = {
                    name = util.Colorize(info.args.toggle.name, className) .. " [" .. info.order .. "]",
                    image = info.args.toggle.image,
                    imageCoords = info.args.toggle.imageCoords,
                    imageWidth = 16,
                    imageHeight = 16,
                    type = "description",
                    order = info.order + 1,
                }
            end
        end
    end

    self.priorityListDialog.name = "Enabled Auras Priority List"
    self.priorityListDialog.args = spells
    util.AddDebugData(spells,"Spell list for the extra aura window")
end

function addon:AddTabsToOptions() 

    self.options.args.bars.args.settings = {
        name = SETTINGS,
        type = "group",
        order = 3,
        args = {
            includeSpecTanks = {
                type = 'toggle',
                name = 'Include players in a tank spec',
                desc = 'Show any party/raid members in their tank specialization even if they have not been assigned a tanking role. ',
                get = function() return self.config.includeSpecTanks end,
                set = function(info, value) self.config.includeSpecTanks = value end,
                width = 2,
                order = 10,
            },
            autoAddTanks = {
                type = 'toggle',
                name = 'Auto Add tanks',
                desc = ('Auto add units from the selected sources.'),
                get = function() return self.config.autoAddTanks end,
                set = function(info, value)
                    self.config.autoAddTanks = value
                    if not self.config.autoAddTanks then
                        self.config.purgeAutoAdds = false
                    end
                end,
                order = 11,
            },
            includePlayerAsTank = {
                type = 'toggle',
                name = 'Add you as tank when solo',
                desc = 'Includes you as a tank when your playing solo for self buffing even if your another role.',
                width = 1.5,
                get = function() return self.config.includePlayerAsTank end,
                set = function(info, value) 
                        self.config.includePlayerAsTank = value 
                        addon:updateRoster()
                    end,
                order = 12,
            },
            numberOfTanks = {
                type = 'range',
            	min = 1, max = 4, step = 1,
                name = 'How many tanks to display',
                desc = ('The maximum number of tanks that the addon will display'),
                get = function() return self.config.numberOfTanks end,
                set = function(info, value)
                    self.config.numberOfTanks = value
                end,
                order = 13,
                width = 'full',
            },
            includePlayerAsDamager = {
                type = 'toggle',
                name = 'Add you as DPS when solo',
                desc = 'Includes you as a DPS when your playing solo even if your in a healer or tanking spec.',
                width = 1.5,
                get = function() return self.config.includePlayerAsDamager end,
                set = function(info, value) self.config.includePlayerAsDamager = value end,
                order = 14,
            },
            autofillDPS = {
                type = 'toggle',
                name = 'Auto fill best DPS',
                desc = 'Includes DPS based on spec, class and your priority named players',
                width = 1.5,
                get = function() return self.config.autofillDPS end,
                set = function(info, value) self.config.autofillDPS = value end,
                order = 14.5,
            },
            numberOfnumberOfDamagers = {
                type = 'range',
            	min = 1, max = 12, step = 1,
                name = 'How many DPS to display',
                desc = ('The maximum number of DPS that the addon will display'),
                get = function() return self.config.numberOfDamagers end,
                set = function(info, value)
                    self.config.numberOfDamagers = value
                end,
                order = 15,
                width = 'full',
            },
            space = {
                name = " ",
                type = "description",
                order = 17,
                width = "full",
            },
            h2 = {
                type = 'header',
                name = 'Choose spells to cast',
                order = 40,
            },
            spaceSettingsA2 = {
                order = 40.5,
                name = " ",
                type = "description",
                width = "full",
            },
            allowModifierNone = {
                name = "Allow no modifiers",
                type = "toggle",
                order = 41,
                desc = "Allow clicks with no modifiers",
                get = function(info) return self.config.allowModifierNone end,
                set = function(_, value) 
                    if not value then
                        if not addon.dbNew.profile.config.allowModifierAlt and not addon.dbNew.profile.config.allowModifierShift then 
                            -- if the other two choices are off then stop all of them being off and set the first option to on
                            addon.dbNew.profile.config.allowModifierShift = true 
                        end
                    end 
                    self.config.allowModifierNone = value 
                end,
            },
            allowModifierShift = {
                name = "Allow SHIFT modifiers",
                type = "toggle",
                order = 42,
                desc = "Allow clicks with no modifiers",
                get = function(info) return addon.dbNew.profile.config.allowModifierShift end,
                set = function(_, value) 
                    if not value then
                        if not addon.dbNew.profile.config.allowModifierNone and not addon.dbNew.profile.config.allowModifierAlt then 
                            -- if the other two choices are off then stop all of them being off and set the first option to on
                            addon.dbNew.profile.config.allowModifierNone = true 
                        end
                    end 
                    addon.dbNew.profile.config.allowModifierShift = value 
                end,
            },
            allowModifierAlt = {
                name = "Allow ALT modifiers",
                type = "toggle",
                order = 43,
                desc = "Allow clicks with no modifiers",
                get = function(info) return addon.dbNew.profile.config.allowModifierAlt end,
                set = function(_, value)
                    if not value then
                        if not addon.dbNew.profile.config.allowModifierNone and not addon.dbNew.profile.config.allowModifierShift then 
                            -- if the other two choices are off then stop all of them being off and set the first option to on
                            addon.dbNew.profile.config.allowModifierNone = true 
                        end
                    end 
                    addon.dbNew.profile.config.allowModifierAlt = value 
                end,
            },
            tankClickSpell = {
                name = "Cast on tank (Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 45,
                desc = "Cast on tank when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierNone end,
                get = function(info) return addon.dbNew.profile.config.tankClickSpell end,
                set = function( _, value) 
                    addon.dbNew.profile.config.tankClickSpell = value
                    UpdateBuffListfromOptions()
                end,
            },
            tankClickSpellShift = {
                name = "Cast on tank (Shift-Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 46,
                desc = "Cast on tank when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierShift end,
                get = function(info) return addon.dbNew.profile.config.tankClickSpellShift end,
                set = function(_, value)
                     addon.dbNew.profile.config.tankClickSpellShift = value 
                     UpdateBuffListfromOptions()
                    end,
            },
            tankClickSpellAlt = {
                name = "Cast on tank (Alt-Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 47,
                desc = "Cast on tank when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierAlt end,
                get = function(info) return addon.dbNew.profile.config.tankClickSpellAlt end,
                set = function(_, value) 
                    addon.dbNew.profile.config.tankClickSpellAlt = value 
                    UpdateBuffListfromOptions()
                end,
            },
            damagerClickSpell = {
                name = "Cast on others (Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 51,
                desc = "Cast on damager when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierNone end,
                get = function(info) return self.config.damagerClickSpell end,
                set = function(_, value) 
                    self.config.damagerClickSpell = value 
                    UpdateBuffListfromOptions()
                end,
            },
            damagerClickSpellShift = {
                name = "Cast on others (Shift-Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 52,
                desc = "Cast on damager when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierShift end,
                get = function(info) return addon.dbNew.profile.config.damagerClickSpellShift end,
                set = function(_, value) 
                    addon.dbNew.profile.config.damagerClickSpellShift = value 
                    UpdateBuffListfromOptions()
                end,
            },
            damagerClickSpelllAlt = {
                name = "Cast on others (Alt-Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 53,
                desc = "Cast on damager when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierAlt end,
                get = function(info) return addon.dbNew.profile.config.damagerClickSpellAlt end,
                set = function(_, value) 
                    addon.dbNew.profile.config.damagerClickSpellAlt = value 
                    UpdateBuffListfromOptions()
                end,
            },
            myClickSpell = {
                name = "Cast on myself (Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 55,
                desc = "Cast on myself when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierNone end,
                get = function(info) return self.config.myClickSpell end,
                set = function(_, value) 
                    self.config.myClickSpell = value 
                    UpdateBuffListfromOptions()
                end,
            },
            myClickSpellShift = {
                name = "Cast on myself (Shift-Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 56,
                desc = "Cast on myself when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierShift end,
                get = function(info) return addon.dbNew.profile.config.myClickSpellShift end,
                set = function(_, value) 
                    addon.dbNew.profile.config.myClickSpellShift = value 
                    UpdateBuffListfromOptions()
                end,
            },
            myClickSpelllAlt = {
                name = "Cast on myself (Alt-Click)",
                type = "select",
                values = self.dbNew.profile.spells,
                order = 57,
                desc = "Cast on myself when clicked",
                disabled = function() return not addon.dbNew.profile.config.allowModifierAlt end,
                get = function(info) return addon.dbNew.profile.config.myClickSpelllAlt end,
                set = function(_, value) 
                    addon.dbNew.profile.config.myClickSpelllAlt = value 
                    UpdateBuffListfromOptions()
                end,
            },
        }
    }

    self.options.args.bars.args.foundation = {
        name = "Header and buttons",
        order = 4,
        type = "group",
        args = {
            h1 = {
                type = 'header',
                name = 'Header bar',
                order = 10,
            },
            autoHideHeader = {
                type = 'toggle',
                name = 'Hide header bar',
                desc = 'Hides the header bar until you hover your mouse over it.',
                width = '1',
                get = function() return self.config.autoHideHeader end,
                set = function(info, value)
                    self.config.autoHideHeader = value
                    self:updateConfig()
                end,
                order = 11,
            },
            headerUnlocked = {
                type = 'toggle',
                name = 'Unlock header',
                desc = 'Allows the header bar to be moved by dragging it with the mouse.  Uncheck to lock it in place.',
                width = '2',
                get = function() return self.config.headerUnlocked end,
                set = function(info, value) self.config.headerUnlocked = value end,
                order = 12,
            },
            hideAddonName = {
                type = 'toggle',
                name = 'Hide addon name',
                desc = ('Removes the text %q from the header bar.'):format(MyAddOnName),
                width = '2',
                get = function() return self.config.hideAddonName end,
                set = function(info, value)
                    self.config.hideAddonName = value
                    if value then
                        self.headerFrame.text:Hide()
                    else
                        self.headerFrame.text:Show()
                    end
                end,
                order = 13,
            },
            headerTexture = {
                type = 'select',
                name = 'Header texture',
                desc = 'Texture used to paint the header bar.  If this control is greyed out please installed SharedMedia.',
                dialogControl = 'LSM30_Statusbar',
                values = AceGUIWidgetLSMlists.statusbar,
                get = function() return util.keyFromValue(AceGUIWidgetLSMlists.statusbar, self.config.headerTexture) end,
                set = function(info, key)
                    self.config.headerTexture = AceGUIWidgetLSMlists.statusbar[key]
                    self:updateConfig()
                end,
                order = 15,
            },
            headerColor = {
                type = 'color',
                name = 'Header color',
                desc = 'Changes the color of the header bar.',
                hasAlpha = true,
                get = function() return unpack(self.config.headerColor) end,
                set = function(info, r,g,b,a)
                    self.config.headerColor = {r,g,b,a}
                    self:updateConfig()
                end,
                width = 1,
                order = 16,
            },
            headerHeight = {
                type = 'range',
                name = 'Header height',
                desc = 'Height of the header bar (a positive value)',
                min = 10, max = 50, step = 1,
                get = function() return self.config.headerHeight end,
                set = function(info, value)
                    self.config.headerHeight = value
                    self:updateConfig()
                end,
                width = 1,
                order = 17,
            },

            addhealthbar = {
                type = 'toggle',
                name = 'Add your health bar',
                desc = 'Adds your healthbar above the header bar"',

                get = function() return self.config.addhealthbar end,
                set = function(info, value)
                    self.config.addhealthbar = value
                    if value then
                        self.config.healthbaroffset = self.config.buttonHeight
                    else
                        self.config.healthbaroffset = 0
                    end
                    addon:showHealthBar("health")
                end,
                width = 1,
                order = 20,
            },
            displaybartext = {
                type = 'toggle',
                name = 'Display bar health percentage',
                desc = 'Display health details on your health bar',

                get = function() return self.config.displaybartext end,
                set = function(info, value)
                    self.config.displaybartext = value
                    addon:UpdateHealth()
                end,
                disabled = function() return not self.config.addhealthbar end,
                width = 1.5,
                order = 22,
            },

            displayraidicon = {
                type = 'toggle',
                name = 'Display raid icons',
                desc = 'Display any raid or tartget icons in the buttons',
                get = function() return self.config.displayraidicon end,
                set = function(info, value)
                    self.config.displayraidicon = value
                end,
                width = 1,
                order = 24,
            },
            raidiconpos = {
                type = 'select',
                name = 'Icon Position',
                desc = 'Display any raid or tartget icons in the buttons',
                values = function()  return self.config.raidiconanchor end,
                disabled = function() return not self.config.displayraidicon end,
                get = function() return self.config.raidiconpos end,
                set = function(info, value)
                    self.config.raidiconpos = value
                    addon:formatRaidIcon()
                end,
                width = 0.75,
                order = 25,
            },
            spaceSettingsRI = {
                order = 25.5,
                name = " ",
                type = "description",
                width = 0.25,
            },
            raidiconsize = {
                type = 'range',
                name = 'Scale raid icons',
                desc = 'Make the size of the raid target icon a percentage of the button height',
                min = .25, max = 1, step = 0.05,
                disabled = function() return not self.config.displayraidicon end,
                get = function() return self.config.raidiconsize end,
                set = function(info, value)
                    self.config.raidiconsize = value
                    addon:formatRaidIcon()
                end,
                width = 1,
                order = 26,
            },

            spaceSettingsA = {
                order = 27,
                name = " ",
                type = "description",
                width = "full",
            },

            h2 = {
                type = 'header',
                name = 'Format the buttons for each player',
                order = 30,
            },
            spaceSettings3A = {
                order = 31,
                name = " ",
                type = "description",
                width = "full",
            },
            -- description1B = {
            --     order = 32,
            --     name = "The primary display consists of the augmentAssist bar with tanks displayed above and DPS below or visa-versa.  Below you can spcify details on the buttons for each player",
            --     type = "description",
            --     width = "full",
            -- },
            spaceSettings1C = {
                order = 33,
                name = " ",
                type = "description",
                width = "full",
            },
            -- spacingOffset = {  -- only needed when two columns of buttons are implemented
            --     type = 'input',
            --     name = 'Horizontal spacing',
            --     desc = 'Horizontal spacing between assist buttons',
            --     pattern = '%d',
            --     width = '1',
            --     get = function() return tostring(self.config.spacingOffset) end,
            --     set = function(info, value)
            --         self.config.spacingOffset = tonumber(value)
            --         self:updateConfig()
            --     end,
            --     order = 34,
            -- },
            verticalOffset = {
                type = 'range',
                name = 'Vertical spacing',
                desc = 'Vertical spacing between buttons and the header bar.',
                min = 0, max = 10, step = 1,
                width = 1.5,
                get = function() return self.config.tankButtonAnchor[3] end,
                set = function(info, value)
                    self.config.tankButtonAnchor[3] = value
                    self:updateConfig()
                end,
                order = 35,
            },
            buttonHeight = {
                type = 'range',
                name = 'Button height',
                desc = 'Height of the assist buttons (a positive value)',
            	min = 10, max = 40, step = 1,
                width = 1.5,
                get = function() return self.config.buttonHeight end,
                set = function(info, value)
                    self.config.buttonHeight = value
                    self:updateConfig()
                end,
                order = 37,
            },
            buttonWidth = {
                type = 'range',
                name = 'Button width',
                desc = 'Width of the assist buttons (a positive value)',
            	min = 50, max = 300, step = 5,
                width = 1.5,
                get = function() return self.config.buttonWidth end,
                set = function(info, value)
                    self.config.buttonWidth = value
                    self:updateConfig()
                end,
                order = 38,
            },
            buttonTexture = {
                type = 'select',
                name = 'Button texture (All buttons)',
                desc = 'Texture used to paint the assist buttons.  If this control is greyed out please installed SharedMedia.',
                width = '2',
                dialogControl = 'LSM30_Statusbar',
                values = AceGUIWidgetLSMlists.statusbar,
                get = function() return util.keyFromValue(AceGUIWidgetLSMlists.statusbar, self.config.buttonTexture) end,
                set = function(info, key)
                    self.config.buttonTexture = AceGUIWidgetLSMlists.statusbar[key]
                    self:updateConfig()
                end,
                order = 39,
            },
            colorFriendlyButtonsByClass = {
                type = 'toggle',
                name = 'Colour players by class',
                desc = "Colours the assist buttons tracking friendly targets based on the character's class.",
                get = function() return self.config.colorFriendlyButtonsByClass end,
                set = function(info, value)
                    self.config.colorFriendlyButtonsByClass = value
                    self:updateConfig()
                end,
                width = '3',
                order = 40,
            },
            tankButtonColor = {
                type = 'color',
                name = 'Tank button',
                desc = 'Changes the colour of the tanks buttons if not using class colours.',
                hasAlpha = true,
                get = function() return unpack(self.config.tankButtonColor) end,
                set = function(info, r,g,b,a)
                    self.config.tankButtonColor = {r,g,b,a}
                    self:updateConfig()
                end,
                width = 0.65,
                disabled = function() return self.config.colorFriendlyButtonsByClass end,
                order = 41,
            },
            damagerButtonColor = {
                type = 'color',
                name = 'DPS button',
                desc = 'Changes the colour of the DPS buttons if not using class colours.',
                hasAlpha = true,
                get = function() return unpack(self.config.damagerButtonColor) end,
                set = function(info, r,g,b,a)
                    self.config.damagerButtonColor = {r,g,b,a}
                    self:updateConfig()
                end,
                width = 0.65,
                disabled = function() return self.config.colorFriendlyButtonsByClass end,
                order = 42,
            },
            missingColor = {
                type = 'color',
                name = 'Dead',
                desc = 'Colour for buttons when the associated unit is dead or missing.',
                hasAlpha = true,
                width = 0.65,
                get = function() return unpack(self.config.missingColor) end,
                set = function(info, r,g,b,a)
                    self.config.missingColor = {r,g,b,a}
                    self:updateConfig()
                end,
                order = 43,
            },
            fadeOutOfRange = {
                type = 'toggle',
                name = 'Fade out of range units',
                desc = 'Fades unit buttons for targets that are out of range.  Friendly units are faded based on the range of typical heals.  Hostile targets are faded based on class-specific spell/ability checks.',
                get = function() return self.config.fadeOutOfRange end,
                set = function(info, value)
                	self.config.fadeOutOfRange = value
                	if self.config.fadeOutOfRange then
                  		self.friendOutOfRangeChecker = self.LibRange:GetFriendMinChecker(self.config.friendRange)
                	end
                end,
                disabled = not (addon.LibRange),
                width = 'full',
                order = 44,
            },
            friendRange = {
            	type = 'range',
            	name = 'Range to fade',
            	desc = 'Further than y (numeric) yards will be considered out of range',
            	min = 5, max = 50, step = 1,
                width = 1.5,
            	get = function() return self.config.friendRange end,
            	set = function(info, value)
            		local val,range = value
            		self.friendOutOfRangeChecker,range = self.LibRange:GetFriendMinChecker(val)
            		self.config.friendRange = range and range or val
            	end,
            	disabled = function() return not self.config.fadeOutOfRange end,
            	order = 45,
            },
            outOfRangeAlphaOffset = {
            	type = 'range',
            	name = 'Fade out alpha offset',
            	desc = 'The amount of alpha to reduce when the target is out of range. Bigger values affect visibility more.',
            	min = 0.1, max = 0.9, step = 0.1,
                width = 1.5,
            	get = function() return self.config.outOfRangeAlphaOffset end,
            	set = function(info, value) self.config.outOfRangeAlphaOffset = value end,
            	disabled = function() return not self.config.fadeOutOfRange end,
            	order = 46,
            },

        }
    }

    self.options.args.bars.args.iconsAndSpells = {
        order = 5,
        name = "Icons",
        type = "group",
        args = {
            h1 = {
                type = 'header',
                name = 'Format the buff and aura icons when they appear',
                order = 5,
            },
            numberOfBuffIcons = {
            	type = 'range',
            	name = 'Number of Buffs',
            	desc = 'How many of your spell buffs to display on a button',
            	min = 01, max = 4, step = 1,
                width = 1.5,
            	get = function() return self.config.numberOfBuffIcons end,
            	set = function(info, value) 
                    self.config.numberOfBuffIcons = value 
                    self:updateConfig()
                end,
                order = 6,
            },
            numberOfAuraIcons = {
            	type = 'range',
            	name = 'Number of cooldowns',
            	desc = 'How many of your selected players big cooldowns will be displayed.',
            	min = 1, max = 4, step = 1,
                width = 1.5,
            	get = function() return self.config.numberOfAuraIcons end,
            	set = function(info, value) 
                    self.config.numberOfAuraIcons = value 
                    self:updateConfig()
                end,
                order = 7,
            },
            iconSize = {
            	type = 'range',
            	name = 'Change the buff size',
            	desc = 'The amount of buff size is changes when its displayed..',
            	min = 0.5, max = 2, step = 0.1,
                width = 1.5,
            	get = function() return self.config.iconSize end,
            	set = function(info, value) 
                    self.config.iconSize = value 
                    self:updateIcons()
                end,
                order = 11,
            },
            iconBorders = {
                type = 'toggle',
                name = 'Remove borders',
                desc = "Remove the border from the buffs when they are displayed",
                get = function() return self.config.iconBorders end,
                set = function(info, value) 
                    self.config.iconBorders = value 
                    self:updateIcons()
                end,
                width = 0.75,
                order = 12,
            },
            -- showTooltip = {
            --     order = 13,
            --     name = "Show Tooltip",
            --     type = "toggle",
            --     width = 0.75,
            --     desc = "Toggle showing of the tooltip when hovering over an icon.",
            -- },
            iconYOfftank = {
                order = 15,
                name = "Y-Offset top group",
                type = "range",
                width = 1.5,
                desc = "Change the icon group's Y-Offset (-down +up) from the button.",
                min = -50,
                max = 50,
                step = 1,
                get = function() return self.config.iconYOfftank end,
                set = function(info, value) 
                    self.config.iconYOfftank = value 
                    self:updateIcons()
                end,
            },
            iconYOffdps = {
                order = 15,
                name = "Y-Offset bottom group",
                type = "range",
                width = 1.5,
                desc = "Change the icon group's Y-Offset (-down +up) from the button.",
                min = -50,
                max = 50,
                step = 1,
                get = function() return self.config.iconYOffdps end,
                set = function(info, value) 
                    self.config.iconYOffdps = value 
                    self:updateIcons()
                end,
            },
            iconXOff = {
                order = 20,
                name = "X-Offset",
                type = "range",
                width = 1.5,
                desc = "Change the icon group's X-Offset from the button.  e.g. how far from the button do the icons start",
                min = -25,
                max = 25,
                step = 1,
                get = function() return self.config.iconXOff end,
                set = function(info, value) 
                    self.config.iconXOff = value 
                    self:updateIcons()
                end,
            },

            -- iconAlpha = {
            --     order = 22,
            --     name = "Icon Alpha",
            --     type = "range",
            --     width = 1.5,
            --     desc = "Icon transparency.",
            --     min = 0,
            --     max = 1,
            --     step = 0.01,
            -- },
            iconSpacing = {
                order = 25,
                name = "Icon Spacing",
                type = "range",
                width = 1.5,
                desc = "Spacing between icons. Spacing is scaled based on icon size for uniformity across different icon sizes.",
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.config.iconSpacing end,
                set = function(info, value) 
                    self.config.iconSpacing = value 
                    self:updateIcons()
                end,
            },
            iconfontHeight = {
                order = 28,
                name = "Cooldown Text Font Size",
                type = "range",
                width = 1.5,
                desc = "Scale the icon's cooldown text size.",
                min = 8,
                max = 18,
                step = 1,
                get = function() return self.config.iconfontHeight end,
                set = function(info, value) 
                    self.config.iconfontHeight = value 
                    self:updateIcons()
                end,
            },
            cooldowntrigger = {
                order = 28,
                name = "Show cooldown text when X secodns to go",
                type = "range",
                width = 1.5,
                desc = "Dont show the cooldown time until there are the specified number of seconds to go",
                min = 10,
                max = 90,
                step = 1,
                get = function() return self.config.cooldowntrigger end,
                set = function(info, value) 
                    self.config.cooldowntrigger = value 
                end,
            },
            spaceSettingsA1 = {
                order = 28.5,
                name = " ",
                type = "description",
                width = "full",
            },
            -- h2 = {
            --     type = 'header',
            --     name = 'Choose spells to cast',
            --     order = 40,
            -- },
            -- spaceSettingsA2 = {
            --     order = 40.5,
            --     name = " ",
            --     type = "description",
            --     width = "full",
            -- },
            -- allowModifierNone = {
            --     name = "Allow no modifiers",
            --     type = "toggle",
            --     order = 41,
            --     desc = "Allow clicks with no modifiers",
            --     get = function(info) return self.config.allowModifierNone end,
            --     set = function(_, value) 
            --         if not value then
            --             if not addon.dbNew.profile.config.allowModifierAlt and not addon.dbNew.profile.config.allowModifierShift then 
            --                 -- if the other two choices are off then stop all of them being off and set the first option to on
            --                 addon.dbNew.profile.config.allowModifierShift = true 
            --             end
            --         end 
            --         self.config.allowModifierNone = value 
            --     end,
            -- },
            -- allowModifierShift = {
            --     name = "Allow SHIFT modifiers",
            --     type = "toggle",
            --     order = 42,
            --     desc = "Allow clicks with no modifiers",
            --     get = function(info) return addon.dbNew.profile.config.allowModifierShift end,
            --     set = function(_, value) 
            --         if not value then
            --             if not addon.dbNew.profile.config.allowModifierNone and not addon.dbNew.profile.config.allowModifierAlt then 
            --                 -- if the other two choices are off then stop all of them being off and set the first option to on
            --                 addon.dbNew.profile.config.allowModifierNone = true 
            --             end
            --         end 
            --         addon.dbNew.profile.config.allowModifierShift = value 
            --     end,
            -- },
            -- allowModifierAlt = {
            --     name = "Allow ALT modifiers",
            --     type = "toggle",
            --     order = 43,
            --     desc = "Allow clicks with no modifiers",
            --     get = function(info) return addon.dbNew.profile.config.allowModifierAlt end,
            --     set = function(_, value)
            --         if not value then
            --             if not addon.dbNew.profile.config.allowModifierNone and not addon.dbNew.profile.config.allowModifierShift then 
            --                 -- if the other two choices are off then stop all of them being off and set the first option to on
            --                 addon.dbNew.profile.config.allowModifierNone = true 
            --             end
            --         end 
            --         addon.dbNew.profile.config.allowModifierAlt = value 
            --     end,
            -- },
            -- tankClickSpell = {
            --     name = "Cast on tank (Click)",
            --     type = "select",
            --     values = self.dbNew.profile.spells,
            --     order = 45,
            --     desc = "Cast on tank when clicked",
            --     disabled = function() return not addon.dbNew.profile.config.allowModifierNone end,
            --     get = function(info) return addon.dbNew.profile.config.tankClickSpell end,
            --     set = function( _, value) 
            --         addon.dbNew.profile.config.tankClickSpell = value
            --         UpdateBuffListfromOptions()
            --     end,
            -- },
            -- tankClickSpellShift = {
            --     name = "Cast on tank (Shift-Click)",
            --     type = "select",
            --     values = self.dbNew.profile.spells,
            --     order = 46,
            --     desc = "Cast on tank when clicked",
            --     disabled = function() return not addon.dbNew.profile.config.allowModifierShift end,
            --     get = function(info) return addon.dbNew.profile.config.tankClickSpellShift end,
            --     set = function(_, value)
            --          addon.dbNew.profile.config.tankClickSpellShift = value 
            --          UpdateBuffListfromOptions()
            --         end,
            -- },
            -- tankClickSpellAlt = {
            --     name = "Cast on tank (Alt-Click)",
            --     type = "select",
            --     values = self.dbNew.profile.spells,
            --     order = 47,
            --     desc = "Cast on tank when clicked",
            --     disabled = function() return not addon.dbNew.profile.config.allowModifierAlt end,
            --     get = function(info) return addon.dbNew.profile.config.tankClickSpellAlt end,
            --     set = function(_, value) 
            --         addon.dbNew.profile.config.tankClickSpellAlt = value 
            --         UpdateBuffListfromOptions()
            --     end,
            -- },
            -- damagerClickSpell = {
            --     name = "Cast on others (Click)",
            --     type = "select",
            --     values = self.dbNew.profile.spells,
            --     order = 51,
            --     desc = "Cast on damager when clicked",
            --     disabled = function() return not addon.dbNew.profile.config.allowModifierNone end,
            --     get = function(info) return self.config.damagerClickSpell end,
            --     set = function(_, value) 
            --         self.config.damagerClickSpell = value 
            --         UpdateBuffListfromOptions()
            --     end,
            -- },
            -- damagerClickSpellShift = {
            --     name = "Cast on others (Shift-Click)",
            --     type = "select",
            --     values = self.dbNew.profile.spells,
            --     order = 52,
            --     desc = "Cast on damager when clicked",
            --     disabled = function() return not addon.dbNew.profile.config.allowModifierShift end,
            --     get = function(info) return addon.dbNew.profile.config.damagerClickSpellShift end,
            --     set = function(_, value) 
            --         addon.dbNew.profile.config.damagerClickSpellShift = value 
            --         UpdateBuffListfromOptions()
            --     end,
            -- },
            -- damagerClickSpelllAlt = {
            --     name = "Cast on others (Alt-Click)",
            --     type = "select",
            --     values = self.dbNew.profile.spells,
            --     order = 53,
            --     desc = "Cast on tank when clicked",
            --     disabled = function() return not addon.dbNew.profile.config.allowModifierAlt end,
            --     get = function(info) return addon.dbNew.profile.config.damagerClickSpellAlt end,
            --     set = function(_, value) 
            --         addon.dbNew.profile.config.damagerClickSpellAlt = value 
            --         UpdateBuffListfromOptions()
            --     end,
            -- },
        }
    }

    self.options.args.bars.args.auras = {
        order = 6,
        name = "Auras",  -- SPELLS,
        type = "group",
        args = {
            disableAll = {
                order = 2,
                name = "Disable All",
                type = "execute",
                width = 0.7,
                desc = "Disable all spells.",
                func = function()
                    local dialogIsOpen = AceConfigDialog.OpenFrames["augmentAssistDialog"]

                    if dialogIsOpen then
                        self:CreatePriorityDialog()
                    end

                    for k in pairs(self.dbNew.profile.buffs) do
                        self.dbNew.profile.buffs[k].state.enabled = false

                        if dialogIsOpen then
                            addon.priorityListDialog.args[tostring(k)] = nil
                        end
                    end

                    if dialogIsOpen then
                        AceRegistry:NotifyChange("augmentAssistDialog")
                    end

                    -- self:RefreshOverlays()
                end,
            },
            recommended = {
                order = 2,
                name = "Recommend",
                type = "execute",
                width = 0.70,
                desc = "Selected those recommended by the addon then update as required.",
                func = function()
                    local dialogIsOpen = AceConfigDialog.OpenFrames["augmentAssistDialog"]

                    if dialogIsOpen then
                        self:CreatePriorityDialog()
                    end

                    for k in pairs(self.dbNew.profile.buffs) do

                        if self.dbNew.profile.buffs[k].recommended then
                            self.dbNew.profile.buffs[k].state.enabled = true
                        else
                            self.dbNew.profile.buffs[k].state.enabled = false
                        end
                        if dialogIsOpen then
                            addon.priorityListDialog.args[tostring(k)] = nil
                        end
                    end

                    if dialogIsOpen then
                        AceRegistry:NotifyChange("augmentAssistDialog")
                    end

                    -- self:RefreshOverlays()
                end,
            },
            fullPriorityList = {
                order = 2,
                name = "Aura List",
                type = "execute",
                width = 0.7,
                desc = "Shows a list of all enabled auras for this bar in order of priority.",
                func = function()
                    local dialog = AceConfigDialog.OpenFrames["augmentAssistDialog"]
                    if dialog  then
                        AceConfigDialog:Close("augmentAssistDialog")
                    else
                        self:CreatePriorityDialog()
                        AceConfigDialog:Open("augmentAssistDialog")
                        dialog = AceConfigDialog.OpenFrames["augmentAssistDialog"]
                        dialog:EnableResize(false)
                        local baseDialog = AceConfigDialog.OpenFrames[MyAddOnName]
                        local width = (baseDialog and baseDialog.frame.width) or (InterfaceOptionsFrame and InterfaceOptionsFrame:GetWidth()) or 900

                        if not dialog.frame:IsUserPlaced() then
                            dialog.frame:ClearAllPoints()
                            dialog.frame:SetPoint("LEFT", UIParent, "CENTER", width / 2, 0)
                        end

                        if not dialog.frame.hooked then
                            -- Avoid the dialog being moved unless the user drags it
                            hooksecurefunc(dialog.frame, "SetPoint", function(widget, point, relativeTo, relativePoint, x, y)
                                if widget:IsUserPlaced() then return end

                                local appName = widget.obj.userdata.appName
                                if (appName and appName == "augmentAssistDialog")
                                and (point ~= "LEFT"
                                    or relativeTo ~= UIParent
                                    or relativePoint ~= "CENTER"
                                    or x ~= width / 2
                                    or y ~= 0)
                                then
                                    widget:ClearAllPoints()
                                    widget:SetPoint("LEFT", UIParent, "CENTER", width / 2, 0)
                                end
                            end)
                            dialog.frame.hooked = true
                        end
                    end
                end,
            },
            space4 = {
                order = 4,
                name = " ",
                type = "description",
                width = "full",
            },
            space5 = {
                order = 4.5,
                name = " ",
                type = "description",
                width = 1.3,
            },
            tableHeader = {
                order = 5,
                name = "Spell name",
                type = "description",
                width = .9,
            },
            tableHeader2 = {
                order = 5.5,
                name = "Edit",
                type = "description",
                width = 0.15,
            },
            -- tableHeader3 = {
            --     order = 5.6,
            --     name = "Priority",
            --     type = "description",
            --     width = 0.3,
            -- },
            tableHeader4 = {
                order = 5.7,
                name = "Recommend",
                type = "description",
                width = 0.4,
            },
        },
    }
    self:updateAuraOptionTab()

    self.options.args.bars.args.autoFill = {
        name = "Autofill",  -- PRiority class specs
        type = "group",
        order = 6,
        args = {
            helpDesc = {
                name =  "Below are a list of classes and specifications that will be used autifill DPS slots if available after including "..
                        "any priority players in your group or raid.  We recommend picking 3-4 of the specs that will get the most imapct "..
                        "from your buffs.  Look for those that get the best DPS from a combination of their cooldowns and your buffs",
                type = "description",
                order = 1,
            },
            spaceSettingsA = {
                order = 1.2,
                name = " ",
                type = "description",
                width = "full",
            },
        },
    }
    self:updateAutofillOptionTab()

    self.options.args.bars.args.priority = {
        order = 6,
        name = "Priority",  -- pririty players,
        type = "group",
        args = {
            spaceSettingsA = {
                order = 0.2,
                name = " ",
                type = "description",
                width = "full",
            },
            desc = {
                name = "This informational panel is updated when you right click on a player button in the addon and select to add them to your piority list.  These players will then be auto-populated into the button list if they are in your group and you have selected to autifill DPS slots",
                type = "description",
                order = 0,
            },
            spaceSettingsB = {
                order = 0.2,
                name = " ",
                type = "description",
                width = "full",
            },
            addGroup = {
                order = 0.3,
                name = "Add Group*",
                type = "execute",
                width = 0.7,
                desc = "* NOT IMPLEMENTTED* Add group to the priority player list  ",
                func = function() 
                end,

            },
            deleteAll = {
                order = 0.5,
                name = "Delete All",
                type = "execute",
                width = 0.7,
                desc = "Delete all records in the priority players list",
                confirm = true,
                func = function() wipe(addon.dbNew.profile.priorityPlayers) end,
            },
            space4 = {
                order = 0.7,
                name = " ",
                type = "description",
                width = "full",
            },
        },
    }
    self:updatePriorityOptionTab()

end

-- Options-> Custom Spells-> This is all the details that appear in the Custom Spells table on the right for the custom spell selected 
local customSpellInfo = {
    spellId = {
        order = 1,
        type = "description",
        width = "full",
        name = function(info)
            local spellId = tonumber(info[#info - 1])
            local str = util.Colorize("Spell ID") .. " " .. spellId
            -- if addon.dbNew.profile.buffs[spellId].children then
            --     str = str .. "\n\n" .. util.Colorize("Child Spell ID(s)") .. "\n"
            --     for child in pairs(addon.dbNew.profile.buffs[spellId].children) do
            --         str = str .. child .. "\n"
            --     end
            -- end
            return str .. "\n\n"
        end,
    },
    delete = {
        order = 2,
        type = "execute",
        name = DELETE,
        width = 1,
        func = function(info)
            local spellId = tonumber(info[#info - 1])
            local spellName, _, icon = GetSpellInfo(spellId)
            if addon.customIcons[spellId] then
                icon = addon.customIcons[spellId]
            end
            local text = format("%s\n\n%s %s\n\n", "Are you sure you want to delete this spell?", addon:GetIconString(icon, 20), spellName)
            if addon.dbNew.profile.buffs[spellId] then          -- addon.defaultSpells[spellId] then
                text = text .. format("(%s: This is a default spell. Deleting it from this tab will simply reset all of its values to their defaults, but it will not be removed from the spells tab.)", util.Colorize(LABEL_NOTE, "accent"))
            end
            deleteSpellDelegate.text = text

            LibDialog:Spawn(deleteSpellDelegate, info[#info - 1])
        end,
    },
    header1 = {
        order = 3,
        name = "",
        type = "header",
    },
    class = {
        order = 4,
        type = "select",
        name = CLASS,
        values = function()
            local classes = {}
            -- Use "_MISC" to put Miscellaneous at the end of the list since Ace sorts the dropdown by key. (Hacky, but it works)
            -- _MISC gets converted in the setters/getters, so it won't affect other structures.
            classes["_MISC"] = format("%s %s", addon:GetIconString(addon.customIcons["Cogwheel"], 15), util.Colorize(MISCELLANEOUS, "MISC"))
            for i = 1, MAX_CLASSES do
                local className = CLASS_SORT_ORDER[i]
                classes[className] = format("%s %s", addon:GetIconString(classIcons[className], 15), util.Colorize(LOCALIZED_CLASS_NAMES_MALE[className], className))
            end
            return classes
        end,
        get = function(info)
            local spellId = tonumber(info[#info - 1])
            local class = addon.dbNew.profile.buffs[spellId].class
            if class == "MISC" then
                class = "_MISC"
            end
            return class
        end,
        set = function(info, state)
            local option = info[#info]
            local spellId = info[#info - 1]
            spellId = tonumber(spellId)
            if state == "_MISC" then
                state = "MISC"
            end
            addon.dbNew.profile.buffs[spellId].class = state

            -- addon.dbNew.global.customBuffs[spellId][option] = state
            -- addon.dbNew.profile.buffs[spellId][option] = state
            -- if addon.dbNew.profile.buffs[spellId].children then
            --     addon.dbNew.profile.buffs[spellId]:UpdateChildren()
            -- end
            local spell = addon.priorityListDialog.args[info[#info - 1]]
            if spell and AceConfigDialog.OpenFrames["augmentAssistDialog"] then
                addon.AddToPriorityDialog(info[#info - 1])
                AceRegistry:NotifyChange("augmentAssistDialog")
            end
            addon:updateAuraOptionTab()
        end,
    },
    space = {
        order = 5,
        name = "\n",
        type = "description",
        width = "full",
    },
    prio = {
        order = 6,
        type = "input",
        name = "Priority (Lower is Higher Prio)",
        desc = "The priority of this spell. Lower numbers are higher priority. If two spells have the same priority, it will show alphabetically.",
        validate = function(_, value)
            local num = tonumber(value)
            if num and num < 1000000 and value:match("^%d+$") then
                if addon.errorStatusText then
                    -- Clear error text on successful validation
                    local rootFrame = AceConfigDialog.OpenFrames["augmentAssist"]
                    if rootFrame and rootFrame.SetStatusText then
                        rootFrame:SetStatusText("")
                    end
                    addon.errorStatusText = nil
                end
                return true
            else
                addon.errorStatusText = true
                return "Priority must be a positive integer from 0 to 999999"
            end
        end,
        set = function(info, state)
            local option = info[#info]
            local spellId = info[#info - 1]
            local val = tonumber(state)
            spellId = tonumber(spellId)
            -- addon.dbNew.global.customBuffs[spellId][option] = val
            addon.dbNew.profile.buffs[spellId].prio = val
            if addon.dbNew.profile.buffs[spellId].children then
                addon.dbNew.profile.buffs[spellId]:UpdateChildren()
            end
            local spell = addon.priorityListDialog.args[info[#info - 1]]
            if spell and AceConfigDialog.OpenFrames["augmentAssistDialog"] then
                spell.name = string.gsub(spell.name, tostring(spell.order - 1) .. "]", state .. "]")
                spell.order = val + 1
                AceRegistry:NotifyChange("augmentAssistDialog")
            end
            -- addon:RefreshOverlays()
            addon:updateAuraOptionTab()
        end,
        get = function(info)
            local option = info[#info]
            local spellId = info[#info - 1]
            spellId = tonumber(spellId)
            return tostring(addon.dbNew.profile.buffs[spellId].prio)
        end,
    },
    space2 = {
        order = 7,
        name = " ",
        type = "description",
        width = 2,
    },
    currentIcon = {
        order = 7.5,
        name = "",
        type = "description",
        width = 0.33,
        image = function(info)
            local spellId = info[#info - 1]
            spellId = tonumber(spellId)
            local icon = addon.dbNew.profile.buffs[spellId].icon

            return icon
                or select(3, GetSpellInfo(spellId))
                or addon.customIcons[info[#info - 1]]
                or addon.customIcons["?"]
        end,
        imageCoords = { 0.08, 0.92, 0.08, 0.92 },
    },
    -- icon = {
    --     order = 8,
    --     name = "Custom Icon",
    --     type = "input",
    --     width = 0.66,
    --     desc = "The icon ID to use for this spell. This will overwrite the default icon.",
    --     get = function(info)
    --         local option = info[#info]
    --         local spellId = info[#info - 1]
    --         spellId = tonumber(spellId)
    --         local state = addon.dbNew.global.customBuffs[spellId][option]
    --         return state ~= nil and tostring(state) or ""
    --     end,
    --     set = function(info, state)
    --         local option = info[#info]
    --         local spellIdStr = info[#info - 1]
    --         local val = tonumber(state)
    --         local spellId = tonumber(spellIdStr)

    --         local name, _, icon = GetSpellInfo(spellId)

    --         if not (state:match("^%d+$") and val < 1000000000) then
    --             if state == "" then
    --                 addon.dbNew.global.customBuffs[spellId][option] = nil
    --                 addon.options.args.customSpells.args[spellIdStr].name = format("%s %s", addon:GetIconString(icon, 15), name)
    --             else
    --                 addon:Print(format("Invalid input for custom icon: %s", util.Colorize(state)))
    --             end
    --         else
    --             addon.dbNew.global.customBuffs[spellId][option] = val
    --             addon.options.args.customSpells.args[spellIdStr].name = format("%s %s", addon:GetIconString(val, 15), name)
    --         end

    --         addon:UpdateCustomBuffs()
    --     end,
    -- },
    -- space3 = {
    --     order = 9,
    --     name = " ",
    --     type = "description",
    --     width = 2,
    -- },
    -- addChild = {
    --     order = 10,
    --     type = "input",
    --     name = "Add Child Spell ID",
    --     desc = "Add a child spell ID to this spell. Child IDs will be checked like normal IDs but will use all the same settings (including icon) as its parent. Also, any changes to the parent will apply to all of its children. This is useful for spells that have multiple ids which are convenient to track as a single spell (e.g. different ranks of the same spell).",
    --     width = 1,
    --     validate = function(_, value)
    --         local num = tonumber(value)

    --         if (not value or value == "")
    --         or (num and num < 10000000 and value:match("^%d+$")) then
    --             if addon.errorStatusText then
    --                 -- Clear error text on successful validation
    --                 local rootFrame = AceConfigDialog.OpenFrames["augmentAssist"]
    --                 if rootFrame and rootFrame.SetStatusText then
    --                     rootFrame:SetStatusText("")
    --                 end
    --                 addon.errorStatusText = nil
    --             end
    --             return true
    --         else
    --             addon.errorStatusText = true
    --             return "Spell ID must be a positive integer from 0 to 9999999"
    --         end
    --     end,
    --     set = function(info, value)
    --         if not value or value == "" then return end

    --         local parentId = tonumber(info[#info - 1])
    --         local childId = tonumber(value)

    --         addon:InsertCustomChild(childId, parentId)
    --         addon:UpdateCustomBuffs()
    --     end,
    -- },
    -- space4 = {
    --     order = 11,
    --     name = " ",
    --     type = "description",
    --     width = 2,
    -- },
    -- removeChild = {
    --     order = 12,
    --     type = "select",
    --     name = "Remove Custom Child Spell ID",
    --     width = 1,
    --     values = function(info)
    --         local spellId = tonumber(info[#info - 1])
    --         local values = {}
    --         for id in pairs(addon.dbNew.global.customBuffs) do
    --             if addon.dbNew.global.customBuffs[id].parent == spellId
    --             and not (addon.defaultSpells[id] and addon.defaultSpells[id].parent == spellId) then
    --                 values[id] = id
    --             end
    --         end
    --         return values
    --     end,
    --     hidden = function(info)
    --         local spellId = tonumber(info[#info - 1])
    --         for id in pairs(addon.dbNew.global.customBuffs) do
    --             if addon.dbNew.global.customBuffs[id].parent == spellId
    --             and not (addon.defaultSpells[id] and addon.defaultSpells[id].parent == spellId) then
    --                 return false
    --             end
    --         end
    --         return true
    --     end,
    --     set = function(info, value)
    --         local parentId = tonumber(info[#info - 1])
    --         local childId = tonumber(value)

    --         addon:RemoveCustomChild(childId, parentId)
    --         addon:UpdateCustomBuffs()
    --     end,
    -- },
}
-- Options->Custom spells - This gets and starts the process for adding a custom spell - its the overall page
local customSpells = {
    spellId_info = {
        order = 1,
        type = "description",
        name = "Adding a new spell here will make it appear in the Auras list as a type CUSTOM.  It allows you to include missing call auras or special auras",
    },
    spellId = {
        order = 2,
        name = "Spell ID",
        desc = "Enter the spell ID of the spell you want to keep track of." .. "\n\n" .. "Keep in mind you want to add the Spell ID of the aura that appears on the buff/debuff bar, not necessarily the Spell ID from the spell book or talent tree.",
        type = "input",
        validate = function(_, value)
            local num = tonumber(value)
            if num and num < 10000000 and value:match("^%d+$") then
                if addon.errorStatusText then
                    -- Clear error text on successful validation
                    local rootFrame = AceConfigDialog.OpenFrames["augmentAssist"]
                    if rootFrame and rootFrame.SetStatusText then
                        rootFrame:SetStatusText("")
                    end
                    addon.errorStatusText = nil
                end
                return true
            else
                addon.errorStatusText = true
                return "Spell ID must be a positive integer from 0 to 9999999"
            end
        end,
    
        set = function(_, state)
            local spellId = tonumber(state)
            local spellIdStr = state
            local child = false
            local childId

            -- if addon.dbNew.profile.buffs[spellId] and addon.dbNew.profile.buffs[spellId].parent then
            --     child = true
            --     childId = spellId
            --     spellId = addon.dbNew.profile.buffs[spellId].parent
            --     spellIdStr = tostring(spellId)
            -- end

            local name, _, icon = GetSpellInfo(spellId)

            if addon.customIcons[spellId] then
                icon = addon.customIcons[spellId]
            end

            if name then
                if spellId and not addon.dbNew.profile.buffs[spellId] then 
                    local spellDetails = {      -- also currently defined in core.lua
                        recommended = false,
                        prio = 50,
                        class = "",
                        enabled = false,
                        source = "spell_db",
                        icon = 0,
                    }
                    addon.dbNew.profile.buffs[spellId] = CopyTable(spellDetails)
                    addon.dbNew.profile.buffs[spellId].recommended = false
                    addon.dbNew.profile.buffs[spellId].prio = 50
                    addon.dbNew.profile.buffs[spellId].enabled = false
                    addon.dbNew.profile.buffs[spellId].class = "_MISC"
                    addon.dbNew.profile.buffs[spellId].source = "custom"
                    addon.dbNew.profile.buffs[spellId].icon = icon

                    addon.options.args.customSpells.args[spellIdStr] = {
                        name = format("%s %s", addon:GetIconString(icon, 15), name),
                        desc = function()
                            return spellDescriptions[spellId] or ""
                        end,
                        type = "group",
                        args = customSpellInfo,
                    }
                    -- addon:UpdateCustomBuffs()

                    if AceConfigDialog.OpenFrames["augmentAssistDialog"] then
                        AddToPriorityDialog(spellIdStr)
                        AceRegistry:NotifyChange("augmentAssistDialog")
                    end
                else
                    addon:Print(format("%s %s is already being tracked.", addon:GetIconString(icon, 20), name))
                end
            else
                -- if child then
                --     util.Print(format("%s is already being tracked as a child of %s and cannot be edited.", util.Colorize(childId), util.Colorize(spellId)))
                -- else
                    util.Print(format("Invalid Spell ID %s", util.Colorize(spellId)))
                -- end
            end
        end,
    }
}

function addon:Options()

    --  Keep for missing spells e.g. new ones that are not in spell_db
    for spellId, v in pairs(self.dbNew.profile.buffs) do             -- self.dbNew.global.customBuffs) do
        if self.dbNew.profile.buffs[spellId].source == "custom" then

            local name, _, icon = GetSpellInfo(spellId)
            customSpells[tostring(spellId)] = {
                name = format("%s %s", self:GetIconString(v.icon or icon, 15), name),
                desc = function()
                    return spellDescriptions[spellId] or ""
                end,
                type = "group",
                args = customSpellInfo,
            }
        end
    end

    -- populate the tabs with stuff
    self.options = {
        name = MyAddOnName,
        type = "group",
        plugins = { profiles = { profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.dbNew) } },
        childGroups = "tab",
        args = {
            logo = {
                order = 1,
                type = "description",
                name = util.Colorize("Author")..":  The Author \n" ..util.Colorize("Addon Version")..": V0.5 \n\n",
                fontSize = "medium",
                -- "Logo" created by Marz Gallery @ https://www.flaticon.com/free-icons/nocturnal
                image = "Interface\\AddOns\\augmentAssist\\Media\\Textures\\logo_transparent",
                imageWidth = 64,
                imageHeight = 64,
            },
            globalSettings = {
                order = 2,
                name = BASE_SETTINGS,
                type = "group",
                args = {
                    spaceSettingsA = {
                        order = 0.5,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    welcomeMessage = {
                        order = 1,
                        name = "Welcome Message",
                        type = "toggle",
                        width = 1.5,
                        desc = "Toggle showing of the welcome message in chat when you login.",
                        get = function(info) return self.dbNew.profile.welcomeMessage end,
                        set = function(info, val)
                            self.dbNew.profile.welcomeMessage = val
                        end,
                    },
                    welcomeMessage2 = {
                        order = 1.5,
                        name = "Introduction picture",
                        type = "toggle",
                        width = 1.5,
                        desc = "Showing the welcome picture with basic information and instructions at first login",
                        get = function(info) return self.dbNew.profile.welcomeMessage2 end,
                        set = function(info, val)
                            self.dbNew.profile.welcomeMessage2 = val
                        end,
                    },
                    minimap = {
                        order = 2,
                        name = "Minimap Icon",
                        type = "toggle",
                        width = "full",
                        desc = "Toggle the minimap icon.",
                        get = function() return not self.dbNew.profile.minimap.hide end,
                        set = function()
                            self:ToggleMinimapIcon()
                        end,
                    },
                    spaceSettingsB = {
                        order = 9,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    h1 = {
                        type = 'header',
                        name = 'What to show and when to show it',
                        order = 10,
                    },

                    spaceSettings1A = {
                        order = 11,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    description1B = {
                        order = 12,
                        name = "The primary display consists of the aumentAssist bar with tanks displayed above and DPS below or visa-versa.  Below you can spcify when the bar will be displayed on your UI",
                        type = "description",
                        width = "full",
                    },
                    spaceSettings1C = {
                        order = 13,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    -- createTestData = {
                    --     order = 15,
                    --     name = "Create test data",
                    --     type = "toggle",
                    --     width = "full",
                    --     desc = "Create a range of test data to help setup the position and look of the addon",
                    --     get = function() return self.config.createTestData end,
                    --     set = function(info, value) self.config.createTestData = value end,
                    -- },
                    autoHideHeader = {
                        order = 19,
                        name = "Automatically hide header",
                        type = "toggle",
                        width = "full",
                        desc = "Automatically hide teh header based on the other settings",
                        get = function() return self.config.autoHideHeader end,
                        set = function(info, value) self.config.autoHideHeader = value end,
                    },
                    hideOutOfGroup = {
                        type = 'toggle',
                        name = 'Hide addon when not in a group',
                        desc = 'Hides the header bar and any targeting buttons when you are not in a party/raid.  Uncheck to leave the header bar shown at all times.',
                        width = 1.5,
                        get = function() return self.config.hideOutOfGroup end,
                        set = function(info, value)
                            self.config.hideOutOfGroup = value
                            self:updateRoster()
                        end,
                        order = 20,
                    },
                    neverShow = {
                        order = 21,
                        name = "Never Show",
                        type = "toggle",
                        width = 1.5,
                        desc = "Never show the bar.",
                        get = function() return self.config.neverShow end,
                        set = function(info, value) self.config.neverShow = value end,
                    },
                    showInWorld = {
                        order = 22,
                        name = "Show When Non-Instanced",
                        type = "toggle",
                        width = 1.5,
                        desc = "Toggle showing this bar in the world/outside of instances.",
                        get = function() return self.config.showInWorld end,
                        set = function(info, value) self.config.showInWorld = value end,
                    },
                    showInArena = {
                        order = 22.5,
                        name = "Show In Arena",
                        type = "toggle",
                        width = 1.5,
                        desc = "Toggle showing this bar in an arena.",
                        get = function() return self.config.showInArena end,
                        set = function(info, value) self.config.showInArena = value end,
                    },
                    showInBattleground = {
                        order = 23,
                        name = "Show In Battleground",
                        type = "toggle",
                        width = 1.5,
                        desc = "Toggle showing this bar in a battleground.",
                        get = function() return self.config.showInBattleground end,
                        set = function(info, value) self.config.showInBattleground = value end,
                    },
                    showInRaid = {
                        order = 23.5,
                        name = "Show In Raid",
                        type = "toggle",
                        width = 1.5,
                        desc = "Toggle showing this bar in a raid instance.",
                        get = function() return self.config.showInRaid end,
                        set = function(info, value) self.config.showInRaid = value end,
                    },
                    showInDungeon = {
                        order = 24,
                        name = "Show In Dungeon",
                        type = "toggle",
                        width = 1.5,
                        desc = "Toggle showing this bar in a dungeon instance.",
                        get = function() return self.config.showInDungeon end,
                        set = function(info, value) self.config.showInDungeon = value end,
                    },
                    showInScenario = {
                        order = 25,
                        name = "Show In Scenario",
                        type = "toggle",
                        width = 1.5,
                        desc = "Toggle showing this bar in a scenario.",
                        get = function() return self.config.showInScenario end,
                        set = function(info, value) self.config.showInScenario = value end,
                    },
                    h3 = {
                        type = 'header',
                        name = 'Debugging and Development',
                        order = 30,
                    },

                    spaceSettings3A = {
                        order = 11,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    spaceSettings3B = {
                        order = 32,
                        name = "Settings to be used during additional development and defect resolution",
                        type = "description",
                        width = "full",
                    },
                    spaceSettings3C = {
                        order = 33,
                        name = " ",
                        type = "description",
                        width = "full",
                    },
                    doYouHaveDevTool = {
                        type = 'toggle',
                        name = 'Do you want to output debugging to DevTool',
                        desc = 'You have the "DevTool" addon for debugging installed and configured and want to use it.',
                        width = 'full',
                        hidden = function() 
                                    local loaded = false
                                    loaded , _ = IsAddOnLoaded("DevTool")
                                    return not loaded
                                 end,
                        get = function() return self.config.doYouHaveDevTool end,
                        set = function(info, value) 
                                self.config.doYouHaveDevTool = value 
                              end,
                        order = 36,
                    },
                    doYouWantToDebug = {
                        type = 'toggle',
                        name = 'Do you want to show debugging output ?',
                        desc = 'You have the "DevTool" addon for debugging installed and configured.',
                        get = function() return self.config.doYouWantToDebug end,
                        set = function(info, value) self.config.doYouWantToDebug = value end,
                        width = 'full',
                        order = 37,
                    },
       
                },
            },
            bars = {
                name = "General",
                type = "group",
                childGroups = "tab",
                order = 3,
                args = {
                    space = {
                        name = " ",
                        type = "description",
                        order = 1,
                        width = "full",
                    },
                    heading1 = {
                        name =  "Configure the layout and function of the augmentAssist button and icons including what spells will be displayed "..
                                "for each class and in what priority.  Autofill and priority provide the basis for automatically filling your "..
                                "DPS roster with those players that will have the most impact.",
                        type = "description",
                        order = 1.1,
                        width = "full",
                    },
                },

            },
            customSpells = {
                order = 5,
                name = "Custom Spells",
                type = "group",
                args = customSpells,
                get = function(info)
                    local option = info[#info]
                    local spellId = info[#info - 1]
                    spellId = tonumber(spellId)
                    if not spellId then return end
                    return self.dbNew.global.customBuffs[spellId][option]
                end,
            }
        },
    }

    addon.priorityListDialog = {
        name = "Temp",
        type = "group",
        args = {},
    }

    -- GET281023 self:AddOptionsTabs() -- GRT added this to try and replicate a button press for Adbar while testing

    -- self:UpdateBarOptionsTable()
    self:AddTabsToOptions()

    -- Main options dialog.
       
    AceConfig:RegisterOptionsTable(MyAddOnName, self.options ) -- , {MyAddOnName , 'auga'}
    AceConfig:RegisterOptionsTable(MyAddOnName.."Dialog", self.priorityListDialog)
    AceConfigDialog:SetDefaultSize(MyAddOnName, 635, 730)
    AceConfigDialog:SetDefaultSize(MyAddOnName.."Dialog", 300, 730)

    -------------------------------------------------------------------
    -- Create a simple blizzard options panel to direct users to "/auga"
    -------------------------------------------------------------------
    local panel = CreateFrame("Frame")
    panel.name = MyAddOnName

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetText(MyAddOnName)
    title:SetFont("Fonts\\FRIZQT__.TTF", 72, "OUTLINE")
    title:ClearAllPoints()
    title:SetPoint("TOP", 0, -70)

    local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    ver:SetText(addon.version)
    ver:SetFont("Fonts\\FRIZQT__.TTF", 48, "OUTLINE")
    ver:ClearAllPoints()
    ver:SetPoint("TOP", title, "BOTTOM", 0, -20)

    local slash = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slash:SetText("/auga")
    slash:SetFont("Fonts\\FRIZQT__.TTF", 69, "OUTLINE")
    slash:ClearAllPoints()
    slash:SetPoint("BOTTOM", 0, 150)

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetText("Open Options")
    btn.Text:SetTextColor(1, 1, 1)
    btn:SetWidth(150)
    btn:SetHeight(30)
    btn:SetPoint("BOTTOM", 0, 100)
    btn.Left:SetDesaturated(true)
    btn.Right:SetDesaturated(true)
    btn.Middle:SetDesaturated(true)
    btn:SetScript("OnClick", function()
        if not InCombatLockdown() then
            HideUIPanel(SettingsPanel)
            HideUIPanel(InterfaceOptionsFrame)
            HideUIPanel(GameMenuFrame)
        end
        addon:OpenOptions()
    end)

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    -- bg:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu\\MM_sky_01")
    bg:SetTexture("Interface\\AddOns\\augmentAssist\\Media\\Textures\\logo_transparent")
    bg:SetAlpha(0.2)
    bg:SetTexCoord(0, 1, 0, 1)

    if isRetail then
        local category = Settings.RegisterCanvasLayoutCategory(panel, MyAddOnName)
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end

