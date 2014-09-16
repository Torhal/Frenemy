local FOLDER_NAME, private = ...
local L = LibStub("AceLocale-3.0"):NewLocale(FOLDER_NAME, "enUS", true)

if not L then return end

L.MINIMAP_ICON_DESC = "Show the interface as a minimap icon."
L.TOOLTIP_HIDEDELAY_LABEL = "Tooltip Hide Delay"
L.TOOLTIP_HIDEDELAY_DESC = "Length of time the tooltip will continue to be shown after the mouse has been moved."
L.TOOLTIP_SCALE_LABEL = "Tooltip Scale"
L.NOTES_ARRANGEMENT_COLUMN = "Column"
L.NOTES_ARRANGEMENT_ROW = "Row"
L.COLUMN_LABEL_REALM = "Realm"
L.RIGHT_CLICK = "Right-Click"
L.LEFT_CLICK = "Left-Click"
L.CONTROL_KEY = "Control-"
L.SHIFT_KEY = "Shift-"
L.ALT_KEY = "Alt-"
