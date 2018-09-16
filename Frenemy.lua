-- ----------------------------------------------------------------------------
-- Localized Lua globals.
-- ----------------------------------------------------------------------------
-- Libraries
local math = _G.math
local string = _G.string
local table = _G.table

-- Functions
local pairs = _G.pairs
local tonumber = _G.tonumber
local time = _G.time
local type = _G.type

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local AddOnFolderName, private = ...

local LibStub = _G.LibStub
local Frenemy = LibStub("AceAddon-3.0"):NewAddon(AddOnFolderName, "AceBucket-3.0", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnFolderName)
local Dialog = LibStub("LibDialog-1.0")
local HereBeDragons = LibStub("HereBeDragons-2.0")
local LibQTip = LibStub('LibQTip-1.0')

local DataObject = LibStub("LibDataBroker-1.1"):NewDataObject(AddOnFolderName, {
	icon = [[Interface\Calendar\MeetingIcon]],
	text = " ",
	type = "data source",
})

-- ----------------------------------------------------------------------------
-- Debugger.
-- ----------------------------------------------------------------------------
do
	local TextDump = LibStub("LibTextDump-1.0")

	local DEBUGGER_WIDTH = 750
	local DEBUGGER_HEIGHT = 800

	local debugger

	function private.Debug(...)
		if not debugger then
			debugger = TextDump:New(("%s Debug Output"):format(AddOnFolderName), DEBUGGER_WIDTH, DEBUGGER_HEIGHT)
		end

		local message = string.format(...)
		debugger:AddLine(message, "%X")

		return message
	end

	function private.GetDebugger()
		if not debugger then
			debugger = TextDump:New(("%s Debug Output"):format(AddOnFolderName), DEBUGGER_WIDTH, DEBUGGER_HEIGHT)
		end

		return debugger
	end
end

-- ----------------------------------------------------------------------------
-- Constants
-- ----------------------------------------------------------------------------
local BNET_CLIENT_MOBILE = "BSAp"

local CLIENT_SORT_ORDERS = {
	[_G.BNET_CLIENT_WOW] = 1,
	[_G.BNET_CLIENT_SC2] = 2,
	[_G.BNET_CLIENT_D3] = 3,
	[_G.BNET_CLIENT_WTCG] = 4,
	[_G.BNET_CLIENT_HEROES] = 5,
	[_G.BNET_CLIENT_OVERWATCH] = 6,
	[_G.BNET_CLIENT_SC] = 7,
	[_G.BNET_CLIENT_DESTINY2] = 8,
	[_G.BNET_CLIENT_COD] = 9,
	[_G.BNET_CLIENT_CLNT] = 10,
	[_G.BNET_CLIENT_APP] = 11,
	[BNET_CLIENT_MOBILE] = 12,
}

local NON_GAME_CLIENT = {
	[_G.BNET_CLIENT_CLNT] = true,
	[_G.BNET_CLIENT_APP] = true,
	[BNET_CLIENT_MOBILE] = true,
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

	for index = 1, #_G.CLASS_SORT_ORDER do
		local className = _G.CLASS_SORT_ORDER[index]
		local left, right, top, bottom = _G.unpack(_G.CLASS_ICON_TCOORDS[className])
		CLASS_ICONS[className] = textureFormat:format(left * textureSize, right * textureSize, top * textureSize, bottom * textureSize)
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

local FACTION_NAME_TO_ICON = {
	Alliance = CreateIcon([[Interface\COMMON\icon-alliance]], FACTION_ICON_SIZE),
	Horde = CreateIcon([[Interface\COMMON\icon-horde]], FACTION_ICON_SIZE),
	Neutral = CreateIcon([[Interface\COMMON\Indicator-Gray]], FACTION_ICON_SIZE),
}

local HELP_ICON = CreateIcon([[Interface\COMMON\help-i]], 20)

local PLAYER_ICON_GROUP = [[|TInterface\Scenarios\ScenarioIcon-Check:0|t]]
local PLAYER_ICON_FACTION = FACTION_NAME_TO_ICON[PLAYER_FACTION]

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
local OnlineBattleNetCount = 0
local OnlineFriendsCount = 0
local OnlineGuildMembersCount = 0

local TotalBattleNetCount = 0
local TotalFriendsCount = 0
local TotalGuildMembersCount = 0

-- Zone data
local CurrentMapID

-- Populated from SavedVariables and during travel.
local ZoneColorsByName = {
	[_G.GARRISON_LOCATION_TOOLTIP] = private.ZonePVPStatusRGB[private.ZonePVPStatus.Normal]
}

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
			SectionDisplayOrders = {
				"WoWFriends",
				"BattleNetGames",
				"BattleNetApp",
				"Guild",
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
			label = _G.GREEN_FONT_COLOR_CODE .. _G.GUILDCONTROL_OPTION9 .. "|r",
			max_letters = 128,
			text = _G.GetGuildRosterMOTD(),
			width = 200,
		},
	},
	show_while_dead = true,
	hide_on_escape = true,
	icon = [[Interface\Calendar\MeetingIcon]],
	width = 400,
	on_show = function(self)
		self.text:SetFormattedText("%s%s|r", _G.BATTLENET_FONT_COLOR_CODE, AddOnFolderName)
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
	local color = ZoneColorsByName[zoneName:gsub(" %b()", "")] or _G.GRAY_FONT_COLOR
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

