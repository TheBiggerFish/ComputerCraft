local coords = require("/apis/coords")

if not turtle then
    printError("Requires a Turtle")
    return
end

local homeX, homeY, homeZ = coords.getCoords("home")
if homeX == nil then
    print("Home position not set")
    return
end

local tArgs = { ... }
if #tArgs ~= 0 and #tArgs ~= 1 and #tArgs ~= 2 then
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usage: " .. programName .. " <diameter> [skip]")
    return
end

local continuing = settings.get("excavation.in_progress")
if continuing == nil or not continuing then
    continuing = false
    settings.set("excavation.in_progress", continuing)
    settings.save()
end

-- Mine in a quarry pattern until we hit something we can't dig
local size = settings.get("excavation.size", tonumber(tArgs[1]))
if continuing and size == nil then
    print("Excavation size not set")
    return
elseif continuing then
    print("Resuming excavation with size " .. size)
else
    size = tonumber(tArgs[1])
end
if size < 1 then
    print("Excavate diameter must be positive")
    return
end

local skip = tonumber(tArgs[2])
if skip ~= nil and continuing then
    continuing = false
elseif skip == nil then
    skip = 0
end

local depth = 0
local unloaded = 0
local collected = 0

local xPos, zPos = 0, 0
local xDir, zDir = 0, 1

local goTo -- Filled in further down
local refuel -- Filled in further down

local function unload(_bKeepOneFuelStack)
    print("Unloading items...")
    for n = 1, 16 do
        local nCount = turtle.getItemCount(n)
        if nCount > 0 then
            turtle.select(n)
            local bDrop = true
            if _bKeepOneFuelStack and turtle.refuel(0) then
                bDrop = false
                _bKeepOneFuelStack = false
            end
            if bDrop then
                turtle.drop()
                unloaded = unloaded + nCount
            end
        end
    end
    collected = 0
    turtle.select(1)
end

local function returnSupplies()
    local x, y, z, xd, zd = xPos, depth, zPos, xDir, zDir
    print("Returning to surface...")
    goTo(0, 0, 0, 0, -1)

    local fuelNeeded = 2 * (x + y + z) + 1
    if not refuel(fuelNeeded) then
        unload(true)
        print("Waiting for fuel")
        while not refuel(fuelNeeded) do
            os.pullEvent("turtle_inventory")
        end
    else
        unload(true)
    end

    print("Resuming mining...")
    goTo(x, y, z, xd, zd)
end

local function collect()
    local bFull = true
    local nTotalItems = 0
    for n = 1, 16 do
        local nCount = turtle.getItemCount(n)
        if nCount == 0 then
            bFull = false
        end
        nTotalItems = nTotalItems + nCount
    end

    if nTotalItems > collected then
        collected = nTotalItems
        if math.fmod(collected + unloaded, 50) == 0 then
            print("Mined " .. collected + unloaded .. " items.")
        end
    end

    if bFull then
        print("No empty slots left.")
        return false
    end
    return true
end

function refuel(amount)
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" then
        return true
    end

    local needed = amount or xPos + zPos + depth + 2
    if turtle.getFuelLevel() < needed then
        for n = 1, 16 do
            if turtle.getItemCount(n) > 0 then
                turtle.select(n)
                if turtle.refuel(1) then
                    while turtle.getItemCount(n) > 0 and turtle.getFuelLevel() < needed do
                        turtle.refuel(1)
                    end
                    if turtle.getFuelLevel() >= needed then
                        turtle.select(1)
                        return true
                    end
                end
            end
        end
        turtle.select(1)
        return false
    end

    return true
end

local function tryForwards()
    if not refuel() then
        print("Not enough Fuel")
        returnSupplies()
    end

    while not turtle.forward() do
        if turtle.detect() then
            if turtle.dig() then
                if not collect() then
                    returnSupplies()
                end
            else
                return false
            end
        elseif turtle.attack() then
            if not collect() then
                returnSupplies()
            end
        else
            sleep(0.5)
        end
    end

    xPos = xPos + xDir
    zPos = zPos + zDir
    return true
end

local function tryUp()
    if not refuel() then
        print("Not enough Fuel")
        returnSupplies()
    end
    
    while not turtle.up() do
        if turtle.detectUp() then
            if turtle.digUp() then
                if not collect() then
                    returnSupplies()
                end
            else
                return false
            end
        elseif turtle.attackUp() then
            if not collect() then
                returnSupplies()
            end
        else
            sleep(0.5)
        end
    end
    
    depth = depth - 1
    if math.fmod(depth, 10) == 0 then
        print("Ascended " .. depth .. " meters")
    end
    
    return true
end
    
    

local function tryDown()
    if not refuel() then
        print("Not enough Fuel")
        returnSupplies()
    end

    while not turtle.down() do
        if turtle.detectDown() then
            if turtle.digDown() then
                if not collect() then
                    returnSupplies()
                end
            else
                return false
            end
        elseif turtle.attackDown() then
            if not collect() then
                returnSupplies()
            end
        else
            sleep(0.5)
        end
    end

    depth = depth + 1
    if math.fmod(depth, 10) == 0 then
        print("Descended " .. depth .. " metres.")
    end

    return true
