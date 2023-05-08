--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

local Sorting = private.Sorting
local SortOrder = private.SortOrder

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnFolderName)

---@class TooltipHandler
---@field BattleNetSection TooltipHandler.BattleNetSection
---@field CellScripts TooltipHandler.CellScripts
---@field Class TooltipHandler.ClassData
---@field Icon TooltipHandler.Icon
---@field GuildSection TooltipHandler.GuildSection
---@field OnlineFriendsByName table<string, BattleNetFriend|GuildMember|WoWFriend> Used to handle duplication between in-game and RealID friends.
---@field Player TooltipHandler.Player
---@field PlayerLists TooltipHandler.PlayerLists
---@field Tooltip TooltipHandler.Tooltip
---@field WoWFriendSection TooltipHandler.WoWFriendSection
local TooltipHandler = private.TooltipHandler

TooltipHandler.BattleNetSection = {}

---@class TooltipHandler.CellScripts
---@field BattleNetFriend_OnMouseUp function
---@field ToggleColumnSortMethod function
TooltipHandler.CellScripts = {
    ---@param _ LibQTip-2.0.Cell
    ---@param friend BattleNetFriend|WoWFriend
    ---@param mouseButton string
    BattleNetFriend_OnMouseUp = function(_, friend, mouseButton)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")

        if mouseButton == "LeftButton" then
            if IsAltKeyDown() and friend.RealmName == TooltipHandler.Player.RealmName then
                C_PartyInfo.InviteUnit(friend.ToonName)
            elseif IsControlKeyDown() then
                FriendsFrame.NotesID = friend.PresenceID
                StaticPopup_Show("SET_BNFRIENDNOTE", friend.PresenceName)
            elseif not BNIsSelf(friend.PresenceID) then
                ChatFrame_SendBNetTell(friend.PresenceName)
            end
        elseif mouseButton == "RightButton" then
            TooltipHandler.Tooltip.Main:SetFrameStrata("DIALOG")
            CloseDropDownMenus()
            FriendsFrame_ShowBNDropdown(friend.PresenceName, true, nil, nil, nil, true, friend.PresenceID)
        end
    end,

    ---@param _ LibQTip-2.0.Cell
    ---@param sortFieldData string
    ToggleColumnSortMethod = function(_, sortFieldData)
        local sectionName, fieldName = strsplit(":", sortFieldData)

        if not sectionName or not fieldName then
            return
        end

        local DB = private.DB
        local savedSortField = DB.Tooltip.Sorting[sectionName]
        local columnSortFieldID = Sorting.FieldIDs[sectionName][fieldName]

        if savedSortField.Field == columnSortFieldID then
            savedSortField.Order = savedSortField.Order == SortOrder.Enum.Ascending and SortOrder.Enum.Descending
                or SortOrder.Enum.Ascending
        else
            savedSortField = DB.Tooltip.Sorting[sectionName]
            savedSortField.Field = columnSortFieldID
            savedSortField.Order = SortOrder.Enum.Ascending
        end

        table.sort(
            TooltipHandler.PlayerLists[sectionName],
            Sorting.Functions[sectionName .. fieldName .. SortOrder.Name[savedSortField.Order]]
        )

        TooltipHandler:Render()
    end,
}

---@class TooltipHandler.ClassData
---@field Color Dictionary<string> Dictionary of localizedName to class color
---@field Token table<"Female"|"Male", Dictionary<string>> Dictionary of feminine or masculine localizedName to classToken
TooltipHandler.Class = {
    Color = {},
    Token = {
        Female = {},
        Male = {},
    },
}

TooltipHandler.GuildSection = {}
TooltipHandler.OnlineFriendsByName = {}

---@class TooltipHandler.Player
---@field Faction string
---@field Name string
---@field RealmName string
TooltipHandler.Player = {
    Faction = UnitFactionGroup("player"),
    Name = UnitName("player") or UNKNOWN,
    RealmName = GetRealmName(),
}

---@class TooltipHandler.PlayerLists
---@field BattleNetApp BattleNetFriend[]
---@field BattleNetGames BattleNetFriend[]
---@field Guild GuildMember[]
---@field WoWFriends WoWFriend[]
TooltipHandler.PlayerLists = {
    BattleNetApp = {},
    BattleNetGames = {},
    Guild = {},
    WoWFriends = {},
}

---@class TooltipHandler.Tooltip
---@field AnchorFrame? Frame
---@field Help? LibQTip-2.0.Tooltip
---@field Main? LibQTip-2.0.Tooltip
TooltipHandler.Tooltip = {
    AnchorFrame = nil,
    Help = nil,
    Main = nil,
}

