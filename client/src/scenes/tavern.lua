local ELT        = require("src.core.elt_color")
local GS         = require("src.core.gamestate")
local Adventurer = require("src.entities.adventurer")
local CLASSES    = require("src.data.classes")
local RACES      = require("src.data.races")

local Tavern = {}

-- ── Ordered lists for display ─────────────────────────────────────────────────
local ALL_RACES = { "human", "elf", "dwarf", "hobbit" }

-- ── Layout constants ──────────────────────────────────────────────────────────
local MAIN_LEFT    = 80
local MAIN_WIDTH   = 820
local PARTY_LEFT   = 940
local PARTY_WIDTH  = 300
local CONTENT_TOP  = 130
local ROW_H        = 62
local ROSTER_VISIBLE = 8    -- max rows shown at once in the roster / party lists
local SCROLLBAR_X  = MAIN_LEFT + MAIN_WIDTH + 8   -- sits in the gap before the party panel
local SCROLLBAR_W  = 8
local function maxNameLen()
    local iq = pendingStats and pendingStats.iq or 10
    return math.max(4, iq * 3 - 6)
end
local STATS_COL_W  = 230   -- width of each stat column in create screen
local CLASS_X      = MAIN_LEFT + 490   -- x-start of the class eligibility panel
local CLASS_RECT_X = CLASS_X - 6       -- left edge of the selection highlight rect
local CLASS_RECT_W = PARTY_LEFT - CLASS_RECT_X - 10  -- fills up to the party panel
local CLASS_ROW_H  = 120   -- vertical step between class rows (room for wrapped desc)
local CLASS_RECT_H = 112   -- height of the selection rect (accommodates two desc lines)

-- ── Costs ─────────────────────────────────────────────────────────────────────
local COST_CREATE = 10
local COST_REROLL = 5
local COST_HIRE   = 10

-- ── Menu entries ──────────────────────────────────────────────────────────────
local MENU_ITEMS = {
    { key = "c", label = "Create Adventurer", desc = "Roll a new warrior for your cause.  Costs " .. COST_CREATE .. " GP." },
    { key = "r", label = "Roster",            desc = "View adventurers waiting to join."  },
    { key = "p", label = "Party",             desc = "Review your current party."         },
    { key = "l", label = "Leave",             desc = "Return to the village."             },
}

-- ── Internal state ────────────────────────────────────────────────────────────
local sub
-- Adventurer-creation pipeline (shared across CREATE_RACE / CREATE_STATS / CREATE_NAME).
local pendingName  = ""
local pendingRace  = nil
local pendingStats = nil
local pendingClass = nil
-- Transient status line (any sub-state may call postMessage).
local message      = nil
local messageTimer = 0

-- ── Stat roll animation ───────────────────────────────────────────────────────
-- Stats are displayed in this order in the 2-column grid (row by row).
local ANIM_ORDER   = { "str", "iq", "wis", "con", "agi", "cha", "hp" }
-- Each stat stops spinning at this elapsed time (seconds).
local ANIM_STOPS   = {  0.6,  0.85, 1.1,  1.35, 1.6,  1.85, 2.2  }

local function startRollAnimation(state, stats)
    state.isRolling       = true
    state.statAnimations  = {}
    for i, key in ipairs(ANIM_ORDER) do
        state.statAnimations[key] = {
            displayVal = love.math.random(3, 18),
            finalVal   = stats[key],
            spinning   = true,
            stopAt     = ANIM_STOPS[i],
            elapsed    = 0,
            cycleTimer = 0,
        }
    end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Returns `text` truncated with "…" so it fits within `maxW` pixels using `font`.
local function truncateText(font, text, maxW)
    if font:getWidth(text) <= maxW then return text end
    local ellipsis = "..."
    local eW = font:getWidth(ellipsis)
    for i = #text, 1, -1 do
        local candidate = text:sub(1, i)
        if font:getWidth(candidate) + eW <= maxW then
            return candidate .. ellipsis
        end
    end
    return ellipsis
end

--- Maximum value a stat can reach through augmentation (highest it could roll).
-- Base roll max is 12; racial bonus is always applied on top.
local function statAugmentCap(statKey)
    local bonus = pendingRace and (RACES[pendingRace].stat_bonus[statKey] or 0) or 0
    return 12 + bonus
end

local function postMessage(text)
    message      = text
    messageTimer = 2.5
end

--- Returns true only when every stat required by the given class has finished animating.
local function classStatsSettled(classId, statsState)
    local class = CLASSES[classId]
    local anims = statsState.statAnimations or {}
    for stat in pairs(class.requires or {}) do
        local anim = anims[stat]
        if anim and anim.spinning then return false end
    end
    return true
end

-- Thresholds below which a stat value is considered poor (shown in red).
-- STR/IQ/CON have a lower bar (Fighter-class stats); AGI/WIS/CHA a higher one.
local STAT_LOW_THRESHOLD = {
    str = 8, iq = 8, con = 8,
    agi = 9, wis = 9, cha = 9,
    hp  = 2,
}

