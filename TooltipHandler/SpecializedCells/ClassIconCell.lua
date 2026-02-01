--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

local providerValues = QTip:CreateCellProvider(QTip:GetCellProvider("LibQTip-2.0 Icon"))

QTip:RegisterCellProvider("LibQTip-2.0 Class Icon", providerValues.newCellProvider)

---@class LibQTip-2.0.ClassIconCell: LibQTip-2.0.IconCell
local ClassIconCell = providerValues.newCellPrototype

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

--- Populates the Cell with an icon texture.
---@param className string The player Class name for the desired icon.
function ClassIconCell:SetIconTexture(className)
	local texCoords = CLASS_ICON_TCOORDS[className]

	if texCoords then
		self.IconTexture:SetTexture([[Interface\TargetingFrame\UI-Classes-Circles]])
		self.IconTexture:SetTexCoord(unpack(texCoords))

		self:OnContentChanged()
	end

	return self
end
