local addonName, vars = ...
SavedInstances = vars
local addon = vars
vars.core = LibStub("AceAddon-3.0"):NewAddon("SavedInstances", "AceEvent-3.0", "AceTimer-3.0")
local core = vars.core
vars.L = SavedInstances_locale()
local L = vars.L
vars.LDB = LibStub("LibDataBroker-1.1", true)
vars.icon = vars.LDB and LibStub("LibDBIcon-1.0", true)

vars.instanceDB = select(1, GetLFDChoiceInfo())

local QTip = LibStub("LibQTip-1.0")
--local bosses = LibStub("LibBossIDs-1.0")
local dataobject, db, config

-- local (optimal) references to provided functions
local GetExpansionLevel = GetExpansionLevel
local GetInstanceDifficulty = GetInstanceDifficulty
local GetNumSavedInstances = GetNumSavedInstances
local GetSavedInstanceInfo = GetSavedInstanceInfo
local IsInInstance = IsInInstance
local SecondsToTime = SecondsToTime

-- local (optimal) references to Blizzard's strings
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local NO_RAID_INSTANCES_SAVED = NO_RAID_INSTANCES_SAVED -- "You are not saved to any instances"
local FONTEND = FONT_COLOR_CODE_CLOSE
local GOLDFONT = NORMAL_FONT_COLOR_CODE
local YELLOWFONT = LIGHTYELLOW_FONT_COLOR_CODE
local WHITEFONT = HIGHLIGHT_FONT_COLOR_CODE
local GRAYFONT = GRAY_FONT_COLOR_CODE
local LFD_RANDOM_REWARD_EXPLANATION2 = LFD_RANDOM_REWARD_EXPLANATION2

vars.Indicators = {
	ICON_STAR = ICON_LIST[1] .. "16:16:0:0|t",
	ICON_CIRCLE = ICON_LIST[2] .. "16:16:0:0|t",
	ICON_DIAMOND = ICON_LIST[3] .. "16:16:0:0|t",
	ICON_TRIANGLE = ICON_LIST[4] .. "16:16:0:0|t",
	ICON_MOON = ICON_LIST[5] .. "16:16:0:0|t",
	ICON_SQUARE = ICON_LIST[6] .. "16:16:0:0|t",
	ICON_CROSS = ICON_LIST[7] .. "16:16:0:0|t",
	ICON_SKULL = ICON_LIST[8] .. "16:16:0:0|t",
	BLANK = "None",
}

vars.Categories = {
	D0 = EXPANSION_NAME0 .. ": " .. LFG_TYPE_DUNGEON,
	R0 = EXPANSION_NAME0 .. ": " .. LFG_TYPE_RAID,
	D1 = EXPANSION_NAME1 .. ": " .. LFG_TYPE_DUNGEON,
	R1 = EXPANSION_NAME1 .. ": " .. LFG_TYPE_RAID,
	D2 = EXPANSION_NAME2 .. ": " .. LFG_TYPE_DUNGEON,
	R2 = EXPANSION_NAME2 .. ": " .. LFG_TYPE_RAID,
	D3 = EXPANSION_NAME3 .. ": " .. LFG_TYPE_DUNGEON,
	R3 = EXPANSION_NAME3 .. ": " .. LFG_TYPE_RAID,
}

local tooltip, indicatortip
local history = { }
local thisToon = UnitName("player") .. " - " .. GetRealmName()
local maxlvl = MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE]

local storelockout = false -- when true, store the details against the current lockout

local scantt = CreateFrame("GameTooltip", "SavedInstancesScanTooltip", UIParent, "GameTooltipTemplate")

local currency = { 
  395, -- Justice Points 
  396, -- Valor Points
  392, -- Honor Points
  390, -- Conquest Points
}

