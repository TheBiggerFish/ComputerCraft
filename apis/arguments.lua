local module = {}

---@alias args string[]
---@alias kwargs table<string, string|boolean>

---@param arguments string[] A list of strings sent directly from user input
---@return args r_args List of non-flag arguments
---@return kwargs r_kwargs Mapping of keyword arguments
function module.Interpret( arguments )
    r_args = {} ---@type args
    r_kwargs = {} ---@type kwargs

    local i = 1
    while i <= #arguments do
        local token = arguments[i]
        if #token == 0 then
        elseif string.sub(token, 1, 1) == "-" then
            if string.sub(token, 2, 2) == "-" then
                if #token > 2 then
                    local key = string.sub(token, 3)
                    if i + 1 <= #arguments then
                        r_kwargs[key] = arguments[i+1]
                    end
                    i = i + 1
                end
            else
                for j = 2, #token do
                    local char = string.sub(token, j, j)
                    r_kwargs[char] = true
                end
            end
        else
            table.insert(r_args, token)
        end

        i = i + 1
    end

    return r_args, r_kwargs
end

return module
