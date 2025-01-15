local coords = require("/apis/coords")

---@returns nil
function PrintUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " get [name]")
    print(programName .. " set <name>")
    print(programName .. " set <x> <y> <z>")
    error()
end

---@param name string Name of the coordinate to print
---@returns nil
function PrintCoords(name)
    local x,y,z
    if name == nil or name == "" then
        --- Get current location
        x,y,z = gps.locate()
        if x == nil or y == nil or z == nil then
            print("Location could no be determined")
        else 
            print("Location is: " .. x .. " " .. y .. " " .. z)
        end
        return
    end

    --- Get stored location
    x,y,z = coords.getCoords(name)
    if x == nil or y == nil or z == nil then
        print("Alias \"" .. name .. "\" not set")
    else
        print("Alias \"" .. name .. "\" is set to: " .. x .. " " .. y .. " " .. z)
    end
end

---@param name string Name of the coordinate to store
---@returns nil
function SetCoordHere(name)
    x, y, z = gps.locate()
    SetCoord(name, x, y, z)
end

---@param name string Name of the coordinate to store
---@param x integer
---@param y integer
---@param z integer
---@returns nil
function SetCoord(name, x, y, z)
    coords.saveCoords(name, x, y, z)
    print("Set alias \"" .. name .. "\" to: " .. x .. " " .. y .. " " .. z)
end

if #arg < 1 then
    PrintUsage()
elseif arg[1] == "get" and #arg == 1 then
    PrintCoords("")
elseif arg[1] == "get" and #arg == 2 then
    PrintCoords(arg[2])
elseif arg[1] == "set" and #arg == 2 then
    SetCoordHere(arg[2])
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
    SetCoord(arg[2], x,y,z)
else 
    PrintUsage()
end
