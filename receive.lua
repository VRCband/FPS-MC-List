-- receive.lua
-- Prompt for channel
term.clear()
term.setCursorPos(1,1)
print("Billboard Receiver")
write("Enter channel name: ")
local channel = read()

-- Open all modem types
for _, side in ipairs({"left","right","top","bottom","back","front"}) do
  if peripheral.getType(side) == "modem" then
    rednet.open(side)
  end
end

-- Find all monitors
local monitors = {}
for _, name in ipairs(peripheral.getNames()) do
  if peripheral.getType(name) == "monitor" then
    monitors[name] = peripheral.wrap(name)
  end
end
if next(monitors) == nil then error("No monitor attached") end

-- Render image helper
local function renderImage(imageURL)
  local path = "temp_image.nfp"
  if fs.exists(path) then fs.delete(path) end
  shell.run("wget", imageURL, path)
  local image = paintutils.loadImage(path)
  if not image then return end

  for _, monitor in pairs(monitors) do
    local mw, mh = monitor.getSize()
    local iw, ih = #image[1], #image
    local scaled = image

    if iw > mw or ih > mh then
      local scale = math.min(mw/iw, mh/ih)
      local tmp = {}
      for y=1,mh do
        tmp[y] = {}
        for x=1,mw do
          local srcX = math.max(1, math.min(iw, math.floor(x/scale)))
          local srcY = math.max(1, math.min(ih, math.floor(y/scale)))
          tmp[y][x] = image[srcY][srcX]
        end
      end
      scaled = tmp
    end

    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    paintutils.drawImage(scaled, 1, 1)
  end
end

-- Render text helper
local function renderText(entry)
  for _, monitor in pairs(monitors) do
    monitor.setBackgroundColor(colors[entry.bgColor] or colors.black)
    monitor.clear()
    monitor.setTextColor(colors[entry.Text_Color] or colors.white)
    monitor.setTextScale(tonumber(entry.Text_Size) or 1)

    local w, h    = monitor.getSize()
    local message = entry.message or ""
    local lines   = {}

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
    local startY     = centerLine - math.floor(totalLines / 2)

    for i, line in ipairs(lines) do
      local pad = math.floor((w - #line) / 2)
      monitor.setCursorPos(pad + 1, startY + i - 1)
      monitor.write(line)
    end
  end
end

-- Listen for all billboard messages, then filter by channel
while true do
  local _, msg = rednet.receive("billboard")
  if type(msg) == "table" and msg.channel == channel then
    if msg.imageURL then
      renderImage(msg.imageURL)
    elseif msg.message then
      renderText(msg)
    end
    sleep(tonumber(msg.duration) or 5)
  end
end
