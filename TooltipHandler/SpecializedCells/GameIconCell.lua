--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

local providerValues = QTip:CreateCellProvider(QTip:GetCellProvider("LibQTip-2.0 Icon"))

QTip:RegisterCellProvider("LibQTip-2.0 Game Icon", providerValues.newCellProvider)

---@class LibQTip-2.0.GameIconCell: LibQTip-2.0.IconCell
local GameIconCell = providerValues.newCellPrototype

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

--- Populates the Cell with an icon texture.
---@param gameTitle string The game name for the desired icon.
function GameIconCell:SetIconTexture(gameTitle)
	C_Texture.SetTitleIconTexture(self.IconTexture, gameTitle, Enum.TitleIconVersion.Small)

	self:OnContentChanged()

	return self
end
