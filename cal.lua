-- google_calendar_multi.lua
-- Fetch and display events from multiple public Google Calendars.

-- UTILITIES -----------------------------------------------------------

local function urlEncode(str)
  if not str then return "" end
  str = str:gsub("\n", "\r\n")
  str = str:gsub("([^%w _~%-%.])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return str:gsub(" ", "%%20")
end

local function prompt(msg)
  write(msg)
  return read()
end

local function safeSleep(sec, mon, notice)
  if notice and mon then
    mon.clear(); mon.setCursorPos(1,1)
    mon.write(notice)
  end
  sleep(sec)
end

local function fetchJSON(url)
  local resp, err = http.get(url)
  if not resp then return nil, "HTTP error: "..tostring(err) end
  local body = resp.readAll() resp.close()
  local ok, js = pcall(textutils.unserializeJSON, body)
  if not ok then return nil, "JSON parse error" end
  return js
end

-- DATE HELPERS --------------------------------------------------------

local function nowISO()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function monthBounds()
  local t = os.date("*t"); local y,m = t.year, t.month
  local start = string.format("%04d-%02d-01T00:00:00Z", y, m)
  local nm, ny = m+1, y
  if nm == 13 then nm, ny = 1, y+1 end
  local nextStart = string.format("%04d-%02d-01T00:00:00Z", ny, nm)
  return start, nextStart
end

local function fmtDateDay(iso)
  local y,mo,d = iso:match("^(%d+)%-(%d+)%-(%d+)")
  return string.format("%02d/%02d", tonumber(mo), tonumber(d))
end

-- DRAWERS -------------------------------------------------------------

local function drawList(mon, items)
  mon.clear(); mon.setCursorPos(1,1)
  mon.write("Upcoming Events:")
  for i, ev in ipairs(items) do
    local s = ev.start.dateTime or ev.start.date or ""
    mon.setCursorPos(1, i+1)
    mon.write(string.format("%2d) %s - %s",
      i, fmtDateDay(s), ev.summary or "(no title)")
    )
  end
end

local function drawMonthGrid(mon, items)
  mon.clear()
  local w,h = mon.getSize()
  local counts = {}
  for _, ev in ipairs(items) do
    local iso = ev.start.dateTime or ev.start.date or ""
    local _,_,day = iso:match("^(%d+)%-(%d+)%-(%d+)")
    if day then counts[tonumber(day)] = (counts[tonumber(day)] or 0) + 1 end
  end

  local thisStart, nextStart = monthBounds()
  local t0 = os.time{year=thisStart:sub(1,4),
                     month=thisStart:sub(6,7),day=1}
  local wday1 = os.date("*t", t0).wday  -- Sunday=1
  local daysInMonth = os.date("*t", os.time{year=thisStart:sub(1,4),
                              month=(thisStart:sub(6,7)+1)%12,day=0}).day

  local cellW = math.floor(w/7)
  local headers = {"Su","Mo","Tu","We","Th","Fr","Sa"}
  for i,hd in ipairs(headers) do
    local x = (i-1)*cellW + 1
    mon.setCursorPos(x,1); mon.write(hd)
  end

  local row, col = 2, wday1
  for day=1, daysInMonth do
    local x = (col-1)*cellW + 1
    local txt = tostring(day)
    if counts[day] and counts[day] > 0 then txt = txt.."*" end
    mon.setCursorPos(x, row); mon.write(txt)
    col = col + 1
    if col > 7 then col = 1; row = row + 1 end
  end
end

-- MAIN ----------------------------------------------------------------

-- 1) Prompts
term.clear(); term.setCursorPos(1,1)
print("Multi-Calendar Viewer")
print("Enter comma-separated Calendar IDs.")
print("For US Holidays, use: en.usa#holiday@group.v.calendar.google.com")
write("Calendar IDs: ")
local rawIds = read()


local apiKey = "AIzaSyCDMxDebtI7ciwQAmJ3lXHcbSYt-FwaC_s"

write("Mode (list/month): ")
local mode = read():lower()

-- parse IDs
local calendarIds = {}
for id in rawIds:gmatch("[^,]+") do
  id = id:match("^%s*(.-)%s*$")
  if #id > 0 then table.insert(calendarIds, id) end
end

-- 2) Monitor
local mon = peripheral.find("monitor")
if not mon then error("Attach a monitor and enable HTTP.") end
mon.setTextScale(1)

-- 3) Prebuild URLs
local base = "https://www.googleapis.com/calendar/v3/calendars/"
local listURLs = {}
local gridURLs = {}
local monthStart, monthEnd = monthBounds()

for _, calId in ipairs(calendarIds) do
  local enc = urlEncode(calId)
  listURLs[#listURLs+1] = string.format(
    "%s%s/events?key=%s&timeMin=%s&maxResults=10&singleEvents=true&orderBy=startTime",
     base, enc, urlEncode(apiKey), urlEncode(nowISO())
  )
  gridURLs[#gridURLs+1] = string.format(
    "%s%s/events?key=%s&timeMin=%s&timeMax=%s&singleEvents=true&orderBy=startTime&maxResults=250",
     base, enc, urlEncode(apiKey),
     urlEncode(monthStart), urlEncode(monthEnd)
  )
end

-- 4) Loop: fetch & merge
while true do
  if mode == "month" or mode == "m" then
    local allItems = {}
    for _, url in ipairs(gridURLs) do
      local data, err = fetchJSON(url)
      if data and data.items then
        for _,ev in ipairs(data.items) do table.insert(allItems, ev) end
      end
    end
    drawMonthGrid(mon, allItems)

  else  -- list view
    local allItems = {}
    for _, url in ipairs(listURLs) do
      local data, err = fetchJSON(url)
      if data and data.items then
        for _,ev in ipairs(data.items) do table.insert(allItems, ev) end
      end
    end
    -- sort by start time
    table.sort(allItems, function(a,b)
      local ta = a.start.dateTime or (a.start.date.."T00:00:00Z")
      local tb = b.start.dateTime or (b.start.date.."T00:00:00Z")
      return ta < tb
    end)
    -- take first 10
    local nextN = {}
    for i=1, math.min(10,#allItems) do nextN[i] = allItems[i] end
    drawList(mon, nextN)
  end

  safeSleep(60, mon, "Refreshing in 60s…")
end