local function statColor(key, value)
    if value >= 15 then return ELT.STAT_HIGH end
    local threshold = STAT_LOW_THRESHOLD[key]
    if threshold and value < threshold then return ELT.STAT_LOW end
    return ELT.STAT_NORMAL
end

-- Draws a minimal track-and-thumb scrollbar.
-- `total` = total number of items, `visible` = items shown, `first` = 1-based index of top item.
local function drawScrollbar(total, visible, first)
    if total <= visible then return end
    local trackH = visible * ROW_H
    love.graphics.setColor(ELT.SELECT_BG)
    love.graphics.rectangle("fill", SCROLLBAR_X, CONTENT_TOP, SCROLLBAR_W, trackH, SCROLLBAR_W / 2)
    local thumbH   = math.max(20, trackH * visible / total)
    local maxFirst = total - visible
    local thumbY   = CONTENT_TOP + (first - 1) / maxFirst * (trackH - thumbH)
    love.graphics.setColor(ELT.TEXT_FOOTER)
    love.graphics.rectangle("fill", SCROLLBAR_X, thumbY, SCROLLBAR_W, thumbH, SCROLLBAR_W / 2)
end

--- Adjusts scroll so selection stays within the visible window (`SUB.ROSTER`).
local function clampRosterScroll(rosterState)
    local total = #GS.roster
    if rosterState.rosterSel < rosterState.rosterScroll then
        rosterState.rosterScroll = rosterState.rosterSel
    elseif rosterState.rosterSel > rosterState.rosterScroll + ROSTER_VISIBLE - 1 then
        rosterState.rosterScroll = rosterState.rosterSel - ROSTER_VISIBLE + 1
    end
    rosterState.rosterScroll = math.max(1,
        math.min(rosterState.rosterScroll, math.max(1, total - ROSTER_VISIBLE + 1)))
end

-- ── Draw helpers ──────────────────────────────────────────────────────────────

local function drawHeader(title, subtitle)
    local W = love.graphics.getWidth()
    love.graphics.setFont(Fonts.large)
    love.graphics.setColor(ELT.HEADING)
    love.graphics.printf(title, MAIN_LEFT, 36, MAIN_WIDTH, "center")

    if subtitle then
        love.graphics.setFont(Fonts.small)
        love.graphics.setColor(ELT.TEXT_SUBTITLE)
        love.graphics.printf(subtitle, MAIN_LEFT, 90, MAIN_WIDTH, "center")
    end

    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", MAIN_LEFT, 116, MAIN_WIDTH, 1)
end

local function drawPartyPanel()
    local capacity = GS:partyCapacity()

    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(ELT.HEADING)
    love.graphics.printf("Party", PARTY_LEFT, 36, PARTY_WIDTH, "center")

    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", PARTY_LEFT, 72, PARTY_WIDTH, 1)

    -- Gold display.
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.RESOURCE_GOLD)
    love.graphics.printf(GS.gold .. " GP", PARTY_LEFT, 80, PARTY_WIDTH, "center")

    love.graphics.setFont(Fonts.small)
    if #GS.party == 0 then
        love.graphics.setColor(ELT.TEXT_FOOTER)
        love.graphics.printf("(empty)", PARTY_LEFT, 104, PARTY_WIDTH, "center")
    else
        for i, a in ipairs(GS.party) do
            local y = 100 + (i - 1) * 72
            love.graphics.setColor(ELT.TEXT_BODY)
            love.graphics.print(a.name, PARTY_LEFT + 8, y)
            love.graphics.setColor(ELT.TEXT_DESC)
            love.graphics.print(a:raceClassLabel() .. "  Lv." .. a.level, PARTY_LEFT + 8, y + 24)
            local sc = (a.status == "ok") and ELT.STATUS_OK or ELT.STATUS_DEAD
            love.graphics.setColor(sc)
            love.graphics.print(a:statusLabel(), PARTY_LEFT + 8, y + 46)
        end
    end

    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.TEXT_FOOTER)
    love.graphics.printf(#GS.party .. " / " .. capacity .. " members",
        PARTY_LEFT, love.graphics.getHeight() - 50, PARTY_WIDTH, "center")
end

local function drawFooter(hint)
    love.graphics.setFont(Fonts.small)
    if message then
        love.graphics.setColor(ELT.STAT_LOW)
        love.graphics.printf(message, MAIN_LEFT, love.graphics.getHeight() - 36, MAIN_WIDTH, "center")
    else
        love.graphics.setColor(ELT.TEXT_FOOTER)
        love.graphics.printf(hint, MAIN_LEFT, love.graphics.getHeight() - 36, MAIN_WIDTH, "center")
    end
end

-- ── Sub-state draw functions ──────────────────────────────────────────────────

