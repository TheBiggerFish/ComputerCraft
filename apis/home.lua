local module = {}

---@return integer | nil, integer | nil, integer | nil
function module.getHome()
    local x = settings.get("home.x")
    local y = settings.get("home.y")
    local z = settings.get("home.z")
    if x == nil or y == nil or z == nil then
        return nil, nil, nil
    elseif type(x) ~= "integer" or type(y) ~= "integer" or type(z) ~= "integer" then
        return nil, nil, nil
    else
        return x, y, z
    end
end

---@param x integer #New home coordinate (x axis)
---@param y integer #New home coordinate (y axis)
---@param z integer #New home coordinate (z axis)
---@return boolean #Whether the home setting was set successfully
function module.setHome(x, y, z)
    if type(x) ~= "integer" or type(y) ~= "integer" or type(z) ~= "integer" then
        return false
    end
    settings.set("home.x", x)
    settings.set("home.y", y)
    settings.set("home.z", z)
    return true
end

return module