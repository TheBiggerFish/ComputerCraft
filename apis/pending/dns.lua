local dns = {}

local stringExt = require("/api/string")
local time = require("/api/time")

---@type protocol
dns.PROTOCOL = "dns2"
dns.HOSTNAMES = "/hostnames"

---@enum dnsMethod types
dns.METHOD = {
    DELETE = "DELETE",
    GET = "GET",
    PUT = "PUT",
}

---@alias record string

---@class dnsRecord
---@field name record The human-readable record identifier
---@field hostname hostname Where the record points
---@field modified datetime Time of last update

---@class dnsCached
---@field record dnsRecord Record
---@field expires datetime? Time of expiration

---@class dnsRequest
---@field method dnsMethod Functionality requested of server
---@field record string Identifier of record to be modified or read
---@field hostname hostname? Computer ID

---@class dnsResponse
---@field status status Response for client interpretation
---@field record dnsRecord? Metadata of file present on server


---@alias dnsHandler fun(request: dnsRequest, response: dnsResponse)

dns.STATUS_UNKNOWN = "Status unknown."
dns.SUCCESS_READ = "Record read."
dns.SUCCESS_WRITTEN = "Record written."
dns.SUCCESS_REMOVED = "Record removed."
dns.ERR_DOES_NOT_EXIST = "Record does not exist."
dns.ERR_FAILURE = "Server encountered an error."


---@return table<record, dnsCached>
function dns.ReadHostnames()
    local cache = {}
    local now = time.now()
    local file
    if not fs.exists(dns.HOSTNAMES) then
        fs.open(dns.HOSTNAMES, "w").close()
        return cache
    end

    file = fs.open(dns.HOSTNAMES, "r")
    local line
    repeat
        line = file.readLine()
        local list = stringExt.split(line, "|")
        local hostname = tonumber(list[2])
        local modified = tonumber(list[3])
        local expires
        if list[4] then
            expires = tonumber(list[4])
        end

        local unexpired = not expires or expires < now

        if hostname and modified and unexpired then
            ---@type dnsRecord
            local record = {
                name = list[1],
                hostname = hostname,
                modified = modified,
            }
            ---@type dnsCached
            local entry = {
                record = record,
                expires = expires
            }

            cache[list[1]] = entry
        end
    until line == nil
    file.close()

    return cache
end

---@param name string Identifier of record to be modified or read
---@param hostname hostname? Computer ID
---@return boolean #Whether an error was encountered
function dns.SetHostname(name, hostname)
    local hostnames = dns.ReadHostnames()
    if hostname == nil then
        hostnames[name] = nil
    else
        ---@type dnsRecord
        local record = {
            name = name,
            hostname = hostname,
            modified = time.now(),
        }

        hostnames[name] = {
            record = record,
        }
    end

    local keys = {} ---@type string[]
    for k, v in pairs(hostnames) do
        table.insert(keys, k)
    end
    local lt = function (a, b) return a < b end
    table.sort(keys, lt)

    local file = fs.open(dns.HOSTNAMES, "w")
    for _, key in pairs(keys) do
        local entry = hostnames[key]
        local record = entry.record
        local flattened = string.format("%s|%d|%d", record.name, record.hostname, record.modified)
        if entry.expires then
            flattened = flattened .. "|" .. entry.expires
        end
        file.writeLine(flattened)
    end
    file.close()

    return false
end


---@param request dnsRequest The request for the dnsServer
---@param response dnsResponse The response returned to the client
---@return nil
local function HandleGet(request, response)
    local hostnames = dns.ReadHostnames()
    local entry = hostnames[request.record]
    if entry then
        response.status = dns.SUCCESS_READ
        response.record = entry.record
    else
        response.status = dns.ERR_DOES_NOT_EXIST
    end
end


---@param request dnsRequest The request for the dnsServer
---@param response dnsResponse The response returned to the client
---@return nil
local function HandleDelete(request, response)
    local err = dns.SetHostname(request.record, nil)
    if err then
        response.status = dns.ERR_FAILURE
    else
        response.status = dns.SUCCESS_REMOVED
    end
end


---@param request dnsRequest The request for the dnsServer
---@param response dnsResponse The response returned to the client
---@return nil
local function HandlePut(request, response)
    local err = dns.SetHostname(request.record, request.hostname)
    if err then
        response.status = dns.ERR_FAILURE
    else
        response.status = dns.SUCCESS_WRITTEN
    end
end


---@type table<dnsMethod, dnsHandler>
dns.Handlers = {
    [dns.METHOD.DELETE] = HandleDelete,
    [dns.METHOD.GET] = HandleGet,
    [dns.METHOD.PUT] = HandlePut,
}

---@param request dnsRequest The request for the dnsServer
---@return dnsResponse response
local function HandleRequest(request)
    ---@type dnsResponse
    local response = {
        status = dns.STATUS_UNKNOWN
    }

    handler = dns.Handlers[request.method]
    if request.record and handler then
        handler(request, response)
    else
        response.status = dns.ERR_INVALID_REQUEST
    end
    return response
end

---Will never return except in case of error
---@param name string? The name of the server
function dns.Serve(name)
    name = name or "nameserver"
    rednet.host(dns.PROTOCOL, name)

    while true do
        local sender, request, protocol = rednet.receive(dns.PROTOCOL, 5)
        if request ~= nil then
            response = HandleRequest(request)
            rednet.send(sender, response, dns.PROTOCOL)
        end
    end
end

---Will never return except in case of error
---@param nameserver string The name of the nameserver
function dns.lookup(nameserver)
    rednet.lookup(dns.PROTOCOL, nameserver)

    while true do
        local sender, request, protocol = rednet.receive(dns.PROTOCOL, 5)
        if request ~= nil then
            response = HandleRequest(request)
            rednet.send(sender, response, dns.PROTOCOL)
        end
    end
end

return dns