local function drawMenu(self)
    local tavernLevel = GS.buildings.tavern
    drawHeader("The Tavern",
        "Level " .. tavernLevel .. "  —  A smoky inn where adventurers gather.")

    for i, item in ipairs(MENU_ITEMS) do
        local y   = CONTENT_TOP + (i - 1) * ROW_H
        local sel = (i == self.menuSel)

        if sel then
            love.graphics.setColor(ELT.SELECT_BG)
            love.graphics.rectangle("fill", MAIN_LEFT, y - 4, MAIN_WIDTH, ROW_H - 8, 5)
            love.graphics.setColor(ELT.SELECT_BORDER)
            love.graphics.rectangle("line", MAIN_LEFT, y - 4, MAIN_WIDTH, ROW_H - 8, 5)
        end

        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(sel and ELT.KEY_ACTIVE or ELT.KEY_INACTIVE)
        love.graphics.print("[" .. item.key:upper() .. "]", MAIN_LEFT + 12, y + 6)

        love.graphics.setColor(sel and ELT.HEADING_BRIGHT or ELT.TEXT_BODY)
        love.graphics.print(item.label, MAIN_LEFT + 60, y + 6)

        love.graphics.setFont(Fonts.small)
        love.graphics.setColor(ELT.TEXT_DESC)
        love.graphics.print(item.desc, MAIN_LEFT + 60, y + 30)
    end

    drawPartyPanel()
    drawFooter("UP / DOWN  navigate     ENTER  select     ESC  return to village")
end

local function drawCreateName(self)
    local raceLabel  = pendingRace  and RACES[pendingRace].label  or "?"
    local classLabel = pendingClass and CLASSES[pendingClass].label or "Adventurer"
    drawHeader("Name your " .. raceLabel .. " " .. classLabel,
        raceLabel .. "  ·  " .. classLabel)

    local labelY = CONTENT_TOP + 40
    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(ELT.TEXT_SUBTITLE)
    love.graphics.print("Enter name:", MAIN_LEFT + 60, labelY)

    -- Input box.
    local boxX = MAIN_LEFT + 60
    local boxY = labelY + 44
    local boxW = 420
    local boxH = 44
    love.graphics.setColor(ELT.SELECT_BG)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 4)
    love.graphics.setColor(ELT.SELECT_BORDER)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 4)

    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(ELT.INPUT_TEXT)
    love.graphics.print(pendingName, boxX + 10, boxY + 10)

    -- Blinking cursor.
    if self.showCursor then
        local cx = boxX + 10 + Fonts.medium:getWidth(pendingName)
        love.graphics.setColor(ELT.INPUT_CURSOR)
        love.graphics.rectangle("fill", cx, boxY + 8, 2, boxH - 16)
    end

    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.TEXT_FOOTER)
    love.graphics.print("Max " .. maxNameLen() .. " characters.", boxX, boxY + boxH + 12)

    drawFooter("ENTER  confirm     ESC  back to stats")
end

local function drawCreateRace(self)
    drawHeader("Choose Your Race",
        "Browse freely.  Costs " .. COST_CREATE .. " GP to roll stats once you choose.")

    local STAT_ORDER = { "str", "iq", "wis", "con", "agi", "cha" }
    local raceRowH   = 112

    for i, raceId in ipairs(ALL_RACES) do
        local race = RACES[raceId]
        local sel  = (i == self.raceListSel)
        local y    = CONTENT_TOP + (i - 1) * raceRowH

        if sel then
            love.graphics.setColor(ELT.SELECT_BG)
            love.graphics.rectangle("fill", MAIN_LEFT, y - 4, MAIN_WIDTH, raceRowH - 8, 5)
            love.graphics.setColor(ELT.SELECT_BORDER)
            love.graphics.rectangle("line", MAIN_LEFT, y - 4, MAIN_WIDTH, raceRowH - 8, 5)
        end

        -- Race name.
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(sel and ELT.HEADING_BRIGHT or ELT.HEADING)
        love.graphics.print(race.label, MAIN_LEFT + 16, y + 6)

        -- Description.
        love.graphics.setFont(Fonts.small)
        love.graphics.setColor(ELT.TEXT_DESC)
        love.graphics.print(race.desc, MAIN_LEFT + 16, y + 34)

        -- Stat modifiers.
        local modX = MAIN_LEFT + 16
        for _, key in ipairs(STAT_ORDER) do
            local val = race.stat_bonus[key]
            if val and val ~= 0 then
                local sign = val > 0 and "+" or ""
                love.graphics.setColor(val > 0 and ELT.STATUS_OK or ELT.STATUS_DEAD)
                love.graphics.print(
                    Adventurer.statLabel(key) .. " " .. sign .. val,
                    modX, y + 58)
                modX = modX + 110
            end
        end
    end

    drawPartyPanel()
    drawFooter("UP / DOWN  navigate     ENTER  select race (" .. COST_CREATE .. " GP)     ESC  cancel")
end

