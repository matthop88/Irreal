-- Class definitions.
-- 'requires' maps stat keys to minimum values for eligibility.
-- 'hp_die' is the die size rolled for HP on level up.
-- 'prime_stats' are highlighted on the stat display.

return {
    fighter = {
        id          = "fighter",
        label       = "Fighter",
        desc        = "A sturdy warrior trained in all weapons and armour.",
        hp_die      = 3,
        prime_stats = { "str", "con" },
        requires    = { str = 10, con = 10 },
    },
    ranger = {
        id          = "ranger",
        label       = "Ranger",
        desc        = "A skilled hunter adept in combat and wilderness survival.",
        hp_die      = 3,
        prime_stats = { "iq", "agi" },
        requires    = { iq = 10, agi = 11 },
    },
    priest = {
        id          = "priest",
        label       = "Priest",
        desc        = "A devoted healer who channels divine power.",
        hp_die      = 3,
        prime_stats = { "wis", "cha" },
        requires    = { wis = 12, cha = 11 },
    },
}
