--[[ Core/AddonCategories.lua
  Which shelf each addon sits on in the sidebar.

  One flat alphabetical column was fine at six addons and stopped being fine
  somewhere around twenty: every name starts with the same word once the
  "Peavers" prefix is stripped off for display, so the eye has nothing to sort
  by and finding a known addon means reading the whole list. Grouping gives it
  something to sort by first, and alphabetical within a group means the second
  half of the lookup is a scan of four or five names rather than twenty-five.

  The map is held here rather than in each addon's own Register call because a
  category is a statement about the collection, not about the addon - whether
  Item Level belongs under Group & Raid or Character is a question you can only
  answer by looking at what else is on both shelves. Registration may still pass
  `category` and it wins; that is the escape hatch for an addon the map has not
  heard of yet, and for anything out of tree.

  Anything unmapped and undeclared lands in the last group rather than
  disappearing, which is the behaviour that matters: a new addon shows up in the
  sidebar the day it ships, just not in the right place until this file catches
  up.
]]
local _, PC = ...

local AddonCategories = {}
PC.AddonCategories = AddonCategories

-- The shelves, in the order they are drawn. Not alphabetical: the groups a
-- player opens this window for come first, and the bucket for the unmapped is
-- last by definition.
local ORDER = {
    "Interface",
    "Combat",
    "Group & Raid",
    "Character",
    "Performance",
    "Utility",
    "Other",
}

-- The bucket everything unmapped falls into. Also the last entry in ORDER, and
-- the two have to stay the same string.
local FALLBACK = "Other"

local CATEGORIES = {
    -- Things that replace or reskin a piece of Blizzard's UI.
    PeaversCastBar       = "Interface",
    PeaversChat          = "Interface",
    PeaversMiniMap       = "Interface",
    PeaversScaler        = "Interface",
    PeaversToolTip       = "Interface",
    PeaversUI            = "Interface",
    PeaversUnitFrames    = "Interface",

    -- Things that only do anything once the fight starts.
    PeaversAlwaysSquare  = "Combat",
    PeaversBroadcast     = "Combat",
    PeaversCombatTime    = "Combat",
    PeaversConsumableBar = "Combat",
    PeaversDynamicStats  = "Combat",

    -- Things about the other people in the group.
    BetterTogether       = "Group & Raid",
    PeaversGuildCount    = "Group & Raid",
    PeaversItemLevel     = "Group & Raid",
    PeaversNeedThat      = "Group & Raid",
    PeaversRemembersYou  = "Group & Raid",
    PeaversSplits        = "Group & Raid",

    -- Things about your own character's gear, spec and consumables.
    PeaversBestInSlot    = "Character",
    PeaversConsumables   = "Character",
    PeaversTalents       = "Character",

    -- Things you install to get frames back.
    PeaversCVars         = "Performance",
    PeaversPerformance   = "Performance",
    PeaversSystemBars    = "Performance",

    -- Everything else that earns its place without fitting the shelves above.
    PeaversGetThere      = "Utility",
    PeaversIconSearch    = "Utility",
    PeaversRealValue     = "Utility",
    PeaversShots         = "Utility",
    PeaversUIVault       = "Utility",
    PeaversUpdater       = "Utility",
}

--- The category an addon belongs to. What registration declared wins over the
--- map, and the map wins over the fallback.
--- @param info table a ConfigRegistry addon record
--- @return string category
function AddonCategories:For(info)
    if not info then return FALLBACK end
    -- A declared category is taken at face value, including one this file has
    -- never heard of: the point of the escape hatch is that it does not need a
    -- change here to work.
    if type(info.category) == "string" and info.category ~= "" then
        return info.category
    end
    return CATEGORIES[info.name] or FALLBACK
end

--- The registered addons, shelved and sorted: groups in ORDER, then any
--- declared category the order does not mention, alphabetically; addons inside
--- a group alphabetically by the name the sidebar actually prints.
---
--- Empty groups are dropped, so a player with four addons sees one or two
--- headings rather than seven headings and four rows.
---
--- @param addons table array of ConfigRegistry addon records
--- @return table groups array of { name = string, addons = table }
function AddonCategories:Group(addons)
    local byName = {}
    local extras = {}

    for _, info in ipairs(addons or {}) do
        local category = self:For(info)
        if not byName[category] then
            byName[category] = {}
            -- Tracked separately so a category declared by an addon and absent
            -- from ORDER still gets drawn, after the known ones and before the
            -- fallback bucket.
            local known = false
            for _, name in ipairs(ORDER) do
                if name == category then
                    known = true
                    break
                end
            end
            if not known then
                table.insert(extras, category)
            end
        end
        table.insert(byName[category], info)
    end

    table.sort(extras)

    local groups = {}

    local function Take(category)
        local list = byName[category]
        if not list then return end
        table.sort(list, function(a, b)
            local left = a.displayName or a.name or ""
            local right = b.displayName or b.name or ""
            if left == right then
                return (a.name or "") < (b.name or "")
            end
            return left < right
        end)
        table.insert(groups, { name = category, addons = list })
    end

    for _, category in ipairs(ORDER) do
        if category ~= FALLBACK then
            Take(category)
        end
    end
    for _, category in ipairs(extras) do
        Take(category)
    end
    -- Last, whatever the order of everything before it.
    Take(FALLBACK)

    return groups
end

return AddonCategories