local function drawCreateStats(self)
    local raceLabel = pendingRace and RACES[pendingRace].label or "?"
    drawHeader("New " .. raceLabel, "Reroll until a suitable class appears, then select it.")

    local statKeys   = Adventurer.statKeys()
    local eligibility = Adventurer.classEligibility(pendingStats)
    local cols   = 2
    local startY = CONTENT_TOP + 10

    -- ── Left panel: stats ────────────────────────────────────────────────────
    for idx, key in ipairs(statKeys) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local x   = MAIN_LEFT + 30 + col * STATS_COL_W
        local y   = startY + row * 58

        local anim       = self.statAnimations[key]
        local displayVal = (anim and anim.spinning) and anim.displayVal or pendingStats[key]
        local spinning   = anim and anim.spinning

        -- Selection highlight when augment mode is active.
        if self.augmentMode and idx == self.statSel and not self.isRolling then
            love.graphics.setColor(ELT.SELECT_BG)
            love.graphics.rectangle("fill", x - 4, y - 4, STATS_COL_W - 10, 32, 4)
            love.graphics.setColor(ELT.SELECT_BORDER)
            love.graphics.rectangle("line", x - 4, y - 4, STATS_COL_W - 10, 32, 4)
        end

        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(ELT.TEXT_SUBTITLE)
        love.graphics.print(Adventurer.statLabel(key), x, y)
        love.graphics.setColor(spinning and ELT.TEXT_FOOTER or statColor(key, pendingStats[key]))
        love.graphics.print(tostring(displayVal), x + 70, y)

        -- MAX badge when the stat is at its augment ceiling.
        if not spinning and pendingStats[key] >= statAugmentCap(key) then
            love.graphics.setFont(Fonts.small)
            love.graphics.setColor(ELT.TEXT_FOOTER)
            love.graphics.print("MAX", x + 110, y + 4)
        end
    end

    -- HP below the stat grid.
    local hpY   = startY + 3 * 58 + 8
    local hpAnim = self.statAnimations["hp"]
    local hpDisplay = (hpAnim and hpAnim.spinning) and hpAnim.displayVal or (pendingStats and pendingStats.hp)
    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", MAIN_LEFT + 30, hpY - 4, CLASS_X - MAIN_LEFT - 60, 1)

    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(ELT.TEXT_SUBTITLE)
    love.graphics.print("HP", MAIN_LEFT + 30, hpY + 4)
    love.graphics.setColor((hpAnim and hpAnim.spinning) and ELT.TEXT_FOOTER or statColor("hp", pendingStats.hp))
    love.graphics.print(tostring(hpDisplay or "?"), MAIN_LEFT + 100, hpY + 4)

    -- Reroll / augment cost notes.
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.RESOURCE_GOLD)
    love.graphics.print("Reroll: " .. COST_REROLL .. " GP  |  Augment: " .. self.augmentCost .. " GP  (have " .. GS.gold .. " GP)",
        MAIN_LEFT + 30, hpY + 44)

    -- ── Vertical divider ─────────────────────────────────────────────────────
    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", CLASS_X - 14, CONTENT_TOP, 1, 360)

    -- ── Right panel: class eligibility ───────────────────────────────────────
    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(ELT.TEXT_SUBTITLE)
    love.graphics.print("Class", CLASS_X, startY)

    for i, classId in ipairs(Adventurer.CLASSES_ORDER) do
        local class    = CLASSES[classId]
        local eligible = eligibility[classId] and classStatsSettled(classId, self)
        local sel      = (i == self.classListSel)
        local y        = startY + 48 + (i - 1) * CLASS_ROW_H

        -- Selection highlight (only shown when eligible).
        if sel and eligible then
            love.graphics.setColor(ELT.SELECT_BG)
            love.graphics.rectangle("fill", CLASS_RECT_X, y - 4, CLASS_RECT_W, CLASS_RECT_H, 4)
            love.graphics.setColor(ELT.SELECT_BORDER)
            love.graphics.rectangle("line", CLASS_RECT_X, y - 4, CLASS_RECT_W, CLASS_RECT_H, 4)
        elseif sel then
            love.graphics.setColor(ELT.SELECT_BG)
            love.graphics.rectangle("fill", CLASS_RECT_X, y - 4, CLASS_RECT_W, CLASS_RECT_H, 4)
        end

        -- Class name: gold if eligible, gray if not.
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(eligible and ELT.HEADING or ELT.TEXT_FOOTER)
        love.graphics.print(class.label, CLASS_X, y)

        -- Requirements: each stat shown green if met, red if not.
        love.graphics.setFont(Fonts.small)
        local reqX = CLASS_X
        for stat, minVal in pairs(class.requires) do
            local anim    = self.statAnimations[stat]
            local settled = not (anim and anim.spinning)
            local met     = settled and (pendingStats[stat] or 0) >= minVal
            love.graphics.setColor(met and ELT.STATUS_OK or ELT.STATUS_DEAD)
            love.graphics.print(Adventurer.statLabel(stat) .. " " .. minVal, reqX, y + 28)
            reqX = reqX + 100
        end

        -- Description.
        love.graphics.setColor(eligible and ELT.TEXT_DESC or ELT.TEXT_FOOTER)
        love.graphics.printf(class.desc, CLASS_X, y + 52, CLASS_RECT_W - (CLASS_X - CLASS_RECT_X))
    end

    local selClass   = Adventurer.CLASSES_ORDER[self.classListSel]
    local canConfirm = eligibility[selClass] and classStatsSettled(selClass, self)
    if self.isRolling then
        drawFooter("Rolling...")
    elseif self.augmentMode then
        local sk  = Adventurer.statKeys()[self.statSel]
        local cap = statAugmentCap(sk)
        local augHint = (pendingStats[sk] >= cap)
            and "ENTER augment " .. Adventurer.statLabel(sk) .. " (MAX)"
            or  "ENTER augment " .. Adventurer.statLabel(sk) .. " (" .. self.augmentCost .. " GP)"
        drawFooter("ARROWS navigate stats  |  " .. augHint .. "  |  ESC cancel")
    else
        drawFooter(
            "[R] Reroll (" .. COST_REROLL .. " GP)  |  [A] augment stats  |  " ..
            "UP/DOWN navigate classes  |  " ..
            (canConfirm and "ENTER select class" or "ENTER (select an eligible class)")
        )
    end
