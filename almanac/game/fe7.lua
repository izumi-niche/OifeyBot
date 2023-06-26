local almanac = require("almanac")

local fe8 = require("almanac.game.fe8")

local Character = {}
local Job = {}
local Item = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = fe8.Character.inventory:use_as_base()

inventory.eff_multiplier = 2

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, fe8.Character)

Character.section = almanac.get("database/fe7/char.json")
Character.helper_portrait = "database/fe7/images"

Character.inventory = inventory

Character.alt_icon = {
    {label = "Main Mode", emoji = "fe7_lord"},
    {label = "Lyn Mode", emoji = "lyn"}
}

Character.Job = Job
Character.Item = Item

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, fe8.Job)

Job.section = almanac.get("database/fe7/job.json")

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, fe8.Item)

Item.section = almanac.get("database/fe7/item.json")

return {
    Character = Character,
    Job = Job,
    Item = Item
}