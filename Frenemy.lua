-- ----------------------------------------------------------------------------
-- Localized Lua globals.
-- ----------------------------------------------------------------------------
local _G = getfenv(0)

local math = _G.math
local string = _G.string
local table = _G.table

local pairs = _G.pairs
local tonumber = _G.tonumber
local type = _G.type

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
local Frenemy = LibStub("AceAddon-3.0"):NewAddon(FOLDER_NAME, "AceEvent-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale(FOLDER_NAME)
local Dialog = LibStub("LibDialog-1.0")
local LibQTip = LibStub('LibQTip-1.0')

local DataObject = LibStub("LibDataBroker-1.1"):NewDataObject(FOLDER_NAME, {
	icon = [[Interface\Calendar\MeetingIcon]],
	text = " ",
	type = "data source",
})

local RequestUpdater = _G.CreateFrame("Frame")

-- ----------------------------------------------------------------------------
-- Constants
-- ----------------------------------------------------------------------------
local BNET_CLIENT_APP = "App" -- Battle.net Application - doesn't have a constant.

local CLIENT_SORT_ORDERS = {
	[_G.BNET_CLIENT_WOW] = 1,
	[_G.BNET_CLIENT_D3] = 2,
	[_G.BNET_CLIENT_SC2] = 3,
	[_G.BNET_CLIENT_WTCG] = 4,
	[BNET_CLIENT_APP] = 5,
}

local FRIENDS_WOW_NAME_COLOR = _G.FRIENDS_WOW_NAME_COLOR_CODE:gsub("|cff", "")

local FRIENDS_FRAME_TAB_TOGGLES = {
	FRIENDS = 1,
	WHO = 2,
	CHAT = 3,
	RAID = 4,
}

local HELP_TIP_DEFINITIONS = {
	[_G.DISPLAY] = {
		[L.LEFT_CLICK] = _G.BINDING_NAME_TOGGLEFRIENDSTAB,
		[L.ALT_KEY .. L.LEFT_CLICK] = _G.BINDING_NAME_TOGGLEGUILDTAB,
		[L.RIGHT_CLICK] = _G.INTERFACE_OPTIONS,
	},
	[_G.NAME] = {
		[L.LEFT_CLICK] = _G.WHISPER,
		[L.RIGHT_CLICK] = _G.ADVANCED_OPTIONS,
		[L.ALT_KEY .. L.LEFT_CLICK] = _G.INVITE,
		[L.CONTROL_KEY .. L.LEFT_CLICK] = _G.SET_NOTE,
		[L.CONTROL_KEY .. L.RIGHT_CLICK] = _G.GUILD_OFFICER_NOTE,
	},
}

local PLAYER_FACTION = _G.UnitFactionGroup("player")
local PLAYER_NAME = _G.UnitName("player")
local PLAYER_REALM = _G.GetRealmName()

local REQUEST_UPDATE_INTERVAL = 30

local SORT_ORDER_ASCENDING = 1
local SORT_ORDER_DESCENDING = 2

local SORT_ORDER_NAMES = {
	[SORT_ORDER_ASCENDING] = "Ascending",
	[SORT_ORDER_DESCENDING] = "Descending",
}

-- ----------------------------------------------------------------------------
-- Icons
-- ----------------------------------------------------------------------------
local function CreateIcon(texture_path, icon_size)
	return ("|T%s:%d|t"):format(texture_path, icon_size or 0)
end

local BROADCAST_ICON = CreateIcon([[Interface\FriendsFrame\BroadcastIcon]])

local CLIENT_ICON_TEXTURE_CODES = {}
do
	local CLIENT_ICON_SIZE = 18

	for clientToken in pairs(CLIENT_SORT_ORDERS) do
		CLIENT_ICON_TEXTURE_CODES[clientToken] = _G.BNet_GetClientEmbeddedTexture(clientToken, CLIENT_ICON_SIZE, CLIENT_ICON_SIZE)
	end
end

local CLASS_ICONS = {}
do
	local textureFormat = [[|TInterface\TargetingFrame\UI-CLASSES-CIRCLES:0:0:0:0:256:256:%d:%d:%d:%d|t]]
	local textureSize = 256
	local increment = 64
	local left = 0
	local right = increment
	local top = 0
	local bottom = increment

	-- This is the order in which the icons appear in the UI-CLASSES-CIRCLES image.
	local CLASS_ICON_SORT_ORDER = {
		"WARRIOR",
		"MAGE",
		"ROGUE",
		"DRUID",
		"HUNTER",
		"SHAMAN",
		"PRIEST",
		"WARLOCK",
		"PALADIN",
		"DEATHKNIGHT",
		"MONK",
	}

	for index = 1, #CLASS_ICON_SORT_ORDER do
		local class_name = CLASS_ICON_SORT_ORDER[index]
		CLASS_ICONS[class_name] = textureFormat:format(left, right, top, bottom)

		if bottom == textureSize then
			break
		end

		if right == textureSize then
			left = 0
			right = increment
			top = top + increment
			bottom = bottom + increment
		else
			left = left + increment
			right = right + increment
		end
	end
end

local CLASS_COLORS = {}
local CLASS_TOKEN_FROM_NAME_FEMALE = {}
local CLASS_TOKEN_FROM_NAME_MALE = {}
do
	for classToken, localizedName in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do
		local color = _G.RAID_CLASS_COLORS[classToken]
		CLASS_COLORS[localizedName] = ("%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
		CLASS_TOKEN_FROM_NAME_FEMALE[localizedName] = classToken
	end

	for classToken, localizedName in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
		local color = _G.RAID_CLASS_COLORS[classToken]
		CLASS_COLORS[localizedName] = ("%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
		CLASS_TOKEN_FROM_NAME_MALE[localizedName] = classToken
	end
end -- do-blcok

local COLUMN_ICON_CLASS = CreateIcon([[Interface\GossipFrame\TrainerGossipIcon]])
local COLUMN_ICON_GAME = CreateIcon([[Interface\Buttons\UI-GroupLoot-Dice-Up]])
local COLUMN_ICON_LEVEL = CreateIcon([[Interface\GROUPFRAME\UI-GROUP-MAINASSISTICON]])

local FACTION_ICON_SIZE = 18
local FACTION_ICON_ALLIANCE = CreateIcon([[Interface\COMMON\icon-alliance]], FACTION_ICON_SIZE)
local FACTION_ICON_HORDE = CreateIcon([[Interface\COMMON\icon-horde]], FACTION_ICON_SIZE)
local FACTION_ICON_NEUTRAL = CreateIcon([[Interface\COMMON\Indicator-Gray]], FACTION_ICON_SIZE)

local HELP_ICON = CreateIcon([[Interface\COMMON\help-i]], 20)

local PLAYER_ICON_GROUP = [[|TInterface\Scenarios\ScenarioIcon-Check:0|t]]
local PLAYER_ICON_FACTION = PLAYER_FACTION == "Horde" and FACTION_ICON_HORDE or (PLAYER_FACTION == "Alliance" and FACTION_ICON_ALLIANCE) or FACTION_ICON_NEUTRAL

local SECTION_ICON_DISABLED = CreateIcon([[Interface\COMMON\Indicator-Red]])
local SECTION_ICON_ENABLED = CreateIcon([[Interface\COMMON\Indicator-Green]])

local SORT_ICON_ASCENDING = CreateIcon([[Interface\Buttons\Arrow-Up-Up]])
local SORT_ICON_DESCENDING = CreateIcon([[Interface\Buttons\Arrow-Down-Up]])

local STATUS_ICON_AFK = CreateIcon(_G.FRIENDS_TEXTURE_AFK)
local STATUS_ICON_DND = CreateIcon(_G.FRIENDS_TEXTURE_DND)
local STATUS_ICON_MOBILE_AWAY = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat-AwayMobile]])
local STATUS_ICON_MOBILE_BUSY = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat-BusyMobile]])
local STATUS_ICON_MOBILE_ONLINE = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat]])
local STATUS_ICON_NOTE = CreateIcon(_G.FRIENDS_TEXTURE_OFFLINE)
local STATUS_ICON_ONLINE = CreateIcon(_G.FRIENDS_TEXTURE_ONLINE)

