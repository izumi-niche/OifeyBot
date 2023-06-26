local file = require("almanac.util.file")

local config = {
    enabled = false,
    default = ""
}

---------------------------------------------------
-- Emoji--
---------------------------------------------------
local Emoji = {}
Emoji.__index = Emoji

function Emoji:new(name, id, animated)
    local obj = {}
    setmetatable(obj, self)
    
    obj.name = name
    obj.id = id
    obj.animated = animated or false
    
    return obj
end

function Emoji:get()
    if self.animated then
        return string.format("<:a:%s:%s>", self.name, self.id)
        
    else
        return string.format("<:%s:%s>", self.name, self.id)
        
    end
    
end

---------------------------------------------------
-- Pack --
---------------------------------------------------
local Pack = {}
Pack.__index = Pack

function Pack:new(file_path)
    local obj = {}
    setmetatable(obj, self)
    
    obj.emojis = {}
    
    if file_path then
        local r = file.json_read(file_path)
        
        for key, value in pairs(r) do
            local emoji = Emoji:new(value.name, value.id, value.animated)
            
            obj.emojis[key] = emoji
        end
        
    end
    
    return obj
end

function Pack:get(emoji, on_error)
    on_error = on_error or config.default
    
    if self:has(emoji) then
        return self.emojis[emoji]:get()
    else
        return on_error
    end
    
end

-- For use in buttons
function Pack:raw(emoji)
    if self:has(emoji) then
        return self.emojis[emoji]
    else
        return config.default
        
    end
    
end

function Pack:has(emoji)
    if config.enabled and self.emojis[emoji] then
        return true
        
    else
        return false
        
    end
end
---------------------------------------------------
-- Misc --
---------------------------------------------------
local loaded_packs = {}

function get(file_path)
    if not loaded_packs[file_path] then
        local pack = Pack:new(file_path)
        
        loaded_packs[file_path] = pack
    end
    
    return loaded_packs[file_path]
    
end

loaded_packs["global"] = Pack:new("database/emoji_global.json")

r =  {
    Emoji = Emoji,
    Pack = Pack,
    config = config,
    get = get
}

r.__index = function(tbl, key)
    return get(key)
end

setmetatable(r, r)

return r