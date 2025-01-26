local coords = require("/apis/coords")


local programName = arg[0] or fs.getName(shell.getRunningProgram())
local tArgs = { ... }
local running = settings.get("quarry.running", false)

local posX, posY, posZ = gps.locate()
local dirX, _,  dirZ = coords.getCoords("dir")
local homeX, homeY, homeZ = coords.getCoords("home")
local lastKnownX, lastKnownY, lastKnownZ = coords.getCoords("lastKnown")
local lastKnownDirX, _, lastKnownDirZ = coords.getCoords("lastKnownDir")
local homeDirX, _, homeDirZ = coords.getCoords("homeDir")
local unloaded = settings.get("quarry.unloaded", 0)
local collected = settings.get("quarry.collected", 0)
local returning = settings.get("quarry.returning", false)
local resumingAfterReturn = settings.get("quarry.resumingAfterReturn", false)
local size = settings.get("quarry.size", 0)

local GoTo
local Refuel
local ReturnSupplies
local TurnLeft
local TurnRight
local DoForwards
local TryForwards
local DoUp
local TryUp
local DoDown
local TryDown
local StartQuarry
local ContinueQuarry
local Quarry


-- Print the usage string of the program
---@returns nil
function PrintUsage()
    print("Usage:")
    print(programName .. " <diameter>")
    error()
end

-- Parse the input arguments for a new quarry
---@returns nil
function ParseInput()
    if #tArgs ~= 1 then
        PrintUsage()
    end

    size = tonumber(tArgs[1])
    if size < 1 then
        print("Quarry diameter must be positive")
        error()
    end
end

-- Save all settings related to the quarry
---@returns nil
function SaveSettings()
    coords.saveCoords("home", homeX, homeY, homeZ)
    coords.saveCoords("dir", dirX, 0, dirZ)
    coords.saveCoords("homeDir", homeDirX, 0, homeDirZ)
    coords.saveCoords("lastKnown", lastKnownX, lastKnownY, lastKnownZ)
    coords.saveCoords("lastKnownDir", dirX, 0, dirZ)
    settings.set("quarry.running", running)
    settings.set("quarry.unloaded", unloaded)
    settings.set("quarry.collected", collected)
    settings.set("quarry.size", size)
    settings.set("quarry.returning", returning)
    settings.set("quarry.resumingAfterReturn", resumingAfterReturn)
    settings.save()
end

-- Clear all settings related to the quarry
---@returns nil
function ClearSettings()
    coords.clearCoords("home")
    coords.clearCoords("dir")
    coords.clearCoords("homeDir")
    coords.clearCoords("lastKnown")
    coords.clearCoords("lastKnownDir")
    settings.unset("quarry.running")
    settings.unset("quarry.unloaded")
    settings.unset("quarry.collected")
    settings.unset("quarry.size")
    settings.unset("quarry.returning")
    settings.unset("quarry.resumingAfterReturn")
    settings.save()
end

-- Confirm that the quarry is running by checking if all necessary parameters are set
---@returns boolean #Whether the quarry is running
function ConfirmRunning()
    if homeX == nil or homeY == nil or homeZ == nil then
        return false
    end

    if dirX == nil or dirZ == nil or homeDirX == nil or homeDirZ == nil then
        return false
    end

    if size < 1 then
        return false
    end

    return true
end

-- Move the turtle to a specific location
---@param x number # X coordinate to move to
---@param y number # Y coordinate to move to
---@param z number # Z coordinate to move to
---@param xd number # X direction to face
---@param zd number # Z direction to face
---@returns boolean # Whether the turtle successfully moved to the location
function GoTo(x, y, z, xd, zd)
    local xDiff = posX - x
    local yDiff = posY - y
    local zDiff = posZ - z

    print("goto directions: " .. xDiff .. "x " .. yDiff .. "y " .. zDiff .. "z" .. " " .. xd .. "xd " .. zd .. "zd")

    if xDiff == 0 and yDiff == 0 and zDiff == 0 then
        while dirX ~= xd or dirZ ~= zd do
            TurnLeft()
        end
        return true
    end

    if yDiff > 0 then
        print("climbing for goto")
        while yDiff > 0 do
            if not DoDown() then
                return false
            end
            yDiff = yDiff - 1
        end
    elseif yDiff < 0 then
        print("descending for goto")
        while yDiff < 0 do
            if not DoUp() then
                return false
            end
            yDiff = yDiff + 1
        end
    end

    if xDiff > 0 then
        print("lowering x for goto")
        while dirX ~= -1 or dirZ ~= 0 do
            TurnLeft()
        end
        while xDiff > 0 do
            if not DoForwards() then
                return false
            end
            xDiff = xDiff - 1
        end
    elseif xDiff < 0 then
        print("raising x for goto")
        while dirX ~= 1 or dirZ ~= 0 do
            TurnLeft()
        end
        while xDiff < 0 do
            if not DoForwards() then
                return false
            end
            xDiff = xDiff + 1
        end
    end

    if zDiff > 0 then
        print("lowering z for goto")
        while dirX ~= 0 or dirZ ~= -1 do
            TurnLeft()
        end
        while zDiff > 0 do
            if not DoForwards() then
                return false
            end
            zDiff = zDiff - 1
        end
    elseif zDiff < 0 then
        print("raising z for goto")
        while dirX ~= 0 or dirZ ~= 1 do
            TurnLeft()
        end
        while zDiff < 0 do
            if not DoForwards() then
                return false
            end
            zDiff = zDiff + 1
        end
    end

    while dirX ~= xd or dirZ ~= zd do
        TurnLeft()
    end

    return true
