local arguments = require("/api/arguments")


local mail = {}

---@type protocol
mail.PROTOCOL = "mail"

---@enum mailMethod types
mail.METHOD = {
    PUT = "PUT",
    GET = "GET",
    DELETE = "DELETE",
}

--- Client-side errors
mail.ERR_MOUNT_TO_DIRECTORY = "Mountpoint must be a directory."
mail.ERR_MAX_RETIRES = "Reached maximum retries."
mail.ERR_INVALID_RETIRES = "Invalid number of retries. Retries must be a positive integer."
mail.ERR_CANNOT_SEND_DIRECTORY = "Cannot send a directory."
mail.ERR_SERVER_NOT_FOUND = "Failed to lookup the server by name."

--- Server-side errors
mail.ERR_INVALID_REQUEST = "Request missing required field."
mail.ERR_CANNOT_MODIFY_DIRECTORY = "Unable to modify directory."
mail.ERR_ALREADY_EXISTS = "File already exists."
mail.ERR_DOES_NOT_EXIST = "File does not exist."
mail.ERR_INSUFFICIENT_STORAGE = "Insufficient storage."
mail.SUCCESS_WRITTEN = "File written."
mail.SUCCESS_REMOVED = "File removed."
mail.SUCCESS_MESSAGES_FOUND = "Messaged found."
mail.SUCCESS_NO_MESSAGES = "No messages."


---@class mailRequest
---@field method mailMethod Functionality requested of server
---@field recipient integer User meant to receive message
---@field filename string Name of file being transmitted for PUT request or deleted for "DELETE" request
---@field data string Contents of file being transmitted for PUT request

---@class mailResponse
---@field message status Response for client interpretation
---@field filesize integer Size of file already present on mailserver


---@param receiverPath string The absolute path to the receiving user's stored messages
---@param request mailRequest The request for the mailserver
---@param response mailResponse The response sent to the user
---@return mailResponse response
local function HandleGet(receiverPath, request, response)
    messages = fs.list(receiverPath)
    if not messages then
        response.message = mail.SUCCESS_NO_MESSAGES
    else
        response.message = mail.SUCCESS_MESSAGES_FOUND
    end
    return response
end


---@param receiverPath string The absolute path to the receiving user's stored messages
---@param request mailRequest The request for the mailserver
---@param response mailResponse The response sent to the user
---@return mailResponse response
local function HandlePut(receiverPath, request, response)
    local filepath = fs.combine(receiverPath, request.filename)
    if fs.exists(filepath) then
        if fs.isDir(filepath) then
            response.message = mail.ERR_CANNOT_MODIFY_DIRECTORY
        else
            response.message = mail.ERR_ALREADY_EXISTS
            response.filesize = fs.getSize(filepath)
        end
    elseif fs.getFreeSpace(filepath) < #request.data then
        response.message = mail.ERR_INSUFFICIENT_STORAGE
    else
        file = fs.open(filepath, "w")
        file.write(request.data)
        file.close()
        response.message = mail.SUCCESS_WRITTEN
    end
    return response
end


---@param receiverPath string The absolute path to the receiving user's stored messages
---@param request mailRequest The request for the mailserver
---@param response mailResponse The response sent to the user
---@return mailResponse response
local function HandleDelete(receiverPath, request, response)
    local filepath = fs.combine(receiverPath, request.filename)
    if fs.exists(filepath) then
        if fs.isDir(filepath) then
            response.message = mail.ERR_CANNOT_MODIFY_DIRECTORY
        else
            fs.delete(filepath)
            response.message = mail.SUCCESS_REMOVED
        end
    else
        response.message = mail.ERR_DOES_NOT_EXIST
    end
    return response
end


