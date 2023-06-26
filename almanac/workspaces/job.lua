local almanac = require("almanac.core")
local Workspace = almanac.Workspace

local util = require("almanac.util")
---------------------------------------------------
-- Job --
---------------------------------------------------
local Job = {}
Job.__index = Job
setmetatable(Job, Workspace)

function Job:show()
    local infobox = almanac.Infobox:new({title = self.data.name})
    
    infobox:insert("Bases", self:show_base())
    infobox:insert("Growths", self:show_growth())
    infobox:insert("Caps", self:show_cap())
    
    infobox:insert("Ranks", self:show_rank(), true)
    infobox:insert("Skills", self:show_skill(), true)
    
    return infobox
end

---------------------------------------------------
-- Base
function Job:show_base()
    return util.table_stats(self:get_base())
end

function Job:get_base()
    local base = util.copy(self.data.base)
    setmetatable(base, util.math.Stats)
    
    return base
end

---------------------------------------------------
-- Growth
function Job:show_growth()
    if self.data.growth then
        return util.table_stats(self:get_growth(), {value_end = "%"})
    end
    
end

function Job:get_growth()
    local growth = util.copy(self.data.growth)
    setmetatable(growth, util.math.Stats)
    
    return growth
end

---------------------------------------------------
-- Cap
function Job:show_cap()
    if self.data.cap then
        return util.table_stats(self:get_cap())
    end
end

function Job:get_cap()
    local cap = util.copy(self.data.cap)
    setmetatable(cap, util.math.Stats)
    
    return cap
end

---------------------------------------------------
function Job:show_skill()
    if self.data.skill then
        return self:display_skill(self.data.skill)
    end
end

function Job:get_skill()
    return util.copy(self.data.skill)
end

function Job:display_skill(data)
    if self.Skill and data then
        local text = ""
        
        local function get(s)
            return self.Skill:new(s):get_fancy() .. "\n"
        end
            
        local found = false
        
        -- loop first with pairs to catch ordered dicts
        for key, value in pairs(data) do
            if type(key) ~= "number" then
                found = true
                
                text = text .. get(key)
            end
        end
        
        -- loop sequences here
        if not found then
            for i, pair in ipairs(data) do
                text = text .. get(pair)
            end
        end
        
        return text
    end
end

---------------------------------------------------
function Job:show_rank()
    if self:has_rank() then
        return util.text.weapon_rank(self:get_rank(), {pack = self.pack, exp = self.rank_exp})
    end
end

function Job:has_rank()
    return (self.data.rank and #self.data.rank > 0)
end

function Job:get_rank()
    return util.copy(self.data.rank)
end

---------------------------------------------------

function Job:get_name()
    return util.text.remove_parentheses(self.data.name)
end

function Job:can_promo()
    if self.data.promo ~= nil then
        if type(self.data.promo) == "table" and #self.data.promo > 0 then
            return true
            
        elseif type(self.data.promo) ~= "table" and self.data.promo then
            return true
        end
    end
    
    return false
end

function Job:is_promoted()
    return not self:can_promo()
end

function Job:can_dismount()
    return false
end

function Job:get_promo()
    local promo = self.data.promo
    
    if type(promo) ~= "string" then
        promo = promo[1]
    end
    
    return self.tbl:new(promo)
end

function Job:get_promo_bonus()
    if self.data.promo_bonus then
        return util.copy(self.data.promo_bonus)
        
    else
        return {}
    end
end

function Job:has_multiple_promos()
    return (type(self.data.promo) == "table" and #self.data.promo > 1)
end

return Job
