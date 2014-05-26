-------------------------------------------------------------------------------
-- Localized Lua globals.
-------------------------------------------------------------------------------
local _G = getfenv(0)

local math = _G.math
local string = _G.string
local table = _G.table

local pairs = _G.pairs
local tonumber = _G.tonumber
local type = _G.type

-------------------------------------------------------------------------------
-- AddOn namespace.
-------------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
local Frenemy = LibStub("AceAddon-3.0"):NewAddon(FOLDER_NAME, "AceEvent-3.0")

local LibQTip = LibStub('LibQTip-1.0')
local LDBIcon = LibStub("LibDBIcon-1.0")

local DataObject = LibStub("LibDataBroker-1.1"):NewDataObject(FOLDER_NAME, {
	icon = [[Interface\Calendar\MeetingIcon]],
	text = " ",
	type = "data source",
})

local RequestUpdater = _G.CreateFrame("Frame")

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local BNET_CLIENT_APP = "App" -- Battle.net Application - doesn't have a constant.

local CLIENT_SORT_ORDERS = {
	[_G.BNET_CLIENT_WOW] = 1,
	[_G.BNET_CLIENT_D3] = 2,
	[_G.BNET_CLIENT_SC2] = 3,
	[_G.BNET_CLIENT_WTCG] = 4,
	[BNET_CLIENT_APP] = 5,
}

local CLIENT_ICON_TEXTURE_CODES = {}
do
	local CLIENT_ICON_SIZE = 18

	for clientToken in pairs(CLIENT_SORT_ORDERS) do
		CLIENT_ICON_TEXTURE_CODES[clientToken] = _G.BNet_GetClientEmbeddedTexture(clientToken, CLIENT_ICON_SIZE, CLIENT_ICON_SIZE)
	end
end

local CLASS_COLORS = {}
do
	for classToken, localizedName in pairs(_G.FillLocalizedClassList({}, true)) do
		local color = _G.RAID_CLASS_COLORS[classToken]
		CLASS_COLORS[localizedName] = ("%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
	end

	for classToken, localizedName in pairs(_G.FillLocalizedClassList({}, false)) do
		local color = _G.RAID_CLASS_COLORS[classToken]
		CLASS_COLORS[localizedName] = ("%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
	end
end -- do-blcok

local BROADCAST_ICON = [[|TInterface\FriendsFrame\BroadcastIcon:0|t]]

local FRIENDS_WOW_NAME_COLOR = _G.FRIENDS_WOW_NAME_COLOR_CODE:gsub("|cff", "")

local PLAYER_FACTION = _G.UnitFactionGroup("player")
local PLAYER_REALM = _G.GetRealmName()

local function CreateIcon(texture_path, icon_size)
	return ("|T%s:%d|t"):format(texture_path, icon_size)
end

local COLUMN_ICON_GAME = CreateIcon([[Interface\Buttons\UI-GroupLoot-Dice-Up]], 0)
local COLUMN_ICON_LEVEL = CreateIcon([[Interface\GROUPFRAME\UI-GROUP-MAINASSISTICON]], 0)

local FACTION_ICON_SIZE = 18

local FACTION_ICON_ALLIANCE = CreateIcon([[Interface\COMMON\icon-alliance]], FACTION_ICON_SIZE)
local FACTION_ICON_HORDE = CreateIcon([[Interface\COMMON\icon-horde]], FACTION_ICON_SIZE)
local FACTION_ICON_NEUTRAL = CreateIcon([[Interface\COMMON\Indicator-Gray]], FACTION_ICON_SIZE)

local PLAYER_ICON_GROUP = [[|TInterface\Scenarios\ScenarioIcon-Check:0|t]]
local PLAYER_ICON_FACTION = PLAYER_FACTION == "Horde" and FACTION_ICON_HORDE or (PLAYER_FACTION == "Alliance" and FACTION_ICON_ALLIANCE) or FACTION_ICON_NEUTRAL

local SECTION_ICON_DISABLED = CreateIcon([[Interface\COMMON\Indicator-Red]], 0)
local SECTION_ICON_ENABLED = CreateIcon([[Interface\COMMON\Indicator-Green]], 0)

local SORT_ICON_ASCENDING = CreateIcon([[Interface\Buttons\Arrow-Up-Up]], 0)
local SORT_ICON_DESCENDING = CreateIcon([[Interface\Buttons\Arrow-Down-Up]], 0)

local STATUS_ICON_AFK = CreateIcon(_G.FRIENDS_TEXTURE_AFK, 0)
local STATUS_ICON_DND = CreateIcon(_G.FRIENDS_TEXTURE_DND, 0)
local STATUS_ICON_MOBILE_AWAY = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat-AwayMobile]], 0)
local STATUS_ICON_MOBILE_BUSY = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat-BusyMobile]], 0)
local STATUS_ICON_MOBILE_ONLINE = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat]], 0)
local STATUS_ICON_NOTE = CreateIcon(_G.FRIENDS_TEXTURE_OFFLINE, 0)
local STATUS_ICON_ONLINE = CreateIcon(_G.FRIENDS_TEXTURE_ONLINE, 0)

