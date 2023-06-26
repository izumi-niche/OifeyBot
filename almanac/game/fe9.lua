local almanac = require("almanac")
local workspaces = almanac.workspaces

local util = almanac.util

local fe10 = require("almanac.game.fe10")

local Character = {}
local Job = {}
local Item = {}
local Skill = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = fe10.Character.inventory:use_as_base()

inventory:get_calc("hit").func = function(data, unit, item)
    return item.stats.hit + (unit.stats.skl * 2) + util.floor(unit.stats.lck / 2)
end

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, fe10.Character)

Character.section = almanac.get("database/fe9/char.json")
Character.helper_portrait = "database/fe9/images"

Character.Job = Job
Character.Item = Item
Character.Skill = Skill

-- Mod
-- Base
function Character:show_base()
    local base = self:final_base()
    
    if not self:is_personal() and self:is_laguz() then
        local trans = self:get_transform_bonus(base)
        
        for key, value in pairs(trans) do
            if base[key] ~= nil and base[key] ~= value and value ~= 0 then
                base[key] = string.format("%s***+%s***", base[key], value)
            end
        end
    elseif not self:is_laguz() then
        base = util.math.cap_stats(base, self:final_cap(), {bold = true, higher = true})
    end
    
    return util.table_stats(base)
end

function Character:get_transform_bonus(base)
    local result = {}
    setmetatable(result, util.math.Stats)
    
    local trans = self.Job:new(self.job.data.trans):get_base()
    
    local result = util.math.sub_stats(trans, self.job:get_base())
    
    return result
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, fe10.Job)

Job.section = almanac.get("database/fe9/job.json")

function Job:get_name()
    if self:is_laguz() then
        return self.data.name
        
    else
        return fe10.Job.get_name(self)
    end
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, fe10.Item)

Item.section = almanac.get("database/fe9/item.json")


---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, fe10.Skill)

Skill.section = almanac.get("database/fe9/skill.json")

return {
    Character = Character,
    Job = Job,
    Item = Item,
    Skill = Skill
}