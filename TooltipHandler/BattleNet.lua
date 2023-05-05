--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

local Icon = private.TooltipHandler.Icon
local OnlineFriendsByName = private.TooltipHandler.OnlineFriendsByName
local People = private.People

local TooltipHandler = private.TooltipHandler
local Player = TooltipHandler.Player
local PlayerLists = TooltipHandler.PlayerLists

local BattleNetFriend_OnMouseUp = TooltipHandler.CellScripts.BattleNetFriend_OnMouseUp
local ToggleColumnSortMethod = TooltipHandler.CellScripts.ToggleColumnSortMethod

---@class TooltipHandler.BattleNetSection
local BattleNetSection = TooltipHandler.BattleNetSection

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

local BNET_CLIENT_MOBILE_CHAT = "BSAp"
local BattleNetClientIndex = {} ---@type Dictionary<integer>

do
    local BattleNetClientTokens = {
        --------------------------------------------------------------------------------
        ---- Blizzard Games
        --------------------------------------------------------------------------------
        "RTRO", -- Blizzard Arcade Collection
        "OSI", -- Diablo II: Resurrected
        "D3", -- Diablo III
        "ANBS", -- Diablo Immortal
        "WTCG", -- Hearthstone
        "Hero", -- Heroes of the Storm
        "Pro", -- Overwatch
        "S1", -- StarCraft
        "S2", -- StarCraft II
        "W3", -- Warcraft III: Reforged
        "GRY", -- Warcraft Arclight Rumble
        "WoW", -- World of Warcraft

        --------------------------------------------------------------------------------
        ---- Activision Games
        --------------------------------------------------------------------------------
        "VIPR", -- Call of Duty
        "ZEUS", -- Call of Duty: Black Ops Cold War
        "ODIN", -- Call of Duty: Modern Warfare
        "LAZR", -- Call of Duty: Modern Warfare II
        "FORE", -- Call of Duty: Vanguard
        "WLBY", -- Crash Bandicoot 4

        --------------------------------------------------------------------------------
        ---- Non-Game Clients
        --------------------------------------------------------------------------------
        BNET_CLIENT_CLNT,
        BNET_CLIENT_APP,
        BNET_CLIENT_MOBILE_CHAT,
    }

    for index, value in ipairs(BattleNetClientTokens) do
        BattleNetClientIndex[value] = index
    end
end

local BattleNetNonGameClient = {
    [BNET_CLIENT_CLNT] = true,
    [BNET_CLIENT_APP] = true,
    [BNET_CLIENT_MOBILE_CHAT] = true,
}

-- Used to handle duplication between in-game and RealID friends.
local OnlineFriendsByPresenceName = {}

local ColumnID = {
    ClientIcon = 1,
    PresenceName = 2,
    ToonName = 4,
    GameText = 5,
    Note = 7,
}

local ColSpan = {
    ClientIcon = 1,
    PresenceName = 2,
    ToonName = 1,
    GameText = 2,
    Note = 2,
}

--------------------------------------------------------------------------------
---- Helpers
--------------------------------------------------------------------------------

