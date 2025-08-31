-- billboard_update_trigger.lua

-- Open all modem sides
for _, side in ipairs({ "left", "right", "top", "bottom", "back", "front" }) do
  if peripheral.getType(side) == "modem" then
    rednet.open(side)
  end
end

-- Broadcast update signal
print("Broadcasting update signal to all billboard nodes...")
rednet.broadcast("update", "billboard_update")
print("Done.")
