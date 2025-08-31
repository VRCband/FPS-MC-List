-- Open all modem sides
for _, side in ipairs({"left", "right", "top", "bottom", "back", "front"}) do
    if peripheral.getType(side) == "modem" then
        rednet.open(side)
    end
end

-- Routing loop
while true do
    local senderId, msg, protocol = rednet.receive("billboard")
    if type(msg) == "table" and msg.monitorID then
        -- Send to specific receiver
        rednet.send(msg.monitorID, msg, "billboard")
    elseif type(msg) == "table" and msg.broadcast == true then
        -- Broadcast to all receivers
        rednet.broadcast(msg, "billboard")
    end
end