end

local function drawRoster(self)
    drawHeader("Tavern Roster",
        #GS.roster == 0 and "No adventurers are waiting." or
        #GS.roster .. " adventurer(s) available.")

    if #GS.roster == 0 then
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(ELT.TEXT_FOOTER)
        love.graphics.printf("Visit 'Create Adventurer' to hire your first warrior.",
            MAIN_LEFT, CONTENT_TOP + 40, MAIN_WIDTH, "center")
    else
        local lastVisible = math.min(self.rosterScroll + ROSTER_VISIBLE - 1, #GS.roster)
        for i = self.rosterScroll, lastVisible do
            local a   = GS.roster[i]
            local y   = CONTENT_TOP + (i - self.rosterScroll) * ROW_H
            local sel = (i == self.rosterSel)

            if sel then
                love.graphics.setColor(ELT.SELECT_BG)
                love.graphics.rectangle("fill", MAIN_LEFT, y - 4, MAIN_WIDTH, ROW_H - 8, 5)
                love.graphics.setColor(ELT.SELECT_BORDER)
                love.graphics.rectangle("line", MAIN_LEFT, y - 4, MAIN_WIDTH, ROW_H - 8, 5)
            end

            love.graphics.setFont(Fonts.medium)
            love.graphics.setColor(sel and ELT.HEADING_BRIGHT or ELT.TEXT_BODY)
            love.graphics.print(a.name, MAIN_LEFT + 12, y + 4)

            love.graphics.setFont(Fonts.small)
            love.graphics.setColor(ELT.TEXT_DESC)
            love.graphics.print(a:raceClassLabel() .. "  ·  Lv." .. a.level ..
                "  ·  HP " .. a.hp.current .. "/" .. a.hp.max,
                MAIN_LEFT + 12, y + 30)

            local sc = (a.status == "ok") and ELT.STATUS_OK or ELT.STATUS_DEAD
            love.graphics.setColor(sc)
            love.graphics.print(a:statusLabel(), MAIN_LEFT + MAIN_WIDTH - 80, y + 14)
        end

        drawScrollbar(#GS.roster, ROSTER_VISIBLE, self.rosterScroll)
    end

    drawPartyPanel()

    local hint = GS:partyHasRoom()
        and "UP / DOWN  navigate     ENTER  hire  (" .. COST_HIRE .. " GP)     ESC  back"
        or  "UP / DOWN  navigate     (Party is full)     ESC  back"
    drawFooter(hint)
end

local function drawPartyStatsPanel(a)
    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(ELT.HEADING)
    local displayName = a and truncateText(Fonts.medium, a.name, PARTY_WIDTH - 16) or "—"
    love.graphics.printf(displayName, PARTY_LEFT, 36, PARTY_WIDTH, "center")

    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", PARTY_LEFT, 72, PARTY_WIDTH, 1)

    if not a then
        love.graphics.setFont(Fonts.small)
        love.graphics.setColor(ELT.TEXT_FOOTER)
        love.graphics.printf("(empty)", PARTY_LEFT, CONTENT_TOP + 20, PARTY_WIDTH, "center")
        return
    end

    -- Race · Class · Level
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.TEXT_SUBTITLE)
    love.graphics.printf(a:raceClassLabel() .. "  ·  Lv." .. a.level,
        PARTY_LEFT, 80, PARTY_WIDTH, "center")

    -- Status
    local sc = (a.status == "ok") and ELT.STATUS_OK or ELT.STATUS_DEAD
    love.graphics.setColor(sc)
    love.graphics.printf(a:statusLabel(), PARTY_LEFT, 102, PARTY_WIDTH, "center")

    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", PARTY_LEFT, 126, PARTY_WIDTH, 1)

    -- Stats: 2-column grid (STR/IQ | WIS/CON | AGI/CHA)
    local colW   = PARTY_WIDTH / 2
    local startY = 138
    for idx, key in ipairs(Adventurer.statKeys()) do
        local col = (idx - 1) % 2
        local row = math.floor((idx - 1) / 2)
        local x   = PARTY_LEFT + col * colW + 10
        local y   = startY + row * 32
        love.graphics.setFont(Fonts.small)
        love.graphics.setColor(ELT.TEXT_SUBTITLE)
        love.graphics.print(Adventurer.statLabel(key), x, y)
        love.graphics.setColor(statColor(key, a.stats[key]))
        love.graphics.print(tostring(a.stats[key]), x + 52, y)
    end

    -- HP below the stat grid
    local hpY = startY + 3 * 32 + 6
    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", PARTY_LEFT, hpY - 4, PARTY_WIDTH, 1)
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.TEXT_SUBTITLE)
    love.graphics.print("HP", PARTY_LEFT + 10, hpY + 4)
    love.graphics.setColor(statColor("hp", a.hp.current))
    love.graphics.print(a.hp.current .. " / " .. a.hp.max, PARTY_LEFT + 62, hpY + 4)

    -- Member count at bottom
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.TEXT_FOOTER)
    love.graphics.printf(#GS.party .. " / " .. GS:partyCapacity() .. " members",
        PARTY_LEFT, love.graphics.getHeight() - 50, PARTY_WIDTH, "center")