---@param request mailRequest The request for the mailserver
---@param serverPath string The absolute path to the stored messages
---@return mailResponse response
local function HandleRequest(request, serverPath)
    response = {}

    if request.recipient then
        local receiverPath = fs.combine(serverPath, tostring(request.recipient))
        if not fs.exists(receiverPath) then
            fs.makeDir(receiverPath)
        end

        if request.method == mail.METHOD.GET then
            response = HandleGet(receiverPath, request, response)
        elseif request.method == mail.METHOD.PUT then
            response = HandlePut(receiverPath, request, response)
        elseif request.method == mail.METHOD.DELETE then
            response = HandleDelete(receiverPath, request, response)
        else
            response.message = mail.ERR_INVALID_REQUEST
        end
    else 
        response.message = mail.ERR_INVALID_REQUEST
    end
    return response
end


---@param name string The name of the mailserver
---@param mountPath string The path to the stored messages
---@return error #Will never return except in case of error
function mail.Serve(name, mountPath)
    local sPath = shell.resolve(mountPath)
    if fs.exists(sPath) and not fs.isDir(sPath) then
        return mail.ERR_MOUNT_TO_DIRECTORY
    end
    fs.makeDir(sPath)

    rednet.host(mail.PROTOCOL, name)

    while true do
        local sender, request, protocol = rednet.receive(mail.PROTOCOL, 5)
        if protocol == mail.PROTOCOL then
            response = HandleRequest(request, sPath)
            rednet.send(sender, response, mail.PROTOCOL)
        end
    end
end


---@param name string The name of the mailserver
---@param recipient string Username receiving the sent mail
---@param filepath string The path to the file being sent
---@param retries? integer How many seconds to wait for response from server
---@return status
function mail.SendFile(name, recipient, filepath, retries)

    retries = retries or 5
    if retries < 0 then
        return mail.ERR_INVALID_RETIRES
    end

    local sPath = shell.resolve(filepath)
    if not fs.exists(sPath) then
        return mail.ERR_DOES_NOT_EXIST
    elseif fs.isDir(sPath) then
        return mail.ERR_CANNOT_SEND_DIRECTORY
    end

    local filename = fs.getName(sPath)
    local file = fs.open(sPath, "r")
    local data = file.readAll()
    file.close()
    
    local request = {
        ["method"] = mail.METHOD.PUT,
        ["filename"] = filename,
        ["data"] = data,
        ["recipient"] = recipient,
    } ---@type mailRequest

    local serverID
    local attempt = 0
    repeat
        serverID = rednet.lookup(mail.PROTOCOL, name)
    until serverID or attempt > retries
    if not serverID then
        return mail.ERR_SERVER_NOT_FOUND
    end

    rednet.send(serverID, request, mail.PROTOCOL)

    attempt = 0
    repeat
        senderID, response, _ = rednet.receive(mail.PROTOCOL, 1)
        attempt = attempt + 1
    until senderID == serverID or attempt > retries
    if senderID ~= serverID then
        return mail.ERR_MAX_RETIRES
    end

    return response.message
end


---@param name string The name of the mailserver
---@param recipient string Username whose mail is being removed
---@param filename string The name of the file being removed
---@param retries? integer How many seconds to wait for response from server
---@return status
function mail.DeleteFile(name, recipient, filename, retries)

    retries = retries or 5
    if retries < 0 then
        return mail.ERR_INVALID_RETIRES
    end
    
    local request = {
        ["method"] = mail.METHOD.DELETE,
        ["recipient"] = recipient,
        ["filename"] = filename,
    } ---@type mailRequest

    local serverID
    local attempt = 0
    repeat
        serverID = rednet.lookup(mail.PROTOCOL, name)
    until serverID or attempt > retries
    if not serverID then
        return mail.ERR_SERVER_NOT_FOUND
    end

    rednet.send(serverID, request, mail.PROTOCOL)

    attempt = 0
    repeat
        senderID, response, _ = rednet.receive(mail.PROTOCOL, 1)
        attempt = attempt + 1
    until senderID == serverID or attempt > retries
    if senderID ~= serverID then
        return mail.ERR_MAX_RETIRES
    end

    return response.message
end

return mail
