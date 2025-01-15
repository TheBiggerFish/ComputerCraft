local home = require("/apis/home")

---@returns nil
function PrintUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " get")
    print(programName .. " set")
    print(programName .. " set <x> <y> <z>")
    error()
end

---@returns nil
function PrintHome()
    local x,y,z = home.getHome()
    if x == nil or y == nil or z == nil then
        print("Home is not set")
    else
        print("Home is set to: " .. x .. " " .. y .. " " .. z)
    end
end

---@returns nil
function SetHomeHere()
    x, y, z = gps.locate()
    SetHome(x, y, z)
end

---@param x integer
---@param y integer
---@param z integer
---@returns nil
function SetHome(x, y, z)
    home.setHome(x, y, z)
end

if #arg < 1 then
    PrintUsage()
elseif arg[1] == "get" and #arg == 1 then
    PrintHome()
elseif arg[1] == "set" and #arg == 1 then
    SetHomeHere()
elseif arg[1] == "set" and #arg == 4 then
    local x,y,z
    x = tonumber(arg[3])
    y = tonumber(arg[4])
    z = tonumber(arg[5])
    if x == nil or y == nil or z == nil then
        PrintUsage()
        error()
    end
    --- cast to integer
    x = math.floor(x)
    y = math.floor(y)
    z = math.floor(z)
    SetHome(x,y,z)
else 
    PrintUsage()
end
