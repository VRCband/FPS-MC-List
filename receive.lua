-- receive.lua
-- Self-update URL: https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/receive.lua

-- OPEN ALL MODEMS
for _, side in ipairs({ "left","right","top","bottom","back","front" }) do
  if peripheral.getType(side)=="modem" then rednet.open(side) end
end

-- SELF-UPDATE LISTENER
local function listenForUpdate()
  while true do
    local _, msg = rednet.receive("billboard_update")
    if msg=="update" then
      print("Updating receiver…")
      local name = shell.getRunningProgram()
      local url  = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/receive.lua"
      if fs.exists(name) then fs.delete(name) end
      shell.run("wget",url,name)
      print("Restarting updated receiver…")
      shell.run(name)
      return
    end
  end
end

-- LOAD LAST CHANNEL
local cfgFile, lastChan = "receiver.cfg"
if fs.exists(cfgFile) then
  local f = fs.open(cfgFile,"r")
  local ok,data = pcall(textutils.unserialize, f.readAll())
  f.close()
  if ok and type(data)=="table" then lastChan = data.channel end
end

-- PROMPT WITH TIMEOUT
local function promptDefault(prompt, default)
  local timer = os.startTimer(5)
  write(string.format("%s [%s]: ", prompt, default or ""))
  while true do
    local ev,p = os.pullEvent()
    if ev=="timer" and p==timer then return nil end
    if ev=="char" or ev=="key" then
      local input = read()
      return input~="" and input or nil
    end
  end
end

-- CHANNEL SELECTION
term.clear(); term.setCursorPos(1,1)
local ci = promptDefault("Enter channel", lastChan)
local channel = ci or lastChan
if not channel then error("No channel provided.") end

-- SAVE CHANNEL
do
  local f = fs.open(cfgFile,"w")
  f.write(textutils.serialize({ channel=channel }))
  f.close()
end

local proto = "billboard_"..channel

-- DISCOVER ALL MONITORS
local monitors = {}
for _, name in ipairs(peripheral.getNames()) do
  if peripheral.getType(name)=="monitor" then
    monitors[name] = peripheral.wrap(name)
  end
end
if not next(monitors) then error("No monitors attached") end

-- RENDER HELPERS (image + wrapped text)
local function renderImage(url)
  local path="temp_image.nfp"
  if fs.exists(path) then fs.delete(path) end
  shell.run("wget",url,path)
  local img=paintutils.loadImage(path); if not img then return end
  for _,m in pairs(monitors) do
    local mw,mh=m.getSize(); local iw,ih=#img[1],#img
    local scaled=img
    if iw>mw or ih>mh then
      local sc=math.min(mw/iw,mh/ih); local tmp={}
      for y=1,mh do tmp[y]={}
        for x=1,mw do
          local sx=math.max(1,math.min(iw,math.floor(x/sc)))
          local sy=math.max(1,math.min(ih,math.floor(y/sc)))
          tmp[y][x]=img[sy][sx]
        end
      end
      scaled=tmp
    end
    m.setBackgroundColor(colors.black); m.clear()
    paintutils.drawImage(scaled,1,1)
  end
end

local function renderText(e)
  for _,m in pairs(monitors) do
    m.setBackgroundColor(colors[e.bgColor] or colors.black)
    m.clear(); m.setTextColor(colors[e.Text_Color] or colors.white)
    m.setTextScale(tonumber(e.Text_Size) or 1)
    local w,h=m.getSize(); local msg=e.message or ""
    local lines={}
    for word in msg:gmatch("%S+") do
      if #lines==0 then lines[1]=word
      else
        local test=lines[#lines].." "..word
        if #test<=w then lines[#lines]=test else lines[#lines+1]=word end
      end
    end
    local total=#lines; local startY=math.floor(h/2)-math.floor(total/2)
    for i,line in ipairs(lines) do
      local pad=math.floor((w-#line)/2)
      m.setCursorPos(pad+1,startY+i-1); m.write(line)
    end
  end
end

-- MAIN LOOP
local function mainLoop()
  while true do
    local _,msg = rednet.receive(proto)
    if type(msg)=="table" then
      if msg.imageURL then renderImage(msg.imageURL)
      elseif msg.message then renderText(msg) end
      sleep(tonumber(msg.duration) or 5)
    end
  end
end

parallel.waitForAny(mainLoop, listenForUpdate)
