-- cmd_stats_board.lua
-- A pure-commands dashboard for ComputerCraft Command Computers.
-- No RCON, no HTTP. Uses only `commands.exec(...)` to gather data:
--  • Server uptime via `/time query gametime`
--  • Player count and list via `/list`
--  • Per-player session time via a `playtime` scoreboard (stat.play_one_minute)
--  • Schedule a `/stop` shutdown with a countdown overlay
--  • Customizable text scale (e.g. 4)

-------------------------------------------------------------------------------
-- 1) SETUP
-------------------------------------------------------------------------------
if not commands or type(commands.exec) ~= "function" then
  error("This script requires a Command Computer (commands API).")
end
local cmd = commands

-- Prompt for text scale
term.clear()
term.setCursorPos(1,1)
write("Enter text scale (1-5, default 1): ")
local textScale = tonumber(read()) or 1

-- Wrap and configure the monitor
local mon = peripheral.find("monitor")
if not mon then error("Attach a monitor for display.") end
mon.setTextScale(textScale)

-- Ensure the playtime objective exists (tracks minutes automatically)
pcall(function()
  cmd.exec("scoreboard objectives add playtime minecraft.custom:minecraft.play_one_minute PlayTime")
end)

-- Shutdown state
local shutdownAt

-------------------------------------------------------------------------------
-- 2) HELPERS
-------------------------------------------------------------------------------
-- Format seconds → "Xh Ym Zs"
local function fmtDuration(sec)
  local h = math.floor(sec/3600); sec = sec - h*3600
  local m = math.floor(sec/60);   sec = sec - m*60
  local s = sec
  return string.format("%dh %02dm %02ds", h, m, s)
end

-- Query server uptime (ticks → seconds)
local function getUptimeSec()
  local ok, out = cmd.exec("time query gametime")
  if not ok or type(out) ~= "string" then return 0 end
  local ticks = tonumber(out:match("%d+")) or 0
  return math.floor(ticks / 20)
end

-- Get an array of online player names
local function getPlayerList()
  local ok, out = cmd.exec("list")
  if not ok or type(out) ~= "string" then return {} end
  -- "There are X/Y players online: Alice, Bob"
  local part = out:match(":%s*(.*)")
  if not part or part == "" then return {} end
  local names = {}
  for name in part:gmatch("([^,]+)") do
    names[#names+1] = name:match("^%s*(.-)%s*$")
  end
  return names
end

-- Query a player's playtime in minutes, convert → seconds
local function getPlayerPlaytime(name)
  local ok, out = cmd.exec("scoreboard players get " .. name .. " playtime")
  if not ok or type(out) ~= "string" then return 0 end
  local mins = tonumber(out:match(" has (%d+) ")) or 0
  return mins * 60
end

-------------------------------------------------------------------------------
-- 3) RENDERING
-------------------------------------------------------------------------------
local function drawDashboard()
  local uptime = getUptimeSec()
  local players = getPlayerList()

  mon.clear()
  mon.setCursorPos(1,1)
  mon.write("=== Server Status ===")

  mon.setCursorPos(1,3)
  mon.write("Uptime: " .. fmtDuration(uptime))

  mon.setCursorPos(1,5)
  mon.write("Players: " .. #players)

  local y = 7
  for _, name in ipairs(players) do
    local pt = getPlayerPlaytime(name)
    mon.setCursorPos(1, y)
    mon.write(string.format("%s (%s)", name, fmtDuration(pt)))
    y = y + 1
  end
end

local function drawShutdownOverlay()
  if not shutdownAt then return end
  local now = os.time()
  if now >= shutdownAt then
    -- execute the stop command once countdown reaches zero
    cmd.exec("stop")
    return
  end

  local rem = shutdownAt - now
  local msg = string.format("SHUTDOWN IN %02d:%02d", math.floor(rem/60), rem%60)

  local w,h = mon.getSize()
  mon.setBackgroundColor(colors.red)
  mon.clear()
  mon.setTextColor(colors.white)
  mon.setTextScale(textScale * 2)  -- make overlay text larger
  mon.setCursorPos(math.floor((w - #msg)/2)+1, math.floor(h/2))
  mon.write(msg)
  mon.setTextScale(textScale)
  mon.setBackgroundColor(colors.black)
end

-------------------------------------------------------------------------------
-- 4) INPUT & TIMERS
-------------------------------------------------------------------------------
-- Press S to schedule shutdown; Q to quit
local function keyListener()
  while true do
    local _, key = os.pullEvent("key")
    if key == keys.s then
      term.clear(); term.setCursorPos(1,1)
      write("Shutdown in seconds: ")
      local d = tonumber(read())
      if d and d > 0 then
        shutdownAt = os.time() + d
        os.startTimer(1)  -- kick off overlay/tick loop
      end
    elseif key == keys.q then
      error("Exiting stats board")
    end
  end
end

-------------------------------------------------------------------------------
-- 5) MAIN LOOP
-------------------------------------------------------------------------------
-- Start the periodic update
os.startTimer(1)
local function mainLoop()
  while true do
    local ev, id = os.pullEvent("timer")
    -- redraw every second
    drawDashboard()
    drawShutdownOverlay()
    os.startTimer(1)
  end
end

print("Press 'S' to schedule shutdown, 'Q' to quit.")
parallel.waitForAny(mainLoop, keyListener)
