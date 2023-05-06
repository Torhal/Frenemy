--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

--------------------------------------------------------------------------------
---- Initialization
--------------------------------------------------------------------------------

local metaVersion = GetAddOnMetadata(AddOnFolderName, "Version")
local isDevelopmentVersion = false
local isAlphaVersion = false

--@debug@
isDevelopmentVersion = true
--@end-debug@

--@alpha@
isAlphaVersion = true
--@end-alpha@

local buildVersion = isDevelopmentVersion and "Development Version"
    or (isAlphaVersion and ("%s-Alpha"):format(metaVersion))
    or metaVersion

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
local Preferences = private.Preferences

Preferences.DataObject = {}
Preferences.DefaultValues = {
    global = {
        ZoneData = {}, -- Populated during travel.
    },
}

Preferences.Tooltip = {}

---@return AceConfig.OptionsTable
function Preferences:GetOptions()
    if not Options then
        Options = {
            name = ("%s - %s"):format(AddOnFolderName, buildVersion),
            type = "group",
            childGroups = "tab",
            args = {
                dataObject = Preferences.DataObject:GetOptions(),
                tooltip = Preferences.Tooltip:GetOptions(),
            },
        }
    end

    return Options
end

function Preferences:InitializeDatabase()
    return LibStub("AceDB-3.0"):New(AddOnFolderName .. "DB", self.DefaultValues, true).global
end

function Preferences:SetupOptions()
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(AddOnFolderName, self.GetOptions)

    self.OptionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddOnFolderName)
end
