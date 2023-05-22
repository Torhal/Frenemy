-- ----------------------------------------------------------------------------
-- AddOn Namespace
-- ----------------------------------------------------------------------------
local AddOnFolderName = ... ---@type string
local private = select(2, ...) ---@class PrivateNamespace

-- ----------------------------------------------------------------------------
-- Enumerations and Data
-- ----------------------------------------------------------------------------

local SortOrderEnum = {
    Ascending = 1,
    Descending = 2,
}

private.SortOrder = {
    Enum = SortOrderEnum,
    Name = {
        [SortOrderEnum.Ascending] = "Ascending",
        [SortOrderEnum.Descending] = "Descending",
    },
}

local SortOrder = private.SortOrder

---@class Sorting
private.Sorting = {
    FieldIDs = {},
    FieldNames = {},
    --- Changing the order will cause SavedVariables to no longer map appropriately.
    Fields = {
        BattleNetApp = {
            "GameText",
            "PresenceName",
            "ToonName",
            "Note",
        },
        BattleNetGames = {
            "ClientIndex",
            "GameText",
            "PresenceName",
            "ToonName",
            "Note",
        },
        Guild = {
            "Level",
            "RankIndex",
            "ToonName",
            "ZoneName",
            "PublicNote",
            "OfficerNote",
            "Class",
            "RealmName",
        },
        WoWFriends = {
            "Level",
            "PresenceName",
            "RealmName",
            "ToonName",
            "ZoneName",
            "Note",
            "Class",
        },
    },
    ---@type table<string, fun(a?: BattleNetFriend|GuildMember|WoWFriend, b?: BattleNetFriend|GuildMember|WoWFriend): boolean>
    Functions = {},
}

local Sorting = private.Sorting

for sectionName, fieldNameList in pairs(Sorting.Fields) do
    local IDList = {}
    Sorting.FieldIDs[sectionName] = IDList

    local nameList = {}
    Sorting.FieldNames[sectionName] = nameList

    for index = 1, #fieldNameList do
        IDList[fieldNameList[index]] = index
        nameList[index] = fieldNameList[index]

        local sortFuncName = sectionName .. fieldNameList[index]
        Sorting.Functions[sortFuncName .. SortOrder.Name[SortOrder.Enum.Ascending]] = function(a, b)
            local aField = a[fieldNameList[index]] or ""
            aField = type(aField) == "string" and aField:lower() or aField

            local bField = b[fieldNameList[index]] or ""
            bField = type(bField) == "string" and bField:lower() or bField

            if aField == bField then
                return a.ToonName:lower() < b.ToonName:lower()
            end

            return aField < bField
        end

        Sorting.Functions[sortFuncName .. SortOrder.Name[SortOrder.Enum.Descending]] = function(a, b)
            local aField = a[fieldNameList[index]] or ""
            aField = type(aField) == "string" and aField:lower() or aField

            local bField = b[fieldNameList[index]] or ""
            bField = type(bField) == "string" and bField:lower() or bField

            if aField == bField then
                return a.ToonName:lower() > b.ToonName:lower()
            end

            return aField > bField
        end
    end
end
