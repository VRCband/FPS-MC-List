-- billboard.lua
-- Self-update URL: https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/billboard.lua

-- OPEN ALL MODEMS
for _, side in ipairs({ "left","right","top","bottom","back","front" }) do
  if peripheral.getType(side) == "modem" then rednet.open(side) end
end

-- SELF-UPDATE LISTENER
local function listenForUpdate()
  while true do
    local _, msg = rednet.receive("billboard_update")
    if msg == "update" then
      print("Updating sender…")
      local name = shell.getRunningProgram()
      local url  = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/billboard.lua"
      if fs.exists(name) then fs.delete(name) end
      shell.run("wget", url, name)
      print("Restarting updated sender…")
      shell.run(name)
      return
    end
  end
end

-- LOAD LAST CONFIG
local cfgFile, lastChan, lastJSON = "sender.cfg"
if fs.exists(cfgFile) then
  local f = fs.open(cfgFile,"r")
  local ok,data = pcall(textutils.unserialize, f.readAll())
  f.close()
  if ok and type(data)=="table" then lastChan, lastJSON = data.channel, data.jsonFile end
end

-- PROMPT WITH 5s TIMEOUT
local function promptDefault(prompt, default)
  local timer = os.startTimer(5)
  write(string.format("%s [%s]: ", prompt, default or ""))
  while true do
    local ev, p = os.pullEvent()
    if ev=="timer" and p==timer then return nil end
    if ev=="char" or ev=="key" then
      local input = read()
      return input~="" and input or nil
    end
  end
end

-- CHANNEL
term.clear(); term.setCursorPos(1,1)
local ci = promptDefault("Enter channel", lastChan)
local channel = ci or lastChan
if not channel then error("No channel provided.") end

-- JSON FILENAME
local fi = promptDefault("Enter JSON filename", lastJSON)
local jsonFile = fi or lastJSON
if not jsonFile then error("No JSON filename provided.") end

-- SAVE CONFIG
do
  local f = fs.open(cfgFile,"w")
  f.write(textutils.serialize({ channel=channel, jsonFile=jsonFile }))
  f.close()
end

-- BASE JSON URL ONLY
local baseJSON = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/"
local fullJSON = baseJSON .. jsonFile
local jsonPath = "billboard.json"

-- DISCOVER LOCAL MONITORS
local monitors = {}
print("\nDetected monitors:")
for _, name in ipairs(peripheral.getNames()) do
  if peripheral.getType(name)=="monitor" then
    monitors[name] = peripheral.wrap(name)
    print(" - "..name)
  end
end

-- LOCAL RENDER (wrapped + centered)
local function renderLocally(m, e)
  m.setBackgroundColor(colors[e.bgColor] or colors.black)
  m.clear()
  m.setTextColor(colors[e.Text_Color] or colors.white)
  m.setTextScale(tonumber(e.Text_Size) or 1)

  local w,h = m.getSize()
  local msg = e.message or ""
  local lines = {}

  for word in msg:gmatch("%S+") do
    if #lines==0 then
      lines[1]=word
    else
      local test = lines[#lines].." "..word
      if #test<=w then lines[#lines]=test
      else lines[#lines+1]=word end
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

-- DOWNLOAD & PARSE JSON
local function loadMessages()
  if fs.exists(jsonPath) then fs.delete(jsonPath) end
  shell.run("wget", fullJSON, jsonPath)
  local f = fs.open(jsonPath,"r")
  local raw = f.readAll()
  f.close()
  return textutils.unserializeJSON(raw)
end

-- DISPATCH
local routerID = rednet.lookup("billboard","router")
local function dispatch(e)
  e.channel = channel
  local target = e.monitorID or "all"
  local dur    = tonumber(e.duration) or 5

  if target=="all" or target=="local" then
    for _,m in pairs(monitors) do renderLocally(m,e) end
  elseif routerID then
    rednet.send(routerID, e, "billboard")
  end

  sleep(dur)
end

-- INITIAL JSON FETCH
print("Fetching initial JSON → "..fullJSON)
local ok,msgs = pcall(loadMessages)
if not ok then error("JSON download failed: "..tostring(msgs)) end

-- MAIN LOOP
local function mainLoop()
  while true do
    for _,e in ipairs(loadMessages()) do dispatch(e) end
  end
end

-- RUN SENDER + UPDATE LISTENER
parallel.waitForAny(mainLoop, listenForUpdate)