local TAB_TOGGLES = {
	FRIENDS = 1,
	WHO = 2,
	CHAT = 3,
	RAID = 4,
}

local TitleFont = _G.CreateFont("FrenemyTitleFont")
TitleFont:SetTextColor(0.510, 0.773, 1.0)
TitleFont:SetFontObject("QuestTitleFont")

local REQUEST_UPDATE_INTERVAL = 30

local SORT_ORDER_ASCENDING = 1
local SORT_ORDER_DESCENDING = 2

local SORT_ORDER_NAMES = {
	[SORT_ORDER_ASCENDING] = "Ascending",
	[SORT_ORDER_DESCENDING] = "Descending",
}

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local DB
local Tooltip

-- Statistics: Populated and maintained in UpdateStatistics()
local OnlineBattleNetCount
local TotalBattleNetCount

local OnlineFriendsCount
local TotalFriendsCount

local OnlineGuildMembersCount
local TotalGuildMembersCount

-------------------------------------------------------------------------------
-- Enumerations and data for sorting.
-------------------------------------------------------------------------------
-- Changing the order will cause SavedVariables to no longer map appropriately.
local SortFields = {
	BattleNetApp = {
		"GameText",
		"PresenceName",
		"ToonName",
	},
	BattleNetGames = {
		"ClientIndex",
		"GameText",
		"PresenceName",
		"ToonName",
	},
	Guild = {
		"Level",
		"RankIndex",
		"ToonName",
		"ZoneName",
	},
	WoWFriends = {
		"Level",
		"PresenceName",
		"RealmName",
		"ToonName",
		"ZoneName",
	},
}

local function EnumerateSortFieldNames(sortFieldNames)
	local enumeration = {}

	for index = 1, #sortFieldNames do
		enumeration[sortFieldNames[index]] = index
	end

	return enumeration
end

local SortFieldIDs = {}
local SortFieldNames = {}
local SortFunctions = {}

for sectionName, fieldNameList in pairs(SortFields) do
	local IDList = {}
	SortFieldIDs[sectionName] = IDList

	local nameList = {}
	SortFieldNames[sectionName] = nameList

	for index = 1, #fieldNameList do
		IDList[fieldNameList[index]] = index
		nameList[index] = fieldNameList[index]

		local sortFuncName = sectionName .. fieldNameList[index]
		SortFunctions[sortFuncName .. SORT_ORDER_NAMES[SORT_ORDER_ASCENDING]] = function(a, b)
			if a[fieldNameList[index]] == b[fieldNameList[index]] then
				return a.ToonName < b.ToonName
			end

			return a[fieldNameList[index]] < b[fieldNameList[index]]
		end

		SortFunctions[sortFuncName .. SORT_ORDER_NAMES[SORT_ORDER_DESCENDING]] = function(a, b)
			if a[fieldNameList[index]] == b[fieldNameList[index]] then
				return a.ToonName > b.ToonName
			end

			return a[fieldNameList[index]] > b[fieldNameList[index]]
		end
	end
end