end

local function turnLeft()
    turtle.turnLeft()
    xDir, zDir = -zDir, xDir
    settings.set("excavation.xDir", xDir)
    settings.set("excavation.zDir", zDir)
    settings.save()
end

local function turnRight()
    turtle.turnRight()
    xDir, zDir = zDir, -xDir
    settings.set("excavation.xDir", xDir)
    settings.set("excavation.zDir", zDir)
    settings.save()
end

function goTo(x, y, z, xd, zd)
    while depth > y do
        if turtle.up() then
            depth = depth - 1
        elseif turtle.digUp() or turtle.attackUp() then
            collect()
        else
            sleep(0.5)
        end
    end

    if xPos > x then
        while xDir ~= -1 do
            turnLeft()
        end
        while xPos > x do
            if turtle.forward() then
                xPos = xPos - 1
            elseif turtle.dig() or turtle.attack() then
                collect()
            else
                sleep(0.5)
            end
        end
    elseif xPos < x then
        while xDir ~= 1 do
            turnLeft()
        end
        while xPos < x do
            if turtle.forward() then
                xPos = xPos + 1
            elseif turtle.dig() or turtle.attack() then
                collect()
            else
                sleep(0.5)
            end
        end
    end

    if zPos > z then
        while zDir ~= -1 do
            turnLeft()
        end
        while zPos > z do
            if turtle.forward() then
                zPos = zPos - 1
            elseif turtle.dig() or turtle.attack() then
                collect()
            else
                sleep(0.5)
            end
        end
    elseif zPos < z then
        while zDir ~= 1 do
            turnLeft()
        end
        while zPos < z do
            if turtle.forward() then
                zPos = zPos + 1
            elseif turtle.dig() or turtle.attack() then
                collect()
            else
                sleep(0.5)
            end
        end
    end

    while depth < y do
        if turtle.down() then
            depth = depth + 1
        elseif turtle.digDown() or turtle.attackDown() then
            collect()
        else
            sleep(0.5)
        end
    end

    while zDir ~= zd or xDir ~= xd do
        turnLeft()
    end
end

if not refuel() then
    print("Out of Fuel")
    return
end

print("Calibrate directionality")
local realX, realY, realZ = gps.locate()
tryForwards()
local newX, newY, newZ = gps.locate()
if realX == nil or newX == nil then
    print("Could not determine position")
    return
end
turnLeft()
turnLeft()
tryForwards()
turnRight()
turnRight()

xDir = newX - realX
zDir = newZ - realZ

if not continuing then
    coords.saveCoords("home", realX, realY, realZ)
    settings.set("excavation.xDir", xDir)
    settings.set("excavation.zDir", zDir)
else
    depth = homeY - realY
    xPos =  homeX - realX
    zPos =  homeZ - realZ
    
    xDir = settings.get("excavation.xDir", xDir)
    zDir = settings.get("excavation.zDir", zDir)
end
settings.set("excavation.size", size)
settings.set("excavation.in_progress", true)
settings.save()

goTo(0, depth, 0, 0, 1)

if skip > 0 then
    print("Navigating to target site...")
    for _ = 1, skip do
        tryDown()
    end

elseif skip < 0 then   
    print("Navigating to target site...")
    for _ = skip, -1 do
        tryUp()
    end
end

print("Excavating...")

local reseal = false
turtle.select(1)
if turtle.digDown() then
    reseal = true
end

local alternate = 0
local done = false
while not done do
    for n = 1, size do
        for _ = 1, size - 1 do
            if not tryForwards() then
                done = true
                break
            end
        end
        if done then
            break
        end
        if n < size then
            if math.fmod(n + alternate, 2) == 0 then
                turnLeft()
                if not tryForwards() then
                    done = true
                    break
                end
                turnLeft()
            else
                turnRight()
                if not tryForwards() then
                    done = true
                    break
                end
                turnRight()
            end
        end
    end
    if done then
        break
    end

    if size > 1 then
        if math.fmod(size, 2) == 0 then
            turnRight()
        else
            if alternate == 0 then
                turnLeft()
            else
                turnRight()
            end
            alternate = 1 - alternate
        end
    end

    if not tryDown() then
        done = true
        break
    end
end

print("Returning to surface...")

-- Return to where we started
goTo(0, 0, 0, 0, -1)
unload(false)
goTo(0, 0, 0, 0, 1)

-- Seal the hole
if reseal then
    turtle.placeDown()
end

settings.set("excavation.in_progress", false)
settings.unset("excavation.xDir")
settings.unset("excavation.zDir")
settings.unset("excavation.size")
settings.save()

print("Mined " .. collected + unloaded .. " items total.")
