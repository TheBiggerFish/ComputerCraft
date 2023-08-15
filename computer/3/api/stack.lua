local stack = {}
stack.__index = stack

---@class Stack
---@field array Array
---@field push fun(self: Stack, obj: Object) : nil
---@field pop fun() : Object
---@field peek fun() : Object
---@field top fun() : Object
---@field size fun() : integer


---@return Stack
function stack.new()
    local self = setmetatable({}, stack)
    self.array = {}
    return self
end


---Add obj to the top of the stack
---@param self Stack
---@param obj Object
---@return nil
function stack.push(self, obj)
    table.insert(self.array, obj)
end


---Remove the top object from the stack
---@param self Stack
---@return Object
function stack.pop(self)
    assert(self:size() > 0)
    return table.remove(self.array)
end


---Return the size of the stack
---@param self Stack
---@return integer
function stack.size(self)
    return #self.array
end


---Peek at top item on stack
---@param self Stack
---@return Object
function stack.peek(self)
    return self.array[self:size()]
end
stack.top = stack.peek

return stack