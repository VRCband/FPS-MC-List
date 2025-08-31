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

-- Helper: split on literal sep
local function split(str, sep)
  local parts, last = {}, 1
  sep = sep:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")
  for s,e in function() return str:find(sep, last, true) end do
    parts[#parts+1] = str:sub(last, s-1)
    last = e + 1
  end
  parts[#parts+1] = str:sub(last)
  return parts
end

-- Helper: wrap text to width
local function wrapToWidth(text, width)
  local lines, i = {}, 1
  while i <= #text do
    local chunk   = text:sub(i, i + width - 1)
    local wrapPos = chunk:match("^.*() ") or 0
    if wrapPos > 0 and #chunk == width then
      lines[#lines+1] = text:sub(i, i + wrapPos - 2)
      i = i + wrapPos
    else
      lines[#lines+1] = chunk
      i = i + #chunk
    end
    while text:sub(i,i) == " " do i = i + 1 end
  end
  return lines
end

-- Replace your existing renderTextCentered with this:
local function renderTextCentered(monitor, entry)
  local w, h    = monitor.getSize()
  local raw     = entry.message or ""
  local paras   = split(raw, "/n")
  local lines   = {}

  for _, para in ipairs(paras) do
    -- Heading?
    local head = para:match("^# (.+)")
    if head then
      lines[#lines+1] = head:upper()
      lines[#lines+1] = ""
    else
      -- Bold → UPPERCASE
      para = para:gsub("%*%*(.-)%*%*", function(s) return s:upper() end)
      -- Italic → remove stars
      para = para:gsub("%*(.-)%*", "%1")
      -- Wrap
      for _,l in ipairs(wrapToWidth(para, w)) do
        lines[#lines+1] = l
      end
      lines[#lines+1] = ""
    end
  end

  -- Remove trailing blank
  if lines[#lines] == "" then lines[#lines] = nil end

  -- Center vertically
  local total  = #lines
  local startY = math.floor((h - total) / 2) + 1

  -- Paint background first
  monitor.setBackgroundColor(colors[entry.bgColor] or colors.black)
  monitor.clear()

  -- Text styling
  monitor.setTextColor(colors[entry.Text_Color] or colors.white)
  monitor.setTextScale(tonumber(entry.Text_Size) or 1)

  -- Draw lines centered
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
