-------------------------------
-- billboard.lua (full script)
-------------------------------

term.clear()
term.setCursorPos(1,1)

local CONFIG_FILE = "billboard.conf"

-------------------------------
-- CONFIG SAVE / LOAD
-------------------------------
local function saveConfig(channel, jsonFile)
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serialize({channel = channel, jsonFile = jsonFile}))
    f.close()
end

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then return nil end
    local f = fs.open(CONFIG_FILE, "r")
    local raw = f.readAll()
    f.close()
    return textutils.unserialize(raw)
end

-------------------------------
-- BOOT MENU WITH TIMEOUT
-------------------------------
local cfg = loadConfig()

print("FPS-Create Billboard")
print("---------------------")

if cfg then
    print("Saved config found:")
    print("Channel: " .. cfg.channel)
    print("JSON: " .. cfg.jsonFile)
    print("")
    print("[ENTER] Use saved config")
    print("[R] Reconfigure")
    print("[Q] Quit")
    print("")
    print("Auto-continue in 5 seconds...")

    local timer = os.startTimer(5)
    local choice = nil

    while true do
        local event, p1 = os.pullEvent()

        if event == "timer" and p1 == timer then
            choice = ""   -- auto-continue
            break
        elseif event == "key" then
            local key = p1
            local char = keys.getName(key)

            if char == "enter" then
                choice = ""
                break
            elseif char == "r" then
                choice = "r"
                break
            elseif char == "q" then
                choice = "q"
                break
            end
        end
    end

    if choice == "q" then
        print("Exiting...")
        return
    elseif choice == "r" then
        cfg = nil -- force reconfigure
    end
end

-------------------------------
-- CONFIG SETUP (if needed)
-------------------------------
local channel
local jsonFile

if cfg then
    channel = cfg.channel
    jsonFile = cfg.jsonFile
else
    term.clear()
    term.setCursorPos(1,1)
    print("Billboard Sender Setup")

    write("Enter channel name: ")
    channel = read()

    write("Enter JSON filename (e.g. spawn.json): ")
    jsonFile = read()

    saveConfig(channel, jsonFile)
end

-------------------------------
-- REMOTE JSON URL
-------------------------------
local baseURL = "https://raw.githubusercontent.com/VRCband/FPS-MC-List/refs/heads/main/"
local jsonURL = baseURL .. jsonFile
local localJSON = "billboard.json"

-------------------------------
-- OPEN ALL MODEMS
-------------------------------
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

-------------------------------
-- DETECT MONITORS
-------------------------------
local monitors = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitors[name] = peripheral.wrap(name)
    end
end

if next(monitors) == nil then
    error("ERROR: No monitors detected. Place at least one monitor touching the computer.")
end

-------------------------------
-- DOWNLOAD + LOAD JSON
-------------------------------
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

-------------------------------
-- TEXT WRAPPING
-------------------------------
local function wrapText(text, width)
    local lines = {}
    for line in text:gmatch("([^\n]+)") do
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

-------------------------------
-- RENDER TEXT TO MONITOR
-------------------------------
local function renderText(monitor, entry)
    local scale = tonumber(entry.Text_Size) or 1
    scale = math.max(0.5, math.min(5, scale))
    monitor.setTextScale(scale)

    local w, h = monitor.getSize()

    local bgColor = colors[entry.bgColor] or colors.black
    local txtColor = colors[entry.Text_Color] or colors.white
    monitor.setBackgroundColor(bgColor)
    monitor.setTextColor(txtColor)
    monitor.clear()

    local raw = entry.message or ""
    raw = raw:gsub("%*%*(.-)%*%*", function(s) return s:upper() end)

    local lines = wrapText(raw, w)

    local startY = math.floor((h - #lines) / 2) + 1
    if startY < 1 then startY = 1 end

    for i = 1, #lines do
        if (startY + i - 1) <= h then
            local currentLine = lines[i]
            local startX = math.floor((w - #currentLine) / 2) + 1
            if startX < 1 then startX = 1 end

            monitor.setCursorPos(startX, startY + i - 1)
            monitor.write(currentLine)
        end
    end
end

-------------------------------
-- DISPATCH MESSAGE
-------------------------------
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

-------------------------------
-- MAIN LOOP
-------------------------------
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

