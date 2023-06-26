local almanac = require("almanac")

local util = almanac.util

local fe12 = require("almanac.game.fe12")

local pack = util.emoji.get("database/fe11/emoji.json")

local Character = {}
local Job = {}
local Item = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = fe12.Character.inventory:use_as_base()

inventory:get_calc("as").func = function(data, unit, item)
    return unit.stats.spd - math.max(item.stats.wt - unit.stats.str, 0)
end

inventory:get_calc("crit").func = function(data, unit, item)
    return util.floor(unit.stats.skl / 2) + item.stats.crit + unit.job:crit_bonus()
end

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, fe12.Character)

Character.Job = Job
Character.Item = Item
Character.pack = pack

Character.section = almanac.get("database/fe11/char.json")
Character.helper_portrait = "database/fe11/images"

Character.inventory = inventory

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, fe12.Job)

Job.icon = "database/fe11/images/icon/%s"

Job.section = almanac.get("database/fe11/job.json")

Job.pack = pack

function Job:hit_bonus()
    if self.id == "swordmaster" then
        return 10
        
    elseif self.id == "sniper" then
        return 5
        
    else
        return 0
    end
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, fe12.Item)

Item.section = almanac.get("database/fe11/item.json")

return {
    Character = Character,
    Job = Job,
    Item = Item
}