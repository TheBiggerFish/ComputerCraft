local arguments = require("/apis/arguments")
local mailserver = require("/apis/mail")


---@returns nil
function PrintUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usage: \n" .. programName .. " <--mount=> [--modem=[right]] [--name=[mailserver]]")
    error()
end

-- Interpret program input
local args = arguments.Interpret( arg )
if not args["mount"] then
    PrintUsage()
end
local mount = args["mount"]

local modemSide = "right"
if args["modem"] then
    modemSide = args["modem"]
end

local name = "mailserver"
if args["name"] then
    name = args["name"]
end

-- Initialize connection
assert(peripheral.isPresent(modemSide))
if not rednet.isOpen(modemSide) then
    rednet.open(modemSide)
end

mailserver.Serve(name, mount)
