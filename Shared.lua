-- ----------------------------------------------------------------------------
-- Localized Lua globals.
-- ----------------------------------------------------------------------------
local _G = getfenv(0)

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local FOLDER_NAME, private = ...

-- ----------------------------------------------------------------------------
-- Enumerations.
-- ----------------------------------------------------------------------------
local NotesArrangementType = {
	Column = 1,
	Row = 2,
}

private.NotesArrangementType = NotesArrangementType

local ZonePVPStatus = {
	Alliance = 1,
	ContestedTerritory = 2,
	CombatZone = 3,
	FreeForAll = 4,
	Horde = 5,
	Normal = 6,
	Sanctuary = 7,
}

private.ZonePVPStatus = ZonePVPStatus

local ZonePVPStatusByLabel = {
	ALLIANCE = ZonePVPStatus.Alliance,
	CONTESTED = ZonePVPStatus.ContestedTerritory,
	COMBAT = ZonePVPStatus.CombatZone,
	ARENA = ZonePVPStatus.FreeForAll,
	HORDE = ZonePVPStatus.Horde,
	NORMAL = ZonePVPStatus.Normal,
	SANCTUARY = ZonePVPStatus.Sanctuary,
}

private.ZonePVPStatusByLabel = ZonePVPStatusByLabel

local function GetRGBForFaction(factionName)
	if factionName == _G.UnitFactionGroup("player") then
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

private.ZonePVPStatusRGB = ZonePVPStatusRGB
