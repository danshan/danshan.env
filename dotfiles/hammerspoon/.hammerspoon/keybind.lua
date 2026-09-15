local hotkey = require("hs.hotkey")
local windows = require("modules.windows")

local modifiers = {
    app = { "alt" },
    move = { "alt", "ctrl" },
    resize = { "alt", "shift" },
}

local applications = {
    { key = "`", name = "Ghostty" },
    { key = ",", name = "Notion" },
    { key = ".", name = "Bruno" },
    { key = "/", name = "Finder" },
    { key = ";", name = "Preview" },
    { key = "1", name = "Google Chrome" },
    { key = "2", name = "Safari" },
    { key = "3", name = "Feishu" },
    { key = "4", name = "WeChat" },
    { key = "5", bundle_id = "com.tencent.WeWorkMac" },
    { key = "6", name = "Discord" },
    { key = "a", name = "iStatistica Pro" },
    { key = "d", name = "WebStorm" },
    { key = "e", name = "Sublime Text" },
    { key = "k", name = "ChatGPT" },
    { key = "m", name = "QQMusic" },
    { key = "n", name = "Telegram" },
    { key = "p", name = "PyCharm" },
    { key = "r", name = "Reminders" },
    { key = "s", name = "IntelliJ IDEA" },
    { key = "t", name = "Tweetbot" },
    { key = "v", name = "Cursor" },
    { key = "w", name = "Bitwarden" },
    { key = "z", bundle_id = "com.zentraedi.zspaceMacApp" },
}

for _, application in ipairs(applications) do
    local app = application
    hotkey.bind(modifiers.app, application.key, function()
        local launched
        if app.bundle_id then
            launched = hs.application.launchOrFocusByBundleID(app.bundle_id)
        else
            launched = hs.application.launchOrFocus(app.name)
        end

        if not launched then
            hs.alert.show("Application not found: " .. (app.name or app.bundle_id))
        end
    end)
end

hotkey.bind(modifiers.app, "b", hs.reload)

local function bind_all(binding_modifiers, bindings)
    for _, binding in ipairs(bindings) do
        hotkey.bind(binding_modifiers, binding.key, binding.action)
    end
end

bind_all(modifiers.resize, {
    { key = "m", action = windows.maximize },
    { key = "left", action = windows.left_half },
    { key = "h", action = windows.left_half },
    { key = "right", action = windows.right_half },
    { key = "l", action = windows.right_half },
    { key = "up", action = windows.top_half },
    { key = "k", action = windows.top_half },
    { key = "down", action = windows.bottom_half },
    { key = "j", action = windows.bottom_half },
    { key = "-", action = windows.shrink },
    { key = "=", action = windows.grow },
})

bind_all(modifiers.move, {
    { key = "h", action = windows.move_west },
    { key = "l", action = windows.move_east },
    { key = "k", action = windows.move_north },
    { key = "j", action = windows.move_south },
})
