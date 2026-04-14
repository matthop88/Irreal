local ELT        = require("src.core.elt_color")
local GS         = require("src.core.gamestate")
local Adventurer = require("src.entities.adventurer")
local RACES      = require("src.data.races")

--- Race-selection sub-state for the tavern scene (see `tavern.lua`).
return function(deps)
    local drawHeader            = deps.drawHeader
    local drawPartyPanel        = deps.drawPartyPanel
    local drawFooter            = deps.drawFooter
    local postMessage           = deps.postMessage
    local noop                  = deps.noop
    local transitionToCreateStatsFromRace = deps.transitionToCreateStatsFromRace
    local escapeToMenu          = deps.escapeToMenu
    local COST_CREATE           = deps.COST_CREATE
    local MAIN_LEFT             = deps.MAIN_LEFT
    local MAIN_WIDTH            = deps.MAIN_WIDTH
    local CONTENT_TOP           = deps.CONTENT_TOP

    return {
        ALL_RACES   = { "human", "elf", "dwarf", "hobbit" },
        raceListSel = 1,
        STAT_ORDER  = { "str", "iq", "wis", "con", "agi", "cha" },
        init = function(self)
            self.raceListSel = 1
        end,
        draw = function(self)
            drawHeader("Choose Your Race",
                "Browse freely.  Costs " .. COST_CREATE .. " GP to roll stats once you choose.")

            local raceRowH = 112

            for i, raceId in ipairs(self.ALL_RACES) do
                local race = RACES[raceId]
                local sel  = (i == self.raceListSel)
                local y    = CONTENT_TOP + (i - 1) * raceRowH

                if sel then
                    love.graphics.setColor(ELT.SELECT_BG)
                    love.graphics.rectangle("fill", MAIN_LEFT, y - 4, MAIN_WIDTH, raceRowH - 8, 5)
                    love.graphics.setColor(ELT.SELECT_BORDER)
                    love.graphics.rectangle("line", MAIN_LEFT, y - 4, MAIN_WIDTH, raceRowH - 8, 5)
                end

                love.graphics.setFont(Fonts.medium)
                love.graphics.setColor(sel and ELT.HEADING_BRIGHT or ELT.HEADING)
                love.graphics.print(race.label, MAIN_LEFT + 16, y + 6)

                love.graphics.setFont(Fonts.small)
                love.graphics.setColor(ELT.TEXT_DESC)
                love.graphics.print(race.desc, MAIN_LEFT + 16, y + 34)

                local modX = MAIN_LEFT + 16
                for _, key in ipairs(self.STAT_ORDER) do
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
        end,
        update = noop,
        keypressed = function(self, key)
            if key == "up" then
                self.raceListSel = self.raceListSel > 1 and self.raceListSel - 1 or #self.ALL_RACES
            elseif key == "down" then
                self.raceListSel = self.raceListSel < #self.ALL_RACES and self.raceListSel + 1 or 1
            elseif key == "return" then
                if GS.gold >= COST_CREATE then
                    GS.gold = GS.gold - COST_CREATE
                    transitionToCreateStatsFromRace(self.ALL_RACES[self.raceListSel])
                else
                    postMessage("Not enough gold!  Creating an adventurer costs " .. COST_CREATE .. " GP.")
                end
            elseif key == "escape" then
                escapeToMenu()
            end
        end,
    }
end
