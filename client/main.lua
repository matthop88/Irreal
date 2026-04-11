local StateMachine = require("src.core.statemachine")

-- Expose globally so scenes can call StateMachine:switch() without requiring it themselves.
_G.StateMachine = StateMachine

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")   -- smooth scaling for non-pixel fonts

    -- Swap these lines to try different font pairings.
    local TITLE_FONT = "assets/fonts/CinzelDecorative-Regular.ttf"
    local BODY_FONT  = "assets/fonts/Philosopher-Regular.ttf"
    -- local BODY_FONT  = "assets/fonts/Amiri-Regular.ttf"

    -- Pixel-style alternatives (kept for reference):
    -- local TITLE_FONT = "assets/fonts/PressStart2P-Regular.ttf"
    -- local BODY_FONT  = "assets/fonts/VT323-Regular.ttf"
    -- local BODY_FONT  = "assets/fonts/Silkscreen-Regular.ttf"

    _G.Fonts = {
        title  = love.graphics.newFont(TITLE_FONT, 96),
        large  = love.graphics.newFont(BODY_FONT,  42),
        medium = love.graphics.newFont(BODY_FONT,  28),
        small  = love.graphics.newFont(BODY_FONT,  20),
    }

    StateMachine:switch("title")
end

function love.update(dt)
    StateMachine:update(dt)
end

function love.draw()
    StateMachine:draw()
end

function love.keypressed(key, scancode, isrepeat)
    -- Global quit shortcut.
    if key == "f4" and love.keyboard.isDown("lalt", "ralt") then
        love.event.quit()
    end
    StateMachine:keypressed(key)
end

function love.textinput(text)
    StateMachine:textinput(text)
end
