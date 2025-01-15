local gps = require("gps")

---@returns nil
function PrintUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages: \n" .. programName .. " get\n" .. programName .. " set\n" .. programName .. " set <x> <y> <z>")
    error()
end

---@returns nil
function PrintHome()
    local x = settings.get("home.x")
    local y = settings.get("home.y")
    local z = settings.get("home.z")
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
    settings.set("home.x", x)
    settings.set("home.y", y)
    settings.set("home.z", z)
end

if #arg < 2 then
    PrintUsage()
elseif arg[1] == "get" and #arg == 2 then
    PrintHome()
elseif arg[1] == "set" and #arg == 2 then
    SetHomeHere()
elseif arg[1] == "set" and #arg == 5 then
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
