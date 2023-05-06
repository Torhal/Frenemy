--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@class PrivateNamespace

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnFolderName)

---@class Preferences.DataObject
local DataObjectPreferences = private.Preferences.DataObject

--------------------------------------------------------------------------------
---- DataObject Options
--------------------------------------------------------------------------------

---@type AceConfig.OptionsTable
local Options

function DataObjectPreferences:GetOptions()
    if not Options then
        local DB = private.DB
        local LDBIcon = LibStub("LibDBIcon-1.0")

        Options = {
            order = 1,
            name = INFO,
            type = "group",
            args = {},
        }

        if LDBIcon then
            Options.args.miniMap = {
                order = 1,
                type = "toggle",
                name = MINIMAP_LABEL,
                desc = L.MINIMAP_ICON_DESC,
                get = function()
                    return not DB.DataObject.MinimapIcon.hide
                end,
                set = function(info, value)
                    DB.DataObject.MinimapIcon.hide = not DB.DataObject.MinimapIcon.hide
                    LDBIcon[DB.DataObject.MinimapIcon.hide and "Hide" or "Show"](LDBIcon, AddOnFolderName)
                end,
            }
        end
    end

    return Options
end

--------------------------------------------------------------------------------
---- Preferences Augmentation
--------------------------------------------------------------------------------

private.Preferences.DefaultValues.global.DataObject = {
    MinimapIcon = {
        hide = false,
    },
}
