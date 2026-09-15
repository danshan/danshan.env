local M = {}

local function with_focused_window(action)
    local window = hs.window.focusedWindow()
    if not window then
        hs.alert.show("No focused window")
        return
    end

    action(window)
end

local function move_to_unit(unit)
    with_focused_window(function(window)
        window:moveToUnit(unit)
    end)
end

local function resize(ratio)
    with_focused_window(function(window)
        local frame = window:frame()
        frame.x = frame.x + frame.w * (1 - ratio) / 2
        frame.y = frame.y + frame.h * (1 - ratio) / 2
        frame.w = frame.w * ratio
        frame.h = frame.h * ratio
        window:setFrameInScreenBounds(frame)
    end)
end

function M.maximize()
    with_focused_window(function(window)
        window:maximize()
    end)
end

function M.left_half()
    move_to_unit({ x = 0, y = 0, w = 0.5, h = 1 })
end

function M.right_half()
    move_to_unit({ x = 0.5, y = 0, w = 0.5, h = 1 })
end

function M.top_half()
    move_to_unit({ x = 0, y = 0, w = 1, h = 0.5 })
end

function M.bottom_half()
    move_to_unit({ x = 0, y = 0.5, w = 1, h = 0.5 })
end

function M.shrink()
    resize(0.9)
end

function M.grow()
    resize(1.1)
end

function M.move_west()
    with_focused_window(function(window)
        window:moveOneScreenWest(false, true)
    end)
end

function M.move_east()
    with_focused_window(function(window)
        window:moveOneScreenEast(false, true)
    end)
end

function M.move_north()
    with_focused_window(function(window)
        window:moveOneScreenNorth(false, true)
    end)
end

function M.move_south()
    with_focused_window(function(window)
        window:moveOneScreenSouth(false, true)
    end)
end

return M
