local p = peripheral.find("printer")
if not p then
  print("No printer found")
  return
end
print("Create a Engineers Cert")

print("Enter username:")
local username = read()

local bookTitle = "Engineers Certification for " .. username
local pages = {
  "Page 1: Server: FPS-Create",
  "Page 2: Engineer:" .. username,
  "Page 3: Thanks for Playing FPS-Create.",
  "Page 4: Your Generator and Any Future generators are certified for use with any electric systems."
}

for i, text in ipairs(pages) do
  p.newPage()
  p.setPageTitle(bookTitle .. " - Page " .. i)
  p.write(text)
  p.endPage()
end

p.print()
print("Printed " .. #pages .. " pages for " .. username)