-- ----------------------------------------------------------------------------
-- Variables
-- ----------------------------------------------------------------------------
local DB
local HelpTip
local Tooltip

-- Statistics: Populated and maintained in UpdateStatistics()
local OnlineBattleNetCount
local OnlineFriendsCount
local OnlineGuildMembersCount

local TotalBattleNetCount
local TotalFriendsCount
local TotalGuildMembersCount

-- Zone data
local CurrentZoneID
local ZoneColorsByName = {} -- Populated from SavedVariables and during travel.

-- ----------------------------------------------------------------------------
-- Enumerations and data for sorting.
-- ----------------------------------------------------------------------------
--- Changing the order will cause SavedVariables to no longer map appropriately.
local SortFields = {
	BattleNetApp = {
		"GameText",
		"PresenceName",
		"ToonName",
		"Note",
	},
	BattleNetGames = {
		"ClientIndex",
		"GameText",
		"PresenceName",
		"ToonName",
		"Note",
	},
	Guild = {
		"Level",
		"RankIndex",
		"ToonName",
		"ZoneName",
		"PublicNote",
		"OfficerNote",
		"Class",
	},
	WoWFriends = {
		"Level",
		"PresenceName",
		"RealmName",
		"ToonName",
		"ZoneName",
		"Note",
		"Class",
	},
}

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
			local aField = a[fieldNameList[index]] or ""
			aField = type(aField) == "string" and aField:lower() or aField

			local bField = b[fieldNameList[index]] or ""
			bField = type(bField) == "string" and bField:lower() or bField

			if aField == bField then
				return a.ToonName:lower() < b.ToonName:lower()
			end

			return aField < bField
		end

		SortFunctions[sortFuncName .. SORT_ORDER_NAMES[SORT_ORDER_DESCENDING]] = function(a, b)
			local aField = a[fieldNameList[index]] or ""
			aField = type(aField) == "string" and aField:lower() or aField

			local bField = b[fieldNameList[index]] or ""
			bField = type(bField) == "string" and bField:lower() or bField

			if aField == bField then
				return a.ToonName:lower() > b.ToonName:lower()
			end

			return aField > bField
		end
	end
end

-- ----------------------------------------------------------------------------
-- Default settings
-- ----------------------------------------------------------------------------
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
			NotesArrangement = {
				BattleNetApp = private.NotesArrangementType.Row,
				BattleNetGames = private.NotesArrangementType.Row,
				Guild = private.NotesArrangementType.Row,
				GuildOfficer = private.NotesArrangementType.Row,
				WoWFriends = private.NotesArrangementType.Row,
			},
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
		ZoneData = {}, -- Populated during travel.
	}
}

-- ----------------------------------------------------------------------------
-- Dialogs
-- ----------------------------------------------------------------------------
Dialog:Register("FrenemySetGuildMOTD", {
	editboxes = {
		{
			on_enter_pressed = function(self)
				_G.GuildSetMOTD(self:GetText())
				Dialog:Dismiss("FrenemySetGuildMOTD")
			end,
			on_escape_pressed = function(self)
				Dialog:Dismiss("FrenemySetGuildMOTD")
			end,
			on_show = function(self)
				self:SetText(_G.GetGuildRosterMOTD())
			end,
			auto_focus = true,
			label = _G.GREEN_FONT_COLOR_CODE .._G.GUILDCONTROL_OPTION9 .. "|r",
			max_letters = 128,
			text = _G.GetGuildRosterMOTD(),
			width = 200,
		},
	},
	show_while_dead = true,
	hide_on_escape = true,
	icon = [[Interface\Calendar\MeetingIcon]],
	width = 400,
	on_show = function(self, text)
		self.text:SetFormattedText("%s%s|r", _G.BATTLENET_FONT_COLOR_CODE, FOLDER_NAME)
	end
})

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------
local function ColorPlayerLevel(level)
	if type(level) ~= "number" then
		return level
	end
	local color = _G.GetRelativeDifficultyColor(_G.UnitLevel("player"), level)
	return ("|cff%02x%02x%02x%d|r"):format(color.r * 255, color.g * 255, color.b * 255, level)
