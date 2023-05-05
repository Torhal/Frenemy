-- ----------------------------------------------------------------------------
-- AddOn Namespace
-- ----------------------------------------------------------------------------
local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@type PrivateNamespace

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnFolderName)
local LibQTip = LibStub("LibQTip-2.0")

---@class TooltipHandler
local TooltipHandler = private.TooltipHandler

-- ----------------------------------------------------------------------------
-- Constants
-- ----------------------------------------------------------------------------
local MaxTooltipColumns = 10

---@type table<string, table<string, string>>
local HelpTipDefinitions = {
    [DISPLAY] = {
        [L.LEFT_CLICK] = BINDING_NAME_TOGGLEFRIENDSTAB,
        [L.ALT_KEY .. L.LEFT_CLICK] = BINDING_NAME_TOGGLEGUILDTAB,
        [L.RIGHT_CLICK] = INTERFACE_OPTIONS,
    },
    [NAME] = {
        [L.LEFT_CLICK] = WHISPER,
        [L.RIGHT_CLICK] = ADVANCED_OPTIONS,
        [L.ALT_KEY .. L.LEFT_CLICK] = INVITE,
        [L.CONTROL_KEY .. L.LEFT_CLICK] = SET_NOTE,
        [L.CONTROL_KEY .. L.RIGHT_CLICK] = GUILD_OFFICER_NOTE,
    },
}

-- ----------------------------------------------------------------------------
-- Cell Scripts
-- ----------------------------------------------------------------------------
local function HideHelpTip()
    if TooltipHandler.Tooltip.Help then
        LibQTip:Release(TooltipHandler.Tooltip.Help)
        TooltipHandler.Tooltip.Help = nil
    end

    TooltipHandler.Tooltip.Main:SetFrameStrata("TOOLTIP") -- This can be set to DIALOG by various functions.
end

local function ShowHelpTip(tooltipCell)
    local helpTip = TooltipHandler.Tooltip.Help

    if not helpTip then
        helpTip = LibQTip:Acquire(AddOnFolderName .. "HelpTip", 2)
        helpTip:SetBackdropColor(0.05, 0.05, 0.05, 1)
        helpTip:SetScale(private.DB.Tooltip.Scale)

        helpTip
            :SetAutoHideDelay(0.25, tooltipCell)
            :SmartAnchorTo(tooltipCell)
            :SetScript("OnLeave", function()
                LibQTip:Release(helpTip)
            end)
            :Clear()
            :SetCellMarginH(0)
            :SetCellMarginV(1)

        TooltipHandler.Tooltip.Help = helpTip
    end

    local isInitialSection = true

    for entryType, data in pairs(HelpTipDefinitions) do
        if not isInitialSection then
            helpTip:AddLine(" ")
        end

        helpTip:AddLine():GetCell(1):SetColSpan(0):SetFont(GameFontNormal):SetJustifyH("CENTER"):SetText(entryType)
        helpTip:AddSeparator(1, 0.5, 0.5, 0.5)
        helpTip:AddSeparator(1, 0.5, 0.5, 0.5)

        for keyStroke, description in pairs(data) do
            local line = helpTip:AddLine()

            line:GetCell(1):SetJustifyH("RIGHT"):SetText(keyStroke --[[@as string]])
            line:GetCell(2):SetJustifyH("LEFT"):SetText(description)
        end

        isInitialSection = false
    end

    HideDropDownMenu(1)

    TooltipHandler.Tooltip.Main:SetFrameStrata("DIALOG")
    helpTip:Show()
end

-- ----------------------------------------------------------------------------
-- Display rendering
-- ----------------------------------------------------------------------------

---@param self LibQTip-2.0.Tooltip
local function Tooltip_OnRelease(self)
    HideDropDownMenu(1)
    HideHelpTip()

    self:SetFrameStrata("TOOLTIP") -- This can be set to DIALOG by various functions.

    TooltipHandler.Tooltip.AnchorFrame = nil
    TooltipHandler.Tooltip.Main = nil
end

local TitleFont = CreateFont("FrenemyTitleFont")
TitleFont:SetTextColor(0.510, 0.773, 1.0)
TitleFont:SetFontObject("QuestTitleFont")

local SectionDisplayFunction = {
    WoWFriends = TooltipHandler.WoWFriendSection.Display,
    BattleNetGames = TooltipHandler.BattleNetSection.DisplayGames,
    BattleNetApp = TooltipHandler.BattleNetSection.DisplayApps,
    Guild = TooltipHandler.GuildSection.Display,
}

---@param self TooltipHandler
---@param anchorFrame? Frame Anchor frame for the tooltip display
function TooltipHandler:Render(anchorFrame)
    anchorFrame = anchorFrame or self.Tooltip.AnchorFrame

    if not anchorFrame then
        return
    end

    self.Tooltip.AnchorFrame = anchorFrame
    self:GenerateData()

    local DB = private.DB
    local tooltip = self.Tooltip.Main

    if not tooltip then
        tooltip = LibQTip:Acquire(AddOnFolderName, MaxTooltipColumns)

        tooltip
            :SetAutoHideDelay(DB.Tooltip.HideDelay, anchorFrame)
            :SmartAnchorTo(anchorFrame)
            :SetHighlightTexture([[Interface\ClassTrainerFrame\TrainerTextures]])
            :SetHighlightTexCoord(0.00195313, 0.57421875, 0.75390625, 0.84570313)

        tooltip.OnRelease = Tooltip_OnRelease

        tooltip:SetBackdropColor(0.05, 0.05, 0.05, 1)
        tooltip:SetScale(DB.Tooltip.Scale)

        self.Tooltip.Main = tooltip
    end

    tooltip:Clear():SetCellMarginH(0):SetCellMarginV(1)

    tooltip:AddLine():GetCell(1):SetColSpan(0):SetJustifyH("CENTER"):SetFont(TitleFont):SetText(AddOnFolderName)
    tooltip:AddSeparator(1, 0.510, 0.773, 1.0)

    local MOTD = self.GuildSection.MOTD
    MOTD.Line = nil
    MOTD.Text = nil

    for index = 1, #DB.Tooltip.SectionDisplayOrders do
        SectionDisplayFunction[DB.Tooltip.SectionDisplayOrders[index]](nil, tooltip)
    end

    tooltip:Show()

    -- This must be done after everything else has been added to the tooltip in order to have an accurate width.
    if MOTD.Line and MOTD.Text then
        MOTD.Line
            :GetCell(1)
            :SetColSpan(0)
            :SetJustifyH("LEFT")
            :SetMaxWidth(tooltip:GetWidth() --[[@as integer]] - 20)
            :SetText(("%s%s|r"):format(GREEN_FONT_COLOR_CODE, MOTD.Text))
    end

    tooltip:AddSeparator(1, 0.510, 0.773, 1.0)

    tooltip
        :AddLine()
        :GetCell(MaxTooltipColumns)
        :SetJustifyH("RIGHT")
        :SetText(self.Icon.Help)
        :SetScript("OnEnter", ShowHelpTip)
        :SetScript("OnLeave", HideHelpTip)
        :SetScript("OnMouseDown", HideHelpTip)

    tooltip:UpdateScrolling()
end
