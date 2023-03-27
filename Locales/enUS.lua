-- ----------------------------------------------------------------------------
-- AddOn Namespace
-- ----------------------------------------------------------------------------
local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@class PrivateNamespace

local is_silent = true
--@debug@
is_silent = false
--@end-debug@

---@type Localizations
local L = LibStub("AceLocale-3.0"):NewLocale(AddOnFolderName, "enUS", true, is_silent)

if not L then
    return
end

--@localization(locale="enUS", format="lua_additive_table", handle-unlocalized="english", escape-non-ascii=false, same-key-is-true=true)@
