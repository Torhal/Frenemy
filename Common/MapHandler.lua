--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

local HereBeDragons = LibStub("HereBeDragons-2.0")

---@class MapHandler
local MapHandler = private.MapHandler

---@class MapHandler.Data
---@field MapID? number The player's current UIMapID
---@field MapName string The name of the map for the UIMapID
---@field RGBColor table Populated during travel, and stored in SavedVariables
MapHandler.Data = {
    MapID = nil,
    MapName = UNKNOWN,
}

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

---@enum ZonePVPStatus
local ZonePVPStatus = {
    Alliance = 1,
    ContestedTerritory = 2,
    CombatZone = 3,
    FreeForAll = 4,
    Horde = 5,
    Normal = 6,
    Sanctuary = 7,
}

local ZonePVPStatusByLabel = {
    ALLIANCE = ZonePVPStatus.Alliance,
    CONTESTED = ZonePVPStatus.ContestedTerritory,
    COMBAT = ZonePVPStatus.CombatZone,
    ARENA = ZonePVPStatus.FreeForAll,
    HORDE = ZonePVPStatus.Horde,
    NORMAL = ZonePVPStatus.Normal,
    SANCTUARY = ZonePVPStatus.Sanctuary,
}

--------------------------------------------------------------------------------
---- Color Data
--------------------------------------------------------------------------------

local function GetRGBForFaction(factionName)
    if factionName == UnitFactionGroup("player") then
        return { r = 0.1, g = 1.0, b = 0.1 }
    end

    return { r = 1.0, g = 0.1, b = 0.1 }
end

local ZonePVPStatusRGB = {
    [ZonePVPStatus.Alliance] = GetRGBForFaction("Alliance"),
    [ZonePVPStatus.ContestedTerritory] = { r = 1.0, g = 0.7, b = 0 },
    [ZonePVPStatus.CombatZone] = { r = 1.0, g = 0.1, b = 0.1 },
    [ZonePVPStatus.FreeForAll] = { r = 1.0, g = 0.1, b = 0.1 },
    [ZonePVPStatus.Horde] = GetRGBForFaction("Horde"),
    [ZonePVPStatus.Normal] = { r = 1.0, g = 0.9294, b = 0.7607 },
    [ZonePVPStatus.Sanctuary] = { r = 0.41, g = 0.8, b = 0.94 },
}

MapHandler.Data.RGBColor = {
    [GARRISON_LOCATION_TOOLTIP] = ZonePVPStatusRGB[ZonePVPStatus.Normal],
}

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

---@param zoneName string The name of the zone
---@return string coloredZoneName
function MapHandler:ColoredZoneName(zoneName)
    local color = self.Data.RGBColor[zoneName:gsub(" %b()", "")] or GRAY_FONT_COLOR

    return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, zoneName or UNKNOWN)
end

---@param pvpType string
---@return ZonePVPStatus zonePVPStatus
function MapHandler:GetZonePVPStatus(pvpType)
    return ZonePVPStatusByLabel[pvpType:upper()]
end

---@param mapID number
---@param zonePVPStatus ZonePVPStatus
function MapHandler:SetRGBColor(mapID, zonePVPStatus)
    local mapName = HereBeDragons:GetLocalizedMap(mapID)

    if not mapName then
        private.DB.ZoneData[mapID] = nil

        return
    end

    self.Data.RGBColor[mapName] = ZonePVPStatusRGB[zonePVPStatus]
end
