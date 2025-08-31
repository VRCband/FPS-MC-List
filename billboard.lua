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


-- Utility: wrap a single paragraph to at most `width` chars
local function wrapToWidth(text, width)
  local lines = {}
  local i = 1
  while i <= #text do
    -- Grab up to width chars
    local chunk = text:sub(i, i + width - 1)
    -- Find last space in chunk
    local wrapPos = chunk:match("^.*() ") or 0
    if wrapPos > 0 and #chunk == width then
      -- break at last space
      lines[#lines + 1] = text:sub(i, i + wrapPos - 2)
      i = i + wrapPos
    else
      -- no space, or chunk shorter than width: hard break
      lines[#lines + 1] = chunk
      i = i + #chunk
    end
    -- skip leading spaces on next line
    while text:sub(i, i) == " " do i = i + 1 end
  end
  return lines
end

-- New renderText (or renderLocally) function
local function renderTextCentered(monitor, entry)
  local w, h = monitor.getSize()
  local message = entry.message or ""

  -- 1) get wrapped lines
  local lines = wrapToWidth(message, w)

  -- 2) vertical centering
  local total = #lines
  local startY = math.floor(h / 2) - math.floor(total / 2)
  if startY < 1 then startY = 1 end

  -- 3) paint each line, horizontally centered
  monitor.setBackgroundColor(colors[entry.bgColor] or colors.black)
  monitor.clear()
  monitor.setTextColor(colors[entry.Text_Color] or colors.white)
  monitor.setTextScale(tonumber(entry.Text_Size) or 1)

  for i, line in ipairs(lines) do
    local pad = math.floor((w - #line) / 2)
    monitor.setCursorPos(pad + 1, startY + i - 1)
    monitor.write(line)
  end
end




function renderLocally(monitor, entry)
  renderTextCentered(monitor, entry)
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
