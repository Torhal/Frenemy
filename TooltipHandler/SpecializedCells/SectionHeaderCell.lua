--------------------------------------------------------------------------------
---- Initialization
--------------------------------------------------------------------------------

local QTip = LibStub("LibQTip-2.0")
local providerValues = QTip:CreateCellProvider()

QTip:RegisterCellProvider("Frenemy Section Header", providerValues.newCellProvider)

---@class Frenemy.SectionHeaderCell: LibQTip-2.0.Cell
---@field BackgroundAtlas Texture
local SectionHeaderCell = providerValues.newCellPrototype

local BaseCell = providerValues.baseCellPrototype

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

function SectionHeaderCell:GetContentHeight()
    return 24
end

function SectionHeaderCell:OnCreation()
    BaseCell.OnCreation(self)

    local background = self:CreateTexture(nil, "ARTWORK")
    background:SetBlendMode("ADD")
    background:SetAtlas("Objective-Header", true)
    background:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 14)
    background:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 14)

    self.BackgroundAtlas = background
end
