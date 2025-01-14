-- local metadata = {}
-- metadata.FILENAME = "metadata.dat"


-- ---@param filetype string Type of file being requested
-- ---@param filename string Name of file being requested
-- ---@return ftpMetadata? #Metadata of requested file
-- function metadata.ReadMetaData(filetype, filename)
--     local dir = directories[filetype]
--     local metapath = fs.combine(dir, metadata.FILENAME)
--     if not fs.exists(metapath) then
--         return
--     end

--     local file = fs.open(metapath, "r")
--     local allMetadata = textutils.unserialize(file.readAll())
--     fs.close()

--     if type(allMetadata) ~= "table" then
--         return
--     end

--     return allMetadata[filename]
-- end


-- ---@param filetype string Type of file being modified
-- ---@param filename string Name of file being modified
-- ---@param newMetadata ftpMetadata? Metadata details for file being modified, or nil if file is deleted
-- ---@return boolean #Success status for modification
-- function metadata.ModifyMetaData(filetype, filename, newMetadata)
--     local dir = directories[filetype]
--     local metapath = fs.combine(dir, metadata.FILENAME)
--     local allMetadata ---@type table<string, ftpMetadata>
  
--     if fs.exists(metapath) then
--         local file = fs.open(metapath, "r")
--         local oldText = file.readAll()
--         fs.close()
--         allMetadata = textutils.unserialize()
--     else
--         fs.makeDir(dir)
--         allMetadata = {}
--     end

--     if type(allMetadata) ~= "table" then
--         return false
--     end
--     allMetadata[filename] = newMetadata

--     local newText = textutils.serialize(allMetadata)
--     local file = fs.open(metapath, "w")
--     file.writeAll(newText)
--     fs.close()

--     return true
-- end

-- return metadata