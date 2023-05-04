--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------
local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@class PrivateNamespace

local Icon = private.TooltipHandler.Icon
local OnlineFriendsByName = private.TooltipHandler.OnlineFriendsByName
local People = private.People
local Player = private.TooltipHandler.Player
local PlayerLists = private.TooltipHandler.PlayerLists

local BattleNetFriend_OnMouseUp = private.TooltipHandler.CellScripts.BattleNetFriend_OnMouseUp
local ColorPlayerLevel = private.TooltipHandler.Helpers.ColorPlayerLevel
local ColumnLabel = private.TooltipHandler.Helpers.ColumnLabel
local CreateSectionHeader = private.TooltipHandler.Helpers.CreateSectionHeader
local IsUnitGrouped = private.TooltipHandler.Helpers.IsUnitGrouped
local ToggleColumnSortMethod = private.TooltipHandler.CellScripts.ToggleColumnSortMethod

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnFolderName)

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

-- Used to handle duplication between in-game and RealID friends.
local WoWFriendIndexByName = {}

--------------------------------------------------------------------------------
---- Column and ColSpan
--------------------------------------------------------------------------------

local ColumnID = {
    Level = 1,
    Class = 2,
    PresenceName = 3,
    ToonName = 4,
    ZoneName = 5,
    RealmName = 6,
    Note = 7,
}

local ColSpan = {
    Level = 1,
    Class = 1,
    PresenceName = 1,
    ToonName = 1,
    ZoneName = 1,
    RealmName = 1,
    Note = 2,
}

--------------------------------------------------------------------------------
---- Data Compilation
--------------------------------------------------------------------------------

local function GenerateData()
    table.wipe(WoWFriendIndexByName)

    if People.Friends.Online == 0 then
        return
    end

    for friendIndex = 1, People.Friends.Online do
        local friendInfo = C_FriendList.GetFriendInfoByIndex(friendIndex)
        local fullToonName = friendInfo.name
        local toonName, realmName = strsplit("-", fullToonName)
        local zoneName = friendInfo.area

        WoWFriendIndexByName[fullToonName] = friendIndex
        WoWFriendIndexByName[toonName] = friendIndex

        if not OnlineFriendsByName[toonName] then
            ---@type WoWFriend
            local friendData = {
                Class = friendInfo.className,
                FullToonName = fullToonName,
                IsLocalFriend = true,
                Level = friendInfo.level,
                Note = friendInfo.notes,
                RealmName = realmName or Player.RealmName,
                StatusIcon = friendInfo.afk and Icon.Status.AFK
                    or (friendInfo.dnd and Icon.Status.DND or Icon.Status.Online),
                ToonName = toonName,
                ZoneName = zoneName ~= "" and zoneName or UNKNOWN,
            }

            table.insert(PlayerLists.WoWFriends, friendData)
            OnlineFriendsByName[toonName] = friendData
        end
    end
end

--------------------------------------------------------------------------------
---- Cell Scripts
--------------------------------------------------------------------------------

---@param _ LibQTip-2.0.Cell
---@param friend WoWFriend
local function WoWFriend_OnMouseUp(_, friend, mouseButton)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

    local playerName = friend.RealmName == Player.RealmName and friend.ToonName or friend.FullToonName

    if mouseButton == "LeftButton" then
        if IsAltKeyDown() then
            C_PartyInfo.InviteUnit(playerName)
        elseif IsControlKeyDown() then
            FriendsFrame.NotesID = WoWFriendIndexByName[playerName]
            StaticPopup_Show("SET_FRIENDNOTE", playerName)
        else
            ChatFrame_SendTell(playerName)
        end
    elseif mouseButton == "RightButton" then
        private.TooltipHandler.Tooltip.Main:SetFrameStrata("DIALOG")
        CloseDropDownMenus()
        FriendsFrame_ShowDropdown(friend.FullToonName, true, nil, nil, nil, true)
    end
end

--------------------------------------------------------------------------------
---- WoW Friends
--------------------------------------------------------------------------------