end

-- Ensure the turtle has enough fuel to return home. If it doesn't, it will attempt to refuel using items in its inventory.
---@param amount number | nil # Amount of fuel needed
---@returns boolean # Whether the turtle has enough fuel to return home
function Refuel(amount)
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" then
        return true
    end

    xDiff = math.abs(posX - homeX)
    yDiff = math.abs(posY - homeY)
    zDiff = math.abs(posZ - homeZ)

    if amount == nil then
        print("Refuel distance from home: " .. xDiff .. "x " .. yDiff .. "y " .. zDiff .. "z " .. xDiff + yDiff + zDiff + 2 .. " (total)")
    else
        print("Refuel amount needed: " .. amount)
    end

    local needed = amount or (xDiff + yDiff + zDiff + 2)
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

-- Determine if the turtle has space in its inventory to collect more items.
---@returns boolean # Whether the turtle has space in its inventory for more items
function CheckInventory()
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

    SaveSettings()
    if bFull then
        print("No empty slots left.")
        return false
    end
    return true
end

-- Unload all items from the turtle's inventory into an adjacent storage container.
---@param _bKeepOneFuelStack boolean | nil # Whether to keep one fuel stack in the turtle's inventory
function UnloadInventory(_bKeepOneFuelStack)
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
    SaveSettings()
    turtle.select(1)
end

-- Return the turtle to the surface to refuel and unload items.
---@param _bReturnAfterUnload boolean | nil # Whether to return to the mining location after unloading
function ReturnSupplies(_bReturnAfterUnload)

    lastKnownX, lastKnownY, lastKnownZ = posX, posY, posZ
    lastKnownDirX, lastKnownDirZ = dirX, dirZ

    returning = true
    resumingAfterReturn = false
    SaveSettings()
    print("Returning to surface...")

    GoTo(homeX, homeY, homeZ, -homeDirX, -homeDirZ)

    xDiff = math.abs(posX - homeX)
    yDiff = math.abs(posY - homeY)
    zDiff = math.abs(posZ - homeZ)

    local fuelNeeded = 2 * (xDiff + yDiff + zDiff) + 1

    if _bReturnAfterUnload and not Refuel(fuelNeeded) then
        UnloadInventory(true)
        print("Waiting for fuel")
        while not Refuel(fuelNeeded) do
            os.pullEvent("turtle_inventory")
        end
    else
        UnloadInventory(true)
    end

    if not _bReturnAfterUnload then
        print("Finished unloading items")
        return
    end


    returning = false
    resumingAfterReturn = true
    SaveSettings()
    print("Resuming mining...")

    GoTo(lastKnownX, lastKnownY, lastKnownZ, lastKnownDirX, lastKnownDirZ)

    returing = false
    resumingAfterReturn = false
    SaveSettings()
end

-- Turn the turtle to the left
function TurnLeft()
    dirX, dirZ = dirZ, -dirX
    SaveSettings()
    turtle.turnLeft()
end

-- Turn the turtle to the right
function TurnRight()
    dirX, dirZ = -dirZ, dirX
    SaveSettings()
    turtle.turnRight()
end

-- Move the turtle forwards one block
function DoForwards()
    local oldPosX, oldPosY, oldPosZ = gps.locate()
    if oldPosX == nil or oldPosY == nil or oldPosZ == nil then
        oldPosX, oldPosY, oldPosZ = posX, posY, posZ
    end

    while not turtle.forward() do
        if turtle.detect() then
            if turtle.dig() then
                if not CheckInventory() then
                    ReturnSupplies(true)
                end
            else
                return false
            end
        elseif turtle.attack() then
            if not CheckInventory() then
                ReturnSupplies(true)
            end
        else
            sleep(0.5)
        end
    end

    posX, posY, posZ = gps.locate()
    if posX ~= nil and posY ~= nil and posZ ~= nil then
        dirX = posX - oldPosX
        dirZ = posZ - oldPosZ
    else
        posX = posX + dirX
        posZ = posZ + dirZ
    end
    SaveSettings()

    return true
