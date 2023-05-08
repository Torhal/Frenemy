--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

local MapHandler = private.MapHandler
local Preferences = private.Preferences

local TooltipHandler = private.TooltipHandler
local Icon = TooltipHandler.Icon
local Player = TooltipHandler.Player
local PlayerLists = TooltipHandler.PlayerLists

local ToggleColumnSortMethod = TooltipHandler.CellScripts.ToggleColumnSortMethod

local Dialog = LibStub("LibDialog-1.0")

---@class TooltipHandler.GuildSection
local GuildSection = TooltipHandler.GuildSection

---@class TooltipHandler.GuildSection.MOTD
---@field Line LibQTip-2.0.Line|nil
---@field Text string|nil
GuildSection.MOTD = {
    Line = nil,
    Text = nil,
}

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

-- Used to handle duplication between in-game and RealID friends.
local GuildMemberIndexByName = {}

local ColumnID = {
    Level = 1,
    Class = 2,
    ToonName = 3,
    Rank = 4,
    ZoneName = 5,
    PublicNote = 6,
    OfficerNote = 8,
}

local ColSpan = {
    Level = 1,
    Class = 1,
    ToonName = 1,
    Rank = 1,
    ZoneName = 1,
    PublicNote = 2,
    OfficerNote = 2,
}

--------------------------------------------------------------------------------
---- Dialogs
--------------------------------------------------------------------------------

Dialog:Register("FrenemySetGuildMOTD", {
    editboxes = {
        {
            on_enter_pressed = function(self)
                GuildSetMOTD(self:GetText())
                Dialog:Dismiss("FrenemySetGuildMOTD")
            end,
            on_escape_pressed = function(self)
                Dialog:Dismiss("FrenemySetGuildMOTD")
            end,
            on_show = function(self)
                self:SetText(GetGuildRosterMOTD())
            end,
            auto_focus = true,
            label = GREEN_FONT_COLOR_CODE .. GUILDCONTROL_OPTION9 .. "|r",
            max_letters = 128,
            text = GetGuildRosterMOTD(),
            width = 200,
        },
    },
    hide_on_escape = true,
    icon = [[Interface\Calendar\MeetingIcon]],
    on_show = function(self)
        self.text:SetFormattedText("%s%s|r", BATTLENET_FONT_COLOR_CODE, AddOnFolderName)
    end,
    show_while_dead = true,
    width = 400,
})

--------------------------------------------------------------------------------
---- Cell Scripts
--------------------------------------------------------------------------------

---@param button "LeftButton"|"RightButton"
local function GuildMember_OnMouseUp(_, playerEntry, button)
    if not IsAddOnLoaded("Blizzard_GuildUI") then
        LoadAddOn("Blizzard_GuildUI")
    end

    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

    local playerName = playerEntry.Realm == Player.RealmName and playerEntry.ToonName or playerEntry.FullToonName

    if button == "LeftButton" then
        if IsAltKeyDown() then
            C_PartyInfo.InviteUnit(playerName)
        elseif IsControlKeyDown() and CanEditPublicNote() then
            SetGuildRosterSelection(GuildMemberIndexByName[playerName])
            StaticPopup_Show("SET_GUILDPLAYERNOTE")
        else
            ChatFrame_SendTell(playerName)
        end
    elseif button == "RightButton" then
        if IsControlKeyDown() and C_GuildInfo.CanEditOfficerNote() then
            SetGuildRosterSelection(GuildMemberIndexByName[playerName])
            StaticPopup_Show("SET_GUILDOFFICERNOTE")
        else
            TooltipHandler.Tooltip.Main:SetFrameStrata("DIALOG")
            CloseDropDownMenus()
            GuildRoster_ShowMemberDropDown(playerName, true, playerEntry.IsMobile)
        end
    end
end

local function GuildMOTD_OnMouseUp()
    Dialog:Spawn("FrenemySetGuildMOTD")
end

--------------------------------------------------------------------------------
---- Helper Functions
--------------------------------------------------------------------------------

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
        red_low, green_low, blue_low, red_mid, green_mid, blue_mid =
            red_mid, green_mid, blue_mid, red_high, green_high, blue_high
    end

    return red_low + (red_mid - red_low) * fractional,
        green_low + (green_mid - green_low) * fractional,
        blue_low + (blue_mid - blue_low) * fractional
end

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

