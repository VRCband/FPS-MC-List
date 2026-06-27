-- billboard.lua (with full error handling)

term.clear()
term.setCursorPos(1,1)
print("Billboard Sender Setup")

-- Ask user for channel + JSON file
write("Enter channel name: ")
local channel = read()

write("Enter JSON filename (e.g. spawn.json): ")
local jsonFile = read()

-- Remote JSON URL
local baseURL = "https://raw.githubusercontent.com/VRCband/FPS-MC-List/refs/heads/main/"
local jsonURL = baseURL .. jsonFile
local localJSON = "billboard.json"

-- Open all modem sides
local modemOpened = false
for _, side in ipairs({"left","right","top","bottom","back","front"}) do
    if peripheral.getType(side) == "modem" then
        rednet.open(side)
        modemOpened = true
    end
end

if not modemOpened then
    error("ERROR: No modem found. Cannot broadcast messages.")
end

-- Detect monitors
local monitors = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitors[name] = peripheral.wrap(name)
    end
end

if next(monitors) == nil then
    error("ERROR: No monitors detected. Place at least one monitor touching the computer.")
end

-- Download + load JSON
local function loadMessages()
    if fs.exists(localJSON) then fs.delete(localJSON) end

    print("Downloading JSON from: " .. jsonURL)
    local ok = shell.run("wget", jsonURL, localJSON)

    if not ok or not fs.exists(localJSON) then
        print("ERROR: Failed to download JSON file.")
        sleep(3)
        return nil
    end

    local f = fs.open(localJSON, "r")
    if not f then
        print("ERROR: Failed to open downloaded JSON file.")
        sleep(3)
        return nil
    end

    local raw = f.readAll()
    f.close()

    local data = textutils.unserializeJSON(raw)
    if not data then
        print("ERROR: JSON parse error. Check your JSON syntax.")
        sleep(3)
        return nil
    end

    if type(data) ~= "table" then
        print("ERROR: JSON root must be an array.")
        sleep(3)
        return nil
    end

    return data
end

-- Split by newline
local function splitLines(str)
    local t = {}
    for line in str:gmatch("([^\n]*)\n?") do
        if line ~= "" then table.insert(t, line) end
    end
    return t
end

-- Wrap text to width
local function wrap(text, width)
    local lines = {}
    while #text > width do
        local cut = text:sub(1, width)
        local space = cut:match(".*() ")
        if space then
            table.insert(lines, text:sub(1, space - 1))
            text = text:sub(space + 1)
        else
            table.insert(lines, cut)
            text = text:sub(width + 1)
        end
    end
    table.insert(lines, text)
    return lines
end

local function renderText(monitor, entry)
    -- Safe text scale
    local scale = tonumber(entry.Text_Size) or 1
    if scale < 0.5 then scale = 0.5 end
    if scale > 5 then scale = 5 end
    monitor.setTextScale(scale)

    local w, h = monitor.getSize()
    local raw = entry.message or ""

    -- Markdown-like formatting
    raw = raw:gsub("%*%*(.-)%*%*", function(s) return s:upper() end)
    raw = raw:gsub("%*(.-)%*", "%1")

    -- Split into paragraphs
    local paragraphs = {}
    for line in raw:gmatch("([^\n]*)\n?") do
        table.insert(paragraphs, line)
    end

    -- Wrap all lines
    local lines = {}
    for _, p in ipairs(paragraphs) do
        local header = p:match("^# (.+)")
        if header then
            table.insert(lines, header:upper())
        else
            while #p > w do
                table.insert(lines, p:sub(1, w))
                p = p:sub(w + 1)
            end
            table.insert(lines, p)
        end
    end

    -- Apply colors
    monitor.setBackgroundColor(colors[entry.bgColor] or colors.black)
    monitor.clear()
    monitor.setTextColor(colors[entry.Text_Color] or colors.white)

    -- Draw from top, clipped to monitor height
    for i = 1, math.min(#lines, h) do
        monitor.setCursorPos(1, i)
        monitor.write(lines[i])
    end
end


-- Dispatch message
local function dispatch(entry)
    if type(entry) ~= "table" then
        print("ERROR: Invalid entry in JSON (not a table).")
        return
    end

    entry.channel = channel
    local duration = tonumber(entry.duration) or 5

    for _, mon in pairs(monitors) do
        local ok, err = pcall(renderText, mon, entry)
        if not ok then
            print("ERROR rendering message: " .. tostring(err))
        end
    end

    sleep(duration)
end

-- Main loop
while true do
    local messages = loadMessages()

    if not messages then
        print("Retrying JSON download in 5 seconds...")
        sleep(5)
    else
        for _, entry in ipairs(messages) do
            dispatch(entry)
        end
    end
end

