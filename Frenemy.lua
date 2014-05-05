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
local LibQTip = LibStub('LibQTip-1.0')

local Frenemy = _G.CreateFrame("Frame")
Frenemy:SetScript("OnEvent", function(self, eventName, ...)
	if self[eventName] then
		return self[eventName](self, eventName, ...)
	end
end)

local DataObject = LibStub("LibDataBroker-1.1"):NewDataObject(FOLDER_NAME, {
	icon = [[Interface\Calendar\MeetingIcon]],
	text = " ",
	type = "data source",
})

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

local FACTION_COLOR_HORDE = _G.RED_FONT_COLOR_CODE
local FACTION_COLOR_ALLIANCE = "|cff 0bef3"

local FRIENDS_WOW_NAME_COLOR = _G.FRIENDS_WOW_NAME_COLOR_CODE:gsub("|cff", "")

local GROUP_CHECKMARK = [[|TInterface\Buttons\UI-CheckBox-Check:0|t]]

local PLAYER_FACTION = _G.UnitFactionGroup("player")
local PLAYER_REALM = _G.GetRealmName()

local function CreateIcon(texture_path, icon_size)
	return ("|T%s:%d|t"):format(texture_path, icon_size)
end

local SECTION_ICON_BULLET = CreateIcon([[Interface\QUESTFRAME\UI-Quest-BulletPoint]], 12)

local STATUS_ICON_SIZE = 12

local STATUS_ICON_AFK = CreateIcon(_G.FRIENDS_TEXTURE_AFK, STATUS_ICON_SIZE)
local STATUS_ICON_DND = CreateIcon(_G.FRIENDS_TEXTURE_DND, STATUS_ICON_SIZE)
local STATUS_ICON_MOBILE = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat]], STATUS_ICON_SIZE)
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

local DISPLAY_UPDATER_INTERVAL = 15
local REQUEST_UPDATE_INTERVAL = 30

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
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
		TotalGuildMembersCount, OnlineGuildMembersCount = _G.GetNumGuildMembers()
	end
end

