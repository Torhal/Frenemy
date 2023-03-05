-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

local LibStub = _G.LibStub
local Frenemy = LibStub("AceAddon-3.0"):GetAddon(FOLDER_NAME)

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(FOLDER_NAME)

-- ----------------------------------------------------------------------------
-- Variables.
-- ----------------------------------------------------------------------------
local options
local dataObjectOptions
local tooltipOptions

local DB

-- ----------------------------------------------------------------------------
-- Config functions.
-- ----------------------------------------------------------------------------
local function GetDataObjectOptions()
	if not dataObjectOptions then
		local LDBIcon = LibStub("LibDBIcon-1.0")

		dataObjectOptions = {
			order = 1,
			name = _G.INFO,
			type = "group",
			args = {}
		}

		if LDBIcon then
			dataObjectOptions.args.miniMap = {
				order = 1,
				type = "toggle",
				name = _G.MINIMAP_LABEL,
				desc = L.MINIMAP_ICON_DESC,
				get = function()
					return not DB.DataObject.MinimapIcon.hide
				end,
				set = function(info, value)
					DB.DataObject.MinimapIcon.hide = not DB.DataObject.MinimapIcon.hide
					LDBIcon[DB.DataObject.MinimapIcon.hide and "Hide" or "Show"](LDBIcon, FOLDER_NAME)
				end
			}
		end
	end
	return dataObjectOptions
end

local NOTES_ARRANGEMENT_VALUES = {
	[private.NotesArrangementType.Column] = L.NOTES_ARRANGEMENT_COLUMN,
	[private.NotesArrangementType.Row] = L.NOTES_ARRANGEMENT_ROW,
}

local function BuildNotesEntry(optionsTable, entryName, label, order)
	optionsTable["notesArrangement" ..entryName] = {
		order = order,
		type = "select",
		style = "radio",
		name = label,
		values = NOTES_ARRANGEMENT_VALUES,
		get = function(info)
			return DB.Tooltip.NotesArrangement[entryName]
		end,
		set = function(info, value)
			DB.Tooltip.NotesArrangement[entryName] = value
		end,
	}
end

local function GetTooltipOptions()
	if not tooltipOptions then
		tooltipOptions = {
			order = 2,
			name = _G.DISPLAY,
			type = "group",
			args = {
				hideDelay = {
					order = 1,
					type = "range",
					width = "full",
					name = L.TOOLTIP_HIDEDELAY_LABEL,
					desc = L.TOOLTIP_HIDEDELAY_DESC,
					min = 0.10,
					max = 2,
					step = 0.05,
					get = function()
						return DB.Tooltip.HideDelay
					end,
					set = function(info, value)
						DB.Tooltip.HideDelay = value
					end,
				},
				scale = {
					order = 2,
					type = "range",
					width = "full",
					name = L.TOOLTIP_SCALE_LABEL,
					min = 0.5,
					max = 2,
					step = 0.01,
					get = function()
						return DB.Tooltip.Scale
					end,
					set = function(info, value)
						DB.Tooltip.Scale = value
					end,
				},
				notesArrangementHeader = {
					name = _G.LABEL_NOTE,
					order = 3,
					type = "header",
					width = "full",
				},
			}
		}

		BuildNotesEntry(tooltipOptions.args, "BattleNetApp", _G.BATTLENET_OPTIONS_LABEL, 4)
		BuildNotesEntry(tooltipOptions.args, "BattleNetGames", ("%s %s"):format(_G.BATTLENET_OPTIONS_LABEL, _G.PARENS_TEMPLATE:format(_G.GAME)), 5)
		BuildNotesEntry(tooltipOptions.args, "Guild", _G.GetGuildInfo("player") or _G.GUILD, 6)
		BuildNotesEntry(tooltipOptions.args, "GuildOfficer", ("%s %s"):format(_G.GetGuildInfo("player") or _G.GUILD, _G.PARENS_TEMPLATE:format(_G.OFFICER)), 7)
		BuildNotesEntry(tooltipOptions.args, "WoWFriends", _G.FRIENDS, 8)
	end
	return tooltipOptions
end

local function GetOptions()
	if not options then
		options = {
			name = FOLDER_NAME,
			type = "group",
			childGroups = "tab",
			args = {}
		}
		options.args.dataObject = GetDataObjectOptions()
		options.args.tooltip = GetTooltipOptions()
	end
	return options
end

function private.SetupOptions()
	DB = private.DB
	AceConfigRegistry:RegisterOptionsTable(FOLDER_NAME, GetOptions)
	Frenemy.optionsFrame = AceConfigDialog:AddToBlizOptions(FOLDER_NAME)
end