---@param tooltip LibQTip-2.0.Tooltip
---@param playerList BattleNetFriend[]
---@param dataPrefix "BattleNetApp"|"BattleNetGames"
---@param headerLine LibQTip-2.0.Line
---@param noteArrangement NotesArrangement
local function RenderBattleNetLines(tooltip, playerList, dataPrefix, headerLine, noteArrangement)
    --------------------------------------------------------------------------------
    ---- Section Header
    --------------------------------------------------------------------------------

    headerLine
        :SetColor(0, 0, 0, 1)
        :GetCell(ColumnID.PresenceName)
        :SetColSpan(ColSpan.PresenceName)
        :SetText(TooltipHandler:ColumnLabel(BATTLENET_FRIEND, ("%s:PresenceName"):format(dataPrefix)))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, ("%s:PresenceName"):format(dataPrefix))

    headerLine
        :GetCell(ColumnID.ToonName)
        :SetColSpan(ColSpan.ToonName)
        :SetText(TooltipHandler:ColumnLabel(NAME, ("%s:ToonName"):format(dataPrefix)))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, ("%s:ToonName"):format(dataPrefix))

    headerLine
        :GetCell(ColumnID.GameText)
        :SetColSpan(ColSpan.GameText)
        :SetText(TooltipHandler:ColumnLabel(INFO, ("%s:GameText"):format(dataPrefix)))
        :SetScript("OnMouseDown", ToggleColumnSortMethod, ("%s:GameText"):format(dataPrefix))

    if noteArrangement == private.Preferences.Tooltip.NotesArrangement.Column then
        headerLine
            :GetCell(ColumnID.Note)
            :SetColSpan(ColSpan.Note)
            :SetText(TooltipHandler:ColumnLabel(LABEL_NOTE, ("%s:Note"):format(dataPrefix)))
            :SetScript("OnMouseUp", ToggleColumnSortMethod, ("%s:Note"):format(dataPrefix))
    end

    --------------------------------------------------------------------------------
    ---- Section Body
    --------------------------------------------------------------------------------

    tooltip:AddSeparator(1, 0.5, 0.5, 0.5)

    for index = 1, #playerList do
        local friend = playerList[index]
        local line = tooltip:AddLine()

        line:GetCell(ColumnID.ClientIcon):SetColSpan(ColSpan.ClientIcon):SetText(friend.ClientIcon)

        line:GetCell(ColumnID.PresenceName)
            :SetColSpan(ColSpan.PresenceName)
            :SetText(("%s%s%s|r"):format(friend.StatusIcon, FRIENDS_BNET_NAME_COLOR_CODE, friend.PresenceName))
            :SetScript("OnMouseUp", BattleNetFriend_OnMouseUp, friend)

        line:GetCell(ColumnID.ToonName)
            :SetColSpan(ColSpan.ToonName)
            :SetText(("%s%s|r"):format(FRIENDS_OTHER_NAME_COLOR_CODE, friend.ToonName))

        line:GetCell(ColumnID.GameText):SetColSpan(ColSpan.GameText):SetText(friend.GameText)

        if friend.Note then
            local noteText = ("%s%s|r"):format(FRIENDS_OTHER_NAME_COLOR_CODE, friend.Note)

            if noteArrangement == private.Preferences.Tooltip.NotesArrangement.Column then
                line:GetCell(ColumnID.Note):SetColSpan(ColSpan.Note):SetText(noteText)
            else
                tooltip
                    :AddLine()
                    :GetCell(1)
                    :SetColSpan(0)
                    :SetFont("GameTooltipTextSmall")
                    :SetText(("%s %s"):format(Icon.Status.Note, noteText))
            end
        end

        if friend.BroadcastText then
            tooltip:AddLine():GetCell(1):SetColSpan(0):SetFont("GameTooltipTextSmall"):SetText(friend.BroadcastText)
        end
    end

    tooltip:AddLine(" ")
end

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

---@param tooltip LibQTip-2.0.Tooltip
function BattleNetSection:DisplayApps(tooltip)
    if #PlayerLists.BattleNetApp == 0 then
        return
    end

    local DB = private.DB
    local sectionIsCollapsed = DB.Tooltip.CollapsedSections.BattleNetApp

    TooltipHandler:CreateSectionHeader(tooltip, BATTLENET_OPTIONS_LABEL, sectionIsCollapsed, "BattleNetApp")

    if sectionIsCollapsed then
        return
    end

    RenderBattleNetLines(
        tooltip,
        PlayerLists.BattleNetApp,
        "BattleNetApp",
        tooltip:AddLine(),
        DB.Tooltip.NotesArrangement.BattleNetApp
    )
end

---@param tooltip LibQTip-2.0.Tooltip
function BattleNetSection:DisplayGames(tooltip)
    if #PlayerLists.BattleNetGames == 0 then
        return
    end

    local DB = private.DB
    local sectionIsCollapsed = DB.Tooltip.CollapsedSections.BattleNetGames

    TooltipHandler:CreateSectionHeader(
        tooltip,
        ("%s %s"):format(BATTLENET_OPTIONS_LABEL, PARENS_TEMPLATE:format(GAME)),
        sectionIsCollapsed,
        "BattleNetGames"
    )

    if sectionIsCollapsed then
        return
    end

    local headerLine = tooltip:AddLine()

    headerLine
        :GetCell(ColumnID.ClientIcon)
        :SetText(TooltipHandler:ColumnLabel(Icon.Column.Game, "BattleNetGames:ClientIndex"))
        :SetScript("OnMouseUp", ToggleColumnSortMethod, "BattleNetGames:ClientIndex")

    RenderBattleNetLines(
        tooltip,
        PlayerLists.BattleNetGames,
        "BattleNetGames",
        headerLine,
        DB.Tooltip.NotesArrangement.BattleNetGames
    )
end

