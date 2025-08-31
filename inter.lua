-- inter.lua
-- Self-update URL: https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/inter.lua

-- OPEN ALL MODEMS
for _, side in ipairs({ "left","right","top","bottom","back","front" }) do
  if peripheral.getType(side)=="modem" then rednet.open(side) end
end

-- SELF-UPDATE LISTENER
local function listenForUpdate()
  while true do
    local _, msg = rednet.receive("billboard_update")
    if msg=="update" then
      print("Updating router…")
      local name = shell.getRunningProgram()
      local url  = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/inter.lua"
      if fs.exists(name) then fs.delete(name) end
      shell.run("wget",url,name)
      print("Restarting updated router…")
      shell.run(name)
      return
    end
  end
end

-- ROUTER LOOP
local function routerLoop()
  rednet.host("billboard","router")
  while true do
    local _, msg = rednet.receive("billboard")
    if type(msg)=="table" and msg.channel then
      local proto = "billboard_"..msg.channel
      rednet.broadcast(msg, proto)
      print("Forwarded on channel:", msg.channel)
    end
  end
end

-- RUN ROUTER + UPDATE LISTENER
parallel.waitForAny(routerLoop, listenForUpdate)
