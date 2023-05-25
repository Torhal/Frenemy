--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

local Preferences = private.Preferences
local Sorting = private.Sorting
local SortOrder = private.SortOrder

---@type Localizations
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnFolderName)

---@class Preferences.Tooltip
---@field NotesArrangement NotesArrangement
local TooltipPreferences = Preferences.Tooltip

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

---@class NotesArrangement
---@field Column integer
---@field Row integer
local NotesArrangement = {
    Column = 1,
    Row = 2,
}

Preferences.Tooltip.NotesArrangement = NotesArrangement

---@type Array<string>
local NotesArrangementValues = {
    [NotesArrangement.Column] = L.NOTES_ARRANGEMENT_COLUMN,
    [NotesArrangement.Row] = L.NOTES_ARRANGEMENT_ROW,
}

--------------------------------------------------------------------------------
---- Tooltip Options
--------------------------------------------------------------------------------

---@class TooltipOptionsTable: AceConfig.OptionsTable
local Options

---@param entryName string
---@param order number
---@return AceConfig.OptionsTable
local function BuildEnableCheckButton(entryName, order)
    local disabledSections = private.DB.Tooltip.DisabledSections

    return {
        get = function()
            return not disabledSections[entryName]
        end,
        name = ENABLE,
        order = order,
        set = function()
            disabledSections[entryName] = not disabledSections[entryName]
        end,
        type = "toggle",
    }
end

---@param entryName string
---@param label string
---@param order number
---@return AceConfig.OptionsTable
local function BuildNoteTypeSelect(entryName, label, order)
    local notesArrangement = private.DB.Tooltip.NotesArrangement

    return {
        get = function(info)
            return notesArrangement[entryName]
        end,
        name = ("%s %s"):format(label, PARENS_TEMPLATE:format(TYPE)),
        order = order,
        set = function(info, value)
            notesArrangement[entryName] = value
        end,
        style = "radio",
        type = "select",
        values = NotesArrangementValues,
    }
end

function TooltipPreferences:GetOptions()
    if not Options then
        local DB = private.DB

        Options = {
            order = 1,
            name = DISPLAY,
            type = "group",
            args = {
                General = {
                    name = GENERAL_LABEL,
                    order = 1,
                    type = "group",
                    args = {
                        Header = {
                            name = GENERAL_LABEL,
                            order = 1,
                            type = "header",
                            width = "full",
                        },
                        TooltipHideDelay = {
                            desc = L.TOOLTIP_HIDEDELAY_DESC,
                            get = function()
                                return DB.Tooltip.HideDelay
                            end,
                            max = 2,
                            min = 0.10,
                            name = L.TOOLTIP_HIDEDELAY_LABEL,
                            order = 2,
                            type = "range",
                            set = function(info, value)
                                DB.Tooltip.HideDelay = value
                            end,
                            step = 0.05,
                            width = "normal",
                        },
                        TooltipScale = {
                            get = function()
                                return DB.Tooltip.Scale
                            end,
                            max = 2,
                            min = 0.5,
                            name = L.TOOLTIP_SCALE_LABEL,
                            order = 3,
                            set = function(info, value)
                                DB.Tooltip.Scale = value
                            end,
                            step = 0.01,
                            type = "range",
                            width = "normal",
                        },
                    },
                },
                BattleNetApp = {
                    name = BATTLENET_OPTIONS_LABEL,
                    order = 2,
                    type = "group",
                    args = {
                        Header = {
                            name = BATTLENET_OPTIONS_LABEL,
                            order = 1,
                            type = "header",
                            width = "full",
                        },
                        Enable = BuildEnableCheckButton("BattleNetApp", 2),
                        NotesArrangement = BuildNoteTypeSelect("BattleNetApp", LABEL_NOTE, 3),
                    },
                },
                BattleNetGames = {
                    name = GAMES,
                    order = 3,
                    type = "group",
                    args = {
                        Header = {
                            name = GAMES,
                            order = 1,
                            type = "header",
                            width = "full",
                        },
                        Enable = BuildEnableCheckButton("BattleNetGames", 2),
                        NotesArrangement = BuildNoteTypeSelect("BattleNetGames", LABEL_NOTE, 3),
                    },
                },
                Guild = {
                    name = GetGuildInfo("player") or GUILD,
                    order = 4,
                    type = "group",
                    args = {
                        Header = {
                            name = GetGuildInfo("player") or GUILD,
                            order = 1,
                            type = "header",
                            width = "full",
                        },
                        Enable = BuildEnableCheckButton("Guild", 2),
                        MOTD = {
                            get = function()
                                return private.DB.Tooltip.ShowGuildMOTD
                            end,
                            name = GUILD_MOTD,
                            order = 3,
                            set = function()
                                private.DB.Tooltip.ShowGuildMOTD = not private.DB.Tooltip.ShowGuildMOTD
                            end,
                            type = "toggle",
                        },
                        NotesArrangement = BuildNoteTypeSelect("Guild", LABEL_NOTE, 3),
                        NotesArrangementGuildOfficer = BuildNoteTypeSelect("GuildOfficer", GUILD_OFFICER_NOTE, 4),
                    },
                },
                WoWFriends = {
                    name = FRIENDS,
                    order = 5,
                    type = "group",
                    args = {
                        Header = {
                            name = FRIENDS,
                            order = 1,
                            type = "header",
                            width = "full",
                        },
                        Enable = BuildEnableCheckButton("WoWFriends", 2),
                        NotesArrangement = BuildNoteTypeSelect("WoWFriends", LABEL_NOTE, 3),
                    },
                },
            },
        }
    end

    return Options
end

--------------------------------------------------------------------------------
---- Preferences Augmentation
--------------------------------------------------------------------------------

Preferences.DefaultValues.global.Tooltip = {
    CollapsedSections = {
        BattleNetApp = false,
        BattleNetGames = false,
        Guild = false,
        WoWFriends = false,
    },
    DisabledSections = {
        BattleNetApp = false,
        BattleNetGames = false,
        Guild = false,
        WoWFriends = false,
    },
    HideDelay = 0.25,
    NotesArrangement = {
        BattleNetApp = NotesArrangement.Row,
        BattleNetGames = NotesArrangement.Row,
        Guild = NotesArrangement.Row,
        GuildOfficer = NotesArrangement.Row,
        WoWFriends = NotesArrangement.Row,
    },
    SectionDisplayOrders = {
        "WoWFriends",
        "BattleNetGames",
        "BattleNetApp",
        "Guild",
    },
    Scale = 1,
    ShowGuildMOTD = false,
    Sorting = {
        BattleNetApp = {
            Field = Sorting.FieldIDs.BattleNetApp.PresenceName,
            Order = SortOrder.Enum.Ascending,
        },
        BattleNetGames = {
            Field = Sorting.FieldIDs.BattleNetGames.PresenceName,
            Order = SortOrder.Enum.Ascending,
        },
        Guild = {
            Field = Sorting.FieldIDs.Guild.ToonName,
            Order = SortOrder.Enum.Ascending,
        },
        WoWFriends = {
            Field = Sorting.FieldIDs.WoWFriends.ToonName,
            Order = SortOrder.Enum.Ascending,
        },
    },
}
