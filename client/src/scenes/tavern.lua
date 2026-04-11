local ELT        = require("src.core.elt_color")
local GS         = require("src.core.gamestate")
local Adventurer = require("src.entities.adventurer")
local CLASSES    = require("src.data.classes")

local Tavern = {}

-- ── Sub-state identifiers ─────────────────────────────────────────────────────
local SUB = {
    MENU         = "menu",
    CREATE_NAME  = "create_name",
    CREATE_STATS = "create_stats",
    ROSTER       = "roster",
    PARTY        = "party",
}

-- ── Layout constants ──────────────────────────────────────────────────────────
local MAIN_LEFT    = 80
local MAIN_WIDTH   = 820
local PARTY_LEFT   = 940
local PARTY_WIDTH  = 300
local CONTENT_TOP  = 130
local ROW_H        = 62
local function maxNameLen()
    local iq = pendingStats and pendingStats.iq or 10
    return math.max(4, iq * 3 - 6)
end
local STATS_COL_W  = 230   -- width of each stat column in create screen
local CLASS_X      = MAIN_LEFT + 490   -- x-start of the class eligibility panel

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
local sub          = SUB.MENU
local menuSel      = 1
local rosterSel    = 1
local partySel     = 1
local pendingName  = ""
local pendingStats = nil
local pendingClass = nil   -- classId chosen on the stats screen
local classListSel = 1     -- index into Adventurer.CLASSES_ORDER
local blinkTimer   = 0
local showCursor   = true
local message      = nil
local messageTimer = 0

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function maxNameLen()
    local iq = pendingStats and pendingStats.iq or 10
    return math.max(4, iq * 3 - 6)
end

local function postMessage(text)
    message      = text
    messageTimer = 2.5
end

local function statColor(value)
    if value >= 15 then return ELT.STAT_HIGH
    elseif value <= 8 then return ELT.STAT_LOW
    else                   return ELT.STAT_NORMAL
    end
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
            local y = 100 + (i - 1) * 52
            love.graphics.setColor(ELT.TEXT_BODY)
            love.graphics.print(a.name, PARTY_LEFT + 8, y)
            love.graphics.setColor(ELT.TEXT_DESC)
            love.graphics.print(a:raceClassLabel() .. "  Lv." .. a.level, PARTY_LEFT + 8, y + 18)
            local sc = (a.status == "ok") and ELT.STATUS_OK or ELT.STATUS_DEAD
            love.graphics.setColor(sc)
            love.graphics.print(a:statusLabel(), PARTY_LEFT + 8, y + 34)
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

local function drawMenu()
    local tavernLevel = GS.buildings.tavern
    drawHeader("The Tavern",
        "Level " .. tavernLevel .. "  —  A smoky inn where adventurers gather.")

    for i, item in ipairs(MENU_ITEMS) do
        local y   = CONTENT_TOP + (i - 1) * ROW_H
        local sel = (i == menuSel)

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

local function drawCreateName()
    local classLabel = pendingClass and CLASSES[pendingClass].label or "Adventurer"
    drawHeader("Name your " .. classLabel, "Human  ·  " .. classLabel)

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
    if showCursor then
        local cx = boxX + 10 + Fonts.medium:getWidth(pendingName)
        love.graphics.setColor(ELT.INPUT_CURSOR)
        love.graphics.rectangle("fill", cx, boxY + 8, 2, boxH - 16)
    end

    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.TEXT_FOOTER)
    love.graphics.print("Max " .. maxNameLen() .. " characters.", boxX, boxY + boxH + 12)

    drawFooter("ENTER  confirm     ESC  back to stats")
end

