-- billboard.lua
-- Self-update URL: https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/billboard.lua

-- Open all modem sides
for _, side in ipairs({ "left", "right", "top", "bottom", "back", "front" }) do
  if peripheral.getType(side) == "modem" then
    rednet.open(side)
  end
end

-- Self-update listener
local function listenForUpdate()
  while true do
    local _, msg = rednet.receive("billboard_update")
    if msg == "update" then
      print("Sender update signal received.")
      local name = shell.getRunningProgram()
      local url  = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/"..name
      if fs.exists(name) then fs.delete(name) end
      shell.run("wget", url, name)
      print("Restarting updated sender…")
      shell.run(name)
      return
    end
  end
end

-- CONFIG PERSISTENCE
local cfgFile = "sender.cfg"
local lastChan, lastJSON
if fs.exists(cfgFile) then
  local f = fs.open(cfgFile, "r")
  local ok,data = pcall(textutils.unserialize, f.readAll())
  f.close()
  if ok and type(data)=="table" then
    lastChan, lastJSON = data.channel, data.jsonFile
  end
end

-- PROMPT WITH TIMEOUT
local function promptDefault(prompt, default)
  local timer = os.startTimer(5)
  write(string.format("%s [%s]: ", prompt, default or ""))
  while true do
    local e, p = os.pullEvent()
    if e=="timer" and p==timer then return nil end
    if e=="char" or e=="key" then
      -- user started typing; read full line
      local input = read()
      return input~="" and input or nil
    end
  end
end

-- CHANNEL
term.clear(); term.setCursorPos(1,1)
local chanInput = promptDefault("Enter channel", lastChan)
local channel = chanInput or lastChan
if not channel then error("No channel provided.") end

-- JSON FILENAME
local fileInput = promptDefault("Enter JSON filename", lastJSON)
local jsonFile  = fileInput or lastJSON
if not jsonFile then error("No JSON filename provided.") end

-- SAVE CONFIG
local f = fs.open(cfgFile,"w")
f.write(textutils.serialize({ channel=channel, jsonFile=jsonFile }))
f.close()

-- STATIC CONFIG
local baseURL  = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/"
local fullURL  = baseURL..jsonFile
local jsonPath = "billboard.json"
local routerID = rednet.lookup("billboard","router")

-- MONITORS
local monitors = {}
print("\nDetected monitors:")
for _, name in ipairs(peripheral.getNames()) do
  if peripheral.getType(name)=="monitor" then
    monitors[name] = peripheral.wrap(name)
    print(" - "..name)
  end
end

-- LOCAL RENDER
local function renderLocally(m, e)
  m.setBackgroundColor(colors[e.bgColor] or colors.black)
  m.clear(); m.setTextColor(colors[e.Text_Color] or colors.white)
  m.setTextScale(tonumber(e.Text_Size) or 1)
  local w,h = m.getSize()
  -- word-wrap & center
  local msg, lines = e.message or "", {}
  for word in msg:gmatch("%S+") do
    if #lines==0 then lines[1]=word
    else
      local test = lines[#lines].." "..word
      if #test<=w then lines[#lines]=test else lines[#lines+1]=word end
    end
  end
  local total = #lines
  local startY = math.floor(h/2) - math.floor(total/2)
  for i,line in ipairs(lines) do
    local pad = math.floor((w-#line)/2)
    m.setCursorPos(pad+1, startY+i-1)
    m.write(line)
  end
end

-- JSON LOAD
local function loadMessages()
  if fs.exists(jsonPath) then fs.delete(jsonPath) end
  shell.run("wget", fullURL, jsonPath)
  local f = fs.open(jsonPath,"r"); local raw = f.readAll(); f.close()
  return textutils.unserializeJSON(raw)
end

-- Dispatch a single entry
local function dispatch(entry)
  entry.channel = channel
  -- Default to “all” when monitorID is nil
  local target   = entry.monitorID or "all"
  local duration = tonumber(entry.duration) or 5

  if target == "all" or target == "local" then
    -- render on every attached monitor
    for _, m in pairs(monitors) do
      renderLocally(m, entry)
    end

  elseif routerID then
    -- send to router for remote billboards
    rednet.send(routerID, entry, "billboard")
  else
    print("No router found; skipping remote dispatch.")
  end

  sleep(duration)
end


-- INITIAL FETCH
print("Fetching initial JSON from "..fullURL)
local ok, msgs = pcall(loadMessages)
if not ok then error("JSON download failed: "..tostring(msgs)) end

-- MAIN LOOP
local function mainLoop()
  while true do
    for _,e in ipairs(loadMessages()) do dispatch(e) end
  end
end

parallel.waitForAny(mainLoop, listenForUpdate)
