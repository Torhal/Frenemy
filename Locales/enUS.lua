local FOLDER_NAME, private = ...
local is_silent = true
--@debug@
is_silent = false
--@end-debug@

local L = LibStub("AceLocale-3.0"):NewLocale(FOLDER_NAME, "enUS", true, is_silent)

if not L then return end

--@localization(locale="enUS", format="lua_additive_table", handle-unlocalized="english", escape-non-ascii=false, same-key-is-true=true)@
