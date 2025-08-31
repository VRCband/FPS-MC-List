-- maintenance.lua
-- A quick ComputerCraft script that parses a “# ” heading and centers text on an orange background,
-- automatically picking the largest textScale that fits your monitor.

-- Helper: split a string on a literal separator
local function split(str, sep)
  local parts, last = {}, 1
  while true do
    local s, e = str:find(sep, last, true)
    if not s then break end
    parts[#parts+1] = str:sub(last, s-1)
    last = e + 1
  end
  parts[#parts+1] = str:sub(last)
  return parts
end

-- Find an attached monitor
local mon = peripheral.find("monitor")
if not mon then error("Attach a monitor and enable HTTP.") end

-- Raw markdown‐style message
local raw = "# DOWN FOR MAINTENANCE/nWe Are Working on It, Be Back soon!"

-- 1) Parse into lines, handling `/n` as a newline and `# ` as a heading
local paras = split(raw, "/n")
local lines = {}
for _, para in ipairs(paras) do
  local h = para:match("^#%s*(.+)")
  if h then
    -- Heading: uppercase
    lines[#lines+1] = h:upper()
  else
    lines[#lines+1] = para
  end
end

-- 2) Pick the largest textScale that lets the block fit
local bestScale = 0.5
for _, scale in ipairs({2, 1.5, 1, 0.5}) do
  mon.setTextScale(scale)
  local w, h = mon.getSize()
  if #lines <= h then
    local ok = true
    for _, line in ipairs(lines) do
      if #line > w then ok = false break end
    end
    if ok then bestScale = scale break end
  end
end
mon.setTextScale(bestScale)

-- 3) Paint background then clear
mon.setBackgroundColor(colors.orange)
mon.clear()

-- 4) Set text color
mon.setTextColor(colors.white)

-- 5) Center vertically & horizontally, then write
local w, h = mon.getSize()
local total = #lines
local startY = math.floor((h - total) / 2) + 1

for i, line in ipairs(lines) do
  local pad = math.floor((w - #line) / 2) + 1
  mon.setCursorPos(pad, startY + i - 1)
  mon.write(line)
end
