local RACES   = require("src.data.races")
local CLASSES = require("src.data.classes")

local Adventurer = {}
Adventurer.__index = Adventurer

-- Ordered list used for display throughout the UI.
Adventurer.CLASSES_ORDER = { "fighter", "ranger", "priest" }

local STAT_KEYS = { "str", "iq", "wis", "con", "agi", "cha" }

local STAT_LABELS = {
    str = "STR",
    iq  = "IQ",
    wis = "WIS",
    con = "CON",
    agi = "AGI",
    cha = "CHA",
}

--- Roll a single base stat: uniform random between 5 and 14.
local function rollBaseStat()
    return love.math.random(5, 14)
end

--- Roll a full set of stats for a given race, applying racial bonuses.
-- Also rolls starting HP using d3 + CON modifier (class-agnostic at this stage).
function Adventurer.rollStats(raceId)
    local race  = RACES[raceId]
    local bonus = race and race.stat_bonus or {}
    local stats = {}
    for _, key in ipairs(STAT_KEYS) do
        stats[key] = rollBaseStat() + (bonus[key] or 0)
    end
    local conBonus = math.floor((stats.con - 10) / 2)
    stats.hp = math.max(1, love.math.random(1, 3) + conBonus)
    return stats
end

--- Returns a map of classId → bool indicating which classes the stats qualify for.
function Adventurer.classEligibility(stats)
    local result = {}
    for id, class in pairs(CLASSES) do
        local eligible = true
        for stat, minVal in pairs(class.requires or {}) do
            if (stats[stat] or 0) < minVal then
                eligible = false
                break
            end
        end
        result[id] = eligible
    end
    return result
end

--- Create a new adventurer table.
function Adventurer.new(name, raceId, classId, stats)
    local maxHp = stats.hp

    return setmetatable({
        name    = name,
        race    = raceId,
        class   = classId,
        level   = 1,
        xp      = 0,
        stats   = stats,
        hp      = { current = maxHp, max = maxHp },
        status  = "ok",    -- ok | dead | ash | lost
        inParty = false,
    }, Adventurer)
end

--- Short status string for display.
function Adventurer:statusLabel()
    return ({ ok="OK", dead="Dead", ash="Ash", lost="Lost" })[self.status] or "?"
end

--- Short race/class label, e.g. "Human Fighter".
function Adventurer:raceClassLabel()
    local r = RACES[self.race]
    local c = CLASSES[self.class]
    return (r and r.label or self.race) .. " " .. (c and c.label or self.class)
end

function Adventurer.statKeys()
    return STAT_KEYS
end

function Adventurer.statLabel(key)
    return STAT_LABELS[key] or key:upper()
end

return Adventurer