local function drawCreateStats()
    drawHeader("New Adventurer", "Reroll until a suitable class appears, then select it.")

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

        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(ELT.TEXT_SUBTITLE)
        love.graphics.print(Adventurer.statLabel(key), x, y)
        love.graphics.setColor(statColor(pendingStats[key]))
        love.graphics.print(tostring(pendingStats[key]), x + 70, y)
    end

    -- HP below the stat grid.
    local hpY = startY + 3 * 58 + 8
    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", MAIN_LEFT + 30, hpY - 4, CLASS_X - MAIN_LEFT - 60, 1)

    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(ELT.TEXT_SUBTITLE)
    love.graphics.print("HP", MAIN_LEFT + 30, hpY + 4)
    love.graphics.setColor(statColor(pendingStats.hp))
    love.graphics.print(tostring(pendingStats.hp), MAIN_LEFT + 100, hpY + 4)

    -- Reroll cost note.
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.RESOURCE_GOLD)
    love.graphics.print("Reroll: " .. COST_REROLL .. " GP  (have " .. GS.gold .. " GP)",
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
        local eligible = eligibility[classId]
        local sel      = (i == classListSel)
        local y        = startY + 48 + (i - 1) * 96

        -- Selection highlight (only shown when eligible).
        if sel and eligible then
            love.graphics.setColor(ELT.SELECT_BG)
            love.graphics.rectangle("fill", CLASS_X - 6, y - 4, 340, 88, 4)
            love.graphics.setColor(ELT.SELECT_BORDER)
            love.graphics.rectangle("line", CLASS_X - 6, y - 4, 340, 88, 4)
        elseif sel then
            love.graphics.setColor(ELT.SELECT_BG)
            love.graphics.rectangle("fill", CLASS_X - 6, y - 4, 340, 88, 4)
        end

        -- Class name: gold if eligible, gray if not.
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(eligible and ELT.HEADING or ELT.TEXT_FOOTER)
        love.graphics.print(class.label, CLASS_X, y)

        -- Requirements: each stat shown green if met, red if not.
        love.graphics.setFont(Fonts.small)
        local reqX = CLASS_X
        for stat, minVal in pairs(class.requires) do
            local met = (pendingStats[stat] or 0) >= minVal
            love.graphics.setColor(met and ELT.STATUS_OK or ELT.STATUS_DEAD)
            love.graphics.print(Adventurer.statLabel(stat) .. " " .. minVal, reqX, y + 28)
            reqX = reqX + 100
        end

        -- Description.
        love.graphics.setColor(eligible and ELT.TEXT_DESC or ELT.TEXT_FOOTER)
        love.graphics.print(class.desc, CLASS_X, y + 52)
    end

    local selClass = Adventurer.CLASSES_ORDER[classListSel]
    local canConfirm = eligibility[selClass]
    drawFooter(
        "[R] Reroll (" .. COST_REROLL .. " GP)  " ..
        "UP/DOWN navigate classes  " ..
        (canConfirm and "ENTER select class" or "ENTER (select an eligible class)")
    )
end

local function drawRoster()
    drawHeader("Tavern Roster",
        #GS.roster == 0 and "No adventurers are waiting." or
        #GS.roster .. " adventurer(s) available.")

    if #GS.roster == 0 then
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(ELT.TEXT_FOOTER)
        love.graphics.printf("Visit 'Create Adventurer' to hire your first warrior.",
            MAIN_LEFT, CONTENT_TOP + 40, MAIN_WIDTH, "center")
    else
        for i, a in ipairs(GS.roster) do
            local y   = CONTENT_TOP + (i - 1) * ROW_H
            local sel = (i == rosterSel)

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

    drawPartyPanel()

    local hint = GS:partyHasRoom()
        and "UP / DOWN  navigate     ENTER  hire  (" .. COST_HIRE .. " GP)     ESC  back"
        or  "UP / DOWN  navigate     (Party is full)     ESC  back"
    drawFooter(hint)
end

local function drawPartyView()
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
            local sel = (i == partySel)

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

    drawFooter("UP / DOWN  navigate     ENTER  dismiss to roster     ESC  back")
end

-- ── Scene interface ───────────────────────────────────────────────────────────

function Tavern:enter()
    sub          = SUB.MENU
    menuSel      = 1
    rosterSel    = 1
    partySel     = 1
    pendingName  = ""
    pendingStats = nil
    pendingClass = nil
    classListSel = 1
    blinkTimer   = 0
    showCursor   = true
    message      = nil
    messageTimer = 0
end

function Tavern:update(dt)
    blinkTimer = blinkTimer + dt
    if blinkTimer >= 0.5 then
        showCursor = not showCursor
        blinkTimer = 0
    end

    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then
            message      = nil
            messageTimer = 0
        end
    end
end

function Tavern:draw()
    love.graphics.clear(ELT.BG_TOWN)
    if sub == SUB.MENU         then drawMenu()
    elseif sub == SUB.CREATE_NAME  then drawCreateName()
    elseif sub == SUB.CREATE_STATS then drawCreateStats()
    elseif sub == SUB.ROSTER       then drawRoster()
    elseif sub == SUB.PARTY        then drawPartyView()
    end
end

function Tavern:textinput(text)
    if sub == SUB.CREATE_NAME then
        if #pendingName < maxNameLen() then
            pendingName = pendingName .. text
        end
    end
end

function Tavern:keypressed(key)
    if sub == SUB.MENU then
        if key == "up" then
            menuSel = menuSel > 1 and menuSel - 1 or #MENU_ITEMS
        elseif key == "down" then
            menuSel = menuSel < #MENU_ITEMS and menuSel + 1 or 1
        elseif key == "escape" then
            StateMachine:switch("town")
        elseif key == "return" then
            local choice = MENU_ITEMS[menuSel].key
            if choice == "c" then
                if GS.gold >= COST_CREATE then
                    GS.gold      = GS.gold - COST_CREATE
                    pendingName  = ""
                    pendingClass = nil
                    classListSel = 1
                    pendingStats = Adventurer.rollStats("human")
                    sub          = SUB.CREATE_STATS
                else
                    postMessage("Not enough gold!  Creating an adventurer costs " .. COST_CREATE .. " GP.")
                end
            elseif choice == "r" then sub = SUB.ROSTER;  rosterSel = 1
            elseif choice == "p" then sub = SUB.PARTY;   partySel  = 1
            elseif choice == "l" then StateMachine:switch("town")
            end
        else
            for i, item in ipairs(MENU_ITEMS) do
                if key == item.key then menuSel = i; break end
            end
        end

    elseif sub == SUB.CREATE_NAME then
        if key == "backspace" then
            pendingName = pendingName:sub(1, -2)
        elseif key == "return" and #pendingName > 0 then
            local adv = Adventurer.new(pendingName, "human", pendingClass, pendingStats)
            table.insert(GS.roster, adv)
            sub = SUB.ROSTER
            rosterSel = #GS.roster
        elseif key == "escape" then
            sub = SUB.CREATE_STATS   -- back to stats view; gold already spent
        end

    elseif sub == SUB.CREATE_STATS then
        if key == "r" then
            if GS.gold >= COST_REROLL then
                GS.gold      = GS.gold - COST_REROLL
                pendingStats = Adventurer.rollStats("human")
                pendingClass = nil
            else
                postMessage("Not enough gold to reroll!  (Need " .. COST_REROLL .. " GP)")
            end
        elseif key == "up" then
            classListSel = classListSel > 1 and classListSel - 1 or #Adventurer.CLASSES_ORDER
        elseif key == "down" then
            classListSel = classListSel < #Adventurer.CLASSES_ORDER and classListSel + 1 or 1
        elseif key == "return" then
            local classId    = Adventurer.CLASSES_ORDER[classListSel]
            local eligibility = Adventurer.classEligibility(pendingStats)
            if eligibility[classId] then
                pendingClass = classId
                pendingName  = ""
                sub          = SUB.CREATE_NAME
            else
                postMessage("This class requires higher stats.  Reroll or choose an eligible class.")
            end
        elseif key == "escape" then
            sub = SUB.MENU
        end

    elseif sub == SUB.ROSTER then
        if key == "up" then
            rosterSel = rosterSel > 1 and rosterSel - 1 or math.max(1, #GS.roster)
        elseif key == "down" then
            rosterSel = rosterSel < #GS.roster and rosterSel + 1 or 1
        elseif key == "return" and #GS.roster > 0 then
            if GS.gold >= COST_HIRE then
                GS.gold = GS.gold - COST_HIRE
                GS:addToParty(GS.roster[rosterSel])
                rosterSel = math.min(rosterSel, math.max(1, #GS.roster))
            else
                postMessage("Not enough gold to hire!  (Need " .. COST_HIRE .. " GP)")
            end
        elseif key == "escape" then
            sub = SUB.MENU
        end

    elseif sub == SUB.PARTY then
        if key == "up" then
            partySel = partySel > 1 and partySel - 1 or math.max(1, #GS.party)
        elseif key == "down" then
            partySel = partySel < #GS.party and partySel + 1 or 1
        elseif key == "return" and #GS.party > 0 then
            GS:dismissFromParty(GS.party[partySel])
            partySel = math.min(partySel, math.max(1, #GS.party))
        elseif key == "escape" then
            sub = SUB.MENU
        end
    end
end

function Tavern:leave()
    -- Nothing to clean up yet.
end

return Tavern