local function SetMapNameColor(mapID, zonePVPStatus)
	local mapName = HereBeDragons:GetLocalizedMap(mapID)

	if not mapName then
		DB.ZoneData[mapID] = nil
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
	local OnlineFriendsByPresenceName = {}
	local OnlineFriendsByName = {}
	local GuildMemberIndexByName = {}
	local WoWFriendIndexByName = {}

	-- ----------------------------------------------------------------------------
	-- Data compilation.
	-- ----------------------------------------------------------------------------
	local function GenerateTooltipData()
		for _, data in pairs(PlayerLists) do
			table.wipe(data)
		end

		table.wipe(OnlineFriendsByName)
		table.wipe(OnlineFriendsByPresenceName)
		table.wipe(GuildMemberIndexByName)
		table.wipe(WoWFriendIndexByName)

		if OnlineFriendsCount > 0 then
			for friendIndex = 1, OnlineFriendsCount do
				local fullToonName, level, class, zoneName, _, status, note = _G.GetFriendInfo(friendIndex)
				local toonName, realmName = ("-"):split(fullToonName)

				WoWFriendIndexByName[fullToonName] = friendIndex
				WoWFriendIndexByName[toonName] = friendIndex

				if not OnlineFriendsByName[toonName] then
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

					table.insert(PlayerLists.WoWFriends, entry)
					OnlineFriendsByName[toonName] = entry
				end
			end
		end

		if OnlineBattleNetCount > 0 then
			for battleNetIndex = 1, OnlineBattleNetCount do
				local bnetAccountID, accountName, battleTag, _, _, bnetGameAccountID, _, _, _, isAFK, isDND, messageText, noteText, _, messageTime = _G.BNGetFriendInfo(battleNetIndex)
				local numToons = _G.BNGetNumFriendGameAccounts(battleNetIndex)

				for toonIndex = 1, numToons do
					local _, toonName, client, realmName, _, factionName, _, class, _, zoneName, level, gameText = _G.BNGetFriendGameAccountInfo(battleNetIndex, toonIndex)
					local characterName = _G.BNet_GetValidatedCharacterName(toonName, battleTag, client)
					local entry = {
						BroadcastText = (messageText and messageText ~= "") and ("%s%s%s (%s)|r"):format(BROADCAST_ICON, _G.FRIENDS_OTHER_NAME_COLOR_CODE, messageText, _G.SecondsToTime(time() - messageTime, false, true, 1)) or nil,
						Class = class,
						Client = client,
						ClientIndex = CLIENT_SORT_ORDERS[client],
						FactionIcon = FACTION_NAME_TO_ICON[factionName],
						GameText = gameText ~= "" and gameText or _G.UNKNOWN,
						Level = level and tonumber(level) or 0,
						Note = noteText ~= "" and noteText,
						PresenceID = bnetAccountID,
						PresenceName = accountName or _G.UNKNOWN,
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
						elseif not OnlineFriendsByPresenceName[entry.PresenceName] then
							table.insert(PlayerLists.WoWFriends, entry)
							OnlineFriendsByPresenceName[entry.PresenceName] = entry
						end
					elseif not OnlineFriendsByPresenceName[entry.PresenceName] then
						if NON_GAME_CLIENT[client] then
							table.insert(PlayerLists.BattleNetApp, entry)
						elseif bnetGameAccountID then
							table.insert(PlayerLists.BattleNetGames, entry)
						end

						OnlineFriendsByPresenceName[entry.PresenceName] = entry
					end
				end
			end
		end

		if _G.IsInGuild() then
			for index = 1, _G.GetNumGuildMembers() do
				local fullToonName, rank, rankIndex, level, class, zoneName, note, officerNote, isOnline, awayStatus, _, _, _, isMobile = _G.GetGuildRosterInfo(index)

				if isOnline or isMobile then
					local toonName, realmName = ("-"):split(fullToonName)

					local statusIcon
					if awayStatus == 0 then
						statusIcon = isOnline and STATUS_ICON_ONLINE or STATUS_ICON_MOBILE_ONLINE
					elseif awayStatus == 1 then
						statusIcon = isOnline and STATUS_ICON_AFK or STATUS_ICON_MOBILE_AWAY
					elseif awayStatus == 2 then
						statusIcon = isOnline and STATUS_ICON_DND or STATUS_ICON_MOBILE_BUSY
					end

					-- Don't rely on the zoneName from GetGuildRosterInfo - it can be slow, and the player should see their own zone change instantaneously if
					-- traveling with the tooltip showing.
					if isOnline and toonName == PLAYER_NAME then
						zoneName = CurrentMapID and HereBeDragons:GetLocalizedMap(CurrentMapID) or _G.UNKNOWN
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
						StatusIcon = statusIcon,
						ToonName = toonName,
						ZoneName = isMobile and (isOnline and ("%s %s"):format(zoneName or _G.UNKNOWN, _G.PARENS_TEMPLATE:format(_G.REMOTE_CHAT)) or _G.REMOTE_CHAT) or (zoneName or _G.UNKNOWN),
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
	local function BattleNetFriend_OnMouseUp(_, playerEntry, button)
		_G.PlaySound(_G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

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

	local function GuildMember_OnMouseUp(_, playerEntry, button)
		if not _G.IsAddOnLoaded("Blizzard_GuildUI") then
			_G.LoadAddOn("Blizzard_GuildUI")
		end

		_G.PlaySound(_G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

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

	local function GuildMOTD_OnMouseUp()
		Dialog:Spawn("FrenemySetGuildMOTD")
	end

	local function ToggleColumnSortMethod(_, sortFieldData)
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

	local SectionDropDown = _G.CreateFrame("Frame", AddOnFolderName .. "SectionDropDown", _G.UIParent, "UIDropDownMenuTemplate")
	SectionDropDown.displayMode = "MENU"
	SectionDropDown.info = {}
	SectionDropDown.levelAdjust = 0

	local function ChangeSectionOrder(self, currentPosition, direction)
		local sectionEntries = DB.Tooltip.SectionDisplayOrders
		local newPosition

		currentPosition = tonumber(currentPosition)

		if direction == "up" then
			newPosition = currentPosition - 1
		elseif direction == "down" then
			newPosition = currentPosition + 1
		end

		if not newPosition then
			return
		end

		local evictedEntry = sectionEntries[newPosition]
		sectionEntries[newPosition] = sectionEntries[currentPosition]
		sectionEntries[currentPosition] = evictedEntry
		DrawTooltip(TooltipAnchor)
	end

	local function ToggleSectionVisibility(self, sectionName)
		DB.Tooltip.CollapsedSections[sectionName] = not DB.Tooltip.CollapsedSections[sectionName]
		DrawTooltip(TooltipAnchor)
	end

	local function InitializeSectionDropDown(self, level)
		if not level then
			return
		end
		local info = SectionDropDown.info
		table.wipe(info)

		if level == 1 then
			local sectionName = _G.UIDROPDOWNMENU_MENU_VALUE

			info.arg1 = sectionName
			info.func = ToggleSectionVisibility
			info.notCheckable = true
			info.text = DB.Tooltip.CollapsedSections[sectionName] and L.EXPAND_SECTION or L.COLLAPSE_SECTION
			_G.UIDropDownMenu_AddButton(info, level)

			local currentPosition

			for index = 1, #DB.Tooltip.SectionDisplayOrders do
				if DB.Tooltip.SectionDisplayOrders[index] == sectionName then
					currentPosition = index
					break
				end
			end

			if not currentPosition then
				return
			end

			info.arg1 = currentPosition
			info.func = ChangeSectionOrder

			if currentPosition ~= 1 then
				info.arg2 = "up"
				info.text = L.MOVE_SECTION_UP
				_G.UIDropDownMenu_AddButton(info, level)
			end

			if currentPosition ~= #DB.Tooltip.SectionDisplayOrders then
				info.arg2 = "down"
				info.text = L.MOVE_SECTION_DOWN
				_G.UIDropDownMenu_AddButton(info, level)
			end
		end
	end

	SectionDropDown.initialize = InitializeSectionDropDown

	local function SectionTitle_OnMouseUp(_, sectionName, mouseButton)
		if mouseButton == "RightButton" then
			Tooltip:SetFrameStrata("DIALOG")
			_G.CloseDropDownMenus()
			_G.ToggleDropDownMenu(1, sectionName, SectionDropDown, "cursor")
			return
		end

		ToggleSectionVisibility(nil, sectionName)
	end

	local function WoWFriend_OnMouseUp(_, playerEntry, mouseButton)
		_G.PlaySound(_G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

		local playerName = playerEntry.Realm == PLAYER_REALM and playerEntry.ToonName or playerEntry.FullToonName

		if mouseButton == "LeftButton" then
			if _G.IsAltKeyDown() then
				_G.InviteToGroup(playerName)
			elseif _G.IsControlKeyDown() then
				_G.FriendsFrame.NotesID = WoWFriendIndexByName[playerName]
				_G.StaticPopup_Show("SET_FRIENDNOTE", playerName)
			else
				_G.ChatFrame_SendTell(playerName)
			end
		elseif mouseButton == "RightButton" then
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

	local function HideHelpTip()
		if HelpTip then
			HelpTip:Hide()
			HelpTip:Release()
			HelpTip = nil
		end
		Tooltip:SetFrameStrata("TOOLTIP")
	end

	local function ShowHelpTip(tooltipCell)
		local helpTip = LibQTip:Acquire(AddOnFolderName .. "HelpTip", 2)
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
			local line = firstEntryType and helpTip:AddLine() or helpTip:AddLine(" ")

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

	-- ----------------------------------------------------------------------------
	-- WoW Friends
	-- ----------------------------------------------------------------------------
	local function DisplaySectionWoWFriends()
		if #PlayerLists.WoWFriends > 0 then
			local line = Tooltip:AddLine()

			if not DB.Tooltip.CollapsedSections.WoWFriends then
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.FRIENDS, SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", SectionTitle_OnMouseUp, "WoWFriends")

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
				Tooltip:SetCellScript(line, 1, "OnMouseUp", SectionTitle_OnMouseUp, "WoWFriends")
			end
		end
	end

	-- ----------------------------------------------------------------------------
	-- BattleNet In-Game Friends
	-- ----------------------------------------------------------------------------
	local function DisplaySectionBattleNetGames()
		if #PlayerLists.BattleNetGames > 0 then
			local line = Tooltip:AddLine()

			if not DB.Tooltip.CollapsedSections.BattleNetGames then
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", SectionTitle_OnMouseUp, "BattleNetGames")

				Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

				line = Tooltip:AddLine()
				Tooltip:SetCell(line, BattleNetColumns.Client, ColumnLabel(COLUMN_ICON_GAME, "BattleNetGames:ClientIndex"))

				Tooltip:SetCellScript(line, BattleNetColumns.Client, "OnMouseUp", ToggleColumnSortMethod, "BattleNetGames:ClientIndex")

				RenderBattleNetLines("BattleNetGames", line, DB.Tooltip.NotesArrangement.BattleNetGames)
			else
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), SECTION_ICON_DISABLED), _G.GameFontDisable, "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", SectionTitle_OnMouseUp, "BattleNetGames")
			end
		end
	end

	-- ----------------------------------------------------------------------------
	-- BattleNet Friends
	-- ----------------------------------------------------------------------------
	local function DisplaySectionBattleNetApp()
		if #PlayerLists.BattleNetApp > 0 then
			local line = Tooltip:AddLine()

			if not DB.Tooltip.CollapsedSections.BattleNetApp then
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.BATTLENET_OPTIONS_LABEL, SECTION_ICON_ENABLED), _G.GameFontNormal, "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", SectionTitle_OnMouseUp, "BattleNetApp")

				Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

				RenderBattleNetLines("BattleNetApp", Tooltip:AddLine(), DB.Tooltip.NotesArrangement.BattleNetApp)
			else
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, _G.BATTLENET_OPTIONS_LABEL, SECTION_ICON_DISABLED), _G.GameFontDisable, "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", SectionTitle_OnMouseUp, "BattleNetApp")
			end
		end
	end

	-- ----------------------------------------------------------------------------
	-- Guild
	-- ----------------------------------------------------------------------------
	local GuildMOTDText
	local GuildMOTDLine

	local function DisplaySectionGuild()
		if #PlayerLists.Guild > 0 then
			local line = Tooltip:AddLine()

			if not DB.Tooltip.CollapsedSections.Guild then
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_ENABLED, _G.GetGuildInfo("player"), SECTION_ICON_ENABLED), "GameFontNormal", "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", SectionTitle_OnMouseUp, "Guild")

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
				GuildMOTDText = _G.GetGuildRosterMOTD()

				if GuildMOTDText and GuildMOTDText ~= "" then
					Tooltip:AddLine(" ")

					GuildMOTDLine = Tooltip:AddLine()

					if _G.CanEditMOTD() then
						Tooltip:SetCellScript(GuildMOTDLine, 1, "OnMouseUp", GuildMOTD_OnMouseUp)
					end

					Tooltip:AddLine(" ")
				end
			else
				Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_DISABLED, _G.GetGuildInfo("player"), SECTION_ICON_DISABLED), "GameFontDisable", "CENTER", 0)
				Tooltip:SetCellScript(line, 1, "OnMouseUp", SectionTitle_OnMouseUp, "Guild")
			end
		end
	end

	local SECTION_NAME_TO_DISPLAY_FUNCTION = {
		WoWFriends = DisplaySectionWoWFriends,
		BattleNetGames = DisplaySectionBattleNetGames,
		BattleNetApp = DisplaySectionBattleNetApp,
		Guild = DisplaySectionGuild,
	}

	function DrawTooltip(anchorFrame)
		if not anchorFrame then
			return
		end

		TooltipAnchor = anchorFrame
		GenerateTooltipData()

		if not Tooltip then
			Tooltip = LibQTip:Acquire(AddOnFolderName, NUM_TOOLTIP_COLUMNS)
			Tooltip:SetAutoHideDelay(DB.Tooltip.HideDelay, anchorFrame)
			Tooltip:SetBackdropColor(0.05, 0.05, 0.05, 1)
			Tooltip:SetScale(DB.Tooltip.Scale)
			Tooltip:SmartAnchorTo(anchorFrame)
			Tooltip:SetHighlightTexture([[Interface\ClassTrainerFrame\TrainerTextures]])
			Tooltip:SetHighlightTexCoord(0.00195313, 0.57421875, 0.75390625, 0.84570313)

			Tooltip.OnRelease = Tooltip_OnRelease
		end

		Tooltip:Clear()
		Tooltip:SetCellMarginH(0)
		Tooltip:SetCellMarginV(1)

		Tooltip:SetCell(Tooltip:AddLine(), 1, AddOnFolderName, TitleFont, "CENTER", 0)
		Tooltip:AddSeparator(1, 0.510, 0.773, 1.0)

		GuildMOTDLine = nil
		GuildMOTDText = nil

		for index = 1, #DB.Tooltip.SectionDisplayOrders do
			SECTION_NAME_TO_DISPLAY_FUNCTION[DB.Tooltip.SectionDisplayOrders[index]]()
		end
		Tooltip:Show()

		-- This must be done after everything else has been added to the tooltip in order to have an accurate width.
		if GuildMOTDLine and GuildMOTDText then
			Tooltip:SetCell(GuildMOTDLine, 1, _G.GUILD_MOTD_TEMPLATE:format(_G.GREEN_FONT_COLOR_CODE .. GuildMOTDText .. "|r"), 0, 0, 0, Tooltip:GetWidth() - 20)
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
	local output = ("%s: %s%d/%d|r"):format(_G.FRIENDS, _G.BATTLENET_FONT_COLOR_CODE, OnlineFriendsCount + OnlineBattleNetCount, TotalFriendsCount + TotalBattleNetCount)

	if _G.IsInGuild() then
		output = ("%s %s: %s%d/%d|r"):format(output, _G.GUILD, _G.GREEN_FONT_COLOR_CODE, OnlineGuildMembersCount, TotalGuildMembersCount)
	end

	self.text = output
