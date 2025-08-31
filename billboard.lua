-- billboard.lua
-- Prompt for channel and JSON file
term.clear()
term.setCursorPos(1,1)
print("Billboard Sender Setup")

-- 1) Channel
write("Enter channel name: ")
local channel = read()

-- 2) JSON filename
write("Enter JSON filename (e.g. lobby.json): ")
local jsonFile = read()

-- CONFIG
local jsonPath = "billboard.json"
local baseURL  = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/"
local jsonURL  = baseURL .. jsonFile

-- Open all modem sides
for _, side in ipairs({"left","right","top","bottom","back","front"}) do
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
  local f   = fs.open(jsonPath, "r")
  local raw = f.readAll()
  f.close()
  return textutils.unserializeJSON(raw)
end

-- Local rendering fallback
local function renderLocally(monitor, entry)
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
      local test = lines[#lines] .. " " .. word
      if #test <= w then
        lines[#lines] = test
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

-- Dispatch: tag with channel, render local or broadcast
local function dispatch(entry)
  entry.channel = channel
  local target   = entry.monitorID or "all"
  local duration = tonumber(entry.duration) or 5

  if target == "local" then
    for _, m in pairs(monitors) do
      renderLocally(m, entry)
    end
  else
    rednet.broadcast(entry, "billboard")
  end

  sleep(duration)
end

-- Main loop
while true do
  local messages = loadMessages()
  for _, entry in ipairs(messages) do
    dispatch(entry)
  end
end