-------------------------------------------------------------------------------
-- Default settings
-------------------------------------------------------------------------------
local DB_DEFAULTS = {
	global = {
		DataObject = {
			MinimapIcon = {
				hide = false,
			},
		},
		Tooltip = {
			CollapsedSections = {
				BattleNetApp = false,
				BattleNetGames = false,
				Guild = false,
				WoWFriends = false,
			},
			HideDelay = 0.25,
			Scale = 1,
			Sorting = {
				BattleNetApp = {
					Field = SortFieldIDs.BattleNetApp.PresenceName,
					Order = SORT_ORDER_ASCENDING,
				},
				BattleNetGames = {
					Field = SortFieldIDs.BattleNetGames.PresenceName,
					Order = SORT_ORDER_ASCENDING,
				},
				Guild = {
					Field = SortFieldIDs.Guild.ToonName,
					Order = SORT_ORDER_ASCENDING,
				},
				WoWFriends = {
					Field = SortFieldIDs.WoWFriends.ToonName,
					Order = SORT_ORDER_ASCENDING,
				},
			},
		},
	}
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function IsGrouped(name)
	return (_G.GetNumSubgroupMembers() > 0 and _G.UnitInParty(name)) or (_G.GetNumGroupMembers() > 0 and _G.UnitInRaid(name))
end

local function PercentColorGradient(min, max)
	local red_low, green_low, blue_low = 1, 0.10, 0.10
	local red_mid, green_mid, blue_mid = 1, 1, 0
	local red_high, green_high, blue_high = 0.25, 0.75, 0.25
	local percentage = min / max

	if percentage >= 1 then
		return red_high, green_high, blue_high
	elseif percentage <= 0 then
		return red_low, green_low, blue_low
	end
	local integral, fractional = math.modf(percentage * 2)

	if integral == 1 then
		red_low, green_low, blue_low, red_mid, green_mid, blue_mid = red_mid, green_mid, blue_mid, red_high, green_high, blue_high
	end
	return red_low + (red_mid - red_low) * fractional, green_low + (green_mid - green_low) * fractional, blue_low + (blue_mid - blue_low) * fractional
end

local function ColorPlayerLevel(level)
	if not level or level == "" or type(level) ~= "number" then
		return level
	end
	local r, g, b = PercentColorGradient(level, _G.MAX_PLAYER_LEVEL)
	return ("|cff%02x%02x%02x%d|r"):format(r * 255, g * 255, b * 255, level)
end

local function UpdateStatistics()
	TotalBattleNetCount, OnlineBattleNetCount = _G.BNGetNumFriends()
	TotalFriendsCount, OnlineFriendsCount = _G.GetNumFriends()

	if _G.IsInGuild() then
		local _
		TotalGuildMembersCount, _, OnlineGuildMembersCount = _G.GetNumGuildMembers()
	end
end

-------------------------------------------------------------------------------
-- Tooltip.
-------------------------------------------------------------------------------
local DrawTooltip
do
	local BattleNetColumns = {
		Client = 1,
		PresenceName = 2,
		ToonName = 3,
		GameText = 4,
	}

	local BattleNetColSpans = {
		Client = 1,
		PresenceName = 1,
		ToonName = 1,
		GameText = 2,
	}

	local GuildColumns = {
		Level = 1,
		ToonName = 2,
		Rank = 3,
		ZoneName = 4,
	}

	local GuildColSpans = {
		Level = 1,
		ToonName = 1,
		Rank = 1,
		ZoneName = 1,
	}

	local WoWFriendsColumns = {
		Level = 1,
		PresenceName = 2,
		ToonName = 3,
		ZoneName = 4,
		RealmName = 5,
	}

	local WoWFriendsColSpans = {
		Level = 1,
		PresenceName = 1,
		ToonName = 1,
		ZoneName = 1,
		RealmName = 1,
	}

	local PlayerLists = {
		BattleNetApp = {},
		BattleNetGames = {},
		Guild = {},
		WoWFriends = {},
	}

	local NUM_TOOLTIP_COLUMNS = 8

	local TooltipAnchor

	-------------------------------------------------------------------------------
	-- Data compilation.
	-------------------------------------------------------------------------------
	local function GenerateTooltipData()
		for name, data in pairs(PlayerLists) do
			table.wipe(data)
		end

		if OnlineFriendsCount > 0 then
			for friend_index = 1, OnlineFriendsCount do
				local toonName, level, class, zoneName, connected, status, note = _G.GetFriendInfo(friend_index)

				table.insert(PlayerLists.WoWFriends, {
					Class = class,
					Level = level,
					Note = note and STATUS_ICON_NOTE .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. note .. "|r" or nil,
					PresenceName = _G.NOT_APPLICABLE,
					RealmName = PLAYER_REALM,
					StatusIcon = status == _G.CHAT_FLAG_AFK and STATUS_ICON_AFK or (status == _G.CHAT_FLAG_DND and STATUS_ICON_DND or STATUS_ICON_ONLINE),
					ToonName = toonName,
					ZoneName = zoneName,
				})
			end
		end

		if OnlineBattleNetCount > 0 then
			for battleNetIndex = 1, OnlineBattleNetCount do
				local presenceID, presenceName, battleTag, isBattleTagPresence, toonName, toonID, client, _, _, isAFK, isDND, broadcastText, noteText, isRIDFriend, broadcastTime = _G.BNGetFriendInfo(battleNetIndex)
				local _, realmName, faction, class, zoneName, level, gameText

				if toonID then
					_, _, _, realmName, _, faction, _, class, _, zoneName, level, gameText = _G.BNGetToonInfo(toonID)
				end

				local characterName = toonName or _G.UNKNOWN
				if presenceName then
					characterName = characterName or battleTag
				end

				local entry = {
					BroadcastText = (broadcastText and broadcastText ~= "") and BROADCAST_ICON .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. broadcastText .. "|r" or nil,
					Class = class,
					Client = client,
					ClientIndex = CLIENT_SORT_ORDERS[client],
					FactionIcon = faction and faction == "Horde" and FACTION_ICON_HORDE or (faction == "Alliance" and FACTION_ICON_ALLIANCE) or FACTION_ICON_NEUTRAL,
					GameText = gameText or "",
					Level = level and tonumber(level) or 0,
					Note = noteText and STATUS_ICON_NOTE .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. noteText .. "|r" or nil,
					PresenceID = presenceID,
					PresenceName = presenceName or _G.UNKNOWN,
					RealmName = realmName or "",
					StatusIcon = isAFK and STATUS_ICON_AFK or (isDND and STATUS_ICON_DND or STATUS_ICON_ONLINE),
					ToonName = characterName,
					ZoneName = zoneName or "",
				}

				if client == _G.BNET_CLIENT_WOW then
					table.insert(PlayerLists.WoWFriends, entry)
				elseif client == BNET_CLIENT_APP then
					table.insert(PlayerLists.BattleNetApp, entry)
				elseif toonID then
					table.insert(PlayerLists.BattleNetGames, entry)
				end
			end
		end

		if _G.IsInGuild() then
			for index = 1, _G.GetNumGuildMembers() do
				local toonName, rank, rankIndex, level, class, zoneName, note, officerNote, isOnline, status, _, _, _, isMobile = _G.GetGuildRosterInfo(index)

				if isOnline or isMobile then
					if status == 0 then
						status = isMobile and STATUS_ICON_MOBILE_ONLINE or STATUS_ICON_ONLINE
					elseif status == 1 then
						status = isMobile and STATUS_ICON_MOBILE_AWAY or STATUS_ICON_AFK
					elseif status == 2 then
						status = isMobile and STATUS_ICON_MOBILE_BUSY or STATUS_ICON_DND
					end

					table.insert(PlayerLists.Guild, {
						Class = class,
						IsMobile = isMobile,
						Level = level,
						Note = (note and note ~= "") and STATUS_ICON_NOTE .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. note .. "|r" or nil,
						OfficerNote = (officerNote and officerNote ~= "") and STATUS_ICON_NOTE .. _G.ORANGE_FONT_COLOR_CODE .. officerNote .. "|r" or nil,
						Rank = rank,
						RankIndex = rankIndex,
						StatusIcon = status,
						ToonName = _G.Ambiguate(toonName, "guild"),
						ZoneName = isMobile and _G.REMOTE_CHAT or zoneName,
					})
				end
			end
		end

		for listName, list in pairs(PlayerLists) do
			local savedSortField = DB.Tooltip.Sorting[listName]
			table.sort(list, SortFunctions[listName .. SortFieldNames[listName][savedSortField.Field] .. SORT_ORDER_NAMES[savedSortField.Order]])
		end
	end

	-------------------------------------------------------------------------------
	-- Controls
	-------------------------------------------------------------------------------
	local function BattleNetFriend_OnMouseUp(tooltipCell, playerEntry, button)
		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		if button == "LeftButton" then
			if not _G.BNIsSelf(playerEntry.PresenceID) then
				_G.ChatFrame_SendSmartTell(playerEntry.PresenceName)
			end
		elseif button == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.FriendsFrame_ShowBNDropdown(playerEntry.PresenceName, true, nil, nil, nil, true, playerEntry.PresenceID)
		end
	end

	local function GuildMember_OnMouseUp(tooltipCell, playerEntry, button)
		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		if button == "LeftButton" then
			_G.ChatFrame_SendTell(playerEntry.ToonName)
		elseif button == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.GuildRoster_ShowMemberDropDown(playerEntry.ToonName, true, playerEntry.IsMobile)
		end
	end

	local function WoWFriend_OnMouseUp(tooltipCell, playerEntry, button)
		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		if button == "LeftButton" then
			_G.ChatFrame_SendTell(playerEntry.ToonName)
		elseif button == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.FriendsFrame_ShowDropdown(playerEntry.ToonName, true, nil, nil, nil, true)
		end
	end

	local ToggleColumnSortMethod
	do
		function ToggleColumnSortMethod(tooltipCell, sortFieldData)
			local sectionName, fieldName = (":"):split(sortFieldData)

			if not sectionName or not fieldName then
				return
			end

			local savedSortField = DB.Tooltip.Sorting[sectionName]
			local columnSortFieldID = SortFieldIDs[sectionName][fieldName]

			if savedSortField.Field == columnSortFieldID then
				savedSortField.Order = savedSortField.Order == SORT_ORDER_ASCENDING and SORT_ORDER_DESCENDING or SORT_ORDER_ASCENDING
			else
				savedSortField = DB.Tooltip.Sorting[sectionName]
				savedSortField.Field = columnSortFieldID
				savedSortField.Order = SORT_ORDER_ASCENDING
			end

			table.sort(PlayerLists[sectionName], SortFunctions[sectionName .. fieldName .. SORT_ORDER_NAMES[savedSortField.Order]])
			DrawTooltip(TooltipAnchor)
		end
	end

	local function ToggleSectionVisibility(tooltipCell, sectionName)
		DB.Tooltip.CollapsedSections[sectionName] = not DB.Tooltip.CollapsedSections[sectionName]
		DrawTooltip(TooltipAnchor)
	end

	-------------------------------------------------------------------------------
	-- Display rendering
	-------------------------------------------------------------------------------
	local function ColumnLabel(label, data)
		local sectionName, fieldName = (":"):split(data)

		if DB.Tooltip.Sorting[sectionName].Field == SortFieldIDs[sectionName][fieldName] then
			return (DB.Tooltip.Sorting[sectionName].Order == SORT_ORDER_ASCENDING and SORT_ICON_ASCENDING or SORT_ICON_DESCENDING) .. label
		end

		return label
	end

	local function RenderBattleNetLines(sourceListName, headerLine)
		Tooltip:SetLineColor(headerLine, 0, 0, 0, 1)
		Tooltip:SetCell(headerLine, BattleNetColumns.PresenceName, ColumnLabel(_G.BATTLENET_FRIEND, sourceListName .. ":PresenceName"), BattleNetColSpans.PresenceName)
		Tooltip:SetCell(headerLine, BattleNetColumns.ToonName, ColumnLabel(_G.NAME, sourceListName .. ":ToonName"), BattleNetColSpans.ToonName)
		Tooltip:SetCell(headerLine, BattleNetColumns.GameText, ColumnLabel(_G.INFO, sourceListName .. ":GameText"), BattleNetColSpans.GameText)

		Tooltip:SetCellScript(headerLine, BattleNetColumns.PresenceName, "OnMouseUp", ToggleColumnSortMethod, sourceListName .. ":PresenceName")
		Tooltip:SetCellScript(headerLine, BattleNetColumns.ToonName, "OnMouseUp", ToggleColumnSortMethod, sourceListName .. ":ToonName")
		Tooltip:SetCellScript(headerLine, BattleNetColumns.GameText, "OnMouseUp", ToggleColumnSortMethod, sourceListName .. ":GameText")

		Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

		for index = 1, #PlayerLists[sourceListName] do
			local player = PlayerLists[sourceListName][index]
			local line = Tooltip:AddLine()
			Tooltip:SetCell(line, BattleNetColumns.Client, CLIENT_ICON_TEXTURE_CODES[player.Client], BattleNetColSpans.Client)
			Tooltip:SetCell(line, BattleNetColumns.PresenceName, ("%s%s%s|r"):format(player.StatusIcon, _G.FRIENDS_BNET_NAME_COLOR_CODE, player.PresenceName), BattleNetColSpans.PresenceName)
			Tooltip:SetCell(line, BattleNetColumns.ToonName, ("%s%s|r"):format(_G.FRIENDS_OTHER_NAME_COLOR_CODE, player.ToonName), BattleNetColSpans.ToonName)
			Tooltip:SetCell(line, BattleNetColumns.GameText, player.GameText, BattleNetColSpans.GameText)

			Tooltip:SetCellScript(line, BattleNetColumns.PresenceName, "OnMouseUp", BattleNetFriend_OnMouseUp, player)

			if player.Note then
				Tooltip:SetCell(Tooltip:AddLine(), BattleNetColumns.Client, player.Note, "GameTooltipTextSmall", 0)
			end

			if player.BroadcastText then
				Tooltip:SetCell(Tooltip:AddLine(), BattleNetColumns.Client, player.BroadcastText, "GameTooltipTextSmall", 0)
			end
		end

		Tooltip:AddLine(" ")
	end

	local function Tooltip_OnRelease(self)
		_G.HideDropDownMenu(1)

		Tooltip:SetFrameStrata("TOOLTIP") -- This can be set to DIALOG by various functions.
		Tooltip = nil
		TooltipAnchor = nil
	end

	function DrawTooltip(anchorFrame)
		if not anchorFrame then
			return
		end

		TooltipAnchor = anchorFrame
		GenerateTooltipData()

		if not Tooltip then
			Tooltip = LibQTip:Acquire(FOLDER_NAME, NUM_TOOLTIP_COLUMNS)
			Tooltip:SetAutoHideDelay(DB.Tooltip.HideDelay, anchorFrame)
			Tooltip:SetBackdropColor(0.05, 0.05, 0.05, 1)
			Tooltip:SetScale(DB.Tooltip.Scale)
			Tooltip:SmartAnchorTo(anchorFrame)

			Tooltip.OnRelease = Tooltip_OnRelease
		end

		Tooltip:Clear()
		Tooltip:SetCellMarginH(0)
		Tooltip:SetCellMarginV(1)

		Tooltip:SetCell(Tooltip:AddLine(), 1, FOLDER_NAME, TitleFont, "CENTER", 0)
		Tooltip:AddSeparator(1, 0.510, 0.773, 1.0)

		if OnlineBattleNetCount > 0 or OnlineFriendsCount > 0 then
			-------------------------------------------------------------------------------
			-- WoW Friends
			-------------------------------------------------------------------------------
			if #PlayerLists.WoWFriends > 0 then
				local line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.WoWFriends then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.FRIENDS, SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "WoWFriends")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					line = Tooltip:AddLine()
					Tooltip:SetLineColor(line, 0, 0, 0, 1)
					Tooltip:SetCell(line, WoWFriendsColumns.Level, ColumnLabel(COLUMN_ICON_LEVEL, "WoWFriends:Level"), WoWFriendsColSpans.Level)
					Tooltip:SetCell(line, WoWFriendsColumns.PresenceName, ColumnLabel(_G.BATTLENET_FRIEND, "WoWFriends:PresenceName"), WoWFriendsColSpans.PresenceName)
					Tooltip:SetCell(line, WoWFriendsColumns.ToonName, ColumnLabel(_G.NAME, "WoWFriends:ToonName"), WoWFriendsColSpans.ToonName)
					Tooltip:SetCell(line, WoWFriendsColumns.ZoneName, ColumnLabel(_G.ZONE, "WoWFriends:ZoneName"), WoWFriendsColSpans.ZoneName)
					Tooltip:SetCell(line, WoWFriendsColumns.RealmName, ColumnLabel(_G.FRIENDS_LIST_REALM, "WoWFriends:RealmName"), WoWFriendsColSpans.RealmName)

					Tooltip:SetCellScript(line, WoWFriendsColumns.Level, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Level")
					Tooltip:SetCellScript(line, WoWFriendsColumns.PresenceName, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:PresenceName")
					Tooltip:SetCellScript(line, WoWFriendsColumns.ToonName, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:ToonName")
					Tooltip:SetCellScript(line, WoWFriendsColumns.ZoneName, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:ZoneName")
					Tooltip:SetCellScript(line, WoWFriendsColumns.RealmName, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:RealmName")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					for index = 1, #PlayerLists.WoWFriends do
						local player = PlayerLists.WoWFriends[index]
						local groupIndicator = IsGrouped(player.ToonName) and PLAYER_ICON_GROUP or ""
						local nameColor = CLASS_COLORS[player.Class] or FRIENDS_WOW_NAME_COLOR
						local presenceName = player.PresenceName ~= _G.NOT_APPLICABLE and ("%s%s|r"):format(_G.FRIENDS_BNET_NAME_COLOR_CODE, player.PresenceName) or player.PresenceName

						line = Tooltip:AddLine()
						Tooltip:SetCell(line, WoWFriendsColumns.Level, ColorPlayerLevel(player.Level), WoWFriendsColSpans.Level)
						Tooltip:SetCell(line, WoWFriendsColumns.PresenceName, ("%s%s"):format(player.StatusIcon, presenceName), WoWFriendsColSpans.PresenceName)
						Tooltip:SetCell(line, WoWFriendsColumns.ToonName, ("%s|cff%s%s|r%s"):format(player.FactionIcon or PLAYER_ICON_FACTION, nameColor, player.ToonName, groupIndicator), WoWFriendsColSpans.ToonName)
						Tooltip:SetCell(line, WoWFriendsColumns.ZoneName, player.ZoneName, WoWFriendsColSpans.ZoneName)
						Tooltip:SetCell(line, WoWFriendsColumns.RealmName, player.RealmName, WoWFriendsColSpans.RealmName)

						if player.PresenceID then
							Tooltip:SetCellScript(line, WoWFriendsColumns.PresenceName, "OnMouseUp", BattleNetFriend_OnMouseUp, player)
						else
							Tooltip:SetCellScript(line, WoWFriendsColumns.ToonName, "OnMouseUp", WoWFriend_OnMouseUp, player)
						end

						if player.Note then
							line = Tooltip:AddLine()
							Tooltip:SetCell(line, WoWFriendsColumns.Level, player.Note, "GameTooltipTextSmall", 0)
						end

						if player.BroadcastText then
							line = Tooltip:AddLine()
							Tooltip:SetCell(line, WoWFriendsColumns.Level, player.BroadcastText, "GameTooltipTextSmall", 0)
						end
					end

					Tooltip:AddLine(" ")
				else
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, _G.FRIENDS, SECTION_ICON_DISABLED), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "WoWFriends")
				end
			end

			-------------------------------------------------------------------------------
			-- BattleNet In-Game Friends
			-------------------------------------------------------------------------------
			if #PlayerLists.BattleNetGames > 0 then
				local line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.BattleNetGames then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetGames")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					line = Tooltip:AddLine()
					Tooltip:SetCell(line, BattleNetColumns.Client, ColumnLabel(COLUMN_ICON_GAME, "BattleNetGames:ClientIndex"))

					Tooltip:SetCellScript(line, BattleNetColumns.Client, "OnMouseUp", ToggleColumnSortMethod, "BattleNetGames:ClientIndex")

					RenderBattleNetLines("BattleNetGames", line)
				else
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), SECTION_ICON_DISABLED), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetGames")
				end
			end

			-------------------------------------------------------------------------------
			-- BattleNet Friends
			-------------------------------------------------------------------------------
			if #PlayerLists.BattleNetApp > 0 then
				local line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.BattleNetApp then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.BATTLENET_OPTIONS_LABEL, SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetApp")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					RenderBattleNetLines("BattleNetApp", Tooltip:AddLine())
				else
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, _G.BATTLENET_OPTIONS_LABEL, SECTION_ICON_DISABLED), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetApp")
				end
			end
		end

		-------------------------------------------------------------------------------
		-- Guild
		-------------------------------------------------------------------------------
		local guildMOTD

		if #PlayerLists.Guild > 0 then
			local line = Tooltip:AddLine()

			if not DB.Tooltip.CollapsedSections.Guild then
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.GetGuildInfo("player"), SECTION_ICON_ENABLED), "GameFontNormal", "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "Guild")

				Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

				line = Tooltip:AddLine()
				Tooltip:SetLineColor(line, 0, 0, 0, 1)
				Tooltip:SetCell(line, GuildColumns.Level, ColumnLabel(COLUMN_ICON_LEVEL, "Guild:Level"), GuildColSpans.ToonName)
				Tooltip:SetCell(line, GuildColumns.ToonName, ColumnLabel(_G.NAME, "Guild:ToonName"), GuildColSpans.ToonName)
				Tooltip:SetCell(line, GuildColumns.Rank, ColumnLabel(_G.RANK, "Guild:RankIndex"), GuildColSpans.Rank)
				Tooltip:SetCell(line, GuildColumns.ZoneName, ColumnLabel(_G.ZONE, "Guild:ZoneName"), GuildColSpans.ZoneName)

				Tooltip:SetCellScript(line, GuildColumns.Level, "OnMouseUp", ToggleColumnSortMethod, "Guild:Level")
				Tooltip:SetCellScript(line, GuildColumns.ToonName, "OnMouseUp", ToggleColumnSortMethod, "Guild:ToonName")
				Tooltip:SetCellScript(line, GuildColumns.Rank, "OnMouseUp", ToggleColumnSortMethod, "Guild:RankIndex")
				Tooltip:SetCellScript(line, GuildColumns.ZoneName, "OnMouseUp", ToggleColumnSortMethod, "Guild:ZoneName")

				Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

				for index = 1, #PlayerLists.Guild do
					local player = PlayerLists.Guild[index]

					line = Tooltip:AddLine()
					Tooltip:SetCell(line, GuildColumns.Level, ColorPlayerLevel(player.Level), GuildColSpans.Level)
					Tooltip:SetCell(line, GuildColumns.ToonName, ("%s|cff%s%s|r%s"):format(player.StatusIcon, CLASS_COLORS[player.Class] or "ffffff", player.ToonName, IsGrouped(player.ToonName) and PLAYER_ICON_GROUP or ""), GuildColSpans.ToonName)
					Tooltip:SetCell(line, GuildColumns.Rank, player.Rank, GuildColSpans.Rank)
					Tooltip:SetCell(line, GuildColumns.ZoneName, player.ZoneName or _G.UNKNOWN, GuildColSpans.ZoneName)

					if _G.IsAddOnLoaded("Blizzard_GuildUI") then
						Tooltip:SetCellScript(line, GuildColumns.ToonName, "OnMouseUp", GuildMember_OnMouseUp, player)
					end

					if player.Note then
						Tooltip:SetCell(Tooltip:AddLine(), GuildColumns.Level, player.Note, "GameTooltipTextSmall", 0)
					end

					if player.OfficerNote then
						Tooltip:SetCell(Tooltip:AddLine(), GuildColumns.Level, player.OfficerNote, "GameTooltipTextSmall", 0)
					end
				end

				local guildLevel, maxGuildLevel = _G.GetGuildLevel()

				if guildLevel ~= maxGuildLevel then
					local currentXP, nextLevelXP = _G.UnitGetGuildXP("player")
					local percentage = math.min((currentXP / nextLevelXP) * 100, 100)
					local r, g, b = PercentColorGradient(percentage, 100)

					Tooltip:AddLine(" ")

					Tooltip:SetCell(Tooltip:AddLine(), 1, ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, _G.GUILD_LEVEL:format(guildLevel)), "GameFontDisableSmall", "CENTER", 0)
					Tooltip:SetCell(Tooltip:AddLine(), 1, ("|cff%02x%02x%02x%d/%d (%d%%)|r"):format(r * 255, g * 255, b * 255, currentXP, nextLevelXP, percentage), "GameFontDisableSmall", "CENTER", 0)
				end

				guildMOTD = _G.GUILD_MOTD_TEMPLATE:format(_G.GREEN_FONT_COLOR_CODE .. _G.GetGuildRosterMOTD() .. "|r")
			else
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, _G.GetGuildInfo("player"), SECTION_ICON_DISABLED), "GameFontDisable", "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "Guild")
			end

			Tooltip:AddLine(" ")
		end

		Tooltip:Show()

		if guildMOTD and guildMOTD ~= "" then
			Tooltip:SetCell(Tooltip:AddLine(), 1, guildMOTD, 0, 0, 0, Tooltip:GetWidth() - 20)
			Tooltip:AddLine(" ")
		end

		Tooltip:UpdateScrolling()
	end
