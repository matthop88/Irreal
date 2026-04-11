local ELT = require("src.core.elt_color")
local GS  = require("src.core.gamestate")

local Town = {}

-- Each entry represents a visitable location in the village hub.
-- 'level' is nil for locations that aren't buildings (e.g. world map).
local LOCATIONS = {
    { key = "t", label = "Tavern",           level = 1, desc = "Hire and manage your adventurers.",        scene = "tavern" },
    { key = "s", label = "Shop",             level = 1, desc = "Buy and sell weapons, armour, and supplies.", scene = nil },
    { key = "c", label = "Church",           level = 1, desc = "Rest, heal, and pray for the fallen.",     scene = nil },
    { key = "g", label = "Training Grounds", level = 1, desc = "Hone the skills of your party.",           scene = nil },
    { key = "m", label = "World Map",        level = nil, desc = "Survey the valley and choose your destination.", scene = nil },
}

local ROW_HEIGHT  = 72
local LIST_TOP    = 150
local LIST_LEFT   = 180
local LIST_WIDTH  = 920   -- 1280 - 2*180

function Town:enter()
    self.selected = 1
end

function Town:update(dt)
    -- Nothing to animate yet.
end

function Town:drawLocationRows()
    for i, loc in ipairs(LOCATIONS) do
        local y = LIST_TOP + (i - 1) * ROW_HEIGHT
        local selected = (i == self.selected)

        -- Selection highlight.
        if selected then
            love.graphics.setColor(ELT.SELECT_BG)
            love.graphics.rectangle("fill", LIST_LEFT - 4, y - 4, LIST_WIDTH + 8, ROW_HEIGHT - 8, 5)
            love.graphics.setColor(ELT.SELECT_BORDER)
            love.graphics.rectangle("line", LIST_LEFT - 4, y - 4, LIST_WIDTH + 8, ROW_HEIGHT - 8, 5)
        end

        -- Keyboard shortcut badge.
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(selected and ELT.KEY_ACTIVE or ELT.KEY_INACTIVE)
        love.graphics.print("[" .. loc.key:upper() .. "]", LIST_LEFT + 8, y + 6)

        -- Location name + level.
        local nameStr = loc.label
        if loc.level then
            nameStr = nameStr .. "  (Level " .. loc.level .. ")"
        end
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(selected and ELT.HEADING_BRIGHT or ELT.TEXT_BODY)
        love.graphics.print(nameStr, LIST_LEFT + 60, y + 6)

        -- Description.
        love.graphics.setFont(Fonts.small)
        love.graphics.setColor(ELT.TEXT_DESC)
        love.graphics.print(loc.desc, LIST_LEFT + 60, y + 32)
    end
end

function Town:draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    love.graphics.clear(ELT.BG_TOWN)

    -- Header.
    love.graphics.setFont(Fonts.large)
    love.graphics.setColor(ELT.HEADING)
    love.graphics.printf("The Village of Irreal", 0, 40, W, "center")

    -- Decorative rule beneath header.
    love.graphics.setColor(ELT.RULE)
    love.graphics.rectangle("fill", LIST_LEFT, 95, LIST_WIDTH, 1)

    -- Gold / resource display placeholder (top-right corner).
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.RESOURCE_GOLD)
    love.graphics.print("Gold:  " .. GS.gold,  W - 200, 44)
    love.graphics.setColor(ELT.RESOURCE_STONE)
    love.graphics.print("Stone: " .. GS.stone, W - 200, 62)

    self:drawLocationRows()

    -- Footer hint.
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.TEXT_FOOTER)
    love.graphics.printf(
        "UP / DOWN  navigate     ENTER  enter location     ESC  return to title",
        0, H - 36, W, "center"
    )
end

function Town:keypressed(key)
    if key == "up" then
        self.selected = (self.selected > 1) and (self.selected - 1) or #LOCATIONS
    elseif key == "down" then
        self.selected = (self.selected < #LOCATIONS) and (self.selected + 1) or 1
    elseif key == "escape" then
        StateMachine:switch("title")
    elseif key == "return" then
        local loc = LOCATIONS[self.selected]
        if loc.scene then
            StateMachine:switch(loc.scene)
        end
    else
        -- Direct key shortcuts jump to a location.
        for i, loc in ipairs(LOCATIONS) do
            if key == loc.key then
                self.selected = i
                break
            end
        end
    end
end

function Town:leave()
    -- Nothing to clean up yet.
end

return Town
