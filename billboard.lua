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

-- Render text message with word wrapping
local function renderText(monitor, entry)
    monitor.setBackgroundColor(colors[entry.bgColor] or colors.black)
    monitor.clear()
    monitor.setTextColor(colors[entry.Text_Color] or colors.white)
    monitor.setTextScale(tonumber(entry.Text_Size) or 1)

    local w, h = monitor.getSize()
    local message = entry.message or ""
    local lines = {}

    -- Word wrap logic
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

    -- Center vertically
    local startY = math.max(1, math.floor((h - #lines) / 2))
    for i, line in ipairs(lines) do
        local pad = math.floor((w - #line) / 2)
        monitor.setCursorPos(pad + 1, startY + i - 1)
        monitor.write(line)
    end
end


-- Render image from .nfp file with scaling
local function renderImage(monitor, imagePath)
    local image = paintutils.loadImage(imagePath)
    if not image then
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write("Failed to load image")
        return
    end

    local mw, mh = monitor.getSize()
    local iw = #image[1]
    local ih = #image

    -- If image is too big, scale it down
    if iw > mw or ih > mh then
        local scaleX = mw / iw
        local scaleY = mh / ih
        local scale = math.min(scaleX, scaleY)

        local scaled = {}
        for y = 1, mh do
            local row = {}
            for x = 1, mw do
                local srcX = math.floor(x / scale)
                local srcY = math.floor(y / scale)
                srcX = math.max(1, math.min(srcX, iw))
                srcY = math.max(1, math.min(srcY, ih))
                row[x] = image[srcY][srcX]
            end
            scaled[y] = row
        end

        image = scaled
    end

    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    paintutils.drawImage(image, 1, 1)
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

-- Billboard loop
local function runBillboard()
    while true do
        local messages = loadMessages()
        for _, entry in ipairs(messages) do
            local target = entry.monitorID or "all"
            local duration = tonumber(entry.duration) or 5

            if entry.imageURL then
                local imagePath = "temp_image.nfp"
                if fs.exists(imagePath) then fs.delete(imagePath) end
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

        -- Refresh JSON from remote source (overwrite)
        if fs.exists(jsonPath) then fs.delete(jsonPath) end
        shell.run("wget", jsonURL, jsonPath)
    end
end

-- Shutdown listener
local function listenForShutdown()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.h then
            print("Shutdown triggered by keypress.")
            os.shutdown()
        end
    end
end

-- Run both billboard and shutdown listener in parallel
parallel.waitForAny(runBillboard, listenForShutdown)