end -- do-block

-------------------------------------------------------------------------------
-- DataObject methods.
-------------------------------------------------------------------------------
function DataObject:OnClick(button)
	if _G.IsAltKeyDown() then
		_G.ToggleGuildFrame()
	else
		_G.ToggleFriendsFrame(TAB_TOGGLES.FRIENDS)
	end
end

function DataObject:OnEnter()
	DrawTooltip(self)
end

function DataObject.OnLeave()
	-- Null operation: Some LDB displays get cranky if this method is missing.
end

function DataObject:UpdateDisplay()
	local output = ("%s%s: %d|r, "):format(_G.NORMAL_FONT_COLOR_CODE, _G.FRIENDS, OnlineFriendsCount)
	output = ("%s%s%s: %d|r"):format(output, _G.BATTLENET_FONT_COLOR_CODE, _G.BATTLENET_FRIEND, OnlineBattleNetCount)

	if _G.IsInGuild() then
		output = ("%s, %s%s: %d|r"):format(output, _G.GREEN_FONT_COLOR_CODE, _G.GUILD, OnlineGuildMembersCount)
	end

	self.text = output
end

-------------------------------------------------------------------------------
-- Events.
-------------------------------------------------------------------------------
local function UpdateAndDisplay()
	UpdateStatistics()
	DataObject:UpdateDisplay()

	if Tooltip and Tooltip:IsShown() then
		DrawTooltip(DataObject)
	end
