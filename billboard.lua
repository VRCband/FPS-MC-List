-- CONFIG
local jsonPath = "billboard.json"
local jsonURL = "https://raw.githubusercontent.com/VRCband/FPS-MC-List/refs/heads/main/billboard.json?token=GHSAT0AAAAAADKFPCAW6A6ZO4MA2H4GCJVC2FTR3KQ"  -- Replace with your actual URL

-- Discover all monitors
local monitors = {}
for name, _ in pairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitors[name] = peripheral.wrap(name)
    end
end
if next(monitors) == nil then error("No monitors found") end

-- Centering helper
local function centerText(text, width)
    local pad = math.floor((width - #text) / 2)
    return string.rep(" ", pad) .. text
end

-- Render one message to one monitor
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

-- Load JSON from file
local function loadMessages()
    if not fs.exists(jsonPath) then error("Missing JSON file: " .. jsonPath) end
    local file = fs.open(jsonPath, "r")
    local raw = file.readAll()
    file.close()
    local data = textutils.unserializeJSON(raw)
    if type(data) ~= "table" then error("Invalid JSON structure") end
    return data
end

-- Main loop
while true do
    local messages = loadMessages()
    for _, entry in ipairs(messages) do
        local target = entry.monitorID or "all"
        for id, monitor in pairs(monitors) do
            if target == "all" or id == target then
                renderMessage(monitor, entry)
            end
        end
        sleep(tonumber(entry.duration) or 5)
    end

    -- Refresh JSON from remote source
    shell.run("wget", jsonURL, jsonPath)
end

