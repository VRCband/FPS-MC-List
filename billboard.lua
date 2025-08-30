-- billboard_multi.lua
local jsonPath = "billboard.json"
local monitors = {}
for name, peripheralType in pairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitors[name] = peripheral.wrap(name)
    end
end
if next(monitors) == nil then error("No monitors found") end

-- Load JSON
local file = fs.open(jsonPath, "r")
if not file then error("Missing JSON file: " .. jsonPath) end
local raw = file.readAll()
file.close()

local messages = textutils.unserializeJSON(raw)
if type(messages) ~= "table" then error("Invalid JSON structure") end

-- Centering helper
local function centerText(text, width)
    local pad = math.floor((width - #text) / 2)
    return string.rep(" ", pad) .. text
end

-- Render message to one monitor
local function renderMessage(monitor, entry)
    monitor.setBackgroundColor(colors[entry.bgColor] or colors.black)
    monitor.clear()
    monitor.setTextColor(colors[entry.Text_Color] or colors.white)
    monitor.setTextScale(tonumber(entry.Text_Size) or 1)

    local w, h = monitor.getSize()
    local msg = centerText(entry.message, w)
    monitor.setCursorPos(1, math.floor(h / 2))
    monitor.write(msg)
end

-- Main loop
while true do
    for _, entry in ipairs(messages) do
        local target = entry.monitorID or "all"
        for id, monitor in pairs(monitors) do
            if target == "all" or id == target then
                renderMessage(monitor, entry)
            end
        end
        sleep(tonumber(entry.duration) or 5)
    end
end
