-- Race definitions.
-- 'stat_bonus' values are added to the base rolled stats.
-- Positive values are racial strengths; negative values are weaknesses.

return {
    human = {
        id         = "human",
        label      = "Human",
        desc       = "Versatile and adaptable. No natural extremes.",
        stat_bonus = { str=2, wis=1, agi=-2, iq=-1 },
    },
    elf = {
        id         = "elf",
        label      = "Elf",
        desc       = "Swift and charming. Graceful but fragile.",
        stat_bonus = { agi=2, cha=1, str=-2, con=-1 },
    },
    dwarf = {
        id         = "dwarf",
        label      = "Dwarf",
        desc       = "Hardy and powerful. Resilient but blunt.",
        stat_bonus = { con=2, str=1, cha=-2, wis=-1 },
    },
    hobbit = {
        id         = "hobbit",
        label      = "Hobbit",
        desc       = "Small but perceptive. Wise but weak.",
        stat_bonus = { agi=1, wis=2, str=-1, iq=-2 },
    },
}
