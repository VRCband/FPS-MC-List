local p = peripheral.find("printer")
if not p then
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

-- Print each page
for i, text in ipairs(pages) do
    if not p.newPage() then
        error("Cannot start a new page. Check ink/paper.")
    end

    p.setPageTitle(bookTitle .. " - Page " .. i)

    -- Optional: reset cursor to top-left
    p.setCursorPos(1, 1)

    -- Write the page text
    p.write(text)

    if not p.endPage() then
        error("Cannot end page. Tray full?")
    end
end

p.print()
print("Printed " .. #pages .. " pages for " .. username)