vars.defaultDB = {
	DBVersion = 10,
	History = { }, -- for tracking 5 instance per hour limit
		-- key: instance string; value: time first entered
	Broker = {
		HistoryText = false,
	},
	Toons = { }, 	-- table key: "Toon - Realm"; value:
				-- Class: string
				-- Level: integer
				-- AlwaysShow: boolean
				-- Daily1: expiry (normal) REMOVED
				-- Daily2: expiry (heroic) REMOVED
				-- LFG1: expiry 
				-- WeeklyResetTime: expiry
	Indicators = {
		D1Indicator = "BLANK", -- indicator: ICON_*, BLANK
		D1Text = "5",
		D1Color = { 0, 0.6, 0, 1, }, -- dark green
		D1ClassColor = true,
		D2Indicator = "BLANK", -- indicator
		D2Text = "5+",
		D2Color = { 0, 1, 0, 1, }, -- green
		D2ClassColor = true,
		R1Indicator = "BLANK", -- indicator: ICON_*, BLANK
		R1Text = "10",
		R1Color = { 0.6, 0.6, 0, 1, }, -- dark yellow
		R1ClassColor = true,
		R2Indicator = "BLANK", -- indicator
		R2Text = "25",
		R2Color = { 0.6, 0, 0, 1, }, -- dark red
		R2ClassColor = true,
		R3Indicator = "BLANK", -- indicator: ICON_*, BLANK
		R3Text = "10+",
		R3Color = { 1, 1, 0, 1, }, -- yellow
		R3ClassColor = true,
		R4Indicator = "BLANK", -- indicator
		R4Text = "25+",
		R4Color = { 1, 0, 0, 1, }, -- red
		R4ClassColor = true,
	},
	Tooltip = {
		Details = false,
		NewInstanceShow = false,
		ReverseInstances = false,
		ShowCategories = false,
		CategorySpaces = false,
		NewFirst = true,
		RaidsFirst = true,
		CategorySort = "EXPANSION", -- "EXPANSION", "TYPE"
		ShowSoloCategory = false,
		ShowHints = true,
		ColumnStyle = "NORMAL", -- "NORMAL", "CLASS", "ALTERNATING"
		AltColumnColor = { 0.2, 0.2, 0.2, 1, }, -- grey
		RecentHistory = false,
		TrackLFG = true,
		Currency395 = true, -- Justice Points 
		Currency396 = true, -- Valor Points
		Currency392 = false, -- Honor Points
		Currency390 = false, -- Conquest Points
	},
	Instances = { }, 	-- table key: "Instance name"; value:
					-- Show: boolean
					-- Raid: boolean
					-- Expansion: integer
					-- LFDID: integer
					-- LFDupdated: integer
					-- REMOVED Encounters[integer] = { GUID : integer, Name : string }
					-- table key: "Toon - Realm"; value:
						-- table key: "Difficulty"; value:
							-- ID: integer
							-- Expires: integer
	MinimapIcon = { },
	Lockouts = {	-- table key: lockout ID; value:
						-- Name: string
						-- Members: table "Toon name" = "Class"
						-- REMOVED Encounters[GUID : integer] = boolean
						-- Note: string
	},
}

-- general helper functions below