end

local function ColorZoneName(zoneName)
	local color = ZoneColorsByName[zoneName] or _G.GRAY_FONT_COLOR
	return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, zoneName or _G.UNKNOWN)
end

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

local function SetZoneNameColors(zoneID, zonePVPStatus)
	local mapName = _G.GetMapNameByID(zoneID)
	if not mapName then
		DB.ZoneData[zoneID] = nil
		return
	end
	ZoneColorsByName[mapName] = private.ZonePVPStatusRGB[zonePVPStatus]
end

local function UpdateStatistics()
	TotalBattleNetCount, OnlineBattleNetCount = _G.BNGetNumFriends()
	TotalFriendsCount, OnlineFriendsCount = _G.GetNumFriends()

	if _G.IsInGuild() then
		local _
		TotalGuildMembersCount, _, OnlineGuildMembersCount = _G.GetNumGuildMembers()
	end
end

-- ----------------------------------------------------------------------------
-- Tooltip.
-- ----------------------------------------------------------------------------
local DrawTooltip
do
	local BattleNetColumns = {
		Client = 1,
		PresenceName = 2,
		ToonName = 4,
		GameText = 5,
		Note = 7,
	}

	local BattleNetColSpans = {
		Client = 1,
		PresenceName = 2,
		ToonName = 1,
		GameText = 2,
		Note = 2,
	}

	local GuildColumns = {
		Level = 1,
		Class = 2,
		ToonName = 3,
		Rank = 4,
		ZoneName = 5,
		PublicNote = 6,
		OfficerNote = 8,
	}

	local GuildColSpans = {
		Level = 1,
		Class = 1,
		ToonName = 1,
		Rank = 1,
		ZoneName = 1,
		PublicNote = 2,
		OfficerNote = 2,
	}

	local WoWFriendsColumns = {
		Level = 1,
		Class = 2,
		PresenceName = 3,
		ToonName = 4,
		ZoneName = 5,
		RealmName = 6,
		Note = 7,
	}

	local WoWFriendsColSpans = {
		Level = 1,
		Class = 1,
		PresenceName = 1,
		ToonName = 1,
		ZoneName = 1,
		RealmName = 1,
		Note = 2,
	}

	local PlayerLists = {
		BattleNetApp = {},
		BattleNetGames = {},
		Guild = {},
		WoWFriends = {},
	}

	local NUM_TOOLTIP_COLUMNS = 10

	local TooltipAnchor

	-- Used to handle duplication between in-game and RealID friends.
	local OnlineFriendsByName = {}
	local GuildMemberIndexByName = {}
	local WoWFriendIndexByName = {}

	-- ----------------------------------------------------------------------------
	-- Data compilation.
	-- ----------------------------------------------------------------------------
	local function GenerateTooltipData()
		for name, data in pairs(PlayerLists) do
			table.wipe(data)
		end
		table.wipe(OnlineFriendsByName)
		table.wipe(GuildMemberIndexByName)
		table.wipe(WoWFriendIndexByName)

		if OnlineFriendsCount > 0 then
			for friendIndex = 1, OnlineFriendsCount do
				local fullToonName, level, class, zoneName, connected, status, note = _G.GetFriendInfo(friendIndex)
				local toonName, realmName = ("-"):split(fullToonName)

				WoWFriendIndexByName[fullToonName] = friendIndex
				WoWFriendIndexByName[toonName] = friendIndex

				local entry = {
					Class = class,
					FullToonName = fullToonName,
					IsLocalFriend = true,
					Level = level,
					Note = note,
					RealmName = realmName or PLAYER_REALM,
					StatusIcon = status == _G.CHAT_FLAG_AFK and STATUS_ICON_AFK or (status == _G.CHAT_FLAG_DND and STATUS_ICON_DND or STATUS_ICON_ONLINE),
					ToonName = toonName,
					ZoneName = zoneName ~= "" and zoneName or _G.UNKNOWN,
				}

				OnlineFriendsByName[toonName] = entry
				table.insert(PlayerLists.WoWFriends, entry)
			end
		end

		if OnlineBattleNetCount > 0 then
			for battleNetIndex = 1, OnlineBattleNetCount do
				local presenceID, presenceName, battleTag, isBattleTagPresence, _, toonID, client, isOnline, _, isAFK, isDND, broadcastText, noteText, isRIDFriend, broadcastTime = _G.BNGetFriendInfo(battleNetIndex)
				local numToons = _G.BNGetNumFriendToons(battleNetIndex)

				for toonIndex = 1, numToons do
					local hasFocus, toonName, client, realmName, realmID, faction, race, class, guild, zoneName, level, gameText = _G.BNGetFriendToonInfo(battleNetIndex, toonIndex)

					local characterName = toonName
					if presenceName then
						characterName = characterName or battleTag
					end
					characterName = characterName or _G.UNKNOWN

					local entry = {
						BroadcastText = (broadcastText and broadcastText ~= "") and BROADCAST_ICON .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. broadcastText .. "|r" or nil,
						Class = class,
						Client = client,
						ClientIndex = CLIENT_SORT_ORDERS[client],
						FactionIcon = faction and faction == "Horde" and FACTION_ICON_HORDE or (faction == "Alliance" and FACTION_ICON_ALLIANCE) or FACTION_ICON_NEUTRAL,
						GameText = gameText ~= "" and gameText or _G.UNKNOWN,
						Level = level and tonumber(level) or 0,
						Note = noteText ~= "" and noteText,
						PresenceID = presenceID,
						PresenceName = presenceName or _G.UNKNOWN,
						RealmName = realmName or "",
						StatusIcon = isAFK and STATUS_ICON_AFK or (isDND and STATUS_ICON_DND or STATUS_ICON_ONLINE),
						ToonName = characterName,
						ZoneName = zoneName ~= "" and zoneName or _G.UNKNOWN,
					}

					if client == _G.BNET_CLIENT_WOW then
						local existingFriend = OnlineFriendsByName[toonName]

						if realmName == PLAYER_REALM and existingFriend then
							for key, value in pairs(entry) do
								if not existingFriend[key] then
									existingFriend[key] = value
								end
							end
						else
							table.insert(PlayerLists.WoWFriends, entry)
						end

					elseif client == BNET_CLIENT_APP then
						table.insert(PlayerLists.BattleNetApp, entry)
					elseif toonID then
						table.insert(PlayerLists.BattleNetGames, entry)
					end
				end
			end
		end

		if _G.IsInGuild() then
			for index = 1, _G.GetNumGuildMembers() do
				local fullToonName, rank, rankIndex, level, class, zoneName, note, officerNote, isOnline, status, _, _, _, isMobile = _G.GetGuildRosterInfo(index)

				if isOnline or isMobile then
					local toonName, realmName = ("-"):split(fullToonName)

					if status == 0 then
						status = isMobile and STATUS_ICON_MOBILE_ONLINE or STATUS_ICON_ONLINE
					elseif status == 1 then
						status = isMobile and STATUS_ICON_MOBILE_AWAY or STATUS_ICON_AFK
					elseif status == 2 then
						status = isMobile and STATUS_ICON_MOBILE_BUSY or STATUS_ICON_DND
					end

					-- Don't rely on the zoneName from GetGuildRosterInfo - it can be slow, and the player should see their own zone change instantaneously if
					-- traveling with the tooltip showing.
					if not isMobile and toonName == PLAYER_NAME then
						zoneName = CurrentZoneID and _G.GetMapNameByID(CurrentZoneID) or _G.UNKNOWN
					end

					GuildMemberIndexByName[fullToonName] = index
					GuildMemberIndexByName[toonName] = index

					table.insert(PlayerLists.Guild, {
						Class = class,
						FullToonName = fullToonName,
						IsMobile = isMobile,
						Level = level,
						OfficerNote = officerNote ~= "" and officerNote or nil,
						PublicNote = note ~= "" and note or nil,
						Rank = rank,
						RankIndex = rankIndex,
						RealmName = realmName or PLAYER_REALM,
						StatusIcon = status,
						ToonName = toonName,
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

	-- ----------------------------------------------------------------------------
	-- Controls
	-- ----------------------------------------------------------------------------
	local function BattleNetFriend_OnMouseUp(tooltipCell, playerEntry, button)
		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		if button == "LeftButton" then
			if _G.IsAltKeyDown() and playerEntry.RealmName == PLAYER_REALM then
				_G.InviteToGroup(playerEntry.ToonName)
			elseif _G.IsControlKeyDown() then
				_G.FriendsFrame.NotesID = playerEntry.PresenceID
				_G.StaticPopup_Show("SET_BNFRIENDNOTE", playerEntry.PresenceName)
			elseif not _G.BNIsSelf(playerEntry.PresenceID) then
				_G.ChatFrame_SendSmartTell(playerEntry.PresenceName)
			end
		elseif button == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.CloseDropDownMenus()
			_G.FriendsFrame_ShowBNDropdown(playerEntry.PresenceName, true, nil, nil, nil, true, playerEntry.PresenceID)
		end
	end

	local function GuildMember_OnMouseUp(tooltipCell, playerEntry, button)
		if not _G.IsAddOnLoaded("Blizzard_GuildUI") then
			_G.LoadAddOn("Blizzard_GuildUI")
		end

		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		local playerName = playerEntry.Realm == PLAYER_REALM and playerEntry.ToonName or playerEntry.FullToonName

		if button == "LeftButton" then
			if _G.IsAltKeyDown() then
				_G.InviteToGroup(playerName)
			elseif _G.IsControlKeyDown() and _G.CanEditPublicNote() then
				_G.SetGuildRosterSelection(GuildMemberIndexByName[playerName])
				_G.StaticPopup_Show("SET_GUILDPLAYERNOTE")
			else
				_G.ChatFrame_SendTell(playerName)
			end
		elseif button == "RightButton" then
			if _G.IsControlKeyDown() and _G.CanEditOfficerNote() then
				_G.SetGuildRosterSelection(GuildMemberIndexByName[playerName])
				_G.StaticPopup_Show("SET_GUILDOFFICERNOTE")
			else
				Tooltip:SetFrameStrata("DIALOG")
				_G.CloseDropDownMenus()
				_G.GuildRoster_ShowMemberDropDown(playerName, true, playerEntry.IsMobile)
			end
		end
	end

	local function GuildMOTD_OnMouseUp(tooltipCell)
		Dialog:Spawn("FrenemySetGuildMOTD")
	end

	local function ToggleColumnSortMethod(tooltipCell, sortFieldData)
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

	local function ToggleSectionVisibility(tooltipCell, sectionName)
		DB.Tooltip.CollapsedSections[sectionName] = not DB.Tooltip.CollapsedSections[sectionName]
		DrawTooltip(TooltipAnchor)
	end

	local function WoWFriend_OnMouseUp(tooltipCell, playerEntry, button)
		_G.PlaySound("igMainMenuOptionCheckBoxOn")

		local playerName = playerEntry.Realm == PLAYER_REALM and playerEntry.ToonName or playerEntry.FullToonName

		if button == "LeftButton" then
			if _G.IsAltKeyDown() then
				_G.InviteToGroup(playerName)
			elseif _G.IsControlKeyDown() then
				_G.FriendsFrame.NotesID = WoWFriendIndexByName[playerName]
				_G.StaticPopup_Show("SET_FRIENDNOTE", playerName)
			else
				_G.ChatFrame_SendTell(playerName)
			end
		elseif button == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.CloseDropDownMenus()
			_G.FriendsFrame_ShowDropdown(playerEntry.FullToonName, true, nil, nil, nil, true)
		end
	end

	-- ----------------------------------------------------------------------------
	-- Display rendering
	-- ----------------------------------------------------------------------------
	local function ColumnLabel(label, data)
		local sectionName, fieldName = (":"):split(data)

		if DB.Tooltip.Sorting[sectionName].Field == SortFieldIDs[sectionName][fieldName] then
			return (DB.Tooltip.Sorting[sectionName].Order == SORT_ORDER_ASCENDING and SORT_ICON_ASCENDING or SORT_ICON_DESCENDING) .. label
		end

		return label
	end

	local function HideHelpTip(tooltipCell)
		if HelpTip then
			HelpTip:Hide()
			HelpTip:Release()
			HelpTip = nil
		end
		Tooltip:SetFrameStrata("TOOLTIP")
	end

	local function ShowHelpTip(tooltipCell)
		local helpTip = LibQTip:Acquire(FOLDER_NAME .. "HelpTip", 2)
		helpTip:SetAutoHideDelay(0.1, tooltipCell)
		helpTip:SetBackdropColor(0.05, 0.05, 0.05, 1)
		helpTip:SetScale(DB.Tooltip.Scale)
		helpTip:SmartAnchorTo(tooltipCell)
		helpTip:SetScript("OnLeave", function(self) self:Release() helpTip = nil end)
		helpTip:Clear()
		helpTip:SetCellMarginH(0)
		helpTip:SetCellMarginV(1)

		local firstEntryType = true

		for entryType, data in pairs(HELP_TIP_DEFINITIONS) do
			local line

			if not firstEntryType then
				line = helpTip:AddLine(" ")
			end
			line = helpTip:AddLine()
			helpTip:SetCell(line, 1, entryType, _G.GameFontNormal, "CENTER", 0)
			helpTip:AddSeparator(1, 0.5, 0.5, 0.5)

			for keyStroke, description in pairs(data) do
				line = helpTip:AddLine()
				helpTip:SetCell(line, 1, keyStroke)
				helpTip:SetCell(line, 2, description)
			end
			firstEntryType = false
		end

		_G.HideDropDownMenu(1)
		Tooltip:SetFrameStrata("DIALOG")
		helpTip:Show()
	end

	local function RenderBattleNetLines(sourceListName, headerLine, noteArrangement)
		Tooltip:SetLineColor(headerLine, 0, 0, 0, 1)
		Tooltip:SetCell(headerLine, BattleNetColumns.PresenceName, ColumnLabel(_G.BATTLENET_FRIEND, sourceListName .. ":PresenceName"), BattleNetColSpans.PresenceName)
		Tooltip:SetCellScript(headerLine, BattleNetColumns.PresenceName, "OnMouseUp", ToggleColumnSortMethod, sourceListName .. ":PresenceName")

		Tooltip:SetCell(headerLine, BattleNetColumns.ToonName, ColumnLabel(_G.NAME, sourceListName .. ":ToonName"), BattleNetColSpans.ToonName)
		Tooltip:SetCellScript(headerLine, BattleNetColumns.ToonName, "OnMouseUp", ToggleColumnSortMethod, sourceListName .. ":ToonName")

		Tooltip:SetCell(headerLine, BattleNetColumns.GameText, ColumnLabel(_G.INFO, sourceListName .. ":GameText"), BattleNetColSpans.GameText)
		Tooltip:SetCellScript(headerLine, BattleNetColumns.GameText, "OnMouseUp", ToggleColumnSortMethod, sourceListName .. ":GameText")

		local addedNoteColumn

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
				local noteText = _G.FRIENDS_OTHER_NAME_COLOR_CODE .. player.Note .. "|r"

				if noteArrangement == private.NotesArrangementType.Column then
					if not addedNoteColumn then
						Tooltip:SetCell(headerLine, BattleNetColumns.Note, ColumnLabel(_G.LABEL_NOTE, sourceListName .. ":Note"), BattleNetColSpans.Note)
						Tooltip:SetCellScript(headerLine, BattleNetColumns.Note, "OnMouseUp", ToggleColumnSortMethod, sourceListName .. ":Note")

						addedNoteColumn = true
					end
					Tooltip:SetCell(line, BattleNetColumns.Note, noteText, BattleNetColSpans.Note)
				else
					Tooltip:SetCell(Tooltip:AddLine(), BattleNetColumns.Client, STATUS_ICON_NOTE .. noteText, "GameTooltipTextSmall", 0)
				end
			end

			if player.BroadcastText then
				Tooltip:SetCell(Tooltip:AddLine(), BattleNetColumns.Client, player.BroadcastText, "GameTooltipTextSmall", 0)
			end
		end

		Tooltip:AddLine(" ")
	end

	local function Tooltip_OnRelease(self)
		_G.HideDropDownMenu(1)

		if HelpTip then
			HelpTip:Release()
			HelpTip = nil
		end

		Tooltip:SetFrameStrata("TOOLTIP") -- This can be set to DIALOG by various functions.
		Tooltip = nil
		TooltipAnchor = nil
	end

	local TitleFont = _G.CreateFont("FrenemyTitleFont")
	TitleFont:SetTextColor(0.510, 0.773, 1.0)
	TitleFont:SetFontObject("QuestTitleFont")

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
			-- ----------------------------------------------------------------------------
			-- WoW Friends
			-- ----------------------------------------------------------------------------
			if #PlayerLists.WoWFriends > 0 then
				local line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.WoWFriends then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.FRIENDS, SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "WoWFriends")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					local headerLine = Tooltip:AddLine()
					Tooltip:SetLineColor(headerLine, 0, 0, 0, 1)
					Tooltip:SetCell(headerLine, WoWFriendsColumns.Level, ColumnLabel(COLUMN_ICON_LEVEL, "WoWFriends:Level"), WoWFriendsColSpans.Level)
					Tooltip:SetCellScript(headerLine, WoWFriendsColumns.Level, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Level")

					Tooltip:SetCell(headerLine, WoWFriendsColumns.Class, ColumnLabel(COLUMN_ICON_CLASS, "WoWFriends:Class"), WoWFriendsColSpans.Class)
					Tooltip:SetCellScript(headerLine, WoWFriendsColumns.Class, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Class")

					Tooltip:SetCell(headerLine, WoWFriendsColumns.PresenceName, ColumnLabel(_G.BATTLENET_FRIEND, "WoWFriends:PresenceName"), WoWFriendsColSpans.PresenceName)
					Tooltip:SetCellScript(headerLine, WoWFriendsColumns.PresenceName, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:PresenceName")

					Tooltip:SetCell(headerLine, WoWFriendsColumns.ToonName, ColumnLabel(_G.NAME, "WoWFriends:ToonName"), WoWFriendsColSpans.ToonName)
					Tooltip:SetCellScript(headerLine, WoWFriendsColumns.ToonName, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:ToonName")

					Tooltip:SetCell(headerLine, WoWFriendsColumns.ZoneName, ColumnLabel(_G.ZONE, "WoWFriends:ZoneName"), WoWFriendsColSpans.ZoneName)
					Tooltip:SetCellScript(headerLine, WoWFriendsColumns.ZoneName, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:ZoneName")

					Tooltip:SetCell(headerLine, WoWFriendsColumns.RealmName, ColumnLabel(L.COLUMN_LABEL_REALM, "WoWFriends:RealmName"), WoWFriendsColSpans.RealmName)
					Tooltip:SetCellScript(headerLine, WoWFriendsColumns.RealmName, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:RealmName")

					local addedNoteColumn

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					for index = 1, #PlayerLists.WoWFriends do
						local player = PlayerLists.WoWFriends[index]
						local groupIndicator = IsGrouped(player.ToonName) and PLAYER_ICON_GROUP or ""
						local nameColor = CLASS_COLORS[player.Class] or FRIENDS_WOW_NAME_COLOR
						local presenceName = player.PresenceName and ("%s%s|r"):format(_G.FRIENDS_BNET_NAME_COLOR_CODE, player.PresenceName) or _G.NOT_APPLICABLE

						line = Tooltip:AddLine()
						Tooltip:SetCell(line, WoWFriendsColumns.Level, ColorPlayerLevel(player.Level), WoWFriendsColSpans.Level)
						Tooltip:SetCell(line, WoWFriendsColumns.Class, CLASS_ICONS[CLASS_TOKEN_FROM_NAME_FEMALE[player.Class] or CLASS_TOKEN_FROM_NAME_MALE[player.Class]], WoWFriendsColSpans.Class)
						Tooltip:SetCell(line, WoWFriendsColumns.PresenceName, ("%s%s"):format(player.StatusIcon, presenceName), WoWFriendsColSpans.PresenceName)
						Tooltip:SetCell(line, WoWFriendsColumns.ToonName, ("%s|cff%s%s|r%s"):format(player.FactionIcon or PLAYER_ICON_FACTION, nameColor, player.ToonName, groupIndicator), WoWFriendsColSpans.ToonName)
						Tooltip:SetCell(line, WoWFriendsColumns.ZoneName, ColorZoneName(player.ZoneName), WoWFriendsColSpans.ZoneName)
						Tooltip:SetCell(line, WoWFriendsColumns.RealmName, player.RealmName, WoWFriendsColSpans.RealmName)

						if player.PresenceID then
							Tooltip:SetCellScript(line, WoWFriendsColumns.PresenceName, "OnMouseUp", BattleNetFriend_OnMouseUp, player)
						end

						if player.IsLocalFriend then
							Tooltip:SetCellScript(line, WoWFriendsColumns.ToonName, "OnMouseUp", WoWFriend_OnMouseUp, player)
						end

						if player.Note then
							local noteText = _G.FRIENDS_OTHER_NAME_COLOR_CODE .. player.Note .. "|r"

							if DB.Tooltip.NotesArrangement.WoWFriends == private.NotesArrangementType.Column then
								if not addedNoteColumn then
									Tooltip:SetCell(headerLine, WoWFriendsColumns.Note, ColumnLabel(_G.LABEL_NOTE, "WoWFriends:Note"), WoWFriendsColSpans.Note)
									Tooltip:SetCellScript(headerLine, WoWFriendsColumns.Note, "OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Note")

									addedNoteColumn = true
								end
								Tooltip:SetCell(line, WoWFriendsColumns.Note, noteText, WoWFriendsColSpans.Note)
							else
								Tooltip:SetCell(Tooltip:AddLine(), WoWFriendsColumns.Level, STATUS_ICON_NOTE .. noteText, "GameTooltipTextSmall", 0)
							end
						end

						if player.BroadcastText then
							Tooltip:SetCell(Tooltip:AddLine(), WoWFriendsColumns.Level, player.BroadcastText, "GameTooltipTextSmall", 0)
						end
					end

					Tooltip:AddLine(" ")
				else
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, _G.FRIENDS, SECTION_ICON_DISABLED), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "WoWFriends")
				end
			end

			-- ----------------------------------------------------------------------------
			-- BattleNet In-Game Friends
			-- ----------------------------------------------------------------------------
			if #PlayerLists.BattleNetGames > 0 then
				local line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.BattleNetGames then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetGames")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					line = Tooltip:AddLine()
					Tooltip:SetCell(line, BattleNetColumns.Client, ColumnLabel(COLUMN_ICON_GAME, "BattleNetGames:ClientIndex"))

					Tooltip:SetCellScript(line, BattleNetColumns.Client, "OnMouseUp", ToggleColumnSortMethod, "BattleNetGames:ClientIndex")

					RenderBattleNetLines("BattleNetGames", line, DB.Tooltip.NotesArrangement.BattleNetGames)
				else
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), SECTION_ICON_DISABLED), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetGames")
				end
			end

			-- ----------------------------------------------------------------------------
			-- BattleNet Friends
			-- ----------------------------------------------------------------------------
			if #PlayerLists.BattleNetApp > 0 then
				local line = Tooltip:AddLine()

				if not DB.Tooltip.CollapsedSections.BattleNetApp then
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.BATTLENET_OPTIONS_LABEL, SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetApp")

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					RenderBattleNetLines("BattleNetApp", Tooltip:AddLine(), DB.Tooltip.NotesArrangement.BattleNetApp)
				else
					Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, _G.BATTLENET_OPTIONS_LABEL, SECTION_ICON_DISABLED), _G.GameFontDisable, "CENTER", 0)
					Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "BattleNetApp")
				end
			end
		end

		-- ----------------------------------------------------------------------------
		-- Guild
		-- ----------------------------------------------------------------------------
		local guildMOTD

		if #PlayerLists.Guild > 0 then
			local line = Tooltip:AddLine()

			if not DB.Tooltip.CollapsedSections.Guild then
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.GetGuildInfo("player"), SECTION_ICON_ENABLED), "GameFontNormal", "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "Guild")

				Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

				local headerLine = Tooltip:AddLine()
				Tooltip:SetLineColor(headerLine, 0, 0, 0, 1)
				Tooltip:SetCell(headerLine, GuildColumns.Level, ColumnLabel(COLUMN_ICON_LEVEL, "Guild:Level"), GuildColSpans.Level)
				Tooltip:SetCellScript(headerLine, GuildColumns.Level, "OnMouseUp", ToggleColumnSortMethod, "Guild:Level")

				Tooltip:SetCell(headerLine, GuildColumns.Class, ColumnLabel(COLUMN_ICON_CLASS, "Guild:Class"), GuildColSpans.Class)
				Tooltip:SetCellScript(headerLine, GuildColumns.Class, "OnMouseUp", ToggleColumnSortMethod, "Guild:Class")

				Tooltip:SetCell(headerLine, GuildColumns.ToonName, ColumnLabel(_G.NAME, "Guild:ToonName"), GuildColSpans.ToonName)
				Tooltip:SetCellScript(headerLine, GuildColumns.ToonName, "OnMouseUp", ToggleColumnSortMethod, "Guild:ToonName")

				Tooltip:SetCell(headerLine, GuildColumns.Rank, ColumnLabel(_G.RANK, "Guild:RankIndex"), GuildColSpans.Rank)
				Tooltip:SetCellScript(headerLine, GuildColumns.Rank, "OnMouseUp", ToggleColumnSortMethod, "Guild:RankIndex")

				Tooltip:SetCell(headerLine, GuildColumns.ZoneName, ColumnLabel(_G.ZONE, "Guild:ZoneName"), GuildColSpans.ZoneName)
				Tooltip:SetCellScript(headerLine, GuildColumns.ZoneName, "OnMouseUp", ToggleColumnSortMethod, "Guild:ZoneName")

				local addedPublicNoteColumn
				local addedOfficerNoteColumn

				Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

				local numGuildRanks = _G.GuildControlGetNumRanks()

				for index = 1, #PlayerLists.Guild do
					local player = PlayerLists.Guild[index]

					line = Tooltip:AddLine()
					Tooltip:SetCell(line, GuildColumns.Level, ColorPlayerLevel(player.Level), GuildColSpans.Level)
					Tooltip:SetCell(line, GuildColumns.Class, CLASS_ICONS[CLASS_TOKEN_FROM_NAME_FEMALE[player.Class] or CLASS_TOKEN_FROM_NAME_MALE[player.Class]], GuildColSpans.Class)

					Tooltip:SetCell(line, GuildColumns.ToonName, ("%s|cff%s%s|r%s"):format(player.StatusIcon, CLASS_COLORS[player.Class] or "ffffff", player.ToonName, IsGrouped(player.ToonName) and PLAYER_ICON_GROUP or ""), GuildColSpans.ToonName)
					Tooltip:SetCellScript(line, GuildColumns.ToonName, "OnMouseUp", GuildMember_OnMouseUp, player)

					-- The higher the rank index, the lower the priviledge; guild leader is rank 1.
					local r, g, b = PercentColorGradient(player.RankIndex, numGuildRanks)
					Tooltip:SetCell(line, GuildColumns.Rank, ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, player.Rank), GuildColSpans.Rank)
					Tooltip:SetCell(line, GuildColumns.ZoneName, ColorZoneName(player.ZoneName), GuildColSpans.ZoneName)

					if player.PublicNote then
						local noteText = _G.FRIENDS_OTHER_NAME_COLOR_CODE .. player.PublicNote .. "|r"

						if DB.Tooltip.NotesArrangement.Guild == private.NotesArrangementType.Column then
							if not addedPublicNoteColumn then
								Tooltip:SetCell(headerLine, GuildColumns.PublicNote, ColumnLabel(_G.NOTE, "Guild:PublicNote"), GuildColSpans.PublicNote)
								Tooltip:SetCellScript(headerLine, GuildColumns.PublicNote, "OnMouseUp", ToggleColumnSortMethod, "Guild:PublicNote")

								addedPublicNoteColumn = true
							end
							Tooltip:SetCell(line, GuildColumns.PublicNote, noteText, GuildColSpans.PublicNote)
						else
							Tooltip:SetCell(Tooltip:AddLine(), GuildColumns.Level, STATUS_ICON_NOTE .. noteText, "GameTooltipTextSmall", 0)
						end
					end

					if player.OfficerNote then
						local noteText = _G.ORANGE_FONT_COLOR_CODE .. player.OfficerNote .. "|r"

						if DB.Tooltip.NotesArrangement.GuildOfficer == private.NotesArrangementType.Column then
							if not addedOfficerNoteColumn then
								Tooltip:SetCell(headerLine, GuildColumns.OfficerNote, ColumnLabel(_G.GUILD_OFFICERNOTES_LABEL, "Guild:OfficerNote"), GuildColSpans.OfficerNote)
								Tooltip:SetCellScript(headerLine, GuildColumns.OfficerNote, "OnMouseUp", ToggleColumnSortMethod, "Guild:OfficerNote")

								addedOfficerNoteColumn = true
							end
							Tooltip:SetCell(line, GuildColumns.OfficerNote, noteText, GuildColSpans.OfficerNote)
						else
							Tooltip:SetCell(Tooltip:AddLine(), GuildColumns.Level, STATUS_ICON_NOTE .. noteText, "GameTooltipTextSmall", 0)
						end
					end
				end

				guildMOTD = _G.GetGuildRosterMOTD()
			else
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, _G.GetGuildInfo("player"), SECTION_ICON_DISABLED), "GameFontDisable", "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", ToggleSectionVisibility, "Guild")
			end

			Tooltip:AddLine(" ")
		end

		Tooltip:Show()

		if guildMOTD and guildMOTD ~= "" then
			local line = Tooltip:AddLine()
			Tooltip:SetCell(line, 1, _G.GUILD_MOTD_TEMPLATE:format(_G.GREEN_FONT_COLOR_CODE .. guildMOTD .. "|r"), 0, 0, 0, Tooltip:GetWidth() - 20)

			if _G.CanEditMOTD() then
				Tooltip:SetCellScript(line, 1, "OnMouseUp", GuildMOTD_OnMouseUp)
			end

			Tooltip:AddLine(" ")
		end

		Tooltip:AddSeparator(1, 0.510, 0.773, 1.0)

		local line = Tooltip:AddLine()
		Tooltip:SetCell(line, NUM_TOOLTIP_COLUMNS, HELP_ICON, "RIGHT", 0)
		Tooltip:SetCellScript(line, NUM_TOOLTIP_COLUMNS, "OnEnter", ShowHelpTip)
		Tooltip:SetCellScript(line, NUM_TOOLTIP_COLUMNS, "OnLeave", HideHelpTip)

		Tooltip:UpdateScrolling()
	end