end

Frenemy.BN_TOON_NAME_UPDATED = UpdateAndDisplay
Frenemy.BN_FRIEND_INFO_CHANGED = UpdateAndDisplay
Frenemy.FRIENDLIST_UPDATE = UpdateAndDisplay
Frenemy.GUILD_RANKS_UPDATE = UpdateAndDisplay
Frenemy.GUILD_ROSTER_UPDATE = UpdateAndDisplay

-------------------------------------------------------------------------------
-- Framework.
-------------------------------------------------------------------------------
local function CreateUpdater(parent_frame, interval, loop_func)
	local updater = parent_frame:CreateAnimationGroup()
	updater:CreateAnimation("Animation"):SetDuration(interval)
	updater:SetScript("OnLoop", loop_func)
	updater:SetLooping("REPEAT")

	return updater
end

local function RequestUpdates()
	_G.ShowFriends()

	if _G.IsInGuild() then
		_G.GuildRoster()
	end
end

function Frenemy:OnInitialize()
	DB = LibStub("AceDB-3.0"):New(FOLDER_NAME .. "DB", DB_DEFAULTS, true).global
end

function Frenemy:OnEnable()
	if LDBIcon then
		LDBIcon:Register(FOLDER_NAME, DataObject, DB.DataObject.MinimapIcon)
	end

	self:RegisterEvent("BN_FRIEND_INFO_CHANGED")
	self:RegisterEvent("BN_TOON_NAME_UPDATED")
	self:RegisterEvent("FRIENDLIST_UPDATE")
	self:RegisterEvent("GUILD_RANKS_UPDATE")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")

	RequestUpdates()
	self.RequestUpdater = CreateUpdater(RequestUpdater, REQUEST_UPDATE_INTERVAL, RequestUpdates)
	self.RequestUpdater:Play()
end

