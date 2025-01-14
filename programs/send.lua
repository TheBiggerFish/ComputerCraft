local arguments = require("/apis/arguments")
local mail = require("/apis/mail")

-- Invalid inputs
function PrintUsage() 
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usage: \n" .. programName .. " <--recipient=> <--filepath=> [--modem=[right]] [--server=[mailserver]]")
    error()
end


-- Interpret program input
local args = arguments.Interpret( arg )
if not args["recipient"] or not args["filepath"] then
    PrintUsage()
end
local recipient = args["recipient"]
local filepath = args["filepath"]

local modemSide = "right"
if args["modem"] then
    modemSide = args["modem"]
end

local server = "mailserver"
if args["server"] then
    server = args["server"]
end

-- Initialize connection
assert(peripheral.isPresent(modemSide))
if not rednet.isOpen(modemSide) then
    rednet.open(modemSide)
end

response = mail.SendFile(server, recipient, filepath)
print(response)
if response == mail.ERR_ALREADY_EXISTS then
    response = mail.DeleteFile(server, recipient, filepath)
    print(response)
    response = mail.SendFile(server, recipient, filepath)
    print(response)
end
