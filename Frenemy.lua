-------------------------------------------------------------------------------
-- Localized Lua globals.
-------------------------------------------------------------------------------
local _G = getfenv(0)

local math = _G.math
local string = _G.string
local table = _G.table

local pairs = _G.pairs
local tonumber = _G.tonumber

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

local GROUP_CHECKMARK = [[|TInterface\Buttons\UI-CheckBox-Check:0|t]]

local PLAYER_FACTION = _G.UnitFactionGroup("player")
local PLAYER_REALM = _G.GetRealmName()

local function CreateIcon(texture_path, icon_size)
	return ("|T%s:%d|t"):format(texture_path, icon_size)
end

local FACTION_ICON_SIZE = 18

local FACTION_ICON_ALLIANCE = CreateIcon([[Interface\COMMON\icon-alliance]], FACTION_ICON_SIZE)
local FACTION_ICON_HORDE = CreateIcon([[Interface\COMMON\icon-horde]], FACTION_ICON_SIZE)
local FACTION_ICON_NEUTRAL = CreateIcon([[Interface\COMMON\Indicator-Gray]], FACTION_ICON_SIZE)

local PLAYER_FACTION_ICON = PLAYER_FACTION == "Horde" and FACTION_ICON_HORDE or (PLAYER_FACTION == "Alliance" and FACTION_ICON_ALLIANCE) or FACTION_ICON_NEUTRAL

local COLUMN_ICON_SIZE = 16

local COLUMN_ICON_GAME = CreateIcon([[Interface\Buttons\UI-GroupLoot-Dice-Up]], COLUMN_ICON_SIZE)
local COLUMN_ICON_LEVEL = CreateIcon([[Interface\GROUPFRAME\UI-GROUP-MAINASSISTICON]], COLUMN_ICON_SIZE)

local STATUS_ICON_SIZE = 12

local SECTION_ICON_BULLET = CreateIcon([[Interface\QUESTFRAME\UI-Quest-BulletPoint]], STATUS_ICON_SIZE)

local STATUS_ICON_AFK = CreateIcon(_G.FRIENDS_TEXTURE_AFK, STATUS_ICON_SIZE)
local STATUS_ICON_DND = CreateIcon(_G.FRIENDS_TEXTURE_DND, STATUS_ICON_SIZE)
local STATUS_ICON_MOBILE_AWAY = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat-AwayMobile]], STATUS_ICON_SIZE)
local STATUS_ICON_MOBILE_BUSY = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat-BusyMobile]], STATUS_ICON_SIZE)
local STATUS_ICON_MOBILE_ONLINE = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat]], STATUS_ICON_SIZE)
local STATUS_ICON_NOTE = CreateIcon(_G.FRIENDS_TEXTURE_OFFLINE, STATUS_ICON_SIZE)
local STATUS_ICON_ONLINE = CreateIcon(_G.FRIENDS_TEXTURE_ONLINE, STATUS_ICON_SIZE)

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

-------------------------------------------------------------------------------
-- Enumerations.
-------------------------------------------------------------------------------
local function EnumerateSortFieldNames(sortFieldNames)
	local enumeration = {}

	for index = 1, #sortFieldNames do
		enumeration[sortFieldNames[index]] = index
	end

	return enumeration
end

local BattleNetAppSortFieldNames = {
	"GameText",
	"PresenceName",
	"ToonName",
}

local BattleNetGamesSortFieldNames = {
	"Client",
}

