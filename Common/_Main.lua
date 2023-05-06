--------------------------------------------------------------------------------
---- AddOn Namespace
--------------------------------------------------------------------------------

local AddOnFolderName = ... ---@type string

---@class PrivateNamespace
---@field MapHandler MapHandler
---@field People FriendStatistics Populated and maintained in UpdateStatistics()
---@field Preferences Preferences
---@field TooltipHandler TooltipHandler
local private = select(2, ...)

private.MapHandler = {}

private.People = {
    BattleNet = {
        Online = 0,
        Total = 0,
    },
    Friends = {
        Online = 0,
        Total = 0,
    },
    GuildMembers = {
        Online = 0,
        Total = 0,
    },
}

private.Preferences = {}
private.TooltipHandler = {}

--------------------------------------------------------------------------------
---- Helpers
--------------------------------------------------------------------------------

function private.UpdateStatistics()
    local People = private.People
    People.BattleNet.Total, People.BattleNet.Online = BNGetNumFriends()
    People.Friends.Total = C_FriendList.GetNumFriends()
    People.Friends.Online = C_FriendList.GetNumOnlineFriends()

    if IsInGuild() then
        local _
        People.GuildMembers.Total, _, People.GuildMembers.Online = GetNumGuildMembers()
    end
end

--------------------------------------------------------------------------------
---- Types
--------------------------------------------------------------------------------

---@class FriendStatistics
---@field BattleNet FriendStatisticsValues
---@field Friends FriendStatisticsValues
---@field GuildMembers FriendStatisticsValues

---@class FriendStatisticsValues
---@field Online number
---@field Total number
