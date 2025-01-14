local module = {}

---@enum
module.WHITESPACE = {
    SPACE = " ",
    TAB = "\t",
    NEWLINE = "\n",
}


function module.strip()
end


---@param str string Single-character string which may contain whitespace
---@return boolean #Whether this character is whitespace
function module.isWhitespace(str)
    assert(type(str) == "string")
    assert(#str == 1)

    for _, v in pairs(module.WHITESPACE) do
        if str == v then
            return true
        end
    end
    return false
end


---@param str string Input value which will have whitespace removed
---@return string #Returns str with whitespace removed
function module.removeWhitespace(str)
    for _, v in pairs(module.WHITESPACE) do
        str = string.gsub(str, v, "")
    end
    return str
end

---@param str string Input value which will be split
---@param pattern string The pattern that will be split around
---@return string[] #Substrings split by the pattern
function module.split(str, pattern)
    local results = {}
    local cur = 1
    local next_, sub
    repeat
        next_ = string.find(str, pattern, cur)
        if next_ == nil then
            sub = string.sub(str, cur, #str)
        elseif next_ == cur then
            sub = ""
        else
            sub = string.sub(str, cur, next_-1)
        end
        table.insert(results, sub)
        cur = next_ + 1
        next_ = cur
    until cur > #str
    return results
end

return module