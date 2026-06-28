-- maintenance.lua

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

-- Raw message
local raw = "# DOWN FOR MAINTENANCE/nWe Are Working on It, Be Back soon!"

-- Parse lines
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

-- Find EVERY monitor name attached to the computer
local allPeripherals = peripheral.getNames()
local monitorCount = 0

for _, name in ipairs(allPeripherals) do
    if peripheral.getType(name) == "monitor" then
        monitorCount = monitorCount + 1
        local mon = peripheral.wrap(name)
        
        -- Individual Scaling for this specific monitor
        local bestScale = 0.5
        for _, scale in ipairs({5, 4, 3, 2, 1.5, 1, 0.5}) do
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
        
        -- Draw to this specific monitor
        mon.setTextScale(bestScale)
        mon.setBackgroundColor(colors.orange)
        mon.setTextColor(colors.black)
        mon.clear()

        local w, h = mon.getSize()
        local startY = math.floor((h - #lines) / 2) + 1

        for i, line in ipairs(lines) do
            local startX = math.floor((w - #line) / 2) + 1
            mon.setCursorPos(startX, startY + i - 1)
            mon.write(line)
        end
    end
end

if monitorCount == 0 then
    print("Error: No monitors detected!")
else
    print("Success: Message sent to " .. monitorCount .. " monitor(s).")
end
