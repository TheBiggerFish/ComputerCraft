local time = {}

---@alias datetime number

---@return datetime #The current time
function time.now()
    ---@diagnostic disable-next-line: undefined-field
    return os.day() * 24.0 + os.time()
end

---@param dt datetime
---@return string #The string form of dt
function time.string( dt )
    local time = dt % 24
    local date = math.floor(dt / 24)
    return string.format("%d/%2.3f", time, date)
end

return time