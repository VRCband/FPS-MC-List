-- google_calendar.lua
-- Fetch and display public Google Calendar events in List or Month-Grid mode.

-- UTILITIES -----------------------------------------------------------

-- URL-encode a string (for Calendar ID, API key, timestamps)
local function urlEncode(str)
  if not str then return "" end
  str = str:gsub("\n", "\r\n")
  str = str:gsub("([^%w _~%-%.])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return str:gsub(" ", "%%20")
end

-- Read a line with a prompt
local function prompt(msg)
  write(msg)
  return read()
end

-- Sleep, showing a message on monitor if provided
local function safeSleep(sec, mon, notice)
  if notice and mon then
    mon.clear()
    mon.setCursorPos(1,1)
    mon.write(notice)
  end
  sleep(sec)
end

-- Fetch JSON from URL, return Lua table or error
local function fetchJSON(url)
  local resp, err = http.get(url)
  if not resp then return nil, "HTTP error: "..tostring(err) end
  local body = resp.readAll()
  resp.close()
  local ok, js = pcall(textutils.unserializeJSON, body)
  if not ok then return nil, "JSON parse error" end
  return js
end

-- FORMAT TIMESTAMPS --------------------------------------------------

-- ISO8601 now (UTC) for list view
local function nowISO()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Start-of-month and next month for month grid
local function monthBounds()
  local t = os.date("*t")
  local year, month = t.year, t.month
  local thisStart = string.format("%04d-%02d-01T00:00:00Z", year, month)
  local nYear, nMonth = year, month + 1
  if nMonth == 13 then nMonth, nYear = 1, year + 1 end
  local nextStart = string.format("%04d-%02d-01T00:00:00Z", nYear, nMonth)
  return thisStart, nextStart
end

-- FORMAT AND RENDER ---------------------------------------------------

-- Format ISO "YYYY-MM-DDT..." → "MM/DD"
local function fmtDateDay(iso)
  local y,mo,d = iso:match("^(%d+)%-(%d+)%-(%d+)")
  return string.format("%02d/%02d", tonumber(mo), tonumber(d))
end

-- Draw next-N events as a list
local function drawList(mon, items)
  mon.clear()
  mon.setCursorPos(1,1)
  mon.write("Upcoming Events:")
  for i,ev in ipairs(items) do
    if not ev.start then break end
    local start = ev.start.dateTime or ev.start.date
    mon.setCursorPos(1, i+1)
    mon.write(string.format("%2d) %s - %s",
      i, fmtDateDay(start), ev.summary or "(no title)")
    )
  end
end

-- Draw a month-grid with day numbers, marking event days
local function drawMonthGrid(mon, items)
  mon.clear()
  local w,h = mon.getSize()
  -- count events per day
  local counts = {}
  for _,ev in ipairs(items) do
    local iso = ev.start.dateTime or ev.start.date
    local _,_,day = iso:match("^(%d+)%-(%d+)%-(%d+)")
    day = tonumber(day)
    counts[day] = (counts[day] or 0) + 1
  end

  -- compute calendar layout
  local first, nextm = monthBounds()
  local t0 = os.time({year=first:sub(1,4), month=first:sub(6,7), day=1})
  local wday1 = os.date("*t", t0).wday  -- 1=Sunday…7=Saturday
  local daysInMonth = os.date("*t", os.time{year=first:sub(1,4),
                               month=(first:sub(6,7)+1)%12,day=0}).day

  -- cell width & heading
  local cellW = math.floor(w/7)
  local headers = {"Su","Mo","Tu","We","Th","Fr","Sa"}
  for i,hd in ipairs(headers) do
    local x = (i-1)*cellW + 1
    mon.setCursorPos(x,1)
    mon.write(hd)
  end

  -- draw each day
  local row, col = 2, wday1
  for day=1,daysInMonth do
    local x = (col-1)*cellW + 1
    local txt = tostring(day)
    if counts[day] and counts[day] > 0 then
      txt = txt.."*"  -- marker for events
    end
    mon.setCursorPos(x, row)
    mon.write(txt)
    col = col + 1
    if col > 7 then col=1; row=row+1 end
  end
end

-- MAIN ----------------------------------------------------------------

-- 1) Initial prompts
term.clear(); term.setCursorPos(1,1)
print("Google Calendar Viewer")
local calId = prompt("Calendar ID: ")
local apiKey= "AIzaSyCDMxDebtI7ciwQAmJ3lXHcbSYt-FwaC_s"
local mode  = prompt("Mode (list/month): "):lower()

-- 2) Monitor setup
local mon = peripheral.find("monitor")
if not mon then error("Attach a monitor and enable HTTP.") end
mon.setTextScale(1)

-- 3) Build URLs
local base = "https://www.googleapis.com/calendar/v3/calendars/"
local listURL = string.format(
  "%s%s/events?key=%s&timeMin=%s&maxResults=10&singleEvents=true&orderBy=startTime",
  base, urlEncode(calId), urlEncode(apiKey), urlEncode(nowISO())
)
local monthStart, monthEnd = monthBounds()
local gridURL = string.format(
  "%s%s/events?key=%s&timeMin=%s&timeMax=%s&singleEvents=true&orderBy=startTime&maxResults=250",
  base, urlEncode(calId), urlEncode(apiKey),
  urlEncode(monthStart), urlEncode(monthEnd)
)

-- 4) Refresh loop
while true do
  local ok, data, notice

  if mode == "month" or mode == "m" then
    data, notice = fetchJSON(gridURL)
    if not data then
      drawList(mon, {})  -- clear
      mon.setCursorPos(1,1)
      mon.write("Error fetching grid:")
      mon.setCursorPos(1,2)
      mon.write(notice)
    else
      drawMonthGrid(mon, data.items or {})
    end

  else  -- default to list view
    data, notice = fetchJSON(listURL)
    if not data then
      mon.clear()
      mon.setCursorPos(1,1)
      mon.write("Error fetching list:")
      mon.setCursorPos(1,2)
      mon.write(notice)
    else
      drawList(mon, data.items or {})
    end
  end

  safeSleep(60, mon, "Refreshing in 60s…")
end