end

local function drawPartyView(self)
    drawHeader("Current Party",
        #GS.party == 0 and "Your party is empty." or
        #GS.party .. " / " .. GS:partyCapacity() .. " members.")

    if #GS.party == 0 then
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(ELT.TEXT_FOOTER)
        love.graphics.printf("Add adventurers from the Roster.",
            MAIN_LEFT, CONTENT_TOP + 40, MAIN_WIDTH, "center")
    else
        for i, a in ipairs(GS.party) do
            local y   = CONTENT_TOP + (i - 1) * ROW_H
            local sel = (i == self.partySel)

            if sel then
                love.graphics.setColor(ELT.SELECT_BG)
                love.graphics.rectangle("fill", MAIN_LEFT, y - 4, MAIN_WIDTH, ROW_H - 8, 5)
                love.graphics.setColor(ELT.SELECT_BORDER)
                love.graphics.rectangle("line", MAIN_LEFT, y - 4, MAIN_WIDTH, ROW_H - 8, 5)
            end

            love.graphics.setFont(Fonts.medium)
            love.graphics.setColor(sel and ELT.HEADING_BRIGHT or ELT.TEXT_BODY)
            love.graphics.print(a.name, MAIN_LEFT + 12, y + 4)

            love.graphics.setFont(Fonts.small)
            love.graphics.setColor(ELT.TEXT_DESC)
            love.graphics.print(a:raceClassLabel() .. "  ·  Lv." .. a.level ..
                "  ·  HP " .. a.hp.current .. "/" .. a.hp.max,
                MAIN_LEFT + 12, y + 30)

            local sc = (a.status == "ok") and ELT.STATUS_OK or ELT.STATUS_DEAD
            love.graphics.setColor(sc)
            love.graphics.print(a:statusLabel(), MAIN_LEFT + MAIN_WIDTH - 80, y + 14)
        end
    end

    drawPartyStatsPanel(GS.party[self.partySel])
    drawFooter("UP / DOWN  navigate     ENTER  dismiss to roster     ESC  back")
end

-- ── Sub-state handlers (K/V: name → { draw, update, keypressed, textinput? }) ─

local function noop() end

local SUB = {}

SUB.MENU = {
    menuSel = 1,
    draw       = drawMenu,
    update     = noop,
    keypressed = function(self, key)
        if key == "up" then
            self.menuSel = self.menuSel > 1 and self.menuSel - 1 or #MENU_ITEMS
        elseif key == "down" then
            self.menuSel = self.menuSel < #MENU_ITEMS and self.menuSel + 1 or 1
        elseif key == "escape" then
            StateMachine:switch("town")
        elseif key == "return" then
            local choice = MENU_ITEMS[self.menuSel].key
            if choice == "c" then
                pendingRace           = nil
                SUB.CREATE_RACE.raceListSel = 1
                sub                   = SUB.CREATE_RACE
            elseif choice == "r" then
                sub = SUB.ROSTER
                SUB.ROSTER.rosterSel    = 1
                SUB.ROSTER.rosterScroll = 1
            elseif choice == "p" then
                sub = SUB.PARTY
                SUB.PARTY.partySel = 1
            elseif choice == "l" then
                StateMachine:switch("town")
            end
        else
            for i, item in ipairs(MENU_ITEMS) do
                if key == item.key then self.menuSel = i; break end
            end
        end
    end,
}

SUB.CREATE_RACE = {
    raceListSel = 1,
    draw       = drawCreateRace,
    update     = noop,
    keypressed = function(self, key)
        if key == "up" then
            self.raceListSel = self.raceListSel > 1 and self.raceListSel - 1 or #ALL_RACES
        elseif key == "down" then
            self.raceListSel = self.raceListSel < #ALL_RACES and self.raceListSel + 1 or 1
        elseif key == "return" then
            if GS.gold >= COST_CREATE then
                GS.gold        = GS.gold - COST_CREATE
                pendingRace    = ALL_RACES[self.raceListSel]
                pendingName    = ""
                pendingClass   = nil
                pendingStats   = Adventurer.rollStats(pendingRace)
                startRollAnimation(SUB.CREATE_STATS, pendingStats)
                SUB.CREATE_STATS.classListSel = 1
                SUB.CREATE_STATS.statSel      = 1
                SUB.CREATE_STATS.augmentCost  = 10
                SUB.CREATE_STATS.augmentMode  = false
                sub                           = SUB.CREATE_STATS
            else
                postMessage("Not enough gold!  Creating an adventurer costs " .. COST_CREATE .. " GP.")
            end
        elseif key == "escape" then
            sub = SUB.MENU
        end
    end,
}

SUB.CREATE_STATS = {
    statSel       = 1,
    classListSel  = 1,
    augmentMode   = false,
    augmentCost   = 10,
    isRolling     = false,
    statAnimations = {},
    draw = drawCreateStats,
    update = function(self, dt)
        if not self.isRolling then return end
        local allDone = true
        for _, animKey in ipairs(ANIM_ORDER) do
            local anim = self.statAnimations[animKey]
            if anim and anim.spinning then
                allDone         = false
                anim.elapsed    = anim.elapsed + dt
                anim.cycleTimer = anim.cycleTimer + dt
                local timeLeft  = math.max(0, anim.stopAt - anim.elapsed)
                local cycleRate = timeLeft > 0.4 and 0.04 or (timeLeft > 0.15 and 0.09 or 0.18)
                if anim.cycleTimer >= cycleRate then
                    anim.cycleTimer = 0
                    anim.displayVal = love.math.random(3, 18)
                end
                if anim.elapsed >= anim.stopAt then
                    anim.spinning   = false
                    anim.displayVal = anim.finalVal
                end
            end
        end
        if allDone then self.isRolling = false end
    end,
    keypressed = function(self, key)
        if self.isRolling then return end

        if self.augmentMode then
            local row = math.floor((self.statSel - 1) / 2)
            local col = (self.statSel - 1) % 2
            if key == "up" then
                row = (row - 1 + 3) % 3
                self.statSel = row * 2 + col + 1
            elseif key == "down" then
                row = (row + 1) % 3
                self.statSel = row * 2 + col + 1
            elseif key == "left" then
                col = (col - 1 + 2) % 2
                self.statSel = row * 2 + col + 1
            elseif key == "right" then
                col = (col + 1) % 2
                self.statSel = row * 2 + col + 1
            elseif key == "return" then
                local sk  = Adventurer.statKeys()[self.statSel]
                local cap = statAugmentCap(sk)
                if pendingStats[sk] >= cap then
                    postMessage(Adventurer.statLabel(sk) .. " is already at its maximum (" .. cap .. ").")
                elseif GS.gold < self.augmentCost then
                    postMessage("Not enough gold!  Augmenting costs " .. self.augmentCost .. " GP.")
                else
                    GS.gold          = GS.gold - self.augmentCost
                    local oldVal     = pendingStats[sk]
                    pendingStats[sk] = oldVal + 1
                    self.augmentCost = self.augmentCost * 2
                    if sk == "con" then
                        local oldBonus = math.floor((oldVal - 7) / 3)
                        local newBonus = math.floor((pendingStats.con - 7) / 3)
                        pendingStats.hp = math.max(1, pendingStats.hp - oldBonus + newBonus)
                    end
                    self.augmentMode = false
                end
            elseif key == "escape" then
                self.augmentMode = false
            end
        else
            if key == "r" then
                if GS.gold >= COST_REROLL then
                    GS.gold        = GS.gold - COST_REROLL
                    pendingStats   = Adventurer.rollStats(pendingRace)
                    pendingClass   = nil
                    startRollAnimation(self, pendingStats)
                    self.statSel     = 1
                    self.augmentCost = 10
                    self.augmentMode  = false
                else
                    postMessage("Not enough gold to reroll!  (Need " .. COST_REROLL .. " GP)")
                end
            elseif key == "a" then
                self.augmentMode = true
            elseif key == "up" then
                self.classListSel = self.classListSel > 1 and self.classListSel - 1 or #Adventurer.CLASSES_ORDER
            elseif key == "down" then
                self.classListSel = self.classListSel < #Adventurer.CLASSES_ORDER and self.classListSel + 1 or 1
            elseif key == "return" then
                local classId     = Adventurer.CLASSES_ORDER[self.classListSel]
                local eligibility = Adventurer.classEligibility(pendingStats)
                if eligibility[classId] and classStatsSettled(classId, self) then
                    pendingClass = classId
                    pendingName  = ""
                    sub          = SUB.CREATE_NAME
                else
                    postMessage("This class requires higher stats.  Reroll or choose an eligible class.")
                end
            elseif key == "escape" then
                sub = SUB.MENU
            end
        end
    end,
}

SUB.CREATE_NAME = {
    blinkTimer  = 0,
    showCursor  = true,
    draw = drawCreateName,
    update = function(self, dt)
        self.blinkTimer = self.blinkTimer + dt
        if self.blinkTimer >= 0.5 then
            self.showCursor = not self.showCursor
            self.blinkTimer = 0
        end
    end,
    keypressed = function(self, key)
        if key == "backspace" then
            pendingName = pendingName:sub(1, -2)
        elseif key == "return" and #pendingName > 0 then
            local adv = Adventurer.new(pendingName, pendingRace, pendingClass, pendingStats)
            table.insert(GS.roster, adv)
            sub                     = SUB.ROSTER
            SUB.ROSTER.rosterSel    = #GS.roster
            clampRosterScroll(SUB.ROSTER)
        elseif key == "escape" then
            sub = SUB.CREATE_STATS
        end
    end,
    textinput = function(_, text)
        if #pendingName < maxNameLen() then
            pendingName = pendingName .. text
        end
    end,
}

SUB.ROSTER = {
    rosterSel    = 1,
    rosterScroll = 1,
    draw       = drawRoster,
    update     = noop,
    keypressed = function(self, key)
        if key == "up" then
            self.rosterSel = self.rosterSel > 1 and self.rosterSel - 1 or math.max(1, #GS.roster)
            clampRosterScroll(self)
        elseif key == "down" then
            self.rosterSel = self.rosterSel < #GS.roster and self.rosterSel + 1 or 1
            clampRosterScroll(self)
        elseif key == "return" and #GS.roster > 0 then
            if GS.gold >= COST_HIRE then
                GS.gold = GS.gold - COST_HIRE
                GS:addToParty(GS.roster[self.rosterSel])
                self.rosterSel = math.min(self.rosterSel, math.max(1, #GS.roster))
                clampRosterScroll(self)
            else
                postMessage("Not enough gold to hire!  (Need " .. COST_HIRE .. " GP)")
            end
        elseif key == "escape" then
            sub = SUB.MENU
        end
    end,
}

SUB.PARTY = {
    partySel = 1,
    draw       = drawPartyView,
    update     = noop,
    keypressed = function(self, key)
        if key == "up" then
            self.partySel = self.partySel > 1 and self.partySel - 1 or math.max(1, #GS.party)
        elseif key == "down" then
            self.partySel = self.partySel < #GS.party and self.partySel + 1 or 1
        elseif key == "return" and #GS.party > 0 then
            GS:dismissFromParty(GS.party[self.partySel])
            self.partySel = math.min(self.partySel, math.max(1, #GS.party))
        elseif key == "escape" then
            sub = SUB.MENU
        end
    end,
}

sub = SUB.MENU

-- ── Scene interface ───────────────────────────────────────────────────────────

function Tavern:enter()
    sub = SUB.MENU

    SUB.MENU.menuSel            = 1
    SUB.CREATE_RACE.raceListSel = 1
    SUB.CREATE_STATS.statSel       = 1
    SUB.CREATE_STATS.classListSel  = 1
    SUB.CREATE_STATS.augmentMode   = false
    SUB.CREATE_STATS.augmentCost   = 10
    SUB.CREATE_STATS.isRolling     = false
    SUB.CREATE_STATS.statAnimations = {}
    SUB.CREATE_NAME.blinkTimer    = 0
    SUB.CREATE_NAME.showCursor    = true
    SUB.ROSTER.rosterSel          = 1
    SUB.ROSTER.rosterScroll       = 1
    SUB.PARTY.partySel            = 1

    pendingName  = ""
    pendingRace  = nil
    pendingStats = nil
    pendingClass = nil
    message      = nil
    messageTimer = 0
end

function Tavern:update(dt)
    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then
            message      = nil
            messageTimer = 0
        end
    end
    sub:update(dt)
end

function Tavern:draw()
    love.graphics.clear(ELT.BG_TOWN)
    sub:draw()
end

function Tavern:textinput(text)
    if sub.textinput then
        sub:textinput(text)
    end
end

function Tavern:keypressed(key)
    sub:keypressed(key)
end

function Tavern:leave()
    -- Nothing to clean up yet.
end

return Tavern
