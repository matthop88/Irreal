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

--- Roll a single base stat: 2d4+4, giving a bell-curve range of 6–12.
local function rollBaseStat()
    return love.math.random(1, 4) + love.math.random(1, 4) + 4
end

-- Try to rescue Fighter eligibility by swapping BASE rolls (not final values).
-- Operates on the raw `bases` table and uses `bonus` to determine what base
-- value is needed in the target slot to meet the Fighter requirement after
-- the racial modifier is applied.  Non-destructive when no donor qualifies.
local function ensureFighterEligible(bases, bonus)
    local reqs = CLASSES.fighter and CLASSES.fighter.requires or {}

    -- Collect fighter stats whose FINAL value (base+bonus) is deficient.
    local deficient = {}
    for stat, minVal in pairs(reqs) do
        local final = (bases[stat] or 0) + (bonus[stat] or 0)
        if final < minVal then
            table.insert(deficient, stat)
        end
    end
    if #deficient == 0 then return end

    local reqSet = {}
    for stat in pairs(reqs) do reqSet[stat] = true end

    for _, target in ipairs(deficient) do
        -- A donor's base, placed into the target slot, must satisfy:
        --   donor_base + target_bonus >= target_requirement
        local neededBase = reqs[target] - (bonus[target] or 0)

        -- Build a fresh donor list each pass (bases may have changed).
        local donors = {}
        for _, key in ipairs(STAT_KEYS) do
            if not reqSet[key] and (bases[key] or 0) >= neededBase then
                table.insert(donors, key)
            end
        end
        -- Prefer the smallest qualifying base to preserve higher rolls elsewhere.
        table.sort(donors, function(a, b) return bases[a] < bases[b] end)

        if #donors > 0 then
            local donor = donors[1]
            bases[target], bases[donor] = bases[donor], bases[target]
        end
    end
end

--- Roll a full set of stats for a given race, applying racial bonuses.
-- Also rolls starting HP using d3 + CON modifier (class-agnostic at this stage).
function Adventurer.rollStats(raceId)
    local race  = RACES[raceId]
    local bonus = race and race.stat_bonus or {}

    -- Roll raw bases (2d4+4 each, range 6–12).
    local bases = {}
    for _, key in ipairs(STAT_KEYS) do
        bases[key] = rollBaseStat()
    end

    -- Apply racial bonuses to produce tentative final stats.
    local stats = {}
    for _, key in ipairs(STAT_KEYS) do
        stats[key] = bases[key] + (bonus[key] or 0)
    end

    -- Only nudge toward Fighter eligibility when no class qualifies naturally;
    -- a natural Ranger or Priest should keep their rolls untouched.
    local anyEligible = false
    for _, eligible in pairs(Adventurer.classEligibility(stats)) do
        if eligible then anyEligible = true; break end
    end
    if not anyEligible then
        -- Swap bases (not finals) then recompute finals from the new bases.
        ensureFighterEligible(bases, bonus)
        for _, key in ipairs(STAT_KEYS) do
            stats[key] = bases[key] + (bonus[key] or 0)
        end
    end

    local conBonus = math.floor((stats.con - 7) / 3)
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