for index = 1, #BattleNetAppSortFieldNames do
	BattleNetGamesSortFieldNames[#BattleNetGamesSortFieldNames + 1] = BattleNetAppSortFieldNames[index]
end

local GuildSortFieldNames = {
	"Level",
	"RankIndex",
	"ToonName",
	"ZoneName",
}

local WoWFriendsSortFieldNames = {
	"Level",
	"PresenceName",
	"RealmName",
	"ToonName",
	"ZoneName",
}

local BattleNetAppSortFields = EnumerateSortFieldNames(BattleNetAppSortFieldNames)
local BattleNetGamesSortFields = EnumerateSortFieldNames(BattleNetGamesSortFieldNames)
local GuildSortFields = EnumerateSortFieldNames(GuildSortFieldNames)
local WoWFriendsSortFields = EnumerateSortFieldNames(WoWFriendsSortFieldNames)

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
		},
	}
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

	local BattleNetAppList = {}
	local BattleNetGamesList = {}
	local GuildList = {}
	local WoWFriendsList = {}

	local NUM_TOOLTIP_COLUMNS = 8

	local TooltipAnchor

	local function ClientSort(a, b)
		if CLIENT_SORT_ORDERS[a.Client] < CLIENT_SORT_ORDERS[b.Client] then
			return true
		elseif CLIENT_SORT_ORDERS[a.Client] > CLIENT_SORT_ORDERS[b.Client] then
			return false
		else
			return a.ToonName < b.ToonName
		end
	end

	-------------------------------------------------------------------------------
	-- Data compilation.
	-------------------------------------------------------------------------------
	local function GenerateTooltipData()
		table.wipe(BattleNetAppList)
		table.wipe(BattleNetGamesList)
		table.wipe(GuildList)
		table.wipe(WoWFriendsList)

		if OnlineFriendsCount > 0 then

			for friend_index = 1, OnlineFriendsCount do
				local toonName, level, class, zoneName, connected, status, note = _G.GetFriendInfo(friend_index)

				table.insert(WoWFriendsList, {
					Class = class,
					Level = level,
					Note = note and STATUS_ICON_NOTE .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. note .. "|r" or nil,
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
					table.insert(WoWFriendsList, entry)
				elseif client == BNET_CLIENT_APP then
					table.insert(BattleNetAppList, entry)
				elseif toonID then
					table.insert(BattleNetGamesList, entry)
				end
			end

			table.sort(BattleNetGamesList, ClientSort)
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

					table.insert(GuildList, {
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
	end

	-------------------------------------------------------------------------------
	-- Controls
	-------------------------------------------------------------------------------
	local function ShowBattleNetFriendDropdownMenu(tooltipCell, playerEntry, button)
		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		if button == "LeftButton" then
			-- TODO
		elseif button == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.FriendsFrame_ShowBNDropdown(playerEntry.PresenceName, true, nil, nil, nil, true, playerEntry.PresenceID)
		end
	end

	local function ShowGuildMemberDropdown(tooltipCell, playerEntry, button)
		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		if button == "LeftButton" then
			-- TODO
		elseif button == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.GuildRoster_ShowMemberDropDown(playerEntry.ToonName, true, playerEntry.IsMobile)
		end
	end

	local function ShowWoWFriendDropdownMenu(tooltipCell, playerEntry, button)
		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		if button == "LeftButton" then
			-- TODO
		elseif button == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.FriendsFrame_ShowDropdown(playerEntry.ToonName, true, nil, nil, nil, true)
		end
	end

	local function ToggleSectionVisibility(tooltipCell, sectionName)
		DB.Tooltip.CollapsedSections[sectionName] = not DB.Tooltip.CollapsedSections[sectionName]
		DrawTooltip(TooltipAnchor)
	end

	-------------------------------------------------------------------------------
	-- Display rendering
	-------------------------------------------------------------------------------
	local function RenderBattleNetLines(sourceList, headerLine)
		Tooltip:SetCell(headerLine, BattleNetColumns.PresenceName, _G.BATTLENET_FRIEND, BattleNetColSpans.PresenceName)
		Tooltip:SetCell(headerLine, BattleNetColumns.ToonName, _G.NAME, BattleNetColSpans.ToonName)
		Tooltip:SetCell(headerLine, BattleNetColumns.GameText, _G.INFO, BattleNetColSpans.GameText)

		Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

		for index = 1, #sourceList do
			local player = sourceList[index]
			local line = Tooltip:AddLine()
			Tooltip:SetCell(line, BattleNetColumns.Client, CLIENT_ICON_TEXTURE_CODES[player.Client], BattleNetColSpans.Client)
			Tooltip:SetCell(line, BattleNetColumns.PresenceName, ("%s%s%s|r"):format(player.StatusIcon, _G.FRIENDS_BNET_NAME_COLOR_CODE, player.PresenceName), BattleNetColSpans.PresenceName)
			Tooltip:SetCell(line, BattleNetColumns.ToonName, ("%s%s|r"):format(_G.FRIENDS_OTHER_NAME_COLOR_CODE, player.ToonName), BattleNetColSpans.ToonName)
			Tooltip:SetCell(line, BattleNetColumns.GameText, player.GameText, BattleNetColSpans.GameText)

			Tooltip:SetCellScript(line, BattleNetColumns.PresenceName, "OnMouseUp", ShowBattleNetFriendDropdownMenu, player)

			if player.Note then
				line = Tooltip:AddLine()
				Tooltip:SetCell(line, BattleNetColumns.Client, player.Note, "GameTooltipTextSmall", 0)
			end

			if player.BroadcastText then
				line = Tooltip:AddLine()
				Tooltip:SetCell(line, BattleNetColumns.Client, player.BroadcastText, "GameTooltipTextSmall", 0)
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

	function DrawTooltip(anchor_frame)
		if not anchor_frame then
			return
		end

		TooltipAnchor = anchor_frame
		GenerateTooltipData()

		if not Tooltip then
			Tooltip = LibQTip:Acquire(FOLDER_NAME, NUM_TOOLTIP_COLUMNS)
			Tooltip:SetAutoHideDelay(DB.Tooltip.HideDelay, anchor_frame)
			Tooltip:SetBackdropColor(0.05, 0.05, 0.05, 1)
			Tooltip:SetScale(DB.Tooltip.Scale)
			Tooltip:SmartAnchorTo(anchor_frame)

			Tooltip.OnRelease = Tooltip_OnRelease
		end

		Tooltip:Clear()
		Tooltip:SetCellMarginH(0)
		Tooltip:SetCellMarginV(1)

		local line = Tooltip:AddLine()
		Tooltip:SetCell(line, 1, FOLDER_NAME, TitleFont, "CENTER", 0)
		Tooltip:AddSeparator(1, 0.510, 0.773, 1.0)

		if OnlineBattleNetCount > 0 or OnlineFriendsCount > 0 then
			-------------------------------------------------------------------------------
			-- WoW Friends
			-------------------------------------------------------------------------------
			if #WoWFriendsList > 0 then
				line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.WoWFriends then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, _G.FRIENDS, SECTION_ICON_BULLET), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "WoWFriends")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					line = Tooltip:AddLine()
					Tooltip:SetLineColor(line, 0, 0, 0, 1)
					Tooltip:SetCell(line, WoWFriendsColumns.Level, COLUMN_ICON_LEVEL, WoWFriendsColSpans.Level)
					Tooltip:SetCell(line, WoWFriendsColumns.PresenceName, _G.BATTLENET_FRIEND, WoWFriendsColSpans.PresenceName)
					Tooltip:SetCell(line, WoWFriendsColumns.ToonName, _G.NAME, WoWFriendsColSpans.ToonName)
					Tooltip:SetCell(line, WoWFriendsColumns.ZoneName, _G.ZONE, WoWFriendsColSpans.ZoneName)
					Tooltip:SetCell(line, WoWFriendsColumns.RealmName, _G.FRIENDS_LIST_REALM, WoWFriendsColSpans.RealmName)

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					for index = 1, #WoWFriendsList do
						local player = WoWFriendsList[index]
						local groupIndicator = IsGrouped(player.ToonName) and GROUP_CHECKMARK or ""
						local nameColor = CLASS_COLORS[player.Class] or FRIENDS_WOW_NAME_COLOR
						local presenceName = player.PresenceName and ("%s%s|r"):format(_G.FRIENDS_BNET_NAME_COLOR_CODE, player.PresenceName) or _G.NOT_APPLICABLE

						line = Tooltip:AddLine()
						Tooltip:SetCell(line, WoWFriendsColumns.Level, ColorPlayerLevel(player.Level), WoWFriendsColSpans.Level)
						Tooltip:SetCell(line, WoWFriendsColumns.PresenceName, ("%s%s"):format(player.StatusIcon, presenceName), WoWFriendsColSpans.PresenceName)
						Tooltip:SetCell(line, WoWFriendsColumns.ToonName, ("%s|cff%s%s|r%s"):format(player.FactionIcon or PLAYER_FACTION_ICON, nameColor, player.ToonName, groupIndicator), WoWFriendsColSpans.ToonName)
						Tooltip:SetCell(line, WoWFriendsColumns.ZoneName, player.ZoneName, WoWFriendsColSpans.ZoneName)
						Tooltip:SetCell(line, WoWFriendsColumns.RealmName, player.RealmName or PLAYER_REALM, WoWFriendsColSpans.RealmName)

						if player.Realm and player.RealmName ~= PLAYER_REALM then
							Tooltip:SetCellScript(line, WoWFriendsColumns.PresenceName, "OnMouseUp", ShowBattleNetFriendDropdownMenu, player)
						else
							Tooltip:SetCellScript(line, WoWFriendsColumns.ToonName, "OnMouseUp", ShowWoWFriendDropdownMenu, player)
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
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, _G.FRIENDS, SECTION_ICON_BULLET), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "WoWFriends")
				end
			end

			-------------------------------------------------------------------------------
			-- BattleNet In-Game Friends
			-------------------------------------------------------------------------------
			if #BattleNetGamesList > 0 then
				line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.BattleNetGames then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), SECTION_ICON_BULLET), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetGames")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					line = Tooltip:AddLine()
					Tooltip:SetLineColor(line, 0, 0, 0, 1)
					Tooltip:SetCell(line, BattleNetColumns.Client, COLUMN_ICON_GAME)

					RenderBattleNetLines(BattleNetGamesList, line)
				else
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), SECTION_ICON_BULLET), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetGames")
				end
			end

			-------------------------------------------------------------------------------
			-- BattleNet Friends
			-------------------------------------------------------------------------------
			if #BattleNetAppList > 0 then
				local line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.BattleNetApp then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, _G.BATTLENET_OPTIONS_LABEL, SECTION_ICON_BULLET), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetApp")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					line = Tooltip:AddLine()
					Tooltip:SetLineColor(line, 0, 0, 0, 1)

					RenderBattleNetLines(BattleNetAppList, line)
				else
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, _G.BATTLENET_OPTIONS_LABEL, SECTION_ICON_BULLET), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetApp")
				end
			end
		end

		-------------------------------------------------------------------------------
		-- Guild
		-------------------------------------------------------------------------------
		if #GuildList > 0 then
			line = Tooltip:AddLine()

			if not DB.Tooltip.CollapsedSections.Guild then
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, _G.GetGuildInfo("player"), SECTION_ICON_BULLET), "GameFontNormal", "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "Guild")

				Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

				line = Tooltip:AddLine()
				Tooltip:SetLineColor(line, 0, 0, 0, 1)

				Tooltip:SetCell(line, GuildColumns.Level, COLUMN_ICON_LEVEL, GuildColSpans.ToonName)
				Tooltip:SetCell(line, GuildColumns.ToonName, _G.NAME, GuildColSpans.ToonName)
				Tooltip:SetCell(line, GuildColumns.Rank, _G.RANK, GuildColSpans.Rank)
				Tooltip:SetCell(line, GuildColumns.ZoneName, _G.ZONE, GuildColSpans.ZoneName)

				Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

				for index = 1, #GuildList do
					local player = GuildList[index]

					line = Tooltip:AddLine()
					Tooltip:SetCell(line, GuildColumns.Level, ColorPlayerLevel(player.Level), GuildColSpans.Level)
					Tooltip:SetCell(line, GuildColumns.ToonName, ("%s|cff%s%s|r%s"):format(player.StatusIcon, CLASS_COLORS[player.Class] or "ffffff", player.ToonName, IsGrouped(player.ToonName) and GROUP_CHECKMARK or ""), GuildColSpans.ToonName)
					Tooltip:SetCell(line, GuildColumns.Rank, player.Rank, GuildColSpans.Rank)
					Tooltip:SetCell(line, GuildColumns.ZoneName, player.ZoneName or _G.UNKNOWN, GuildColSpans.ZoneName)

					if _G.IsAddOnLoaded("Blizzard_GuildUI") then
						Tooltip:SetCellScript(line, GuildColumns.ToonName, "OnMouseUp", ShowGuildMemberDropdown, player)
					end


					if player.Note then
						line = Tooltip:AddLine()
						Tooltip:SetCell(line, GuildColumns.Level, player.Note, "GameTooltipTextSmall", 0)
					end

					if player.OfficerNote then
						line = Tooltip:AddLine()
						Tooltip:SetCell(line, GuildColumns.Level, player.OfficerNote, "GameTooltipTextSmall", 0)
					end
				end

				Tooltip:AddLine(" ")
			else
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, _G.GetGuildInfo("player"), SECTION_ICON_BULLET), "GameFontDisable", "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "Guild")
			end
		end

		Tooltip:UpdateScrolling()
		Tooltip:Show()
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
	self.RequestUpdater = CreateUpdater(RequestUpdater, REQUEST_UPDATE_INTERVAL, RequestUpdates)
	self.RequestUpdater:Play()

	self:RegisterEvent("BN_FRIEND_INFO_CHANGED")
	self:RegisterEvent("BN_TOON_NAME_UPDATED")
	self:RegisterEvent("FRIENDLIST_UPDATE")
	self:RegisterEvent("GUILD_RANKS_UPDATE")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
end
