local coords = require("/apis/coords")
local completion = require "cc.shell.completion"

-- coords.setCompletionFunction()
shell.setCompletionFunction("/programs/coords.lua", completion.build({ completion.choice, { "get", "set" } }))