end

-- ----------------------------------------------------------------------------
-- Events.
-- ----------------------------------------------------------------------------
function Frenemy:PLAYER_REGEN_DISABLED()
	private.inCombat = true
end


function Frenemy:PLAYER_REGEN_ENABLED()
	private.inCombat = nil

	if private.needsAreaID then
		self:HandleZoneChange()
		private.needsAreaID = nil
	end
end

function Frenemy:HandleZoneChange()
	if private.inCombat then
		private.needsAreaID = true
		return
	end

	local mapID = HereBeDragons:GetPlayerZone()
	local needDisplayUpdate = CurrentMapID ~= mapID
	CurrentMapID = mapID

	if CurrentMapID and CurrentMapID > 0 then
		local pvpType, _, factionName = _G.GetZonePVPInfo()

		if pvpType == "hostile" or pvpType == "friendly" then
			pvpType = factionName
		elseif not pvpType or pvpType == "" then
			pvpType = "normal"
		end

		local zonePVPStatus = private.ZonePVPStatusByLabel[pvpType:upper()]
		DB.ZoneData[CurrentMapID] = zonePVPStatus
		SetMapNameColor(CurrentMapID, zonePVPStatus)

		if needDisplayUpdate then
			self:UpdateData()
		end
	end
end

-- ----------------------------------------------------------------------------
-- Framework.
-- ----------------------------------------------------------------------------
local function RequestUpdates()
	_G.ShowFriends()

	if _G.IsInGuild() then
		_G.GuildRoster()
	end
