-- cmd_stats_board.lua
-- Pure-commands dashboard. If commands fail, it shows the error once and:
--  • Uptime → script runtime  
--  • Players → empty list

-------------------------------------------------------------------------------
-- 1) SETUP
-------------------------------------------------------------------------------
if not commands or type(commands.exec) ~= "function" then
  error("This script needs a Command Computer (commands API).")
end
local cmd = commands

-- Prompt for text scale
term.clear()
term.setCursorPos(1,1)
write("Enter text scale (1–5, default 1): ")
local textScale = tonumber(read()) or 1

-- Wrap your monitor
local mon = peripheral.find("monitor")
if not mon then error("Attach a monitor!") end
mon.setTextScale(textScale)

-- Ensure playtime objective exists
pcall(function()
  cmd.exec("scoreboard objectives add playtime minecraft.custom:minecraft.play_one_minute PlayTime")
end)

-- Track script start for fallback uptime
local scriptStart = os.time()

-- State
local shutdownAt
local seenError = false  -- so we only flash the first error

-------------------------------------------------------------------------------
-- 2) HELPERS
-------------------------------------------------------------------------------
local function fmtDuration(sec)
  local h = math.floor(sec/3600); sec = sec - h*3600
  local m = math.floor(sec/60);   sec = sec - m*60
  return string.format("%dh %02dm %02ds", h, m, sec)
end

-- Query server ticks → seconds
local function getUptimeSec()
  local ok, out = cmd.exec("time query gametime")
  if not ok or type(out) ~= "string" then
    if not seenError then
      mon.clear(); mon.setCursorPos(1,1)
      mon.write("ERROR: time query failed")
      seenError = true
      sleep(3)
    end
    -- fallback to script runtime
    return os.time() - scriptStart
  end
  local ticks = tonumber(out:match("%d+")) or 0
  return math.floor(ticks / 20)
end

-- Get online player names
local function getPlayerList()
  local ok, out = cmd.exec("list")
  if not ok or type(out) ~= "string" then
    if not seenError then
      mon.clear(); mon.setCursorPos(1,1)
      mon.write("ERROR: list command failed")
      seenError = true
      sleep(3)
    end
    return {}
  end
  local part = out:match(":%s*(.*)")
  if not part or part == "" then return {} end
  local t = {}
  for name in part:gmatch("([^,]+)") do
    t[#t+1] = name:match("^%s*(.-)%s*$")
  end
  return t
end

-- Get a player’s playtime (minutes→seconds)
local function getPlayerPlaytime(name)
  local ok, out = cmd.exec("scoreboard players get "..name.." playtime")
  if not ok or type(out) ~= "string" then return 0 end
  local mins = tonumber(out:match(" has (%d+) ")) or 0
  return mins * 60
end

-------------------------------------------------------------------------------
-- 3) RENDERERS
-------------------------------------------------------------------------------
local function drawDashboard()
  local up   = getUptimeSec()
  local pls  = getPlayerList()

  mon.clear()
  mon.setCursorPos(1,1)
  mon.write("=== Server Status ===")

  mon.setCursorPos(1,3)
  mon.write("Uptime: " .. fmtDuration(up))

  mon.setCursorPos(1,5)
  mon.write("Players: " .. #pls)

  local y = 7
  for _, name in ipairs(pls) do
    local pt = getPlayerPlaytime(name)
    mon.setCursorPos(1,y)
    mon.write(string.format("%s (%s)", name, fmtDuration(pt)))
    y = y + 1
  end
end

local function drawShutdownOverlay()
  if not shutdownAt then return end
  local now = os.time()
  if now >= shutdownAt then
    cmd.exec("stop")
    return
  end
  local rem = shutdownAt - now
  local msg = string.format("SHUTDOWN IN %02d:%02d",
    math.floor(rem/60), rem%60)

  local w,h = mon.getSize()
  mon.setBackgroundColor(colors.red)
  mon.clear()
  mon.setTextColor(colors.white)
  mon.setTextScale(textScale * 2)
  mon.setCursorPos(math.floor((w-#msg)/2)+1, math.floor(h/2))
  mon.write(msg)
  mon.setTextScale(textScale)
  mon.setBackgroundColor(colors.black)
end

-------------------------------------------------------------------------------
-- 4) INPUT & LOOPS
-------------------------------------------------------------------------------
local function keyListener()
  while true do
    local _,k = os.pullEvent("key")
    if k == keys.s then
      term.clear(); term.setCursorPos(1,1)
      write("Shutdown in seconds: ")
      local d = tonumber(read())
      if d and d>0 then
        shutdownAt = os.time() + d
        os.startTimer(1)
      end
    elseif k == keys.q then
      error("Exiting")
    end
  end
end

local function mainLoop()
  os.startTimer(1)
  while true do
    os.pullEvent("timer")
    drawDashboard()
    drawShutdownOverlay()
    os.startTimer(1)
  end
end

print("Press S to schedule shutdown, Q to quit.")
parallel.waitForAny(mainLoop, keyListener)
