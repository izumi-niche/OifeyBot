local almanac = require("almanac.core")
local Workspace = almanac.Workspace

local Infobox = almanac.Infobox

local util = require("almanac.util")

---------------------------------------------------
-- Skill --
---------------------------------------------------
local Skill = {}
Skill.__index = Skill
setmetatable(Skill, Workspace)

function Skill:show()
    local desc = self:get_desc()
    
    if self.data.stats then
        desc = util.table_stats(self.data.stats) .. "\n" .. desc
    end
    
    local infobox = Infobox:new({title = self:get_name(), desc = desc})
    
    if self.data.reference then
        for k, v in pairs(self.data.reference) do
            infobox:insert(k, v, true)
        end
    end
    
    infobox:image("thumbnail", self:get_icon())
    
    return infobox
end

function Skill:get_fancy(args)
    args = args or {}
    
    local name = self:get_name()
    
    if args.bold then
        name = util.text.bold(name)
        
    elseif args.italics then
        name = util.text.italics(name)
    end
    
    return self:get_emoji() .. name
end

function Skill:get_name()
    return self.data.name
end

function Skill:get_desc()
    if self.data.desc then
        return self.data.desc
        
    else
        return ""
    end
end

function Skill:get_emoji()
    return util.emoji.global:get("star")
end

function Skill:get_icon()
    return nil
end

return Skill