end

function Frenemy:OnEnable()
	self:RegisterBucketEvent({
		"BN_FRIEND_INFO_CHANGED",
		"FRIENDLIST_UPDATE",
		"GUILD_RANKS_UPDATE",
		"GUILD_ROSTER_UPDATE",
	}, 1, "UpdateData")

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleZoneChange")
	self:RegisterEvent("ZONE_CHANGED", "HandleZoneChange")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "HandleZoneChange")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "HandleZoneChange")

	self:ScheduleRepeatingTimer(RequestUpdates, REQUEST_UPDATE_INTERVAL)

	RequestUpdates()
end

function Frenemy:OnInitialize()
	DB = LibStub("AceDB-3.0"):New(AddOnFolderName .. "DB", DB_DEFAULTS, true).global
	private.DB = DB

	local LDBIcon = LibStub("LibDBIcon-1.0")
	if LDBIcon then
		LDBIcon:Register(AddOnFolderName, DataObject, DB.DataObject.MinimapIcon)
	end

	private.SetupOptions()
	self:RegisterChatCommand("frenemy", "ChatCommand")

	for zoneID, zonePVPStatus in pairs(DB.ZoneData) do
		SetMapNameColor(zoneID, zonePVPStatus)
	end
end

do
	local UPDATE_DISPLAY_THROTTLE_INTERVAL_SECONDS = 5
	local lastUpdateTime = time()

	function Frenemy:UpdateData()
		UpdateStatistics()
		DataObject:UpdateDisplay()

		if Tooltip and Tooltip:IsShown() then
			local now = time()

			if now > lastUpdateTime + UPDATE_DISPLAY_THROTTLE_INTERVAL_SECONDS then
				lastUpdateTime = now

				DrawTooltip(DataObject)
			end
		end
	end
end

do
	local SUBCOMMAND_FUNCS = {
		--@debug@
		DEBUG = function()
			local debugger = private.GetDebugger()

			if debugger:Lines() == 0 then
				debugger:AddLine("Nothing to report.")
				debugger:Display()
				debugger:Clear()
				return
			end

			debugger:Display()
		end,
		--@end-debug@
	}

	function Frenemy:ChatCommand(input)
		local subcommand, arguments = self:GetArgs(input, 2)

		if subcommand then
			local func = SUBCOMMAND_FUNCS[subcommand:upper()]

			if func then
				func(arguments or "")
			end
		else
			local optionsFrame = _G.InterfaceOptionsFrame

			if optionsFrame:IsVisible() then
				optionsFrame:Hide()
			else
				_G.InterfaceOptionsFrame_OpenToCategory(self.OptionsFrame)
			end
		end
	end
end -- do-block
