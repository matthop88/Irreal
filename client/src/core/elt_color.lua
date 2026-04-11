-- Element color mappings for Irreal.
-- Maps UI/game elements to entries in the raw color palette.
-- Scenes should require this module, not color.lua directly.
--
-- Usage:
--   local COLOR = require("src.core.elt_color")
--   love.graphics.setColor(COLOR.HEADING)
--   love.graphics.setColor(COLOR.withAlpha(COLOR.TEXT_LORE, alpha))

local BASE = require("src.core.color")

local ELT_COLOR = {

    -- ── Backgrounds ───────────────────────────────────────────────────────────
    BG_TITLE        = BASE.VOID,
    BG_TOWN         = BASE.SHADOW,

    -- ── Headings & titles ─────────────────────────────────────────────────────
    HEADING         = BASE.GOLD,
    HEADING_BRIGHT  = BASE.GOLD_PALE,        -- selected state

    -- ── Resources ─────────────────────────────────────────────────────────────
    RESOURCE_GOLD   = BASE.GOLD_MID,
    RESOURCE_STONE  = BASE.STONE,

    -- ── Selection highlight ────────────────────────────────────────────────────
    SELECT_BG       = BASE.DUSK,
    SELECT_BORDER   = BASE.GOLD_TARNISH,

    -- ── Keyboard shortcut badges ──────────────────────────────────────────────
    KEY_ACTIVE      = BASE.GOLD_WARM,
    KEY_INACTIVE    = BASE.BARK,

    -- ── Rules & dividers ──────────────────────────────────────────────────────
    RULE            = BASE.EARTH,
    RULE_FAINT      = BASE.LOAM,             -- intended for use with withAlpha()

    -- ── Text hierarchy ────────────────────────────────────────────────────────
    TEXT_SUBTITLE   = BASE.SAND,
    TEXT_BODY       = BASE.PARCHMENT,
    TEXT_LORE       = BASE.UMBER,            -- intended for use with withAlpha()
    TEXT_DESC       = BASE.FLINT,
    TEXT_PROMPT     = BASE.LINEN,
    TEXT_FOOTER     = BASE.DUST,
    TEXT_HINT       = BASE.ASH,

    -- ── Thematic ─────────────────────────────────────────────────────────────
    OMINOUS         = BASE.RUST,             -- the chasm lore line

    -- ── Stat values ───────────────────────────────────────────────────────────
    STAT_HIGH       = BASE.GOLD,             -- stat ≥ 15 (exceptional)
    STAT_NORMAL     = BASE.PARCHMENT,        -- stat 9–14 (average)
    STAT_LOW        = BASE.RUST,             -- stat ≤ 8 (poor)

    -- ── Character status ──────────────────────────────────────────────────────
    STATUS_OK       = BASE.SAGE,             -- alive and well
    STATUS_DEAD     = BASE.RUST,             -- dead, ash, or lost

    -- ── Text input ────────────────────────────────────────────────────────────
    INPUT_TEXT      = BASE.LINEN,            -- typed text
    INPUT_CURSOR    = BASE.GOLD,             -- blinking cursor
    INPUT_INACTIVE  = BASE.FLINT,            -- placeholder / inactive field
}

-- Proxy withAlpha so callers only need to require elt_color.
ELT_COLOR.withAlpha = BASE.withAlpha

return ELT_COLOR