---@param tooltip LibQTip-2.0.Tooltip
function GuildSection:Display(tooltip)
    if #PlayerLists.Guild == 0 then
        return
    end

    local DB = private.DB
    local sectionIsCollapsed = DB.Tooltip.CollapsedSections.Guild

    TooltipHandler:CreateSectionHeader(
        tooltip,
        ("%s %s"):format(GetGuildInfo("player"), PARENS_TEMPLATE:format(#PlayerLists.Guild)),
        sectionIsCollapsed,
        "Guild"
    )

    if sectionIsCollapsed then
        return
    end

    --------------------------------------------------------------------------------
    ---- Section Header
    --------------------------------------------------------------------------------

    local headerLine = tooltip:AddLine()

    headerLine
        :SetColor(0, 0, 0, 1)
        :GetCell(ColumnID.Level)
        :SetColSpan(ColSpan.Level)
        :SetText(TooltipHandler:ColumnLabel(Icon.Column.Level, "Guild:Level"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "Guild:Level")

    headerLine
        :GetCell(ColumnID.Class)
        :SetColSpan(ColSpan.Class)
        :SetText(TooltipHandler:ColumnLabel(Icon.Column.Class, "Guild:Class"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "Guild:Class")

    headerLine
        :GetCell(ColumnID.ToonName)
        :SetColSpan(ColSpan.ToonName)
        :SetText(TooltipHandler:ColumnLabel(NAME, "Guild:ToonName"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "Guild:ToonName")

    headerLine
        :GetCell(ColumnID.Rank)
        :SetColSpan(ColSpan.Rank)
        :SetText(TooltipHandler:ColumnLabel(RANK, "Guild:RankIndex"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "Guild:RankIndex")

    headerLine
        :GetCell(ColumnID.ZoneName)
        :SetColSpan(ColSpan.ZoneName)
        :SetText(TooltipHandler:ColumnLabel(ZONE, "Guild:ZoneName"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "Guild:ZoneName")

    if DB.Tooltip.NotesArrangement.Guild == Preferences.Tooltip.NotesArrangement.Column then
        headerLine
            :GetCell(ColumnID.PublicNote)
            :SetColSpan(ColSpan.PublicNote)
            :SetText(TooltipHandler:ColumnLabel(NOTE, "Guild:PublicNote"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "Guild:PublicNote")
    end

    if DB.Tooltip.NotesArrangement.GuildOfficer == Preferences.Tooltip.NotesArrangement.Column then
        headerLine
            :GetCell(ColumnID.OfficerNote)
            :SetColSpan(ColSpan.OfficerNote)
            :SetText(TooltipHandler:ColumnLabel(GUILD_OFFICERNOTES_LABEL, "Guild:OfficerNote"))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, "Guild:OfficerNote")
    end

    --------------------------------------------------------------------------------
    ---- Section Body
    --------------------------------------------------------------------------------

    tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

    local numGuildRanks = GuildControlGetNumRanks()
    local classToken = TooltipHandler.Class.Token

    for index = 1, #PlayerLists.Guild do
        local guildMate = PlayerLists.Guild[index]

        local line = tooltip:AddLine()

        line:GetCell(ColumnID.Level)
            :SetColSpan(ColSpan.Level)
            :SetJustifyH("LEFT")
            :SetText(TooltipHandler:ColorPlayerLevel(guildMate.Level))

        line:GetCell(ColumnID.Class)
            :SetColSpan(ColSpan.Class)
            :SetText(Icon.Class[classToken.Female[guildMate.Class] or classToken.Male[guildMate.Class]])

        line:GetCell(ColumnID.ToonName)
            :SetColSpan(ColSpan.ToonName)
            :SetText(
                ("%s%s%s|r%s"):format(
                    guildMate.StatusIcon,
                    TooltipHandler.Class.Color[guildMate.Class] or "|cffffff",
                    guildMate.ToonName,
                    TooltipHandler:IsUnitGrouped(guildMate.ToonName) and Icon.Player.Group or ""
                )
            )
            :SetScript("OnMouseUp", GuildMember_OnMouseUp, guildMate)

        -- The higher the rank index, the lower the priviledge; guild leader is rank 1.
        local r, g, b = PercentColorGradient(guildMate.RankIndex, numGuildRanks)
        line:GetCell(ColumnID.Rank)
            :SetColSpan(ColSpan.Rank)
            :SetText(("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, guildMate.Rank))

        line:GetCell(ColumnID.ZoneName)
            :SetColSpan(ColSpan.ZoneName)
            :SetText(MapHandler:ColoredZoneName(guildMate.ZoneName))

        if guildMate.PublicNote then
            local noteText = FRIENDS_OTHER_NAME_COLOR_CODE .. guildMate.PublicNote .. "|r"

            if DB.Tooltip.NotesArrangement.Guild == Preferences.Tooltip.NotesArrangement.Column then
                line:GetCell(ColumnID.PublicNote):SetColSpan(ColSpan.PublicNote):SetText(noteText)
            else
                tooltip
                    :AddLine()
                    :GetCell(1)
                    :SetColSpan(0)
                    :SetFont("GameTooltipTextSmall")
                    :SetText(("%s %s"):format(Icon.Status.Note, noteText))
            end
        end

        if guildMate.OfficerNote then
            local noteText = ("%s%s|r"):format(ORANGE_FONT_COLOR_CODE, guildMate.OfficerNote)

            if DB.Tooltip.NotesArrangement.GuildOfficer == Preferences.Tooltip.NotesArrangement.Column then
                line:GetCell(ColumnID.OfficerNote):SetColSpan(ColSpan.OfficerNote):SetText(noteText)
            else
                tooltip
                    :AddLine()
                    :GetCell(1)
                    :SetColSpan(0)
                    :SetFont("GameTooltipTextSmall")
                    :SetText(("%s %s"):format(Icon.Status.Note, noteText))
            end
        end
    end

    local MOTD = GuildSection.MOTD
    MOTD.Text = GetGuildRosterMOTD()

    if not MOTD.Text or MOTD.Text == "" then
        tooltip:AddLine(" ")

        return
    end

    tooltip:AddLine(" ")

    tooltip:AddLine():GetCell(1):SetColSpan(0):SetJustifyH("CENTER"):SetText(GUILD_MOTD_TEMPLATE:gsub('"%%s"', ""))

    MOTD.Line = tooltip:AddLine()

    if CanEditMOTD() then
        MOTD.Line:GetCell(1):SetScript("OnMouseUp", GuildMOTD_OnMouseUp)
    end

    tooltip:AddLine(" ")
end

function GuildSection:GenerateData()
    table.wipe(GuildMemberIndexByName)

    if not IsInGuild() then
        return
    end

    for index = 1, GetNumGuildMembers() do
        local fullToonName, rank, rankIndex, level, class, zoneName, note, officerNote, isOnline, awayStatus, _, _, _, isMobile =
            GetGuildRosterInfo(index)

        if isOnline or isMobile then
            local toonName, realmName = strsplit("-", fullToonName)

            local statusIcon
            if awayStatus == 0 then
                statusIcon = isOnline and Icon.Status.Online or Icon.Status.Mobile.Online
            elseif awayStatus == 1 then
                statusIcon = isOnline and Icon.Status.AFK or Icon.Status.Mobile.Away
            elseif awayStatus == 2 then
                statusIcon = isOnline and Icon.Status.DND or Icon.Status.Mobile.Busy
            end

            -- Don't rely on the zoneName from GetGuildRosterInfo - it can be slow, and the player should see their own zone change instantaneously if
            -- traveling with the tooltip showing.
            if isOnline and toonName == Player.Name then
                zoneName = MapHandler.Data.MapName
            end

            GuildMemberIndexByName[fullToonName] = index
            GuildMemberIndexByName[toonName] = index

            table.insert(
                PlayerLists.Guild,
                ---@type GuildMember
                {
                    Class = class,
                    FullToonName = fullToonName,
                    IsMobile = isMobile,
                    Level = level,
                    OfficerNote = officerNote ~= "" and officerNote or nil,
                    PublicNote = note ~= "" and note or nil,
                    Rank = rank,
                    RankIndex = rankIndex,
                    RealmName = realmName or Player.RealmName,
                    StatusIcon = statusIcon,
                    ToonName = toonName,
                    ZoneName = isMobile
                            and (isOnline and ("%s %s"):format(zoneName or UNKNOWN, PARENS_TEMPLATE:format(REMOTE_CHAT)) or REMOTE_CHAT)
                        or (zoneName or UNKNOWN),
                }
            )
        end
    end
end

--------------------------------------------------------------------------------
---- Types
--------------------------------------------------------------------------------

---@class GuildMember
---@field Class string
---@field FullToonName string
---@field IsMobile boolean
---@field Level number
---@field OfficerNote string?
---@field PublicNote string?
---@field Rank string
---@field RankIndex number
---@field RealmName string
---@field StatusIcon string
---@field ToonName string
---@field ZoneName string
