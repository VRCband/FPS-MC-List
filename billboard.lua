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

-- Improved text wrapping that respects words
local function wrapText(text, width)
    local lines = {}
    for line in text:gmatch("([^\n]+)") do -- Split by actual newline first
        local currentLine = ""
        for word in line:gmatch("%S+") do
            if #currentLine + #word + 1 <= width then
                currentLine = currentLine == "" and word or currentLine .. " " .. word
            else
                table.insert(lines, currentLine)
                currentLine = word
            end
        end
        table.insert(lines, currentLine)
    end
    return lines
end

local function renderText(monitor, entry)
    -- 1. Apply Scale First
    local scale = tonumber(entry.Text_Size) or 1
    -- Clamp scale between 0.5 and 5 (ComputerCraft limits)
    scale = math.max(0.5, math.min(5, scale))
    monitor.setTextScale(scale)

    -- 2. Get new dimensions AFTER scaling
    local w, h = monitor.getSize()

    -- 3. Prepare Colors
    local bgColor = colors[entry.bgColor] or colors.black
    local txtColor = colors[entry.Text_Color] or colors.white
    monitor.setBackgroundColor(bgColor)
    monitor.setTextColor(txtColor)
    monitor.clear()

    -- 4. Process Markdown-ish formatting (bold/headers)
    local raw = entry.message or ""
    raw = raw:gsub("%*%*(.-)%*%*", function(s) return s:upper() end)
    
    -- 5. Wrap text based on the NEW width
    local lines = wrapText(raw, w)

    -- 6. Calculate Vertical Centering
    -- Start drawing at this Y position to center the block of text
    local startY = math.floor((h - #lines) / 2) + 1
    if startY < 1 then startY = 1 end

    -- 7. Draw Lines with Horizontal Centering
    for i = 1, #lines do
        if (startY + i - 1) <= h then -- Don't draw off screen
            local currentLine = lines[i]
            -- Calculate X offset for centering
            local startX = math.floor((w - #currentLine) / 2) + 1
            if startX < 1 then startX = 1 end
            
            monitor.setCursorPos(startX, startY + i - 1)
            monitor.write(currentLine)
        end
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

