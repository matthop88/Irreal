local Town = {}

-- Each entry represents a visitable location in the village hub.
-- 'level' is nil for locations that aren't buildings (e.g. world map).
local LOCATIONS = {
    { key = "t", label = "Tavern",           level = 1, desc = "Hire and manage your adventurers." },
    { key = "s", label = "Shop",             level = 1, desc = "Buy and sell weapons, armour, and supplies." },
    { key = "c", label = "Church",           level = 1, desc = "Rest, heal, and pray for the fallen." },
    { key = "g", label = "Training Grounds", level = 1, desc = "Hone the skills of your party." },
    { key = "m", label = "World Map",        level = nil, desc = "Survey the valley and choose your destination." },
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

function Town:draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    love.graphics.clear(0.07, 0.06, 0.04)

    -- Header.
    love.graphics.setFont(Fonts.large)
    love.graphics.setColor(0.95, 0.80, 0.25)
    love.graphics.printf("The Village of Irreal", 0, 40, W, "center")

    -- Decorative rule beneath header.
    love.graphics.setColor(0.35, 0.30, 0.18)
    love.graphics.rectangle("fill", LIST_LEFT, 95, LIST_WIDTH, 1)

    -- Gold / resource display placeholder (top-right corner).
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.print("Gold:  0", W - 200, 44)
    love.graphics.setColor(0.60, 0.55, 0.45)
    love.graphics.print("Stone: 0", W - 200, 62)

    -- Location rows.
    for i, loc in ipairs(LOCATIONS) do
        local y = LIST_TOP + (i - 1) * ROW_HEIGHT
        local selected = (i == self.selected)

        -- Selection highlight.
        if selected then
            love.graphics.setColor(0.18, 0.15, 0.08)
            love.graphics.rectangle("fill", LIST_LEFT - 4, y - 4, LIST_WIDTH + 8, ROW_HEIGHT - 8, 5)
            love.graphics.setColor(0.55, 0.48, 0.22)
            love.graphics.rectangle("line", LIST_LEFT - 4, y - 4, LIST_WIDTH + 8, ROW_HEIGHT - 8, 5)
        end

        -- Keyboard shortcut badge.
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(selected and {0.75, 0.65, 0.30} or {0.45, 0.42, 0.32})
        love.graphics.print("[" .. loc.key:upper() .. "]", LIST_LEFT + 8, y + 6)

        -- Location name + level.
        local nameStr = loc.label
        if loc.level then
            nameStr = nameStr .. "  (Level " .. loc.level .. ")"
        end
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(selected and {1.0, 0.92, 0.55} or {0.80, 0.75, 0.60})
        love.graphics.print(nameStr, LIST_LEFT + 60, y + 6)

        -- Description.
        love.graphics.setFont(Fonts.small)
        love.graphics.setColor(0.50, 0.47, 0.38)
        love.graphics.print(loc.desc, LIST_LEFT + 60, y + 32)
    end

    -- Footer hint.
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.32, 0.30, 0.25)
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
        -- TODO Phase 2+: enter the selected location.
        -- StateMachine:switch(LOCATIONS[self.selected].scene)
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
