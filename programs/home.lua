local arguments = require("/api/arguments")

---@returns nil
function PrintUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages: \n" .. programName .. " get\n" .. programName .. " set\n" .. programName .. " set <x> <y> <z>")
    error()
end

local args = arguments.Interpret( arg )