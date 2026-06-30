local printer = peripheral.find("printer")
if not printer then
    print("No printer found")
    return
end

print("Create an Engineer's Cert")
print("Enter username:")
local username = read()

local bookTitle = "Engineer's Certification for " .. username

local pages = {
    "Server: FPS-Create\nEngineer: " .. username,
    "Thanks for playing FPS-Create!",
    "Your generator and any future generators are certified for use with any electric systems."
}

for i, text in ipairs(pages) do
    -- Start a new page
    if not printer.newPage() then
        error("Cannot start a new page. Do you have ink and paper?")
    end

    -- Title
    printer.setPageTitle(bookTitle .. " - Page " .. i)

    -- Start at top-left
    printer.setCursorPos(1, 1)

    -- Write text
    printer.write(text)

    -- Print the page (endPage actually prints)
    if not printer.endPage() then
        error("Cannot end the page. Is there enough space?")
    end
end

print("Printed " .. #pages .. " pages for " .. username)