end -- do-block

-- ----------------------------------------------------------------------------
-- DataObject methods.
-- ----------------------------------------------------------------------------
function DataObject:OnClick(button)
	if button == "LeftButton" then
		if _G.IsAltKeyDown() then
			_G.ToggleGuildFrame()
		else
			_G.ToggleFriendsFrame(FRIENDS_FRAME_TAB_TOGGLES.FRIENDS)
		end
	else
		_G.InterfaceOptionsFrame_OpenToCategory(Frenemy.optionsFrame)
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

-- ----------------------------------------------------------------------------
-- Events.
-- ----------------------------------------------------------------------------
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

function Frenemy:PLAYER_REGEN_DISABLED(eventName)
	private.inCombat = true
end


function Frenemy:PLAYER_REGEN_ENABLED(eventName)
	private.inCombat = nil

	if private.needsAreaID then
		self:HandleZoneChange(eventName)
		private.needsAreaID = nil
	end
end

-- Contains a dirty hack due to Blizzard's strange handling of Micro Dungeons; GetMapInfo() will not return correct information
-- unless the WorldMapFrame is shown.
-- MapFileName = MapAreaID
local MICRO_DUNGEON_IDS = {
	ShrineofTwoMoons = 903,
	ShrineofSevenStars = 905,
}

