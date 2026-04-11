-- Central scene/state manager.
-- Scenes are loaded lazily on first visit.  Each scene is a table that may
-- implement any of: enter(...)  leave()  update(dt)  draw()  keypressed(key)

local StateMachine = {}

-- Map of scene name → module path.  Add new scenes here as the project grows.
local REGISTRY = {
    title  = "src.scenes.title",
    town   = "src.scenes.town",
    tavern = "src.scenes.tavern",
}

local _loaded  = {}   -- cache of required scene modules
local _current = nil  -- active scene table
local _name    = nil  -- name of the active scene

--- Switch to a named scene, forwarding any extra arguments to scene:enter().
function StateMachine:switch(name, ...)
    assert(REGISTRY[name], "StateMachine: unknown scene '" .. tostring(name) .. "'")

    -- Lazy-load the module the first time it is visited.
    if not _loaded[name] then
        _loaded[name] = require(REGISTRY[name])
    end

    if _current and _current.leave then
        _current:leave()
    end

    _current = _loaded[name]
    _name    = name

    if _current.enter then
        _current:enter(...)
    end
end

--- Returns the name of the currently active scene.
function StateMachine:current()
    return _name
end

function StateMachine:update(dt)
    if _current and _current.update then
        _current:update(dt)
    end
end

function StateMachine:draw()
    if _current and _current.draw then
        _current:draw()
    end
end

function StateMachine:keypressed(key)
    if _current and _current.keypressed then
        _current:keypressed(key)
    end
end

function StateMachine:textinput(text)
    if _current and _current.textinput then
        _current:textinput(text)
    end
end

return StateMachine
