local coords = require("/apis/coords")
local completion = require "cc.shell.completion"

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
end