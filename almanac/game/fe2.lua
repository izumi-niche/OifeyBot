local almanac = require("almanac")

local util = almanac.util

local fe15 = require("almanac.game.fe15")

local Character = {}
local Job = {}
local Item = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = fe15.Character.inventory:use_as_base()

inventory:get_calc("hit").func = function(data, unit, item)
if item:is_magic() then
    return item.stats.hit
else
    return item.stats.hit + unit.stats.skl
end end

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, fe15.Character)

Character.section = almanac.get("database/fe2/char.json")
Character.helper_job_growth = false
Character.helper_portrait = "database/fe2/images"

Character.compare_cap = false

Character.inventory = inventory

Character.Job = Job
Character.Item = Item

Character.item_warning = true

function Character:show_cap()
    return nil
end

function Character:get_cap()
    return {hp = 52, atk = 40, skl = 40, spd = 40, lck = 40, def = 40, res = 40}
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, fe15.Job)

Job.section = almanac.get("database/fe2/job.json")

-- Only return the res for display stuff and dread fither
function Job:get_base(display)
    local base = util.copy(self.data.base)
    
    if not display and self.id ~= "dreadfighter" then
        base.res = 0
    end
    
    return base
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, fe15.Item)

Item.section = almanac.get("database/fe2/item.json")

return {
    Character = Character,
    Job = Job,
    Item = Item
}