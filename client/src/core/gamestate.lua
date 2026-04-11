-- Persistent game state for Irreal.
-- Lua caches require() results, so every module that requires this file
-- receives the same table — no globals needed.
--
-- Usage:
--   local GS = require("src.core.gamestate")
--   GS.gold = GS.gold + 100

local GameState = {

    -- ── Resources ─────────────────────────────────────────────────────────────
    gold   = 10000,
    stone  = 0,
    timber = 0,

    -- ── Adventurers ───────────────────────────────────────────────────────────
    roster = {},   -- adventurers waiting in the tavern (not in party)
    party  = {},   -- active party members

    -- ── Building levels ───────────────────────────────────────────────────────
    buildings = {
        tavern   = 1,
        shop     = 1,
        church   = 1,
        training = 1,
    },

    -- ── Progression flags ─────────────────────────────────────────────────────
    unlocks = {
        dwarves  = false,
        elves    = false,
        ranger   = false,
        priest   = false,
        forest   = false,
        sea      = false,
    },
}

--- Maximum party size based on current tavern level.
function GameState:partyCapacity()
    local caps = { 3, 4, 5, 6 }
    return caps[self.buildings.tavern] or 6
end

--- True if the party has room for at least one more adventurer.
function GameState:partyHasRoom()
    return #self.party < self:partyCapacity()
end

--- Move an adventurer from the roster into the party.
-- Returns true on success, false if party is full or adventurer not found.
function GameState:addToParty(adventurer)
    if not self:partyHasRoom() then return false end
    for i, a in ipairs(self.roster) do
        if a == adventurer then
            table.remove(self.roster, i)
            table.insert(self.party, adventurer)
            adventurer.inParty = true
            return true
        end
    end
    return false
end

--- Move an adventurer from the party back to the roster.
function GameState:dismissFromParty(adventurer)
    for i, a in ipairs(self.party) do
        if a == adventurer then
            table.remove(self.party, i)
            table.insert(self.roster, adventurer)
            adventurer.inParty = false
            return true
        end
    end
    return false
end

return GameState
