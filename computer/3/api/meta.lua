local module = {}

---@meta

---@alias error string
---@alias status error
---@alias protocol string
---@alias hostname number

---@class File
---@field close fun() : nil
---@field readLine fun() : string
---@field readAll fun() : string
---@field write fun(string) : nil
---@field writeLine fun(string) : nil
---@field flush fun() : nil
---@field read fun() : number
---@field write fun(number) : nil

---@alias Object any
---@alias Array Object[]

return module