end

-- Attempt to move the turtle forwards one block
function TryForwards()
    if not Refuel() then
        print("Not enough Fuel")
        if not ReturnSupplies(true) then
            print("Failed to return to surface")
        end
    end

    return DoForwards()
end

-- Move the turtle up one block
function DoUp()
    while not turtle.up() do
        if turtle.detectUp() then
            if turtle.digUp() then
                if not CheckInventory() then
                    ReturnSupplies(true)
                end
            else
                return false
            end
        elseif turtle.attackUp() then
            if not CheckInventory() then
                ReturnSupplies(true)
            end
        else
            sleep(0.5)
        end
    end

    posY = posY - 1
    SaveSettings()
    return true
end

-- Attempt to move the turtle up one block
function TryUp()
    if not Refuel() then
        print("Not enough Fuel")
        if not ReturnSupplies(true) then
            print("Failed to return to surface")
        end
    end
    return DoUp()
end

-- Move the turtle down one block
function DoDown()
    while not turtle.down() do
        if turtle.detectDown() then
            if turtle.digDown() then
                if not CheckInventory() then
                    ReturnSupplies(true)
                end
            else
                return false
            end
        elseif turtle.attackDown() then
            if not CheckInventory() then
                ReturnSupplies(true)
            end
        else
            sleep(0.5)
        end
    end

    posY = posY - 1
    SaveSettings()
    return true
end

-- Attempt to move the turtle down one block
function TryDown()
    if not Refuel() then
        print("Not enough Fuel")
        if not ReturnSupplies(true) then
            print("Failed to return to surface")
        end
    end
    
    return DoDown()
end

-- Start the quarry by setting the home location and direction
function StartQuarry()
    homeX, homeY, homeZ = gps.locate()
    running = true

    if size == 1 then
        homeDirX, homeDirZ = 0, 0
        SaveSettings()
        Quarry(false)
    else
        TryForwards()
        homeDirX, homeDirZ = dirX, dirZ
        SaveSettings()
        Quarry(true)
    end

    print("Starting new quarry")

end

-- Quarry the area defined by the size of the quarry
function ContinueQuarry()
    print("Continuing quarry")

    if returning then
        ReturnSupplies(true)
    elseif resumingAfterReturn then
        GoTo(homeX, lastKnownY, homeZ, homeDirX, homeDirZ)
    end

    Quarry()
    
end

-- Quarry the area defined by the size of the quarry
---@param _bSkipFirstForward boolean | nil # Whether to skip the first forward movement
function Quarry(_bSkipFirstForward)

    if not Refuel() then
        print("Out of Fuel")
        return
    end

    local firstSkip = _bSkipFirstForward or false
    print("Do skip first forward: " .. tostring(firstSkip))

    local alternate = 0
    local done = false
    while not done do
        for n = 1, size do
            for _ = 1, size - 1 do
                if firstSkip then
                    print("skipping first forward")
                    firstSkip = false
                else
                    if not TryForwards() then
                        done = true
                        break
                    end
                end
            end

            if done then
                break
            end

            if n < size then
                if math.fmod(n + alternate, 2) == 0 then
                    TurnLeft()
                    if not TryForwards() then
                        done = true
                        break
                    end
                    TurnLeft()
                else
                    TurnRight()
                    if not TryForwards() then
                        done = true
                        break
                    end
                    TurnRight()
                end
            end
        end

        if done then
            break
        end

        if size > 1 then
            if math.fmod(size, 2) == 0 then
                TurnRight()
            else
                if alternate == 0 then
                    TurnLeft()
                else
                    TurnRight()
                end
                alternate = 1 - alternate
            end
        end

        if not TryDown() then
            done = true
            break
        end
    end

    GoTo(homeX, homeY, homeZ, -homeDirX, -homeDirZ)
    ReturnSupplies(false)
    ClearSettings()
end

function Main()
    if not turtle then
        printError("Requires a computer with access to the Turtle API")
        error()
    end

    if running and ConfirmRunning() then
        print("Quarry already running, continuing with previously defined parameters")
        print("Home set to: " .. homeX .. " " .. homeY .. " " .. homeZ)
        ContinueQuarry()
        return
    elseif running then
        print("Quarry was running but parameters were not saved, please restart the program")
        error()
    end

    ParseInput()
    if size < 1 then
        print("Quarry diameter must be positive")
        error()
    end


    StartQuarry()
end

Main()