-- cmd_query_manager.lua
-- A pure “commands” ComputerCraft dashboard:
-- • Uses the built-in commands API (Command Computer)  
-- • No HTTP, no RCON  
-- • Shows server uptime, player list + each player’s session time  
-- • Press S to schedule a shutdown; displays a big red countdown overlay  

-------------------------------------------------------------------------------
-- 1) SETUP
-------------------------------------------------------------------------------
-- Must be running on a Command Computer
if not commands or type(commands.exec) ~= "function" then
  error("This script requires a Command Computer with the commands API.")
end
local cmd = commands

-- Wrap the first attached monitor
local mon = peripheral.find("monitor")
if not mon then error("Attach a monitor to display stats.") end
mon.setTextScale(1)

-- Ensure a playtime objective exists (tracks minutes online)
pcall(function()
  cmd.exec("scoreboard objectives add playtime minecraft.custom:minecraft.play_one_minute PlayTime")
end)

-- cmd_query_manager.lua  (patched)

-- … at the top you already did:
-- local cmd = commands
-- local mon = peripheral.find("monitor")
-- …

-- 2) PARSERS & HELPERS
-------------------------------------------------------------------------------

-- Format seconds → "Xh Ym Zs" (unchanged)
local function fmtDuration(sec)
  local h = math.floor(sec/3600); sec = sec - h*3600
  local m = math.floor(sec/60);   sec = sec - m*60
  return string.format("%dh %02dm %02ds", h, m, sec)
end

-- Query server “age” in ticks, convert to seconds
local function getServerUptime()
  local ok, out = cmd.exec("time query gametime")
  if not ok or type(out) ~= "string" then
    return 0
  end
  local ticks = tonumber(out:match("%d+")) or 0
  return math.floor(ticks / 20)
end

-- Parse `/list` to get an array of player names
local function getPlayerList()
  local ok, out = cmd.exec("list")
  if not ok or type(out) ~= "string" then
    return {}
  end

  -- out looks like: "There are 2/20 players online: Alice, Bob"
  local listPart = out:match(":%s*(.*)")
  if not listPart then return {} end

  local names = {}
  for name in listPart:gmatch("([^,]+)") do
    names[#names+1] = name:match("^%s*(.-)%s*$")
  end
  return names
end

-- Query a single player’s playtime (in minutes)
local function getPlaytime(name)
  local ok, out = cmd.exec("scoreboard players get " .. name .. " playtime")
  if not ok or type(out) ~= "string" then
    return 0
  end

  -- out ≈ "Alice has 5 [in playtime]"
  local score = tonumber(out:match(" has (%d+) ")) or 0
  return score
end


-------------------------------------------------------------------------------
-- 3) RENDERERS
-------------------------------------------------------------------------------
-- Draw the main dashboard
local function drawDashboard()
  local uptimeSec = getServerUptime()
  local players   = getPlayerList()

  mon.clear()
  mon.setCursorPos(1,1)
  mon.write("=== Server Status ===")

  mon.setCursorPos(1,3)
  mon.write("Uptime: " .. fmtDuration(uptimeSec))

  mon.setCursorPos(1,5)
  mon.write(string.format("Players Online: %d", #players))

  local y = 7
  for _, name in ipairs(players) do
    local mins = getPlaytime(name)
    mon.setCursorPos(1, y)
    mon.write(string.format("%s (%s)", name, fmtDuration(mins * 60)))
    y = y + 1
  end
end

-- Draw a full-screen red shutdown countdown
local shutdownAt
local function drawShutdownOverlay()
  if not shutdownAt then return end
  local now = os.time()
  if now >= shutdownAt then
    mon.clear()
    mon.setCursorPos(1,1)
    mon.write("SERVER IS SHUTTING DOWN")
    return
  end

  local rem = shutdownAt - now
  local msg = string.format("SHUTDOWN IN %02d:%02d", math.floor(rem/60), rem%60)

  local w,h = mon.getSize()
  mon.setBackgroundColor(colors.red)
  mon.clear()
  mon.setTextColor(colors.white)
  mon.setTextScale(2)

  local x = math.floor((w - #msg) / 2) + 1
  local y = math.floor(h / 2)
  mon.setCursorPos(x, y)
  mon.write(msg)

  mon.setTextScale(1)
  mon.setBackgroundColor(colors.black)
end

-------------------------------------------------------------------------------
-- 4) INPUT LOOP
-------------------------------------------------------------------------------
-- Press S to schedule shutdown, Q to quit
local function keyListener()
  while true do
    local _, key = os.pullEvent("key")
    if key == keys.s then
      term.clear(); term.setCursorPos(1,1)
      write("Shutdown in how many seconds? ")
      local d = tonumber(read())
      if d and d > 0 then
        shutdownAt     = os.time() + d
        os.startTimer(d)
      end
    elseif key == keys.q then
      error("Exiting manager.")
    end
  end
end

-------------------------------------------------------------------------------
-- 5) MAIN LOOP
-------------------------------------------------------------------------------
-- Kick off the first periodic update
os.startTimer(1)

local function mainLoop()
  while true do
    local ev, id = os.pullEvent("timer")
    if shutdownAt and id == shutdownAt then
      cmd.exec("stop")
    end

    -- Redraw dashboard + overlay
    drawDashboard()
    drawShutdownOverlay()

    -- next update in 1s
    os.startTimer(1)
  end
end

print("Press 'S' to schedule shutdown, 'Q' to quit.")
parallel.waitForAny(mainLoop, keyListener)
