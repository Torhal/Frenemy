--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

--------------------------------------------------------------------------------
---- Initialization
--------------------------------------------------------------------------------

---@return string
local function GetBuildVersion()
    local metaVersion = C_AddOns.GetAddOnMetadata(AddOnFolderName, "Version")
    local isDevelopmentVersion = false
    local isAlphaVersion = false

    --@debug@
    isDevelopmentVersion = true
    --@end-debug@

    if isDevelopmentVersion then
        return "Development Version"
    end

    --@alpha@
    isAlphaVersion = true
    --@end-alpha@

    if isAlphaVersion then
        return ("%s-Alpha"):format(metaVersion)
    end

    return metaVersion or UNKNOWN
end

--------------------------------------------------------------------------------
---- Preferences
--------------------------------------------------------------------------------

---@type AceConfig.OptionsTable
local Options

---@class Preferences
---@field DataObject Preferences.DataObject
---@field DefaultValues AceDB.Schema
---@field Tooltip Preferences.Tooltip
---@field OptionsFrame Frame
private.Preferences = {
    DataObject = {},
    DefaultValues = {
        global = {
            ZoneData = {}, -- Populated during travel.
        },
    },
    Tooltip = {
        NotesArrangement = {
            Column = 1,
            Row = 2,
        },
    },
}

---@class Preferences
local Preferences = private.Preferences

---@return AceConfig.OptionsTable
function Preferences:GetOptions()
    if not Options then
        Options = {
            childGroups = "tree",
            name = ("%s - %s"):format(AddOnFolderName, GetBuildVersion()),
            type = "group",
            args = {
                DataObject = Preferences.DataObject:GetOptions(),
                Tooltip = Preferences.Tooltip:GetOptions(),
            },
        }
    end

    return Options
end

function Preferences:InitializeDatabase()
    return LibStub("AceDB-3.0"):New(("%sDB"):format(AddOnFolderName), self.DefaultValues, true).global
end

function Preferences:SetupOptions()
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(AddOnFolderName, self.GetOptions)

    self.OptionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddOnFolderName)
end

function Preferences:ToggleOptionsVisibility()
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")

    if AceConfigDialog.OpenFrames[AddOnFolderName] then
        AceConfigDialog:Close(AddOnFolderName)
    else
        AceConfigDialog:Open(AddOnFolderName)
        AceConfigDialog:SelectGroup(AddOnFolderName, "Tooltip", "General")
    end
end
