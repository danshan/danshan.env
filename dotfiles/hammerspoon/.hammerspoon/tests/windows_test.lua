local real_hs = hs
local alerts = {}
local calls = {}
local frame = { x = 100, y = 100, w = 800, h = 600 }

local window = {
    frame = function()
        return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
    end,
    maximize = function()
        calls.maximize = true
    end,
    moveToUnit = function(_, unit)
        calls.unit = unit
    end,
    setFrameInScreenBounds = function(_, next_frame)
        calls.frame = next_frame
    end,
    moveOneScreenWest = function(_, no_resize, ensure_in_bounds)
        calls.west = { no_resize, ensure_in_bounds }
    end,
    moveOneScreenEast = function(_, no_resize, ensure_in_bounds)
        calls.east = { no_resize, ensure_in_bounds }
    end,
    moveOneScreenNorth = function(_, no_resize, ensure_in_bounds)
        calls.north = { no_resize, ensure_in_bounds }
    end,
    moveOneScreenSouth = function(_, no_resize, ensure_in_bounds)
        calls.south = { no_resize, ensure_in_bounds }
    end,
}

local focused_window = window
hs = {
    alert = {
        show = function(message)
            table.insert(alerts, message)
        end,
    },
    window = {
        focusedWindow = function()
            return focused_window
        end,
    },
}

local function assert_close(actual, expected)
    assert(math.abs(actual - expected) < 0.000001)
end

local ok, err = xpcall(function()
    local windows = dofile(real_hs.configdir .. "/modules/windows.lua")

    windows.left_half()
    assert(calls.unit.x == 0 and calls.unit.y == 0 and calls.unit.w == 0.5 and calls.unit.h == 1)

    windows.right_half()
    assert(calls.unit.x == 0.5 and calls.unit.y == 0 and calls.unit.w == 0.5 and calls.unit.h == 1)

    windows.top_half()
    assert(calls.unit.x == 0 and calls.unit.y == 0 and calls.unit.w == 1 and calls.unit.h == 0.5)

    windows.bottom_half()
    assert(calls.unit.x == 0 and calls.unit.y == 0.5 and calls.unit.w == 1 and calls.unit.h == 0.5)

    windows.grow()
    assert_close(calls.frame.x, 60)
    assert_close(calls.frame.y, 70)
    assert_close(calls.frame.w, 880)
    assert_close(calls.frame.h, 660)

    focused_window = nil
    windows.maximize()
    assert(alerts[#alerts] == "No focused window")
end, debug.traceback)

hs = real_hs

if not ok then
    error(err)
end

print("Window checks passed")