---@param tooltip LibQTip-2.0.Tooltip
local function DisplaySectionWoWFriends(tooltip)
    if #PlayerLists.WoWFriends == 0 then
        return
    end

    local DB = private.DB
    local sectionIsCollapsed = DB.Tooltip.CollapsedSections.WoWFriends

    CreateSectionHeader(tooltip, FRIENDS, sectionIsCollapsed, "WoWFriends")

    if sectionIsCollapsed then
        return
    end

    --------------------------------------------------------------------------------
    ---- Section Header
    --------------------------------------------------------------------------------

    local headerLine = tooltip:AddLine()

    headerLine:SetColor(0, 0, 0, 1)

    headerLine
        :GetCell(ColumnID.Level, ColSpan.Level)
        :SetJustifyH("LEFT")
        :SetText(ColumnLabel(Icon.Column.Level, "WoWFriends:Level"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Level")

    headerLine
        :GetCell(ColumnID.Class, ColSpan.Class)
        :SetText(ColumnLabel(Icon.Column.Class, "WoWFriends:Class"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Class")

    headerLine
        :GetCell(ColumnID.PresenceName, ColSpan.PresenceName)
        :SetText(ColumnLabel(BATTLENET_FRIEND, "WoWFriends:PresenceName"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:PresenceName")

    headerLine
        :GetCell(ColumnID.ToonName, ColSpan.ToonName)
        :SetText(ColumnLabel(NAME, "WoWFriends:ToonName"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:ToonName")

    headerLine
        :GetCell(ColumnID.ZoneName, ColSpan.ZoneName)
        :SetText(ColumnLabel(ZONE, "WoWFriends:ZoneName"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:ZoneName")

    headerLine
        :GetCell(ColumnID.RealmName, ColSpan.RealmName)
        :SetText(ColumnLabel(L.COLUMN_LABEL_REALM, "WoWFriends:RealmName"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:RealmName")

    if DB.Tooltip.NotesArrangement.WoWFriends == private.Preferences.Tooltip.NotesArrangement.Column then
        headerLine
            :GetCell(ColumnID.Note, ColSpan.Note)
            :SetText(ColumnLabel(LABEL_NOTE, "WoWFriends:Note"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Note")
    end

    --------------------------------------------------------------------------------
    ---- Section Body
    --------------------------------------------------------------------------------

    tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

    local classToken = private.TooltipHandler.Class.Token
    local tooltipIcon = private.TooltipHandler.Icon

    for index = 1, #PlayerLists.WoWFriends do
        local friend = PlayerLists.WoWFriends[index]
        local groupIndicator = IsUnitGrouped(friend.ToonName) and Icon.Player.Group or ""
        local presenceName = friend.PresenceName
                and ("%s%s|r"):format(FRIENDS_BNET_NAME_COLOR_CODE, friend.PresenceName)
            or NOT_APPLICABLE

        local line = tooltip:AddLine()

        line:GetCell(ColumnID.Level, ColSpan.Level):SetText(ColorPlayerLevel(friend.Level))

        line:GetCell(ColumnID.Class, ColSpan.Class)
            :SetText(tooltipIcon.Class[classToken.Female[friend.Class] or classToken.Male[friend.Class]])

        line:GetCell(ColumnID.PresenceName, ColSpan.PresenceName)
            :SetText(("%s%s"):format(friend.StatusIcon, presenceName))

        if friend.PresenceID then
            line:GetCell(ColumnID.PresenceName):SetScript("OnMouseUp", BattleNetFriend_OnMouseUp, friend)
        end

        local toonNameCell = line:GetCell(ColumnID.ToonName, ColSpan.ToonName)

        toonNameCell:SetText(
            ("%s%s%s|r%s"):format(
                Icon.Player.Faction,
                private.TooltipHandler.Class.Color[friend.Class] or FRIENDS_WOW_NAME_COLOR_CODE,
                friend.ToonName,
                groupIndicator
            )
        )

        if friend.IsLocalFriend then
            toonNameCell:SetScript("OnMouseUp", WoWFriend_OnMouseUp, friend)
        end

        line:GetCell(ColumnID.ZoneName, ColSpan.ZoneName):SetText(private.MapHandler:ColoredZoneName(friend.ZoneName))

        line:GetCell(ColumnID.RealmName, ColSpan.RealmName):SetText(friend.RealmName)

        if friend.Note then
            local noteText = FRIENDS_OTHER_NAME_COLOR_CODE .. friend.Note .. "|r"

            if DB.Tooltip.NotesArrangement.WoWFriends == private.Preferences.Tooltip.NotesArrangement.Column then
                line:GetCell(ColumnID.Note, ColSpan.Note):SetText(noteText)
            else
                tooltip
                    :AddLine()
                    :GetCell(1, 0)
                    :SetFont("GameTooltipTextSmall")
                    :SetText(("%s %s"):format(Icon.Status.Note, noteText))
            end
        end

        if friend.BroadcastText then
            tooltip:AddLine():GetCell(1, 0):SetFont("GameTooltipTextSmall"):SetText(friend.BroadcastText)
        end
    end

    tooltip:AddLine(" ")
end

--------------------------------------------------------------------------------
---- TooltipHandler Augmentation
--------------------------------------------------------------------------------

---@class TooltipHandler.WoWFriends
private.TooltipHandler.WoWFriends = {
    DisplaySectionWoWFriends = DisplaySectionWoWFriends,
    GenerateData = GenerateData,
}

--------------------------------------------------------------------------------
---- Types
--------------------------------------------------------------------------------

---@class WoWFriend
---@field BroadcastText string? -- Only set when the WoW friend is also a BattleNet friend
---@field Class string?
---@field FullToonName string?
---@field IsLocalFriend boolean
---@field Level number
---@field Note string?
---@field PresenceID? number -- Only set when the WoW friend is also a BattleNet friend
---@field PresenceName? string -- Only set when the WoW friend is also a BattleNet friend
---@field RealmName string
---@field StatusIcon string
---@field ToonName string
---@field ZoneName string
