local module = {}

---@alias direction {x: number, z: number}

---@type direction
module.NORTH = {x = 0, z = -1}
module.EAST = {x = 1, z = 0}
module.SOUTH = {x = 0, z = 1}
module.WEST = {x = -1, z = 0}

---@return direction | nil #The direction the turtle is facing
function module.calibrateDirection()
    local initX, initY, initZ = gps.locate()
    turtle.dig()
    turtle.forward()
    local newX, newY, newZ = gps.locate()
    turtle.back()

    if newX == nil or initX == nil then
        return nil
    end

    local dx = newX - initX
    local dz = newZ - initZ
    return {x = dx, z = dz}
end

---@param direction direction #The direction to convert
---@return string #The string representation of the direction
function module.directionToString(direction)
    if direction.x == 0 and direction.z == -1 then
        return "NORTH"
    elseif direction.x == 1 and direction.z == 0 then
        return "EAST"
    elseif direction.x == 0 and direction.z == 1 then
        return "SOUTH"
    elseif direction.x == -1 and direction.z == 0 then
        return "WEST"
    else
        return "UNKNOWN"
    end
end

---@param direction direction #The initial facing direction
---@return direction #The new facing direction
function module.turnLeft(direction)
    return {x = -direction.z, z = direction.x}
end

---@param direction direction #The initial facing direction
---@return direction #The new facing direction
function module.turnRight(direction)
    return {x = direction.z, z = -direction.x}
end

return module