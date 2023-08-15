local ftp = {}

local time = require("/api/time")

---@type protocol
ftp.PROTOCOL = "ftp"
ftp.METADATA = "metadata.dat"

---@enum ftpMethod types
ftp.METHOD = {
    DELETE = "DELETE",
    GET = "GET",
    HEAD = "HEAD",
    PATCH = "PATCH",
    PUT = "PUT",
}

---@enum ftpMethod types
ftp.FILETYPE = {
    TEXT = "TEXT",
    API = "API",
    SCRIPT = "SCRIPT",
}

local directories = {
    [ftp.FILETYPE.TEXT] = "/doc",
    [ftp.FILETYPE.API] = "/api",
    [ftp.FILETYPE.SCRIPT] = "/program",
}

---@class ftpMetadata
---@field name string Name of file
---@field size integer Size of file
---@field modified integer Time of last update

---@class ftpRequest
---@field method ftpMethod Functionality requested of server
---@field filetype string Type of file being transmitted or requested
---@field filename string Name of file being transmitted or requested
---@field data string? Contents of file being transmitted for PUT request

---@class ftpResponse
---@field status status Response for client interpretation
---@field metadata ftpMetadata? Metadata of file present on server
---@field data string? Data of file being transmitted back for GET request

---@alias ftpHandler fun(request: ftpRequest, response: ftpResponse)

---Client-side errors
ftp.ERR_MOUNT_TO_DIRECTORY = "Mountpoint must be a directory."
ftp.ERR_MAX_RETIRES = "Reached maximum retries."
ftp.ERR_INVALID_RETRIES = "Invalid number of retries. Retries must be a positive integer."
ftp.ERR_CANNOT_SEND_DIRECTORY = "Cannot send a directory."
ftp.ERR_SERVER_NOT_FOUND = "Failed to lookup the server by name."

---Status responses
ftp.ERR_INVALID_REQUEST = "Request missing required field."
ftp.ERR_CANNOT_MODIFY_DIRECTORY = "Unable to modify directory."
ftp.ERR_METADATA_UPDATE_FAILED = "Metadata file could not be updated."
ftp.ERR_ALREADY_EXISTS = "File already exists."
ftp.ERR_DOES_NOT_EXIST = "File does not exist."
ftp.ERR_INSUFFICIENT_STORAGE = "Insufficient storage."
ftp.SUCCESS_WITHOUT_METADATA = "File read but metadata not found."
ftp.SUCCESS_READ = "File read."
ftp.SUCCESS_WRITTEN = "File written."
ftp.SUCCESS_REMOVED = "File removed."
ftp.SUCCESS_MODIFIED = "File modified."
ftp.STATUS_UNKNOWN = "Status unknown."


---@param filetype string Type of file being requested
---@param filename string Name of file being requested
---@return ftpMetadata? #Metadata of requested file
local function ReadMetaData(filetype, filename)
    local dir = directories[filetype]
    local metapath = fs.combine(dir, ftp.METADATA)
    if not fs.exists(metapath) then
        return
    end

    local file = fs.open(metapath, "r")
    local metadata = textutils.unserialize(file.readAll())
    fs.close()

    if type(metadata) ~= "table" then
        return
    end

    return metadata[filename]
end


---@param filetype string Type of file being modified
---@param filename string Name of file being modified
---@param metadata ftpMetadata? Metadata details for file being modified, or nil if file is deleted
---@return boolean #Success status for modification
local function ModifyMetaData(filetype, filename, metadata)
    local dir = directories[filetype]
    local metapath = fs.combine(dir, ftp.METADATA)
    local allMetadata ---@type table<string, ftpMetadata>

    if fs.exists(metapath) then
        local file = fs.open(metapath, "r")
        local oldText = file.readAll()
        fs.close()
        allMetadata = textutils.unserialize()
    else
        fs.makeDir(dir)
        allMetadata = {}
    end

    if type(allMetadata) ~= "table" then
        return false
    end
    allMetadata[filename] = metadata

    local newText = textutils.serialize(allMetadata)
    local file = fs.open(metapath, "w")
    file.writeAll(newText)
    fs.close()

    return true
end


---@param request ftpRequest The request for the ftpserver
---@param response ftpResponse The response returned to the client
---@return nil
local function HandleGet(request, response)
    local dir = directories[request.filetype]
    local filepath = fs.combine(dir, request.filename)
    local metadata = ReadMetaData(request.filetype, request.filename)
    if not fs.exists(filepath) then
        response.status = ftp.ERR_DOES_NOT_EXIST
    elseif fs.isDir(filepath) then
        response.status = ftp.ERR_CANNOT_SEND_DIRECTORY
    else
        local file = fs.open(filepath, "r")
        response.metadata = metadata
        response.data = file.readAll()
        response.status = ftp.SUCCESS_READ
        fs.close(file)
    end
end


