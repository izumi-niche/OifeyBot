local almanac = require("almanac")

local util = almanac.util

local fe2 = require("almanac.game.fe2")

local Character = {}
local Job = {}
local Item = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = fe2.Character.inventory:use_as_base()

inventory:get_calc("atk").func = function(data, unit, item)
if item:is_magic() then
    return item.stats.mt
else
    return unit.stats.str + item.stats.mt
end end

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, fe2.Character)

Character.section = almanac.get("database/fe1/char.json")
Character.helper_portrait = "database/fe1/images"

Character.inventory = inventory

Character.Job = Job
Character.Item = Item

function Character:default_options()
    return {
        class = self.data.job,
        luck = math.random(0, 7)
    }
end

function Character:setup()
    self.job = self.Job:new(self.options.class)
    
    self.luck = self.options.luck
end

-- Mod
function Character:get_mod()
    local text = self:get_lvl_mod()
    
    if self:has_random_luck() then
        text = text .. "\n:game_die:**Luck Roll**: " .. tostring(self.luck)
        
        if not self.minimal then
            text = text .. " (Min: 0 Max: 7)"
        end
    end
    
    text = text .. self:common_mods()
    
    return text
end

-- Base
function Character:get_base()
    local base = util.copy(self.data.base)
    
    if self:has_random_luck() then
        base.lck = self.luck
    end
    
    return base
end

function Character:has_random_luck()
    return type(self.data.base.lck) == "string"
end

-- Cap
function Character:get_cap()
    return {hp = 52, str = 20, wlv = 20, skl = 20, spd = 20, lck = 20, def = 20, res = 20}
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, fe2.Job)

Job.section = almanac.get("database/fe1/job.json")

Job.hp_bonus = false

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, fe2.Item)

Item.section = almanac.get("database/fe1/item.json")

return {
    Character = Character,
    Job = Job,
    Item = Item
}