local almanac = require("almanac")

local fe7 = require("almanac.game.fe7")

local rank_exp = {
    E = 1,
    D = 51,
    C = 101,
    B = 151,
    A = 201,
    S = 251
}

local Character = {}
local Job = {}
local Item = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = fe7.Character.inventory:use_as_base()

inventory.eff_multiplier = 3

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, fe7.Character)

Character.section = almanac.get("database/fe6/char.json")
Character.helper_portrait = "database/fe6/images"

Character.promo_use_fixed = false
Character.rank_exp = rank_exp

Character.inventory = inventory

Character.alt_icon = {
    {label = "A Route", emoji = "larum"},
    {label = "B Route", emoji = "elffin"}
}

Character.Job = Job
Character.Item = Item

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, fe7.Job)

Job.crit_value = 30

Job.section = almanac.get("database/fe6/job.json")

Job.rank_exp = rank_exp

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, fe7.Item)

Item.section = almanac.get("database/fe6/item.json")

return {
    Character = Character,
    Job = Job,
    Item = Item
}