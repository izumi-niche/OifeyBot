local json = require("almanac.lib.json")

local module = {}

function module.read(path)
    local file = io.open(path, "r")
    
    if not file then
        error("File not found! " .. path)
    end
    
    local text = file:read("*a")
    file:close()
    
    return text
end

function module.json_read(path)
    local function thing()
        return json.decode(module.read(path))
    end
    
    local status, data = pcall(thing)
    
    if status then
        return data
        
    else
        error("JSON ERROR: " .. path .. "|" .. data)
    end
end

function module.exists(path)
    local file = io.open(path, "r")
    
    return file ~= nil and file:close()
end

return module