local module = {}


---@param tab table Table to check
---@return boolean #Whether the provided table is an array
function module.isArray( tab )
    local i = 1
    for _ in pairs(tab) do
        if tab[i] == nil then
            return false
        end
        i = i + 1
    end
    return true
end

return module