function Frenemy:HandleZoneChange(eventName)
	local in_instance = _G.IsInInstance()

	if private.inCombat then
		private.needsAreaID = true
		return
	end
	local mapZoneID = _G.GetCurrentMapAreaID()

	local worldMapFrame = _G.WorldMapFrame
	local mapIsVisible = worldMapFrame:IsVisible()
	local SFXValue = tonumber(_G.GetCVar("Sound_EnableSFX"))

	if not mapIsVisible then
		_G.SetCVar("Sound_EnableSFX", 0)
		worldMapFrame:Show()
	end
	local _, _, _, _, microDungeonMapName = _G.GetMapInfo()
	local microDungeonID = MICRO_DUNGEON_IDS[microDungeonMapName]

	_G.SetMapToCurrentZone()

	local needDisplayUpdate = CurrentZoneID ~= mapZoneID
	CurrentZoneID = microDungeonID or mapZoneID

	if mapIsVisible then
		_G.SetMapByID(mapZoneID)
	else
		worldMapFrame:Hide()
		_G.SetCVar("Sound_EnableSFX", SFXValue)
	end

	local pvpType, _, factionName = _G.GetZonePVPInfo()

	if CurrentZoneID and CurrentZoneID >= 1 then
		if pvpType == "hostile" or pvpType == "friendly" then
			pvpType = factionName
		elseif not pvpType or pvpType == "" then
			pvpType = "normal"
		end

		local zonePVPStatus = private.ZonePVPStatusByLabel[pvpType:upper()]
		DB.ZoneData[CurrentZoneID] = zonePVPStatus
		SetZoneNameColors(CurrentZoneID, zonePVPStatus)

		if needDisplayUpdate then
			UpdateAndDisplay()
		end
	end