TooltipHandler.WoWFriendSection = {}

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

local ClassData = TooltipHandler.Class
local OnlineFriendsByName = TooltipHandler.OnlineFriendsByName
local PlayerData = TooltipHandler.Player
local PlayerLists = TooltipHandler.PlayerLists

--------------------------------------------------------------------------------
---- SectionDropDown
--------------------------------------------------------------------------------

local SectionDropDown = CreateFrame("Frame", AddOnFolderName .. "SectionDropDown", UIParent, "UIDropDownMenuTemplate")
SectionDropDown.displayMode = "MENU"
SectionDropDown.info = {}
SectionDropDown.levelAdjust = 0

---@param currentPosition number
---@param direction "down"|"up"
local function ChangeSectionOrder(_, currentPosition, direction)
    local sectionEntries = private.DB.Tooltip.SectionDisplayOrders
    local newPosition

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

    TooltipHandler:Render()
end

local function ToggleSectionVisibility(self, sectionName)
    local DB = private.DB

    DB.Tooltip.CollapsedSections[sectionName] = not DB.Tooltip.CollapsedSections[sectionName]

    TooltipHandler:Render()
end

local function InitializeSectionDropDown(self, level)
    if not level then
        return
    end

    local DB = private.DB
    local info = SectionDropDown.info
    table.wipe(info)

    if level == 1 then
        local sectionName = UIDROPDOWNMENU_MENU_VALUE

        info.arg1 = sectionName
        info.func = ToggleSectionVisibility
        info.notCheckable = true
        info.text = DB.Tooltip.CollapsedSections[sectionName] and L.EXPAND_SECTION or L.COLLAPSE_SECTION

        UIDropDownMenu_AddButton(info, level)

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
            UIDropDownMenu_AddButton(info, level)
        end

        if currentPosition ~= #DB.Tooltip.SectionDisplayOrders then
            info.arg2 = "down"
            info.text = L.MOVE_SECTION_DOWN
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

SectionDropDown.initialize = InitializeSectionDropDown

--------------------------------------------------------------------------------
---- Class Definitions
--------------------------------------------------------------------------------

do
    ---@param localizedClassNames Dictionary<string>
    ---@param targetTokenList Dictionary<string>
    local function GenerateColorsAndTokens(localizedClassNames, targetTokenList)
        for classToken, localizedName in pairs(localizedClassNames) do
            local color = C_ClassColor.GetClassColor(classToken)

            if color then
                ClassData.Color[localizedName] = color:GenerateHexColorMarkup()
                targetTokenList[localizedName] = classToken
            end
        end
    end

    GenerateColorsAndTokens(LOCALIZED_CLASS_NAMES_FEMALE, ClassData.Token.Female)
    GenerateColorsAndTokens(LOCALIZED_CLASS_NAMES_MALE, ClassData.Token.Male)
end -- do-block

--------------------------------------------------------------------------------
---- Icon Definitions
--------------------------------------------------------------------------------

---@type Dictionary<string>
local ClassIcon = {}

do
    local textureFormat = [[|TInterface\TargetingFrame\UI-CLASSES-CIRCLES:0:0:0:0:256:256:%d:%d:%d:%d|t]]
    local textureSize = 256

    for index = 1, #CLASS_SORT_ORDER do
        local className = CLASS_SORT_ORDER[index]
        local left, right, top, bottom = unpack(CLASS_ICON_TCOORDS[className])
        ClassIcon[className] =
            textureFormat:format(left * textureSize, right * textureSize, top * textureSize, bottom * textureSize)
    end
end

---@param texturePath string
---@param iconSize? number
---@return string
local function CreateIcon(texturePath, iconSize)
    return ("|T%s:%d|t"):format(texturePath, iconSize or 0)
end

local FactionIconSize = 18

---@type table<"Alliance"|"Horde"|"Neutral", string>
local FactionIcon = {
    Alliance = CreateIcon([[Interface\COMMON\icon-alliance]], FactionIconSize),
    Horde = CreateIcon([[Interface\COMMON\icon-horde]], FactionIconSize),
    Neutral = CreateIcon([[Interface\COMMON\Indicator-Gray]], FactionIconSize),
}