---@param request ftpRequest The request for the ftpserver
---@param response ftpResponse The response returned to the client
---@return nil
local function HandlePut(request, response)
    local dir = directories[request.filetype]
    local filepath = fs.combine(dir, request.filename)

    local oldMetadata = ReadMetaData(request.filetype, request.filename)

    ---@type ftpMetadata
    local newMetadata = {
        name = request.filename,
        modified = time.now(),
        size = #request.data
    }

    if fs.exists(filepath) then
        if fs.isDir(filepath) then
            response.status = ftp.ERR_CANNOT_MODIFY_DIRECTORY
        else
            response.status = ftp.ERR_ALREADY_EXISTS
        end
    elseif fs.getFreeSpace(filepath) < #request.data then
        response.status = ftp.ERR_INSUFFICIENT_STORAGE
    elseif not ModifyMetaData(request.filetype, request.filename, newMetadata) then
        response.status = ftp.ERR_METADATA_UPDATE_FAILED
    else
        file = fs.open(filepath, "w")
        file.write(request.data)
        file.close()
        response.status = ftp.SUCCESS_WRITTEN
    end
end


---@param request ftpRequest The request for the ftpserver
---@param response ftpResponse The response returned to the client
---@return nil
local function HandleDelete(request, response)
    local dir = directories[request.filetype]
    local filepath = fs.combine(dir, request.filename)
    local metadata = ReadMetaData(request.filetype, request.filename)
    if not fs.exists(filepath) then
        response.status = ftp.ERR_DOES_NOT_EXIST
    elseif fs.isDir(filepath) then
        response.status = ftp.ERR_CANNOT_SEND_DIRECTORY
    elseif not ModifyMetaData(request.filetype, request.filename, nil) then
        response.status = ftp.ERR_METADATA_UPDATE_FAILED
    else
        local file = fs.delete(filepath)
        response.status = ftp.SUCCESS_READ
    end
end


---@param request ftpRequest The request for the ftpserver
---@param response ftpResponse The response returned to the client
---@return nil
local function HandlePatch(request, response)
    local dir = directories[request.filetype]
    local filepath = fs.combine(dir, request.filename)

    local oldMetadata = ReadMetaData(request.filetype, request.filename)

    ---@type ftpMetadata
    local newMetadata = {
        name = request.filename,
        modified = time.now(),
        size = #request.data
    }

    if fs.exists(filepath) then
        if fs.isDir(filepath) then
            response.status = ftp.ERR_CANNOT_MODIFY_DIRECTORY
        elseif not ModifyMetaData(request.filetype, request.filename, newMetadata) then
            response.status = ftp.ERR_METADATA_UPDATE_FAILED
        else
            file = fs.open(filepath, "w")
            file.write(request.data)
            file.close()
            response.status = ftp.SUCCESS_MODIFIED
        end
    elseif fs.getFreeSpace(filepath) < #request.data then
        response.status = ftp.ERR_INSUFFICIENT_STORAGE
    else
        response.status = ftp.ERR_DOES_NOT_EXIST
    end
end


---@param request ftpRequest The request for the ftpserver
---@param response ftpResponse The response returned to the client
---@return nil
local function HandleHead(request, response)
    local dir = directories[request.filetype]
    local filepath = fs.combine(dir, request.filename)
    local metadata = ReadMetaData(request.filetype, request.filename)
    if not fs.exists(filepath) then
        response.status = ftp.ERR_DOES_NOT_EXIST
    elseif fs.isDir(filepath) then
        response.status = ftp.ERR_CANNOT_SEND_DIRECTORY
    elseif not metadata then
        response.status = ftp.SUCCESS_WITHOUT_METADATA
    else
        response.metadata = metadata
        response.status = ftp.SUCCESS_READ
    end
end

---@type table<ftpMethod, ftpHandler>
ftp.Handlers = {
    [ftp.METHOD.DELETE] = HandleDelete,
    [ftp.METHOD.GET] = HandleGet,
    [ftp.METHOD.HEAD] = HandleHead,
    [ftp.METHOD.PATCH] = HandlePatch,
    [ftp.METHOD.PUT] = HandlePut,
}


---@param request ftpRequest The request for the ftpserver
---@return ftpResponse response
local function HandleRequest(request)
    ---@type ftpResponse
    local response = {
        status = ftp.STATUS_UNKNOWN
    }

    handler = ftp.Handlers[request.method]

    if not request.filename then
        response.status = ftp.ERR_INVALID_REQUEST
    elseif not request.filetype or not directories[request.filetype] then
        response.status = ftp.ERR_INVALID_REQUEST
    elseif handler then
        handler(request, response)
    else
        response.status = ftp.ERR_INVALID_REQUEST
    end
    return response
end


---@param name string? The name of the server
---@return error #Will never return except in case of error
function ftp.Serve(name)
    name = name or "ftpserver"
    rednet.host(ftp.PROTOCOL, name)

    while true do
        local sender, request, protocol = rednet.receive(ftp.PROTOCOL, 5)
        if request ~= nil then
            response = HandleRequest(request)
            rednet.send(sender, response, ftp.PROTOCOL)
        end
    end
end

return ftp