function BattleNetSection:GenerateData()
    table.wipe(OnlineFriendsByPresenceName)

    if People.BattleNet.Total == 0 then
        return
    end

    local ClientIconSize = 18

    for battleNetIndex = 1, People.BattleNet.Total do
        local friendInfo = C_BattleNet.GetFriendAccountInfo(battleNetIndex) or {}
        local accountName = friendInfo.accountName
        local bnetAccountID = friendInfo.bnetAccountID
        local messageText = friendInfo.customMessage
        local noteText = friendInfo.note

        local numToons = C_BattleNet.GetFriendNumGameAccounts(battleNetIndex)

        for toonIndex = 1, numToons do
            local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(battleNetIndex, toonIndex) or {}
            local clientProgram = gameAccountInfo.clientProgram
            local gameText = gameAccountInfo.richPresence
            local toonName = gameAccountInfo.characterName
            local characterName = BNet_GetValidatedCharacterName(toonName, friendInfo.battleTag, clientProgram)

            ---@type BattleNetFriend
            local bNetFriendData = {
                BroadcastText = (messageText and messageText ~= "") and ("%s %s%s (%s)|r"):format(
                    Icon.Broadcast,
                    FRIENDS_OTHER_NAME_COLOR_CODE,
                    messageText,
                    SecondsToTime(time() - friendInfo.customMessageTime, false, true, 1)
                ) or nil,
                Client = clientProgram,
                ClientIcon = CreateAtlasMarkup(
                    BNet_GetBattlenetClientAtlas(clientProgram),
                    ClientIconSize,
                    ClientIconSize
                ),
                ClientIndex = BattleNetClientIndex[clientProgram],
                GameText = gameText ~= "" and gameText or COMMUNITIES_PRESENCE_MOBILE_CHAT,
                Note = noteText ~= "" and noteText or nil,
                PresenceID = bnetAccountID,
                PresenceName = accountName or UNKNOWN,
                StatusIcon = gameAccountInfo.isGameAFK and Icon.Status.AFK
                    or (gameAccountInfo.isGameBusy and Icon.Status.DND or Icon.Status.Online),
                ToonName = characterName,
            }

            if clientProgram == BNET_CLIENT_WOW and gameAccountInfo.wowProjectID == WOW_PROJECT_ID then
                local existingFriend = OnlineFriendsByName[toonName]
                local realmName = gameAccountInfo.realmName

                if existingFriend and realmName == Player.RealmName then
                    for key, value in pairs(bNetFriendData) do
                        if not existingFriend[key] then
                            existingFriend[key] = value
                        end
                    end
                elseif not OnlineFriendsByPresenceName[bNetFriendData.PresenceName] then
                    local level = gameAccountInfo.characterLevel
                    local zoneName = gameAccountInfo.areaName

                    ---@type WoWFriend
                    local wowFriendData = {
                        BroadcastText = bNetFriendData.BroadcastText,
                        Class = gameAccountInfo.className,
                        FullToonName = nil,
                        IsLocalFriend = false,
                        Level = level and tonumber(level) or 0,
                        Note = bNetFriendData.Note,
                        PresenceID = bNetFriendData.PresenceID,
                        PresenceName = bNetFriendData.PresenceName,
                        RealmName = realmName or "",
                        StatusIcon = bNetFriendData.StatusIcon,
                        ToonName = bNetFriendData.ToonName,
                        ZoneName = zoneName ~= "" and zoneName or UNKNOWN,
                    }

                    table.insert(PlayerLists.WoWFriends, wowFriendData)
                    OnlineFriendsByPresenceName[bNetFriendData.PresenceName] = wowFriendData
                end
            elseif not OnlineFriendsByPresenceName[bNetFriendData.PresenceName] then
                if BattleNetNonGameClient[clientProgram] then
                    table.insert(PlayerLists.BattleNetApp, bNetFriendData)
                elseif gameAccountInfo.gameAccountID then
                    table.insert(PlayerLists.BattleNetGames, bNetFriendData)
                end

                OnlineFriendsByPresenceName[bNetFriendData.PresenceName] = bNetFriendData
            end
        end
    end
end

--------------------------------------------------------------------------------
---- Types
--------------------------------------------------------------------------------

---@class BattleNetFriend
---@field BroadcastText string?
---@field Client string
---@field ClientIcon string
---@field ClientIndex integer
---@field GameText string
---@field Note? string
---@field PresenceID number
---@field PresenceName string
---@field StatusIcon string
---@field ToonName string
