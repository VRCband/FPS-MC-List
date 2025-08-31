-- CONFIG
local jsonPath = "billboard.json"
local jsonURL = "https://yourdomain.com/billboard.json"

-- Open all modem types
for _, side in ipairs({"left", "right", "top", "bottom", "back", "front"}) do
    if peripheral.getType(side) == "modem" then
        rednet.open(side)
    end
end

-- Discover local monitors
local monitors = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitors[name] = peripheral.wrap(name)
    end
end

-- Load JSON from remote
local function loadMessages()
    if fs.exists(jsonPath) then fs.delete(jsonPath) end
    shell.run("wget", jsonURL, jsonPath)
    local file = fs.open(jsonPath, "r")
    local raw = file.readAll()
    file.close()
    return textutils.unserializeJSON(raw)
end

-- Send or render message
local function dispatch(entry)
    local target = entry.monitorID or "all"
    local duration = tonumber(entry.duration) or 5

    if target == "local" then
        for _, monitor in pairs(monitors) do
            renderLocally(monitor, entry)
        end
    else
        rednet.broadcast(entry, "billboard")
    end

    sleep(duration)
end

-- Local rendering fallback
function renderLocally(monitor, entry)
    monitor.setBackgroundColor(colors[entry.bgColor] or colors.black)
    monitor.clear()
    monitor.setTextColor(colors[entry.Text_Color] or colors.white)
    monitor.setTextScale(tonumber(entry.Text_Size) or 1)

    local w, h = monitor.getSize()
    local message = entry.message or ""
    local lines = {}

    for word in message:gmatch("%S+") do
        if #lines == 0 then
            table.insert(lines, word)
        else
            local testLine = lines[#lines] .. " " .. word
            if #testLine <= w then
                lines[#lines] = testLine
            else
                table.insert(lines, word)
            end
        end
    end

    local totalLines = #lines
    local centerLine = math.floor(h / 2)
    local startY = centerLine - math.floor(totalLines / 2)

    for i, line in ipairs(lines) do
        local pad = math.floor((w - #line) / 2)
        monitor.setCursorPos(pad + 1, startY + i - 1)
        monitor.write(line)
    end
end

-- Main loop
while true do
    local messages = loadMessages()
    for _, entry in ipairs(messages) do
        dispatch(entry)
    end
end
