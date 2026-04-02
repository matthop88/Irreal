local ELT = require("src.core.elt_color")

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

    love.graphics.clear(ELT.BG_TITLE)

    -- Main title.
    love.graphics.setFont(Fonts.title)
    love.graphics.setColor(ELT.HEADING)
    love.graphics.printf("IRREAL", 0, 86, W, "center")

    -- Subtitle.
    love.graphics.setFont(Fonts.large)
    love.graphics.setColor(ELT.TEXT_SUBTITLE)
    love.graphics.printf("The Mysterious Valley", 0, 200, W, "center")

    -- Thin decorative rule.
    love.graphics.setColor(ELT.withAlpha(ELT.RULE_FAINT, self.loreAlpha))
    love.graphics.rectangle("fill", 340, 258, W - 680, 1)

    -- Lore lines.
    love.graphics.setFont(Fonts.small)
    for i, line in ipairs(LORE_LINES) do
        if i == #LORE_LINES then
            -- The chasm line is dimmer and slightly red — unsettling.
            love.graphics.setColor(ELT.withAlpha(ELT.OMINOUS, self.loreAlpha))
        else
            love.graphics.setColor(ELT.withAlpha(ELT.TEXT_LORE, self.loreAlpha))
        end
        love.graphics.printf(line, 0, 278 + (i - 1) * 30, W, "center")
    end

    -- Blinking prompt.
    if self.showPrompt then
        love.graphics.setFont(Fonts.medium)
        love.graphics.setColor(ELT.TEXT_PROMPT)
        love.graphics.printf("Press ENTER to begin your legend", 0, H - 110, W, "center")
    end

    -- Quit hint.
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(ELT.TEXT_HINT)
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
