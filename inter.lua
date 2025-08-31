-- inter.lua

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
      print("Router update signal received.")
      local scriptName = shell.getRunningProgram()
      local scriptURL  = "https://github.com/VRCband/FPS-MC-List/raw/refs/heads/main/" .. scriptName
      if fs.exists(scriptName) then fs.delete(scriptName) end
      shell.run("wget", scriptURL, scriptName)
      print("Router update complete. Restarting script...")
      shell.run(scriptName)
      return
    end
  end
end

-- Router loop
local function routerLoop()
  rednet.host("billboard", "router")
  while true do
    local _, msg = rednet.receive("billboard")
    if type(msg) == "table" and msg.channel then
      local proto = "billboard_" .. msg.channel
      rednet.broadcast(msg, proto)
      print("Forwarded on channel:", msg.channel)
    end
  end
end

parallel.waitForAny(routerLoop, listenForUpdate)
