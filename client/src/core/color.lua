-- Raw color palette for Irreal.
-- Every entry describes what a color physically looks like — no element
-- semantics here.  Use src/core/elt_color.lua to map colors to UI elements.
--
-- Usage (direct, rarely needed outside elt_color):
--   local COLOR = require("src.core.color")
--   love.graphics.setColor(COLOR.GOLD)

local COLOR = {

    -- ── Dark backgrounds ──────────────────────────────────────────────────────
    VOID          = {0.04, 0.04, 0.08},   -- deep blue-black
    SHADOW        = {0.07, 0.06, 0.04},   -- dark earthy brown
    DUSK          = {0.18, 0.15, 0.08},   -- warm dark brown

    -- ── Golds ─────────────────────────────────────────────────────────────────
    GOLD          = {0.95, 0.80, 0.25},   -- bright gold
    GOLD_PALE     = {1.00, 0.92, 0.55},   -- pale / washed gold
    GOLD_MID      = {0.75, 0.65, 0.25},   -- medium gold
    GOLD_WARM     = {0.75, 0.65, 0.30},   -- warm-toned gold
    GOLD_TARNISH  = {0.55, 0.48, 0.22},   -- tarnished gold

    -- ── Earth & stone ─────────────────────────────────────────────────────────
    EARTH         = {0.35, 0.30, 0.18},   -- dark earth
    LOAM          = {0.30, 0.27, 0.18},   -- deep rich earth
    STONE         = {0.60, 0.55, 0.45},   -- pale stone
    FLINT         = {0.50, 0.47, 0.38},   -- dark flint-grey

    -- ── Warm whites & tans ────────────────────────────────────────────────────
    LINEN         = {0.88, 0.88, 0.82},   -- warm off-white linen
    PARCHMENT     = {0.80, 0.75, 0.60},   -- aged parchment
    SAND          = {0.55, 0.50, 0.40},   -- warm sand
    UMBER         = {0.45, 0.43, 0.36},   -- raw umber
    BARK          = {0.45, 0.42, 0.32},   -- dark tree bark
    DUST          = {0.32, 0.30, 0.25},   -- fine dust
    ASH           = {0.28, 0.26, 0.22},   -- pale ash

    -- ── Accents ───────────────────────────────────────────────────────────────
    RUST          = {0.55, 0.30, 0.28},   -- dim rust-red
}

--- Returns a new color table with the given alpha applied.
-- Example: love.graphics.setColor(COLOR.withAlpha(COLOR.RUST, 0.5))
function COLOR.withAlpha(color, alpha)
    return {color[1], color[2], color[3], alpha}
end

return COLOR
