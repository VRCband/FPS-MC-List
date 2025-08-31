-- CONFIG
local jsonPath = "billboard.json"
local jsonURL = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/billboard.json"

-- Discover all monitors
local monitors = {}
for _, name in ipairs(peripheral.getNames()) do
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

-- Render text message
local function renderText(monitor, entry)
    monitor.setBackgroundColor(colors[entry.bgColor] or colors.black)
    monitor.clear()
    monitor.setTextColor(colors[entry.Text_Color] or colors.white)
    monitor.setTextScale(tonumber(entry.Text_Size) or 1)

    local w, h = monitor.getSize()
    local msg = centerText(entry.message, w)
    monitor.setCursorPos(1, math.floor(h / 2))
    monitor.write(msg)
end

-- Render image from .nfp file
local function renderImage(monitor, imagePath)
    local image = paintutils.loadImage(imagePath)
    if image then
        monitor.setBackgroundColor(colors.black)
        monitor.clear()
        paintutils.drawImage(image, 1, 1)
    else
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write("Failed to load image")
    end
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
        local duration = tonumber(entry.duration) or 5

        -- If imageURL is present, download and render image
        if entry.imageURL then
            local imagePath = "temp_image.nfp"
            shell.run("wget", entry.imageURL, imagePath)
            for id, monitor in pairs(monitors) do
                if target == "all" or id == target then
                    renderImage(monitor, imagePath)
                end
            end
            fs.delete(imagePath)
        elseif entry.message then
            for id, monitor in pairs(monitors) do
                if target == "all" or id == target then
                    renderText(monitor, entry)
                end
            end
        end

        sleep(duration)
    end

    -- Refresh JSON from remote source
    shell.run("wget", jsonURL, jsonPath)
end

