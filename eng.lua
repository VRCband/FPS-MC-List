local printer = peripheral.find("printer")
if not printer then
    print("No printer found")
    return
end

print("Create an Engineer's Cert")
print("Enter username:")
local username = read()

local bookTitle = "Engineer's Certification for " .. username

-- All text for ONE page (with \n)
local pageText = table.concat({
    "Server: FPS-Create",
    "Engineer: " .. username,
    "Thanks for playing FPS",
    "Your generator and any",
    "future generators are",
    "certified for use with",
    "any electric systems."
}, "\n")


-- Max characters per line INCLUDING spaces
local MAX_LINE = 22

-- Write text with newline + max length enforcement
local function writeWithLimits(printer, text)
    local x, y = printer.getCursorPos()

    for rawLine in text:gmatch("[^\n]+") do
        -- enforce max line length
        local line = rawLine:sub(1, MAX_LINE)

        printer.write(line)

        y = y + 1
        printer.setCursorPos(1, y)
    end
end

-- Start printing ONE page
if not printer.newPage() then
    error("Cannot start a new page. Do you have ink and paper?")
end

printer.setPageTitle(bookTitle .. " - Page 1")
printer.setCursorPos(1, 1)

writeWithLimits(printer, pageText)

if not printer.endPage() then
    error("Cannot end the page. Is there enough space?")
end

print("Printed 1 page for " .. username)
