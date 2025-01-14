local json = {}

local stringExt = require("/api/string")
local tableExt = require("/api/table")
local Stack = require("/api/stack")

---@param tab any Object to convert into table notation
---@return string
function json.dumps( tab )
    if type(tab) == "table" then
        local layer = ""
        if tableExt.isArray(tab) then
            layer = layer .. '['
            for i, v in pairs(tab) do
                layer = layer .. json.dumps(v)
                if i < #tab then
                    layer = layer .. ','
                end
            end
            layer = layer .. ']'
        else
            layer = layer .. '{'
            local i = 1
            local tabSize = json.tableSize(tab)
            for k, v in pairs(tab) do
                layer = layer .. string.format("\"%s\":%s", k, json.dumps(v))
                if i < tabSize then
                    layer = layer .. ','
                end
                i = i + 1
            end
            layer = layer .. '}'
        end
        return layer
    else
        return '"' .. tostring(tab) .. '"'
    end
end


---@param str string String in tn to convert into table
---@return table
function json.loads( str )
    str = stringExt.removeWhitespace(str)
    
    local stack = Stack.new()
    local matches = {}
    local i = 1

    while i <= #str do
        local char = str.sub(str, i,i)
        if char == "\"" then
            local found
            local start = i + 1
            repeat
                found = string.find(str, "\"", start)
                assert(found ~= nil)
                start = found + 1
            until found and str[found-1] ~= "\\"
            matches[i] = found
            i = found
        elseif char == "}" then
            local match = stack:pop()
            assert(str.sub(str, match, match) == "{")
            matches[match] = i
        elseif char == "]" then
            local match = stack:pop()
            assert(str.sub(str, match, match) == "[")
            matches[match] = i
        elseif char == "{" or char == "[" then
            stack:push(i)
        end
        i = i + 1
    end
    assert(stack:size() == 0)

    local keys = {} ---@type integer[]
    for k, v in pairs(matches) do
        table.insert(keys, k)
    end
    local lt = function (a, b) return a < b end
    table.sort(keys, lt)

    ---TODO: Use character matches to build hierarchy
    return {}
end


---@param tab table Table to convert into tn
---@param file File File being dumped into
---@return nil
function json.dump( tab, file )
    file.write(json.dumps(tab))
end


---@param file File File being loaded from
---@return table
function json.load( file )
    return json.loads(file.readAll())
end

return json