---@class TooltipHandler.Icon
TooltipHandler.Icon = {
    Broadcast = CreateIcon([[Interface\FriendsFrame\BroadcastIcon]]),
    Class = ClassIcon,
    Column = {
        Class = CreateIcon([[Interface\GossipFrame\TrainerGossipIcon]]),
        Game = CreateIcon([[Interface\Buttons\UI-GroupLoot-Dice-Up]]),
        Level = CreateIcon([[Interface\GROUPFRAME\UI-GROUP-MAINASSISTICON]]),
    },
    Help = CreateIcon([[Interface\COMMON\help-i]], 20),
    Faction = FactionIcon,
    Player = {
        Faction = FactionIcon[PlayerData.Faction] or FactionIcon.Neutral,
        Group = [[|TInterface\Scenarios\ScenarioIcon-Check:0|t]],
    },
    Section = {
        Disabled = CreateIcon([[Interface\COMMON\Indicator-Red]]),
        Enabled = CreateIcon([[Interface\COMMON\Indicator-Green]]),
    },
    Sort = {
        Ascending = CreateIcon([[Interface\Buttons\Arrow-Up-Up]]),
        Descending = CreateIcon([[Interface\Buttons\Arrow-Down-Up]]),
    },
    Status = {
        AFK = CreateIcon(FRIENDS_TEXTURE_AFK),
        DND = CreateIcon(FRIENDS_TEXTURE_DND),
        Mobile = {
            Away = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat-AwayMobile]]),
            Busy = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat-BusyMobile]]),
            Online = CreateIcon([[Interface\ChatFrame\UI-ChatIcon-ArmoryChat]]),
        },
        Note = CreateIcon([[Interface\BUTTONS\UI-GuildButton-PublicNote-Up]]),
        Online = CreateIcon(FRIENDS_TEXTURE_ONLINE),
    },
}

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

---@param level number
function TooltipHandler:ColorPlayerLevel(level)
    if type(level) ~= "number" then
        return level
    end

    local color = GetRelativeDifficultyColor(UnitLevel("player"), level)

    return ("|cff%02x%02x%02x%d|r"):format(color.r * 255, color.g * 255, color.b * 255, level)
end

---@param label string
---@param sectionFieldToken string
---@return string
function TooltipHandler:ColumnLabel(label, sectionFieldToken)
    local sectionName, fieldName = strsplit(":", sectionFieldToken)
    local DB = private.DB

    if DB.Tooltip.Sorting[sectionName].Field == Sorting.FieldIDs[sectionName][fieldName] then
        return (
            DB.Tooltip.Sorting[sectionName].Order == SortOrder.Enum.Ascending and self.Icon.Sort.Ascending
            or self.Icon.Sort.Descending
        ) .. label
    end

    return label
end

do
    ---@param _ LibQTip-2.0.Cell
    ---@param sectionName string
    ---@param mouseButton string
    local function SectionTitle_OnMouseUp(_, sectionName, mouseButton)
        if mouseButton == "RightButton" then
            TooltipHandler.Tooltip.Main:SetFrameStrata("DIALOG")
            CloseDropDownMenus()
            ToggleDropDownMenu(1, sectionName, SectionDropDown, "cursor")

            return
        end

        ToggleSectionVisibility(nil, sectionName)
    end

    ---@param tooltip LibQTip-2.0.Tooltip
    ---@param titleText string The section title to display in the Cell.
    ---@param sectionIsCollapsed boolean
    ---@param scriptParameter string
    function TooltipHandler:CreateSectionHeader(tooltip, titleText, sectionIsCollapsed, scriptParameter)
        local fontName = sectionIsCollapsed and "GameFontDisable" or "GameFontNormal"
        local sectionIcon = sectionIsCollapsed and self.Icon.Section.Disabled or self.Icon.Section.Enabled

        tooltip
            :AddLine()
            :GetCell(1)
            :SetColSpan(0)
            :SetJustifyH("CENTER")
            :SetFont(fontName)
            :SetText(("%s %s %s"):format(sectionIcon, titleText, sectionIcon))
            :SetScript("OnMouseUp", SectionTitle_OnMouseUp, scriptParameter)

        tooltip:AddSeparator(1, 0.5, 0.5, 0.5)
    end
end

function TooltipHandler:GenerateData()
    for _, list in pairs(PlayerLists) do
        table.wipe(list)
    end

    table.wipe(OnlineFriendsByName)

    self.WoWFriendSection:GenerateData()
    self.BattleNetSection:GenerateData()
    self.GuildSection:GenerateData()

    for listName, list in pairs(PlayerLists) do
        local savedSortField = private.DB.Tooltip.Sorting[listName]

        table.sort(
            list,
            Sorting.Functions[listName .. Sorting.FieldNames[listName][savedSortField.Field] .. SortOrder.Name[savedSortField.Order]]
        )
    end
end

---@param name string The unit's name
function TooltipHandler:IsUnitGrouped(name)
    return (GetNumSubgroupMembers() > 0 and UnitInParty(name)) or (GetNumGroupMembers() > 0 and UnitInRaid(name))
end
