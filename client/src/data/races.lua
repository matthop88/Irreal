-- Race definitions.
-- 'stat_bonus' values are added to the base rolled stats.
-- Positive values are racial strengths; negative values are weaknesses.

return {
    human = {
        id         = "human",
        label      = "Human",
        desc       = "Slow and stupid, but versatile and adaptable.",
        stat_bonus = { str=0, con=0, iq=-2, agi=-3, cha=-1, wis=-1 },
    },
    elf = {
        id         = "elf",
        label      = "Elf",
        desc       = "Swift and perceptive. Graceful but fragile.",
        stat_bonus = { str=-2, con=-1, iq=2, agi=1, cha=0, wis=0 },
    },
    dwarf = {
        id         = "dwarf",
        label      = "Dwarf",
        desc       = "Hardy and wise. Resilient but surly.",
        stat_bonus = { str=0, con=1, iq=-2, agi=-1, cha=-3, wis=1 },
    },
    hobbit = {
        id         = "hobbit",
        label      = "Hobbit",
        desc       = "Nimble and charming. Hearty but slight.",
        stat_bonus = { str=-2, con=2, iq=0, agi=2, cha=3, wis=1 },
    },
}