local function ColorCodeOpen(color)
	return format("|c%02x%02x%02x%02x", math.floor(color[4] * 255), math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

local function ClassColorise(class, targetstring)
	local RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local color = {
		RAID_CLASS_COLORS[class].r,
		RAID_CLASS_COLORS[class].g,
		RAID_CLASS_COLORS[class].b,
		1,
	}
	return ColorCodeOpen(color) .. targetstring .. FONTEND
end

local function TableLen(table)
	local i = 0
	for _, _ in pairs(table) do
		i = i + 1
	end
	return i
end

function addon:GetServerOffset()
	-- this function was borrowed from Broker Currency with Azethoth
	local serverHour, serverMinute = GetGameTime()
	local localHour, localMinute = tonumber(date("%H")), tonumber(date("%M"))
	local server = serverHour + serverMinute / 60
	local localT = localHour + localMinute / 60
	offset = floor((server - localT) * 2 + 0.5) / 2
	if raw then return offset end
	if offset >= 12 then
		offset = offset - 24
	elseif offset < -12 then
		offset = offset + 24
	end
	return offset
end

function addon:GetNextWeeklyResetTime()
  local offset = addon:GetServerOffset() * 3600
  local nightlyReset = time() + GetQuestResetTime()
  --while date("%A",nightlyReset+offset) ~= WEEKDAY_TUESDAY do 
  while date("%w",nightlyReset+offset) ~= "2" do
    nightlyReset = nightlyReset + 24 * 3600
  end
  return nightlyReset
end

-- local addon functions below

local function GetLastLockedInstance()
	local numsaved = GetNumSavedInstances()
	if numsaved > 0 then
		for i = 1, numsaved do
			local name, id, expires, diff, locked, extended, mostsig, raid, players, diffname = GetSavedInstanceInfo(i)
			if locked then
				return name, id, expires, diff, locked, extended, mostsig, raid, players, diffname
			end
		end
	end
end

local function GetLFDID(name)
	local foundid, reclevel
	for id, details in pairs(vars.instanceDB) do
		if (strfind(details[1], name, 1, true) or strfind(name, details[1], 1, true))
				and (vars.db.Instances[name].Raid == (details[2] == 2)) then
			if not reclevel or details[5] < reclevel then
				foundid = id
				reclevel = details[5]
			end
		end
	end
	return foundid
end

function addon:InstanceCategory(instance)
	if not instance then return nil end
	local instance = vars.db.Instances[instance]
	return ((instance.Raid and "R") or ((not instance.Raid) and "D")) .. instance.Expansion
end

function addon:InstancesInCategory(targetcategory)
	-- returns a table of the form { "instance1", "instance2", ... }
	if (not targetcategory) then return { } end
	local list = { }
	for instance, _ in pairs(vars.db.Instances) do
		if addon:InstanceCategory(instance) == targetcategory then
			list[#list+1] = instance
		end
	end
	return list
end

function addon:CategorySize(category)
	if not category then return nil end
	local i = 0
	for instance, _ in pairs(vars.db.Instances) do
		if category == addon:InstanceCategory(instance) then
			i = i + 1
		end
	end
	return i
end

function addon:OrderedInstances(category)
	-- returns a table of the form { "instance1", "instance2", ... }
	local orderedlist = { }
	local instances = addon:InstancesInCategory(category)
	while #instances > 0 do
		local highest, lowest, selected
		for i, instance in ipairs(instances) do
			local instancelevel
			if vars.db.Instances[instance].LFDID and vars.instanceDB[vars.db.Instances[instance].LFDID] then
				instancelevel = vars.instanceDB[vars.db.Instances[instance].LFDID][5]
			end
			if vars.db.Tooltip.ReverseInstances then
				if not lowest or (instancelevel and instancelevel < lowest) then
					lowest = instancelevel
					selected = i
				end
			else
				if not highest or (instancelevel and instancelevel > highest) then
					highest = instancelevel
					selected = i
				end
			end
		end
		if vars.db.Tooltip.ReverseInstances then
			selected = selected or 1
		else
			selected = selected or #instances
		end
		orderedlist[1+#orderedlist] = instances[selected]
		tremove(instances, selected)
	end
	return orderedlist
end


function addon:OrderedCategories()
	-- returns a table of the form { "category1", "category2", ... }
	local orderedlist = { }
	local firstexpansion, lastexpansion, expansionstep, firsttype, lasttype
	if vars.db.Tooltip.NewFirst then
		firstexpansion = GetExpansionLevel()
		lastexpansion = 0
		expansionstep = -1
	else
		firstexpansion = 0
		lastexpansion = GetExpansionLevel()
		expansionstep = 1
	end
	if vars.db.Tooltip.RaidsFirst then
		firsttype = "R"
		lasttype = "D"
	else
		firsttype = "D"
		lasttype = "R"
	end
	for i = firstexpansion, lastexpansion, expansionstep do
		orderedlist[1+#orderedlist] = firsttype .. i
		if vars.db.Tooltip.CategorySort == "EXPANSION" then
			orderedlist[1+#orderedlist] = lasttype .. i
		end
	end
	if vars.db.Tooltip.CategorySort == "TYPE" then
		for i = firstexpansion, lastexpansion, expansionstep do
			orderedlist[1+#orderedlist] = lasttype .. i
		end
	end
	return orderedlist
end

local function DifficultyString(instance, diff, toon)
	local setting
	if not instance then
		setting = "D" .. diff
	else
		local instance = vars.db.Instances[instance]
		setting = ((instance.Raid and "R") or ((not instance.Raid) and "D")) .. diff
	end
	local prefs = vars.db.Indicators
	if prefs[setting .. "ClassColor"] then
		local RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
		color = {
		RAID_CLASS_COLORS[vars.db.Toons[toon].Class].r,
		RAID_CLASS_COLORS[vars.db.Toons[toon].Class].g,
		RAID_CLASS_COLORS[vars.db.Toons[toon].Class].b,
		1,
	}
	else
		color = prefs[setting.."Color"]
	end
	if not strfind(prefs[setting.."Text"], "ICON", 1, true) then
		return ColorCodeOpen(color) .. prefs[setting.."Text"] .. FONTEND
	end
	local iconstring
	if prefs[setting.."Indicator"] == "BLANK" then
		iconstring = ""
	else
		iconstring = FONTEND .. vars.Indicators[prefs[setting.."Indicator"]] .. ColorCodeOpen(color)
	end
	return ColorCodeOpen(color) .. gsub(prefs[setting.."Text"], "ICON", iconstring) .. FONTEND
end

function addon:MaintainInstanceDB()
	for instance, i in pairs(vars.db.Instances) do
		for toon, t in pairs(vars.db.Toons) do
			if i[toon] then
				for difficulty, d in pairs(i[toon]) do
					if d.Expires < time() then
						i[toon][difficulty] = nil
						vars.db.Lockouts[d.ID] = nil
					else
						vars.db.Lockouts[d.ID] = vars.db.Lockouts[d.ID] or { }
						vars.db.Lockouts[d.ID].Members = vars.db.Lockouts[d.ID].Members or { }
						vars.db.Lockouts[d.ID].Members[strsplit(' ', toon)] = vars.db.Lockouts[d.ID].Members[strsplit(' ', toon)] or { Class = t.Class }
						vars.db.Lockouts[d.ID].Name = instance
					end
				end
				if TableLen(i[toon]) == 0 then
					i[toon] = nil
				end
			end
		end
	end
	-- update random toon info
	local t = vars.db.Toons[thisToon]
        t.LFG1 = GetLFGRandomCooldownExpiration()
	local desert = select(7,UnitDebuff("player",GetSpellInfo(71041))) -- GetLFGDeserterExpiration()
	if desert and (not t.LFG1 or desert > t.LFG1) then
	  t.LFG1 = desert
	end
	for toon, ti in pairs(vars.db.Toons) do
		if ti.LFG1 and (ti.LFG1 < GetTime()) then ti.LFG1 = nil end
	end
	-- Weekly Reset
	for toon, ti in pairs(vars.db.Toons) do
	  if not ti.WeeklyResetTime or (ti.WeeklyResetTime < time()) then 
	    ti.currency = ti.currency or {}
	    for _,idx in ipairs(currency) do
	      ti.currency[idx] = ti.currency[idx] or {}
	      ti.currency[idx].earnedThisWeek = 0
	    end
          end 
	  ti.WeeklyResetTime = addon:GetNextWeeklyResetTime()
	end
	t.currency = t.currency or {}
	for _,idx in pairs(currency) do
	  local ci = t.currency[idx] or {}
	  _, ci.amount, _, ci.earnedThisWeek, ci.weeklyMax, ci.totalMax = GetCurrencyInfo(idx)
          if idx == 396 then -- VP x 100, CP x 1
            ci.weeklyMax = ci.weeklyMax and ci.weeklyMax/100
          end
          ci.totalMax = ci.totalMax and ci.totalMax/100
          ci.season = addon:GetSeasonCurrency(idx)
	  t.currency[idx] = ci
	end
end

local function coloredText(fontstring)
  if not fontstring then return nil end
  local text = fontstring:GetText()
  if not text then return nil end
  local textR, textG, textB, textAlpha = fontstring:GetTextColor() 
  return string.format("|c%02x%02x%02x%02x"..text.."|r", 
                       textAlpha*255, textR*255, textG*255, textB*255)
end

local function ShowIndicatorTooltip(cell, arg, ...)
	local instance = arg[1]
	local toon = arg[2]
	local diff = arg[3]
	if not instance or not toon or not diff then return end
	indicatortip = QTip:Acquire("SavedInstancesIndicatorTooltip", 2, "LEFT", "RIGHT")
	indicatortip:Clear()
	indicatortip:SetHeaderFont(tooltip:GetHeaderFont())
	local thisinstance = vars.db.Instances[instance]
	local id = thisinstance[toon][diff].ID
	local nameline, _ = indicatortip:AddHeader()
	indicatortip:SetCell(nameline, 1, DifficultyString(instance, diff, toon) .. " " .. GOLDFONT .. instance .. FONTEND, indicatortip:GetHeaderFont(), "LEFT", 2)
	indicatortip:AddHeader(ClassColorise(vars.db.Toons[toon].Class, strsplit(' ', toon)), id)
	indicatortip:AddLine(YELLOWFONT .. L["Time Left"] .. ":" .. FONTEND, SecondsToTime(thisinstance[toon][diff].Expires - time()))
	if db.Lockouts[id].Note and db.Lockouts[id].Note ~= "" then
		local noteline, _ = indicatortip:AddLine()
		indicatortip:SetCell(noteline, 1, WHITEFONT .. db.Lockouts[id].Note .. FONTEND, "LEFT", 2)
	end
	indicatortip:SetAutoHideDelay(0.1, tooltip)
	indicatortip:SmartAnchorTo(tooltip)
	indicatortip:Show()
	if thisinstance[toon][diff].Link then
	  scantt:SetOwner(UIParent,"ANCHOR_NONE")
	  scantt:SetHyperlink(thisinstance[toon][diff].Link)
	  local name = scantt:GetName()
	  for i=2,scantt:NumLines() do
	    local left,right = _G[name.."TextLeft"..i], _G[name.."TextRight"..i]
	    indicatortip:AddLine(coloredText(left), coloredText(right))
	  end
	end
end

local colorpat = "\124c%c%c%c%c%c%c%c%c"
local weeklycap = CURRENCY_WEEKLY_CAP:gsub("%%%d*\$?([ds])","%%%1")
local weeklycap_scan = weeklycap:gsub("%%d","(%%d+)"):gsub("%%s","(\124c%%x%%x%%x%%x%%x%%x%%x%%x)")
local totalcap = CURRENCY_TOTAL_CAP:gsub("%%%d*\$?([ds])","%%%1")
local totalcap_scan = totalcap:gsub("%%d","(%%d+)"):gsub("%%s","(\124c%%x%%x%%x%%x%%x%%x%%x%%x)")
local season_scan = CURRENCY_SEASON_TOTAL:gsub("%%%d*\$?([ds])","(%%%1*)")

function addon:GetSeasonCurrency(idx) 
  scantt:SetOwner(UIParent,"ANCHOR_NONE")
  scantt:SetCurrencyByID(idx)
  local name = scantt:GetName()
  for i=1,scantt:NumLines() do
    local left = _G[name.."TextLeft"..i]
    if left:GetText():find(season_scan) then
      return left:GetText()
    end
  end  
  return nil
end

local function ShowCurrencyTooltip(cell, arg, ...)
  local toon, idx, ci = unpack(arg)
  if not toon or not idx or not ci then return end
  local name,_,tex = GetCurrencyInfo(idx)
  tex = " \124TInterface\\Icons\\"..tex..":0\124t"
  indicatortip = QTip:Acquire("SavedInstancesIndicatorTooltip", 2, "LEFT", "RIGHT")
  indicatortip:Clear()
  indicatortip:SetHeaderFont(tooltip:GetHeaderFont())
  local nameline, _ = indicatortip:AddHeader()
  indicatortip:AddHeader(ClassColorise(vars.db.Toons[toon].Class, strsplit(' ', toon)), "("..(ci.amount or "0")..tex..")")

  scantt:SetOwner(UIParent,"ANCHOR_NONE")
  scantt:SetCurrencyByID(idx)
  local name = scantt:GetName()
  for i=1,scantt:NumLines() do
    local left = _G[name.."TextLeft"..i]
    if left:GetText():find(weeklycap_scan) or 
       left:GetText():find(totalcap_scan) or
       left:GetText():find(season_scan) then
      -- omit player's values
    else
      indicatortip:AddLine("")
      indicatortip:SetCell(indicatortip:GetLineCount(),1,coloredText(left), nil, nil, nil, nil, nil, nil, 250)
    end
  end
  if ci.weeklyMax and ci.weeklyMax > 0 then
    indicatortip:AddLine(weeklycap:format("", (ci.earnedThisWeek or 0), (ci.weeklyMax or 0)))
  end
  if ci.totalMax and ci.totalMax > 0 then
    indicatortip:AddLine(totalcap:format("", (ci.amount or 0), (ci.totalMax or 0)))
  end
  if ci.season and #ci.season > 0 then
    indicatortip:AddLine(ci.season)
  end

  indicatortip:SetAutoHideDelay(0.1, tooltip)
  indicatortip:SmartAnchorTo(tooltip)
  indicatortip:Show()
end

local function UpdateLDBTextMode()
	if db.Broker.HistoryText then
		vars.dataobject.type = "data source"
		core:ScheduleRepeatingTimer("UpdateLDBText", 5, nil)
	else
		vars.dataobject.type = "launcher"
		vars.dataobject.text = addonName
		core:CancelAllTimers()
	end
end

-- global addon code below

function core:OnInitialize()
	SavedInstancesDB = SavedInstancesDB or vars.defaultDB
	-- begin backwards compatibility
	if not SavedInstancesDB.DBVersion then
		SavedInstancesDB = vars.defaultDB
	end
	if SavedInstancesDB.DBVersion == 6 then
		SavedInstancesDB.DBVersion = 7
		SavedInstancesDB.Tooltip.ShowHints = true
	end
	if SavedInstancesDB.DBVersion == 7 then
		SavedInstancesDB.DBVersion = 8
		SavedInstancesDB.Tooltip = vars.defaultDB.Tooltip
		SavedInstancesDB.Broker = vars.defaultDB.Broker
	end
	if SavedInstancesDB.DBVersion == 8 then
		SavedInstancesDB.DBVersion = 9
		SavedInstancesDB.Tooltip.CategorySort = vars.defaultDB.Tooltip.CategorySort
		SavedInstancesDB.Categories = vars.defaultDB.Categories
		SavedInstancesDB.Broker = vars.defaultDB.Broker
	end
	if SavedInstancesDB.DBVersion == 9 then
		SavedInstancesDB.DBVersion = 10
		for instance, i in pairs(SavedInstancesDB.Instances) do
			i.Order = nil
		end
		SavedInstancesDB.Categories = nil
	end
	if SavedInstancesDB.DBVersion ~= 10 then
		SavedInstancesDB = vars.defaultDB
	end
	-- end backwards compatibilty
	db = db or SavedInstancesDB
	vars.db = db
	config = vars.config
	db.Toons[thisToon] = db.Toons[thisToon] or { }
	db.Toons[thisToon].Class = db.Toons[thisToon].Class or select(2, UnitClass("player"))
	db.Toons[thisToon].Level = UnitLevel("player")
	db.Toons[thisToon].AlwaysShow = db.Toons[thisToon].AlwaysShow or false
	db.Lockouts = db.Lockouts or { }
	RequestRaidInfo()
	vars.dataobject = vars.LDB and vars.LDB:NewDataObject("SavedInstances", {
		text = "",
		type = "launcher",
		icon = "Interface\\Addons\\SavedInstances\\icon.tga",
		OnEnter = function(frame)
			core:ShowTooltip(frame)
		end,
		OnClick = function(frame, button)
			if button == "LeftButton" then
				ToggleFriendsFrame(4) -- open Blizzard Raid window
				RaidInfoFrame:Show()
			else
				config:ShowConfig()
			end
		end
	})
	if vars.icon then
		vars.icon:Register("SavedInstances", vars.dataobject, db.MinimapIcon)
	end
	UpdateLDBTextMode()
end

function core:OnEnable()
	self:RegisterEvent("UPDATE_INSTANCE_INFO", "Refresh")
	self:RegisterEvent("RAID_INSTANCE_WELCOME", RequestRaidInfo)
	self:RegisterEvent("CHAT_MSG_SYSTEM", "CheckSystemMessage")
	self:RegisterEvent("CHAT_MSG_CURRENCY", "CheckSystemMessage")
	self:RegisterEvent("CHAT_MSG_LOOT", "CheckSystemMessage")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("LFG_COMPLETION_REWARD") -- for random daily dungeon tracking
end

function core:OnDisable()
	self:UnregisterEvent("UPDATE_INSTANCE_INFO")
	self:UnregisterEvent("RAID_INSTANCE_WELCOME")
	self:UnregisterEvent("CHAT_MSG_SYSTEM")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("LFG_COMPLETION_REWARD")
end

function core:PLAYER_ENTERING_WORLD()
  addon:MaintainInstanceDB()
end

function addon:UpdateThisLockout()
	storelockout = true
	RequestRaidInfo()
end
local currency_msg = CURRENCY_GAINED:gsub(":.*$","")
function core:CheckSystemMessage(event, msg)
	if (msg:find(INSTANCE_SAVED) or -- first boss kill
	    msg:find(currency_msg)) -- subsequent boss kills (unless capped or over level)
	   and IsInInstance() then
	   addon:UpdateThisLockout()
	end
end

function core:LFG_COMPLETION_REWARD()
	--local _, _, diff = GetInstanceInfo()
	--vars.db.Toons[thisToon]["Daily"..diff] = time() + GetQuestResetTime() + addon:GetServerOffset() * 3600
	addon:UpdateThisLockout()
end


function core:Refresh()
	-- update entire database from the current character's perspective
	local numsaved = GetNumSavedInstances()
	if numsaved > 0 then
		for i = 1, numsaved do
			local name, id, expires, diff, locked, extended, mostsig, raid, players, diffname = GetSavedInstanceInfo(i)
			if ( locked ) then
				vars.db.Instances[name] = vars.db.Instances[name] or { }
				local instance = vars.db.Instances[name]
				instance.Raid = instance.Raid or raid
				local currentbuild = select(2, GetBuildInfo())
				if not instance.LFDDID or instance.LFDupdated < currentbuild then
					instance.LFDupdated = currentbuild
					instance.LFDID = GetLFDID(name)
					if instance.LFDID then
						instance.Expansion = vars.instanceDB[instance.LFDID][8]
					end
				end
				instance.Expansion = instance.Expansion or 0
				instance.Show = instance.Show or vars.db.Tooltip.NewInstanceShow
				if locked then
					instance[thisToon] = instance[thisToon] or { }
					instance[thisToon][diff] = {
						ID = id,
						Expires = expires + time(),
                                                Link = GetSavedInstanceChatLink(i)
					}
				end
			else
				-- print("DEBUG: SavedInstances: Refresh() - ignoring expired lock for instance:" .. name)
			end
		end
	end
	-- update the lockout-specific details for the current instance if necessary
	if storelockout then
		local thisname, _, thisdiff = GetInstanceInfo()
		local name, id, _, diff, locked, _, _, raid = GetLastLockedInstance()
		if thisname == name and thisdiff == diff then
			--vars.db.Lockouts[id]
		end
	end
	storelockout = false
	addon:MaintainInstanceDB()
end

function core:ShowTooltip(anchorframe)
	if tooltip and tooltip:IsShown() then return end
	tooltip = QTip:Acquire("SavedInstancesTooltip", 1, "LEFT")
	tooltip:Clear()
	local hFont = tooltip:GetHeaderFont()
	local hFontPath, hFontSize
	hFontPath, hFontSize, _ = hFont:GetFont()
	hFont:SetFont(hFontPath, hFontSize, "OUTLINE")
	tooltip:SetHeaderFont(hFont)
	local headLine, headCol = tooltip:AddHeader(GOLDFONT .. "SavedInstances" .. FONTEND)
	addon:MaintainInstanceDB()
	if columns then columns = nil end
	local columns = { }
	-- allocating columns for characters
	if vars.db.Toons[thisToon].AlwaysShow then
		for diff = 1, 4 do
			columns[thisToon..diff] = columns[thisToon..diff] or tooltip:AddColumn("CENTER")
		end
	end
	for toon, t in pairs(vars.db.Toons) do
		if vars.db.Toons[toon].AlwaysShow then
			for diff = 1, 4 do
				columns[toon..diff] = columns[toon..diff] or tooltip:AddColumn("CENTER")
			end
		end
	end
	-- determining how many instances will be displayed per category
	local categorysize = { } -- remember the number of instances to be shown for each category
	local instancesaved = { } -- remember if each instance has been saved or not (boolean)
	local doseparator = false -- use this to determine whether to insert spaces or not
	for _, category in ipairs(addon:OrderedCategories()) do
		categorysize[category] = 0
		for _, instance in ipairs(addon:OrderedInstances(category)) do
			for toon, t in pairs(vars.db.Toons) do
				for diff = 1, 4 do
					if vars.db.Instances[instance][toon] and vars.db.Instances[instance][toon][diff] then
						instancesaved[instance] = true
						categorysize[category] = categorysize[category] + 1
					elseif vars.db.Instances[instance].Show then
						categorysize[category] = categorysize[category] + 1
					end
				end
			end
		end
	end
	local categories = 0
	-- determining how many categories have instances that will be shown
	if vars.db.Tooltip.ShowCategories then
		for category, size in pairs(categorysize) do
			if size > 0 then
				categories = categories + 1
			end
		end
	end
	-- allocating tooltip space for instances, categories, and space between categories
	local categoryrow = { } -- remember where each category heading goes
	local instancerow = { } -- remember where each instance goes
	local firstcategory = true -- use this to skip spacing before the first category
	for _, category in ipairs(addon:OrderedCategories()) do
		if categorysize[category] > 0 then
			if not firstcategory and vars.db.Tooltip.CategorySpaces then
				tooltip:AddSeparator(6,0,0,0,0)
			end
			if (categories > 1 or vars.db.Tooltip.ShowSoloCategory) and (categorysize[category] > 0) then
				categoryrow[category], _ = tooltip:AddLine()

			end
			for _, instance in ipairs(addon:OrderedInstances(category)) do
				for toon, t in pairs(vars.db.Toons) do
					for diff = 1, 4 do
						if vars.db.Instances[instance][toon] and vars.db.Instances[instance][toon][diff] then
							instancerow[instance] = instancerow[instance] or tooltip:AddLine()
							for diff = 1, 4 do
								columns[toon..diff] = columns[toon..diff] or tooltip:AddColumn("CENTER")
							end
						elseif vars.db.Instances[instance].Show then
							instancerow[instance] = instancerow[instance] or tooltip:AddLine()
						end
					end
				end
			end
			firstcategory = false
		end
	end
	-- now printing instance data
	for instance, row in pairs(instancerow) do
		if instancesaved[instance] then
			tooltip:SetCell(instancerow[instance], 1, GOLDFONT .. instance .. FONTEND)
			for toon, t in pairs(vars.db.Toons) do
				if vars.db.Instances[instance][toon] then
					for diff = 1, 4 do
						local save = vars.db.Instances[instance][toon][diff]
						if save ~= nil then
							tooltip:SetCell(instancerow[instance], columns[toon..diff], DifficultyString(instance, diff, toon))
							tooltip:SetCellScript(instancerow[instance], columns[toon..diff], "OnEnter", ShowIndicatorTooltip, {instance, toon, diff})
							tooltip:SetCellScript(instancerow[instance], columns[toon..diff], "OnLeave", 
							     function() indicatortip:Hide(); GameTooltip:Hide() end)
							tooltip:SetCellScript(instancerow[instance], columns[toon..diff], "OnMouseDown", 
							     function()
							       local db = vars.db.Instances
							       local link = instance and toon and diff and 
							           db[instance] and db[instance][toon] and db[instance][toon][diff] and 
								   db[instance][toon][diff].Link
							       if link and ChatEdit_GetActiveWindow() then
							          ChatEdit_InsertLink(link)
							       elseif link then
							          ChatFrame_OpenChat(link, DEFAULT_CHAT_FRAME)
							       end
							     end)
						else
							tooltip:SetCell(instancerow[instance], columns[toon..diff], "")
						end
					end
				end
			end
		elseif (not instancesaved[instance]) and (vars.db.Instances[instance].Show) then
			tooltip:SetCell(instancerow[instance], 1, GRAYFONT .. instance .. FONTEND)
		end
	end
	-- random dungeon
	if vars.db.Tooltip.TrackLFG then
		local randomcd = false
		for toon, t in pairs(vars.db.Toons) do
			if t.LFG1 then
				randomcd = true
				for diff = 1, 4 do
					columns[toon..diff] = columns[toon..diff] or tooltip:AddColumn("CENTER")
				end
			end
		end
		local randomLine
		if randomcd then
			if not firstcategory and vars.db.Tooltip.CategorySpaces then
				tooltip:AddSeparator(6,0,0,0,0)
			end
			randomLine = tooltip:AddLine(YELLOWFONT .. LFG_TYPE_RANDOM_DUNGEON .. FONTEND)		
		end
		for toon, t in pairs(vars.db.Toons) do
			if t.LFG1 and GetTime() < t.LFG1 then
			        local diff = t.LFG1 - GetTime()
				--[[
				local hr,min,sec = math.floor(diff/3600), math.floor((diff%3600)/60), math.floor(diff%60)
				local str = string.format(":%02d",sec)
				if (min > 0 or hr > 0) then str = string.format("%02d",min)..str end
				if (hr > 0) then str = string.format("%02d:",hr)..str end
				--]]
				local str = SecondsToTime(diff, false, false, 1)
				tooltip:SetCell(randomLine, columns[toon..1], ClassColorise(t.Class,str), "CENTER",4)
			end
		end
	end

        for _,idx in ipairs(currency) do
	  local setting = vars.db.Tooltip["Currency"..idx]
          if setting then
            local show 
   	    for toon, t in pairs(vars.db.Toons) do
		-- ci.name, ci.amount, ci.earnedThisWeek, ci.weeklyMax, ci.totalMax
                local ci = t.currency and t.currency[idx] 
		if ci and (((ci.earnedThisWeek or 0) > 0 and (ci.weeklyMax or 0) > 0) 
		       -- or ((ci.amount or 0) > 0 and ci.weeklyMax == 0 and t.Level == maxlvl)
		       ) then
		  for diff = 1, 4 do
			columns[toon..diff] = columns[toon..diff] or tooltip:AddColumn("CENTER")
		  end
		end
		if ci and (ci.amount or 0) > 0 and columns[toon..1] then
		  local name,_,tex = GetCurrencyInfo(idx)
		  show = name.." \124TInterface\\Icons\\"..tex..":0\124t"
		end
	    end
   	    local currLine
	    if show then
		if not firstcategory and vars.db.Tooltip.CategorySpaces then
			tooltip:AddSeparator(6,0,0,0,0)
		end
		currLine = tooltip:AddLine(YELLOWFONT .. show .. FONTEND)		

   	      for toon, t in pairs(vars.db.Toons) do
                local ci = t.currency and t.currency[idx] 
		if ci and columns[toon..1] and ((ci.earnedThisWeek or 0) > 0 or (ci.amount or 0) > 0) then
                   local str
                   if ci.weeklyMax and ci.weeklyMax > 0 then
                      str = (ci.earnedThisWeek or "0").."/"..ci.weeklyMax..
                            " ("..(ci.amount or "0")..((ci.totalMax and ci.totalMax > 0 and "/"..ci.totalMax) or "")..")"
                   elseif ci.totalMax and ci.totalMax > 0 then
                      str = "("..(ci.amount or "0").."/"..ci.totalMax..")"
                   else
                      str = "("..ci.amount..")"
                   end
		   tooltip:SetCell(currLine, columns[toon..1], ClassColorise(t.Class,str), "CENTER",4)
		   tooltip:SetCellScript(currLine, columns[toon..1], "OnEnter", ShowCurrencyTooltip, {toon, idx, ci})
		   tooltip:SetCellScript(currLine, columns[toon..1], "OnLeave", 
							     function() indicatortip:Hide(); GameTooltip:Hide() end)
                end
              end
	    end
          end
        end

	-- toon names
	for toondiff, col in pairs(columns) do
		local toon = strsub(toondiff, 1, #toondiff-1)
		local diff = strsub(toondiff, #toondiff, #toondiff)
		if diff == "1" then
			tooltip:SetCell(headLine, col, ClassColorise(vars.db.Toons[toon].Class, select(1, strsplit(" - ", toon))), tooltip:GetHeaderFont(), "CENTER", 4)
		end
	end 
	-- we now know enough to put in the category names where necessary
	if vars.db.Tooltip.ShowCategories then
		for category, row in pairs(categoryrow) do
			if (categories > 1 or vars.db.Tooltip.ShowSoloCategory) and (categorysize[category] > 0) then
				tooltip:SetCell(categoryrow[category], 1, YELLOWFONT .. vars.Categories[category] .. FONTEND, "LEFT", tooltip:GetColumnCount())
			end
		end
	end
	-- finishing up, with hints
	if TableLen(instancerow) == 0 then
		local noneLine = tooltip:AddLine()
		tooltip:SetCell(noneLine, 1, GRAYFONT .. NO_RAID_INSTANCES_SAVED .. FONTEND, "LEFT", tooltip:GetColumnCount())
	end
	if vars.db.Tooltip.ShowHints then
		tooltip:AddSeparator(8,0,0,0,0)
		local hintLine, hintCol
		hintLine, hintCol = tooltip:AddLine()
		tooltip:SetCell(hintLine, hintCol, L["|cffffff00Left-click|r to show Blizzard's Raid Information"], "LEFT", tooltip:GetColumnCount())
		hintLine, hintCol = tooltip:AddLine()
		tooltip:SetCell(hintLine, hintCol, L["|cffffff00Right-click|r to configure SavedInstances"], "LEFT", tooltip:GetColumnCount())
		hintLine, hintCol = tooltip:AddLine()
		tooltip:SetCell(hintLine, hintCol, L["Hover mouse on indicator for details"], "LEFT", tooltip:GetColumnCount())
	end
	-- tooltip column colours
	if vars.db.Tooltip.ColumnStyle == "CLASS" then
		for toondiff, col in pairs(columns) do
			local toon = strsub(toondiff, 1, #toondiff-1)
			local diff = strsub(toondiff, #toondiff, #toondiff)
			local color = RAID_CLASS_COLORS[vars.db.Toons[toon].Class]
			tooltip:SetColumnColor(col, color.r, color.g, color.b)
		end 
	end						
	tooltip:SetAutoHideDelay(0.1, anchorframe)
	tooltip:SmartAnchorTo(anchorframe)
	tooltip:Show()
end

function core:UpdateLDBText()
	if db.History and TableLen(db.History) >= 2 then
		-- do the stuff :)
		-- SavedInstances.launcher.text = format(L["%s instances"], number)
		-- SavedInstances.launcher.text = format(L["%s instances"], number)
	else
		vars.dataobject.text = ""
	end	
end