end

-- ----------------------------------------------------------------------------
-- Framework.
-- ----------------------------------------------------------------------------
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

function Frenemy:OnEnable()
	self:RegisterEvent("BN_FRIEND_INFO_CHANGED")
	self:RegisterEvent("BN_TOON_NAME_UPDATED")
	self:RegisterEvent("FRIENDLIST_UPDATE")
	self:RegisterEvent("GUILD_RANKS_UPDATE")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:RegisterEvent("ZONE_CHANGED", "HandleZoneChange")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "HandleZoneChange")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "HandleZoneChange")

	self:HandleZoneChange("OnEnable")

	RequestUpdates()
	self.RequestUpdater = CreateUpdater(RequestUpdater, REQUEST_UPDATE_INTERVAL, RequestUpdates)
	self.RequestUpdater:Play()
end

function Frenemy:OnInitialize()
	DB = LibStub("AceDB-3.0"):New(FOLDER_NAME .. "DB", DB_DEFAULTS, true).global
	private.DB = DB

	local LDBIcon = LibStub("LibDBIcon-1.0")
	if LDBIcon then
		LDBIcon:Register(FOLDER_NAME, DataObject, DB.DataObject.MinimapIcon)
	end
	private.SetupOptions()

	for zoneID, zonePVPStatus in pairs(DB.ZoneData) do
		SetZoneNameColors(zoneID, zonePVPStatus)
	end
end
