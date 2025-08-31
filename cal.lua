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

-- … rest of your code stays the same, calling these helpers …
