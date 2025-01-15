local module = {}

local completion = require "cc.shell.completion"


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

function module.setCompletionFunction()
    local names = {}
    local allNames = settings.getNames()
    for _, name in ipairs(allNames) do
        if name:sub(1, 9) == "location." then
            local locationName = name:sub(10)
            if locationName ~= "" then
                table.insert(names, locationName)
            end
        end
    end
    shell.setCompletionFunction("/programs/coords.lua", completion.build({ completion.choice, { "get", "set" } }, { completion.choice, names }))
    -- return shell.setCompletionFunction(
    --     "/programs/coords.lua",
    --     function(shell, index, text, previous)
    --         if index == 1 then
    --             return { "get", "set" }
    --         elseif index == 2 then
    --             local names = {}
    --             for name in settings.getNames() do
    --                 if name:sub(1, 9) == "location." then
    --                     local locationName = name:sub(10)
    --                     if locationName ~= "" then
    --                         table.insert(names, locationName)
    --                     end
    --                 end
    --             end
    --             return names
    --         end
    --     end
    -- )
end

---@param name string #The name of the coordinate to get
---@return number | nil, number | nil, number | nil
function module.getCoords(name)
    local location = settings.get(getName(name))
    if location == nil then
        return nil, nil, nil
    end

    local x = location.x
    local y = location.y
    local z = location.z
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return nil, nil, nil
    end
    return x, y, z
end

---@param name string #The name of the coordinate to set
---@param x number #New home coordinate (x axis)
---@param y number #New home coordinate (y axis)
---@param z number #New home coordinate (z axis)
---@return boolean #Whether the home setting was set successfully
function module.saveCoords(name, x, y, z)
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return false
    end
    local location = {
        x = x,
        y = y,
        z = z,
    }
    settings.set(getName(name), location)
    settings.save()
    module.setCompletionFunction()
    return true
end

return module