local module = {}


function getName(name)
    return "location." .. name
end

function module.define(name, description)
    settings.define(getName(name), {
        description = description,
        type = "table",
        default = nil,
    })
end

---@param name string #The name of the coordinate to get
---@return integer | nil, integer | nil, integer | nil
function module.getCoord(name)
    local location = settings.get(getName(name))
    if location == nil then
        return nil, nil, nil
    end

    local x = location.x
    local y = location.y
    local z = location.z
    if type(x) ~= "integer" or type(y) ~= "integer" or type(z) ~= "integer" then
        return nil, nil, nil
    end
    return x, y, z
end

---@param name string #The name of the coordinate to set
---@param x integer #New home coordinate (x axis)
---@param y integer #New home coordinate (y axis)
---@param z integer #New home coordinate (z axis)
---@return boolean #Whether the home setting was set successfully
function module.saveCoord(name, x, y, z)
    if type(x) ~= "integer" or type(y) ~= "integer" or type(z) ~= "integer" then
        return false
    end
    local location = {
        x = x,
        y = y,
        z = z,
    }
    settings.set(getName(name), location)
    settings.save()
    return true
end

return module