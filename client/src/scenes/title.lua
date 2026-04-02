local Title = {}

local BLINK_RATE = 0.55   -- seconds per blink half-cycle
local FADE_SPEED = 0.35   -- alpha units per second for the flavour lines

-- Directional flavour text that fades in after the title appears.
local LORE_LINES = {
    "To the East,  the Mountains await.",
    "To the North, the Forest whispers.",
    "To the West,  the Sea calls.",
    "To the South... nothing crosses the Chasm.",
}

function Title:enter()
    self.blinkTimer  = 0
    self.showPrompt  = true
    self.loreAlpha   = 0
end

function Title:update(dt)
    -- Blinking prompt.
    self.blinkTimer = self.blinkTimer + dt
    if self.blinkTimer >= BLINK_RATE then
        self.showPrompt = not self.showPrompt
        self.blinkTimer = 0
    end

    -- Gradually reveal the lore lines.
    self.loreAlpha = math.min(1, self.loreAlpha + dt * FADE_SPEED)
end

function Title:draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    love.graphics.clear(0.04, 0.04, 0.08)

    -- Main title.
    love.graphics.setFont(Fonts.title)
    love.graphics.setColor(0.95, 0.80, 0.25)
    love.graphics.printf("IRREAL", 0, 86, W, "center")

    -- Subtitle.
    love.graphics.setFont(Fonts.large)
    love.graphics.setColor(0.55, 0.50, 0.40)
    love.graphics.printf("The Mysterious Valley", 0, 200, W, "center")

    -- Thin decorative rule.
    love.graphics.setColor(0.30, 0.27, 0.18, self.loreAlpha)
    love.graphics.rectangle("fill", 340, 258, W - 680, 1)

    -- Lore lines.
    love.graphics.setFont(Fonts.small)
    for i, line in ipairs(LORE_LINES) do
        local alpha = self.loreAlpha
        if i == #LORE_LINES then
            -- The chasm line is dimmer and slightly red — unsettling.
            love.graphics.setColor(0.55, 0.30, 0.28, alpha)
        else
            love.graphics.setColor(0.45, 0.43, 0.36, alpha)
        end
        love.graphics.printf(line, 0, 278 + (i - 1) * 30, W, "center")
    end

    -- Blinking prompt.
    if self.showPrompt then
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(0.88, 0.88, 0.82)
        love.graphics.printf("Press ENTER to begin your legend", 0, H - 110, W, "center")
    end

    -- Quit hint.
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.28, 0.26, 0.22)
    love.graphics.printf("ESC to quit", 0, H - 34, W, "center")
end

function Title:keypressed(key)
    if key == "return" then
        StateMachine:switch("town")
    elseif key == "escape" then
        love.event.quit()
    end
end

function Title:leave()
    -- Nothing to clean up yet.
end

return Title