-------------------------------------------------------------------------------
-- DataObject methods.
-------------------------------------------------------------------------------
local DrawTooltip
do
	local BattleNetColumns = {
		Game = 1,
		RealID = 2,
		Name = 3,
		Info = 4,
	}

	local BattleNetColSpans = {
		Game = 1,
		RealID = 1,
		Name = 1,
		Info = 2,
	}

	local GuildColumns = {
		Level = 1,
		Name = 2,
		Rank = 3,
		Zone = 4,
	}

	local GuildColSpans = {
		Level = 1,
		Name = 1,
		Rank = 1,
		Zone = 1,
	}

	local WoWFriendsColumns = {
		Level = 1,
		RealID = 2,
		Name = 3,
		Zone = 4,
		Realm = 5,
	}

	local WoWFriendsColSpans = {
		Level = 1,
		RealID = 1,
		Name = 1,
		Zone = 1,
		Realm = 1,
	}

	local BattleNetAppList = {}
	local BattleNetPlayingList = {}
	local BattleNetWoWList = {}
	local FriendsList = {}
	local GuildList = {}

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

	local function RenderBattleNetLines(sourceList, headerLabel)
		local line = Tooltip:AddLine()
		Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, headerLabel, SECTION_ICON_BULLET), _G.GameFontNormal, "CENTER", 0)
		Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

		line = Tooltip:AddLine()
		Tooltip:SetLineColor(line, 0, 0, 0, 1)

		Tooltip:SetCell(line, BattleNetColumns.RealID, _G.BATTLENET_FRIEND, BattleNetColSpans.RealID)
		Tooltip:SetCell(line, BattleNetColumns.Name, _G.NAME, BattleNetColSpans.Name)
		Tooltip:SetCell(line, BattleNetColumns.Info, _G.INFO, BattleNetColSpans.Info)

		Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

		for index = 1, #sourceList do
			local player = sourceList[index]
			line = Tooltip:AddLine()
			Tooltip:SetCell(line, BattleNetColumns.Game, CLIENT_ICON_TEXTURE_CODES[player.Client], BattleNetColSpans.Game)
			Tooltip:SetCell(line, BattleNetColumns.RealID, ("%s%s%s|r"):format(player.StatusIcon, _G.FRIENDS_BNET_NAME_COLOR_CODE, player.PresenceName), BattleNetColSpans.RealID)
			Tooltip:SetCell(line, BattleNetColumns.Name, ("%s%s|r"):format(_G.FRIENDS_OTHER_NAME_COLOR_CODE, player.ToonName), BattleNetColSpans.Name)
			Tooltip:SetCell(line, BattleNetColumns.Info, player.GameText, BattleNetColSpans.Info)

			if player.Note then
				line = Tooltip:AddLine()
				Tooltip:SetCell(line, BattleNetColumns.Game, player.Note, "GameTooltipTextSmall", 0)
			end

			if player.BroadcastText then
				line = Tooltip:AddLine()
				Tooltip:SetCell(line, BattleNetColumns.Game, player.BroadcastText, "GameTooltipTextSmall", 0)
			end
		end
		Tooltip:AddLine(" ")
	end

	local function Tooltip_OnRelease(self)
		Tooltip = nil
		TooltipAnchor = nil
	end

	function DrawTooltip(anchor_frame)
		if not anchor_frame then
			return
		end
		TooltipAnchor = anchor_frame

		if not Tooltip then
			Tooltip = LibQTip:Acquire(FOLDER_NAME, NUM_TOOLTIP_COLUMNS)
			Tooltip:SetAutoHideDelay(0.25, anchor_frame)
			Tooltip:SetBackdropColor(0.05, 0.05, 0.05, 1)
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
			local headerLine

			if OnlineBattleNetCount > 0 then
				table.wipe(BattleNetAppList)
				table.wipe(BattleNetPlayingList)
				table.wipe(BattleNetWoWList)

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
						FactionColor = faction and (faction == "Horde" and FACTION_COLOR_HORDE or FACTION_COLOR_ALLIANCE) or _G.GRAY_FONT_COLOR_CODE,
						GameText = gameText or "",
						Level = level and tonumber(level) or 0,
						Note = noteText and STATUS_ICON_NOTE .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. noteText .. "|r" or nil,
						PresenceName = presenceName or _G.UNKNOWN,
						RealmName = realmName or "",
						StatusIcon = isAFK and STATUS_ICON_AFK or (isDND and STATUS_ICON_DND or STATUS_ICON_ONLINE),
						ToonName = characterName,
						ZoneName = zoneName or "",
					}

					if client == _G.BNET_CLIENT_WOW then
						table.insert(BattleNetWoWList, entry)
					elseif client == BNET_CLIENT_APP then
						table.insert(BattleNetAppList, entry)
					elseif toonID then
						table.insert(BattleNetPlayingList, entry)
					end
				end

				table.sort(BattleNetPlayingList, ClientSort)

				local hasOnlineWoWFriends = OnlineFriendsCount > 0 or #BattleNetWoWList > 0

				if hasOnlineWoWFriends then
					headerLine = Tooltip:AddLine()
					Tooltip:SetCell(headerLine, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, _G.FRIENDS, SECTION_ICON_BULLET), _G.GameFontNormal, "CENTER", 0)
					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

					line = Tooltip:AddLine()
					Tooltip:SetLineColor(line, 0, 0, 0, 1)

					Tooltip:SetCell(line, WoWFriendsColumns.RealID, _G.BATTLENET_FRIEND, WoWFriendsColSpans.RealID)
					Tooltip:SetCell(line, WoWFriendsColumns.Name, _G.NAME, WoWFriendsColSpans.Name)
					Tooltip:SetCell(line, WoWFriendsColumns.Zone, _G.ZONE, WoWFriendsColSpans.Zone)
					Tooltip:SetCell(line, WoWFriendsColumns.Realm, _G.FRIENDS_LIST_REALM, WoWFriendsColSpans.Realm)

					Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)
				end

				-------------------------------------------------------------------------------
				-- WoW Friends
				-------------------------------------------------------------------------------
				if OnlineFriendsCount > 0 then
					table.wipe(FriendsList)

					for friend_index = 1, OnlineFriendsCount do
						local toonName, level, class, zoneName, connected, status, note = _G.GetFriendInfo(friend_index)

						table.insert(FriendsList, {
							Class = class,
							Level = level,
							Note = note and STATUS_ICON_NOTE .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. note .. "|r" or nil,
							StatusIcon = status == _G.CHAT_FLAG_AFK and STATUS_ICON_AFK or (status == _G.CHAT_FLAG_DND and STATUS_ICON_DND or STATUS_ICON_ONLINE),
							ToonName = toonName,
							ZoneName = zoneName,
						})
					end

					local factionColor = PLAYER_FACTION == "Horde" and FACTION_COLOR_HORDE or FACTION_COLOR_ALLIANCE

					for index = 1, #FriendsList do
						local player = FriendsList[index]

						line = Tooltip:AddLine()
						Tooltip:SetCell(line, WoWFriendsColumns.Level, ColorPlayerLevel(player.Level), WoWFriendsColSpans.Level)
						Tooltip:SetCell(line, WoWFriendsColumns.RealID, ("%s%s"):format(player.StatusIcon, _G.NOT_APPLICABLE), WoWFriendsColSpans.RealID)
						Tooltip:SetCell(line, WoWFriendsColumns.Name, ("|cff%s%s|r%s"):format(CLASS_COLORS[player.Class] or FRIENDS_WOW_NAME_COLOR, player.ToonName, IsGrouped(player.ToonName) and GROUP_CHECKMARK or ""), WoWFriendsColSpans.Name)
						Tooltip:SetCell(line, WoWFriendsColumns.Zone, player.ZoneName, WoWFriendsColSpans.Zone)
						Tooltip:SetCell(line, WoWFriendsColumns.Realm, ("%s%s|r"):format(factionColor, PLAYER_REALM), WoWFriendsColSpans.Realm)

						if player.Note then
							line = Tooltip:AddLine()
							Tooltip:SetCell(line, WoWFriendsColumns.Level, player.Note, "GameTooltipTextSmall", 0)
						end
					end
				end

				-------------------------------------------------------------------------------
				-- BattleNet WoW Friends
				-------------------------------------------------------------------------------
				if #BattleNetWoWList > 0 then
					for index = 1, #BattleNetWoWList do
						local player = BattleNetWoWList[index]

						line = Tooltip:AddLine()
						Tooltip:SetCell(line, WoWFriendsColumns.Level, ColorPlayerLevel(player.Level), WoWFriendsColSpans.Level)
						Tooltip:SetCell(line, WoWFriendsColumns.RealID, ("%s%s%s|r"):format(player.StatusIcon, _G.FRIENDS_BNET_NAME_COLOR_CODE, player.PresenceName), WoWFriendsColSpans.RealID)
						Tooltip:SetCell(line, WoWFriendsColumns.Name, ("|cff%s%s|r%s"):format(CLASS_COLORS[player.Class] or FRIENDS_WOW_NAME_COLOR, player.ToonName, IsGrouped(player.ToonName) and GROUP_CHECKMARK or ""), WoWFriendsColSpans.Name)
						Tooltip:SetCell(line, WoWFriendsColumns.Zone, player.ZoneName, WoWFriendsColSpans.Zone)
						Tooltip:SetCell(line, WoWFriendsColumns.Realm, ("%s%s|r"):format(player.FactionColor, player.RealmName), WoWFriendsColSpans.Realm)

						if player.Note then
							line = Tooltip:AddLine()
							Tooltip:SetCell(line, WoWFriendsColumns.Level, player.Note, "GameTooltipTextSmall", 0)
						end

						if player.BroadcastText then
							line = Tooltip:AddLine()
							Tooltip:SetCell(line, WoWFriendsColumns.Level, player.BroadcastText, "GameTooltipTextSmall", 0)
						end
					end
				end

				if hasOnlineWoWFriends then
					Tooltip:AddLine(" ")
				end

				-------------------------------------------------------------------------------
				-- BattleNet In-Game Friends
				-------------------------------------------------------------------------------
				if #BattleNetPlayingList > 0 then
					RenderBattleNetLines(BattleNetPlayingList, ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)))
				end

				-------------------------------------------------------------------------------
				-- BattleNet Friends
				-------------------------------------------------------------------------------
				if #BattleNetAppList > 0 then
					RenderBattleNetLines(BattleNetAppList, _G.BATTLENET_OPTIONS_LABEL)
				end
			end
		end

		-------------------------------------------------------------------------------
		-- Guild
		-------------------------------------------------------------------------------
		if _G.IsInGuild() then
			line = Tooltip:AddLine()
			Tooltip:SetCell(line, 1, ("%s%s%s"):format(SECTION_ICON_BULLET, _G.GetGuildInfo("player"), SECTION_ICON_BULLET), "GameFontNormal", "CENTER", 0)

			table.wipe(GuildList)

			for index = 1, _G.GetNumGuildMembers() do
				local toonName, rank, rankIndex, level, class, zoneName, note, officerNote, isOnline, status, _, _, _, isMobile = _G.GetGuildRosterInfo(index)

				if isOnline then
					if isMobile then
						status = STATUS_ICON_MOBILE
						zoneName = _G.REMOTE_CHAT
					elseif status == 0 then
						status = STATUS_ICON_ONLINE
					elseif status == 1 then
						status = STATUS_ICON_AFK
					elseif status == 2 then
						status = STATUS_ICON_DND
					end

					table.insert(GuildList, {
						Class = class,
						Level = level,
						Note = (note and note ~= "") and STATUS_ICON_NOTE .. _G.FRIENDS_OTHER_NAME_COLOR_CODE .. note .. "|r" or nil,
						OfficerNote = (officerNote and officerNote ~= "") and STATUS_ICON_NOTE .. _G.ORANGE_FONT_COLOR_CODE .. officerNote .. "|r" or nil,
						Rank = rank,
						StatusIcon = status,
						ToonName = _G.Ambiguate(toonName, "none"),
						ZoneName = zoneName,
					})
				end
			end

			Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

			line = Tooltip:AddLine()
			Tooltip:SetLineColor(line, 0, 0, 0, 1)

			Tooltip:SetCell(line, GuildColumns.Name, _G.NAME, GuildColSpans.Name)
			Tooltip:SetCell(line, GuildColumns.Rank, _G.RANK, GuildColSpans.Rank)
			Tooltip:SetCell(line, GuildColumns.Zone, _G.ZONE, GuildColSpans.Zone)

			Tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

			for index = 1, #GuildList do
				local player = GuildList[index]

				line = Tooltip:AddLine()
				Tooltip:SetCell(line, GuildColumns.Level, ColorPlayerLevel(player.Level), GuildColSpans.Level)
				Tooltip:SetCell(line, GuildColumns.Name, ("%s|cff%s%s|r%s"):format(player.StatusIcon, CLASS_COLORS[player.Class] or "ffffff", player.ToonName, IsGrouped(player.ToonName) and GROUP_CHECKMARK or ""), GuildColSpans.Name)
				Tooltip:SetCell(line, GuildColumns.Rank, player.Rank, GuildColSpans.Rank)
				Tooltip:SetCell(line, GuildColumns.Zone, player.ZoneName or _G.UNKNOWN, GuildColSpans.Zone)

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
		end

		Tooltip:UpdateScrolling()
		Tooltip:Show()
	end
end -- do-block

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

function Frenemy:PLAYER_LOGIN()
	Frenemy.RequestUpdater = CreateUpdater(Frenemy, REQUEST_UPDATE_INTERVAL, RequestUpdates)
	Frenemy.RequestUpdater:Play()
end

Frenemy:RegisterEvent("BN_FRIEND_INFO_CHANGED")
Frenemy:RegisterEvent("BN_TOON_NAME_UPDATED")
Frenemy:RegisterEvent("FRIENDLIST_UPDATE")
Frenemy:RegisterEvent("GUILD_RANKS_UPDATE")
Frenemy:RegisterEvent("GUILD_ROSTER_UPDATE")

Frenemy:RegisterEvent("PLAYER_LOGIN")
