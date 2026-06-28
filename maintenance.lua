-- maintenance.lua

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

-- 1) Find ALL attached monitors
local monitors = { peripheral.find("monitor") }
if #monitors == 0 then error("No monitors found! Attach at least one.") end

-- Raw markdown-style message
local raw = "# DOWN FOR MAINTENANCE/nWe Are Working on It, Be Back soon!"

-- 2) Parse into lines (Done once for all monitors)
local paras = split(raw, "/n")
local lines = {}
for _, para in ipairs(paras) do
  local h = para:match("^#%s*(.+)")
  if h then
    lines[#lines+1] = h:upper()
  else
    lines[#lines+1] = para
  end
end

-- 3) Iterate through every monitor and draw
for _, mon in ipairs(monitors) do
    
    -- Pick the largest textScale that fits THIS specific monitor
    -- We try from largest (5) to smallest (0.5)
    local bestScale = 0.5
    for _, scale in ipairs({5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1, 0.5}) do
        mon.setTextScale(scale)
        local w, h = mon.getSize()
        
        -- Check if the number of lines fits vertically
        if #lines <= h then
            local ok = true
            -- Check if every line fits horizontally
            for _, line in ipairs(lines) do
                if #line > w then 
                    ok = false 
                    break 
                end
            end
            
            if ok then 
                bestScale = scale 
                break 
            end
        end
    end
    
    -- Apply the best scale found for this monitor
    mon.setTextScale(bestScale)

    -- Paint background
    mon.setBackgroundColor(colors.orange)
    mon.clear()

    -- Set text color
    mon.setTextColor(colors.black)

    -- Center vertically & horizontally
    local w, h = mon.getSize()
    local totalLines = #lines
    local startY = math.floor((h - totalLines) / 2) + 1

    for i, line in ipairs(lines) do
        local startX = math.floor((w - #line) / 2) + 1
        -- Prevent negative/zero positions
        if startX < 1 then startX = 1 end
        if startY < 1 then startY = 1 end
        
        mon.setCursorPos(startX, startY + i - 1)
        mon.write(line)
    end
end

print("Maintenance message displayed on " .. #monitors .. " monitor(s).")
