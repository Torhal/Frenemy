--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

local People = private.People

local TooltipHandler = private.TooltipHandler
local Icon = TooltipHandler.Icon
local OnlineFriendsByName = TooltipHandler.OnlineFriendsByName
local Player = TooltipHandler.Player
local PlayerLists = TooltipHandler.PlayerLists

local BattleNetFriend_OnMouseUp = TooltipHandler.CellScripts.BattleNetFriend_OnMouseUp
local ToggleColumnSortMethod = TooltipHandler.CellScripts.ToggleColumnSortMethod

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnFolderName)

---@class TooltipHandler.WoWFriendSection
local WoWFriendSection = TooltipHandler.WoWFriendSection

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

-- Used to handle duplication between in-game and RealID friends.
local WoWFriendIndexByName = {}

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
---- Methods
--------------------------------------------------------------------------------

do
    ---@param _ LibQTip-2.0.Cell
    ---@param friend WoWFriend
    local function WoWFriend_OnMouseUp(_, friend, mouseButton)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

        local playerName = friend.RealmName == Player.RealmName and friend.ToonName or friend.FullToonName or ""

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
            TooltipHandler.Tooltip.Main:SetFrameStrata("DIALOG")
            CloseDropDownMenus()
            FriendsFrame_ShowDropdown(friend.FullToonName, true, nil, nil, nil, true)
        end
    end

    ---@param tooltip LibQTip-2.0.Tooltip
    function WoWFriendSection:Display(tooltip)
        if #PlayerLists.WoWFriends == 0 then
            return
        end

        local DB = private.DB
        local sectionIsCollapsed = DB.Tooltip.CollapsedSections.WoWFriends

        TooltipHandler:CreateSectionHeader(
            tooltip,
            ("%s %s"):format(FRIENDS, PARENS_TEMPLATE:format(#PlayerLists.WoWFriends)),
            sectionIsCollapsed,
            "WoWFriends"
        )

        if sectionIsCollapsed then
            return
        end

        --------------------------------------------------------------------------------
        ---- Section Header
        --------------------------------------------------------------------------------

        tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

        local headerRow = tooltip:AddRow()

        headerRow:SetColor(0, 0, 0, 1)

        headerRow
            :GetCell(ColumnID.Level)
            :SetColSpan(ColSpan.Level)
            :SetJustifyH("LEFT")
            :SetText(TooltipHandler:ColumnLabel(Icon.Column.Level, "WoWFriends:Level"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Level")

        headerRow
            :GetCell(ColumnID.Class)
            :SetColSpan(ColSpan.Class)
            :SetText(TooltipHandler:ColumnLabel(Icon.Column.Class, "WoWFriends:Class"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Class")

        headerRow
            :GetCell(ColumnID.PresenceName)
            :SetColSpan(ColSpan.PresenceName)
            :SetText(TooltipHandler:ColumnLabel(BATTLENET_FRIEND, "WoWFriends:PresenceName"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:PresenceName")

        headerRow
            :GetCell(ColumnID.ToonName)
            :SetColSpan(ColSpan.ToonName)
            :SetText(TooltipHandler:ColumnLabel(NAME, "WoWFriends:ToonName"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:ToonName")

        headerRow
            :GetCell(ColumnID.ZoneName)
            :SetColSpan(ColSpan.ZoneName)
            :SetText(TooltipHandler:ColumnLabel(ZONE, "WoWFriends:ZoneName"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:ZoneName")

        headerRow
            :GetCell(ColumnID.RealmName)
            :SetColSpan(ColSpan.RealmName)
            :SetText(TooltipHandler:ColumnLabel(L.COLUMN_LABEL_REALM, "WoWFriends:RealmName"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:RealmName")

        if DB.Tooltip.NotesArrangement.WoWFriends == private.Preferences.Tooltip.NotesArrangement.Column then
            headerRow
                :GetCell(ColumnID.Note)
                :SetColSpan(ColSpan.Note)
                :SetText(TooltipHandler:ColumnLabel(LABEL_NOTE, "WoWFriends:Note"))
                :SetScript("OnMouseUp", ToggleColumnSortMethod, "WoWFriends:Note")
        end

        tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

        --------------------------------------------------------------------------------
        ---- Section Body
        --------------------------------------------------------------------------------

        local classToken = TooltipHandler.Class.Token

        for index = 1, #PlayerLists.WoWFriends do
            local friend = PlayerLists.WoWFriends[index]
            local groupIndicator = TooltipHandler:IsUnitGrouped(friend.ToonName) and Icon.Player.Group or ""
            local presenceName = friend.PresenceName
                    and ("%s%s|r"):format(FRIENDS_BNET_NAME_COLOR_CODE, friend.PresenceName)
                or NOT_APPLICABLE

            local row = tooltip:AddRow()

            row:GetCell(ColumnID.Level):SetColSpan(ColSpan.Level):SetText(TooltipHandler:ColorPlayerLevel(friend.Level))

            row:GetCell(ColumnID.Class)
                :SetColSpan(ColSpan.Class)
                :SetText(Icon.Class[classToken.Female[friend.Class] or classToken.Male[friend.Class]])

            row:GetCell(ColumnID.PresenceName)
                :SetColSpan(ColSpan.PresenceName)
                :SetText(("%s%s"):format(friend.StatusIcon, presenceName))

            if friend.PresenceID then
                row:GetCell(ColumnID.PresenceName):SetScript("OnMouseUp", BattleNetFriend_OnMouseUp, friend)
            end

            local toonNameCell = row:GetCell(ColumnID.ToonName):SetColSpan(ColSpan.ToonName)

            toonNameCell:SetText(
                ("%s%s%s|r%s"):format(
                    Icon.Player.Faction,
                    TooltipHandler.Class.Color[friend.Class] or FRIENDS_WOW_NAME_COLOR_CODE,
                    friend.ToonName,
                    groupIndicator
                )
            )

            if friend.IsLocalFriend then
                toonNameCell:SetScript("OnMouseUp", WoWFriend_OnMouseUp, friend)
            end

            row:GetCell(ColumnID.ZoneName)
                :SetColSpan(ColSpan.ZoneName)
                :SetText(private.MapHandler:ColoredZoneName(friend.ZoneName))

            row:GetCell(ColumnID.RealmName):SetColSpan(ColSpan.RealmName):SetText(friend.RealmName)

            if friend.Note then
                local noteText = FRIENDS_OTHER_NAME_COLOR_CODE .. friend.Note .. "|r"

                if DB.Tooltip.NotesArrangement.WoWFriends == private.Preferences.Tooltip.NotesArrangement.Column then
                    row:GetCell(ColumnID.Note):SetColSpan(ColSpan.Note):SetText(noteText)
                else
                    tooltip
                        :AddRow()
                        :GetCell(1)
                        :SetColSpan(0)
                        :SetFont("GameTooltipTextSmall")
                        :SetText(("%s %s"):format(Icon.Status.Note, noteText))
                end
            end

            if friend.BroadcastText then
                tooltip:AddRow():GetCell(1):SetColSpan(0):SetFont("GameTooltipTextSmall"):SetText(friend.BroadcastText)
            end
        end

        tooltip:AddRow(" ")
    end
end

function WoWFriendSection:GenerateData()
    table.wipe(WoWFriendIndexByName)

    if People.Friends.Online == 0 then
        return
    end

    for friendIndex = 1, People.Friends.Online do
        local friendInfo = C_FriendList.GetFriendInfoByIndex(friendIndex)

        if friendInfo.connected then
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
end

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
