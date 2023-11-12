local MyAddOnName,NS = ...
local util = NS.Utils
local addon = _G[MyAddOnName]
local classColors = NS.ClassColors
local INLINE_MAINTANK = "|TInterface\\RaidFrame\\UI-RaidFrame-MainTank:0|t"
local tsort = table.sort
local UnitClass,UnitIsPlayer = UnitClass,UnitIsPlayer

local hexFontColors = {
    ["main"] = "ff83b2ff",
    ["accent"] = "ff9b6ef3",
    ["value"] = "ffffe981",
    ["logo"] = "ffff7a00",
    ["blizzardFont"] = NORMAL_FONT_COLOR:GenerateHexColor(),
}


--[[
	Add messages into "DevTool" to help with development and debugging using
	self:AddDebugData(dataitem, comment string)
]]


function util.AddDebugData(theData, theString)
	if addon.dbNew.profile.config.doYouWantToDebug then
        if addon.dbNew.profile.config.doYouHaveDevTool then
		    DevTool:AddData(theData, theString)
        else
            print("DEBUG:",theString,theData )
        end
	end
end

function util.cooldown(expiryTime)
    local duration = expiryTime - GetTime()
    local min = math.floor(duration/60)
    local sec = math.floor(duration-min)


    if duration < 0 then return "" end

    if duration < addon.config.cooldowntrigger then return math.floor(duration) end

    if min > 0 then 
        return min.."m"
    end
end

function util.getNewHealth(unitID)
	local health = UnitHealth(unitID)
    local healthMax = UnitHealthMax(unitID)

    return (health / healthMax)

end

function util.Print(...)
    print(util.Colorize("augmentAssist", "main") .. ":", ...)
end

function util.deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, _copy(getmetatable(object)))
    end
    return _copy(object)
end

function util.hasValue(t, value)
    for _, v in ipairs(t) do
        if v == value then return true end
    end
    for k, v in pairs(t) do
        if v == value then return true end
    end
    return false
end

function util.keys(t)
    local temp_t = {}
    for k,_ in pairs(t) do tinsert(temp_t, k) end
    return temp_t
end

function util.keyFromValue(t, value)
    for k,v in pairs(t) do
        if v == value then return k end
    end
end

function util.tableIndex(t, value)
    for idx, v in ipairs(t) do
        if v == value then return idx end
    end
end

function util.unique(t) -- arrays only
	local temp_t,i = {}
	tsort(t)
    for k,v in ipairs(t) do
    	temp_t[#temp_t+1] = i~=v and v or nil
	    i=v
    end
    return temp_t
end

function util.inverted(t)
    local temp_t = {}
    for i = 0,#t-1 do
        tinsert(temp_t, t[#t-i])
    end
    return temp_t
end

function util.unitname(unit)
	local name, server = UnitName(unit)

    if addon.config.createTestData then
        for c,testData in pairs(addon.testData) do
            if testData.unitID == unit then 
                name = testData.name
                break
            end
        end
    else
        if server and server~="" then
            name = ("%s-%s"):format(name,server)
        end
    end
	return name
end

function util.decoratedName(unitName)
    local name = unitName
    local unit = addon.roster[unitName]
    if UnitIsPlayer(unit) then
        local _,eClass = UnitClass(addon.roster[unitName])
        local colorStr = classColors[eClass] and classColors[eClass].colorStr or classColors["UNKNOWN"].colorStr
        if util.hasValue(addon.tanks,unitName) then
            name = ("%s|c%s%s|r"):format(INLINE_MAINTANK,colorStr,name)
        --GRT elseif util.hasValue(addon.damagers,unitName) then
        --GRT     name = ("%s|c%s%s|r"):format(INLINE_MAINASSIST,colorStr,name)
        else
            name = ("|c%s%s|r"):format(colorStr,name)
        end
    end
    return name
end

function util.GetIconString(icon, iconSize)
    local size = iconSize or 0
    local ltTexel = 0.08 * 256
    local rbTexel = 0.92 * 256

    if not icon then
        icon = 134400 --"?"
    end

    return format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t", icon, size, size, ltTexel, rbTexel, ltTexel, rbTexel)
end

function util.Colorize(text, color)
    if not text then return end
    local hexColor = hexFontColors[color] or hexFontColors["blizzardFont"]
    return "|c" .. hexColor .. text .. "|r"
end

function util.returnTestDataItem(identifier,checkField)

    for _,testRecord in pairs(addon.testData) do
        local returnField
        local foundUnit = false
        for theField,theData in pairs(testRecord) do
            if (theField=="name" and theData==identifier) or
               (theField=="unitID" and theData==identifier) then foundUnit = true end
            if checkField == theField then returnField=theData end
            if foundUnit and returnField then return returnField end
        end
    end
    
end