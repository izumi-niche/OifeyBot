local almanac = require("almanac")
local workspaces = almanac.workspaces
local util = almanac.util

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local Character = {}
local Job = {}
local Item = {}
local Skill = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = util.math.Inventory:new()

inventory:item_calc("atk", function(data, unit, item) return unit.stats.atk + item.stats.mt end)
inventory:item_calc("as", function(data, unit, item) return unit.stats.spd - item.stats.wt end)

inventory:item_calc("hit", function(data, unit, item)
if item:is_magic() then
    return item.stats.hit + util.floor((unit.stats.skl / unit.stats.lck) / 2)
else
    return item.stats.hit + unit.stats.skl
end end)

inventory:item_calc("crit", function(data, unit, item) return item.stats.crit + util.floor((unit.stats.skl + unit.stats.lck) / 2) end)

--[[
inventory:item_calc("avo", function(data, unit, item)
if item:is_magic() then
    return util.floor((data.result.as + unit.stats.lck) / 2) 
else
    return data.result.as
end end)

inventory:item_calc("ddg", function(data, unit, item) return util.floor(unit.stats.lck / 2) end)
--]]

---------------------------------------------------
-- Character --
---------------------------------------------------
local shard_bonus = {
    aries = {lck = 40},
    taurus = {hp = 5, atk = 5, skl = 5, spd = 5, lck = 5, def = 5, res = 2},
    cancer = {atk = 25, skl = -5, def = 50},
    leo = {atk = 50, def = -10},
    virgo = {atk = 10, skl = 10, def = -10, res = 5},
    libra = {hp = -10, atk = 5, skl = 5, spd = 40, lck = 10, res = -2},
    scorpio = {atk = 20, skl = 20, spd = 10, lck = -10},
    sagittarius = {hp = -10, skl = 40, spd = 10},
    capricorn = {hp = 20, atk = 15, skl = 5, spd = -10, def = 10},
    aquarius = {atk = 15, skl = 15, spd = 10},
    pisces = {hp = 10, lck = 10, def = 10, res = 2}
}

Character.__index = Character
setmetatable(Character, workspaces.Character)

Character.section = almanac.get("database/fe15/char.json")
Character.helper_job_growth = true
Character.helper_portrait = "database/fe15/images"

Character.average_rise_stat = true

Character.inventory = inventory
Character.Job = Job
Character.Item = Item

function Character:default_options()
    return {
        class = self.data.job,
        shard = {},
        secret = false,
        forge = false
    }
end

function Character:setup()
    self.job = self.Job:new(self.options.class)
    self.shards = self.options.shard
    
    -- Forge
    if self.item and self.options.forge then
        self.item:set_options({forge = self.options.forge})
    end
    
    -- Secret
    if self.options.secret then
        self.shards = {}
        
        for key, value in pairs(shard_bonus) do
            table.insert(self.shards, key)
        end
    end
end

-- Mod
function Character:show_info()
    local infobox = self:show_mod()
    
    if self.job:can_promo() then
        local promo = self.job:get_promo()
        
        promo_text = promo:promo_bonus(self:final_base())
        promo_text = util.table_stats(promo_text)
        
        local name = promo:get_name()
        
        if self.job.data.lvl then
            name = string.format("%s (Lv. %s)", name, self.job.data.lvl)
        end
        
        infobox:insert(name, "(Raise to these stats if they are lower)\n" .. promo_text, true)
    end
    
    infobox:image("thumbnail", self:get_portrait())
    
    -- Return page infobox if it has magic
    if self.data.black or self.data.white then
        local magicbox = Infobox:new({title = self:get_name()})
        
        if self.data.black then
            magicbox:insert("Mage", self:show_magic(self.data.black), true)
        end
        
        if self.data.white then
            magicbox:insert("Cleric", self:show_magic(self.data.white), true)
        end
        
        local pagebox = Pagebox:new()
        
        pagebox:stats_button()
        pagebox:button({page = 1, label = "Spell", emoji = "magic"})
        
        pagebox:page(infobox)
        pagebox:page(magicbox)
        
        return pagebox
        
    else
        return infobox
    end
    
end

function Character:show_magic(data)
    local text = ""
    
    for key, value in pairs(data) do
        local item = self.Item:new(key)
        
        local line = string.format("Lv. %s %s", value.lvl, item:get_name())
        
        if value.promo then
            line = util.text.bold(line)
        end
        
        text = text .. line .. "\n"
    end
    
    return text
end

function Character:get_mod()
    local text = self:get_lvl_mod()
    
    if #self.shards > 0 then
        local add = "\n**Shards**: "
        
        for i, shard in ipairs(self.shards) do
            add = add .. string.format("`%s` ", util.title(shard))
        end
        
        text = text .. add
    end
    
    text = text .. self:common_mods()
    
    return text
end

-- Base
function Character:final_base()
    local base = self:calc_base()
    
    if self.job.id ~= self.data.job then
        local promo = self.job:promo_bonus(base)
        
        base = util.math.rise_stats(base, promo)
    
    else
        -- Add move from base class
        base = util.math.add_stats(base, self.job:get_base(), {ignore_existing = true})
    end
    
    base = self:common_base(base)
    
    return base
end

-- Growth
function Character:calc_growth()
    local growth = self:get_growth()
    
    if self.shards then
        for i, shard in ipairs(self.shards) do
            growth = growth + shard_bonus[shard]
        end
    end
    
    return growth
end

-- Ranks
function Character:show_rank()
    return self.job:show_rank()
end

---------------------------------------------------
-- Class --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, workspaces.Job)

Job.section = almanac.get("database/fe15/job.json")

Job.hp_bonus = true

function Job:show()
    local infobox = workspaces.Job.show(self)
    
    -- Change the bases to display the res
    infobox.fields[1].value = util.table_stats(self:get_base(true))
    
    return infobox
end

function Job:promo_bonus(base)
    -- check for 1 hp bonus if no stats change
    local hp_bonus = true
    
    function bonus_check(stat, v1, v2)
        if v2 > v1 then
            hp_bonus = false
            return true
            
        else
            return false
            
        end
        
        return false
    end
    
    local job = self:get_base()
    
    local promo = util.math.rise_stats(base, job, {
    ignore = {"res", "mov", "lck"}, check = bonus_check, ignore_unchanged = true})
    
    if self.hp_bonus and hp_bonus then
        promo.hp = base.hp + 1
    end
    
    -- mov always is fixed
    promo.mov = job.mov
    
    return promo
end

function Job:show_rank()
    return util.text.weapon_no_rank(self.data.weapon)
end

-- Only return the res for display stuff
function Job:get_base(display)
    local base = util.copy(self.data.base)
    
    if not display then
        base.res = 0
    end
    
    return base
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, workspaces.Item)

Item.section = almanac.get("database/fe15/item.json")

function Item:default_options()
    return {forge = false}
end

function Item:setup()
    self.forge = self.options.forge or nil
    
    if self.forge then
        if (not self.data.forge) or (self.forge == 0)then
            self.forge = nil
            
        else
            self.forge = math.min(self.forge, #self.data.forge)
        end
    end
end

function Item:get_stats_raw()
    local item = util.copy(self.data.stats)
    
    if self.forge ~= nil then
        local forge = self.data.forge[self.forge]
        
        for key, value in pairs(forge) do
            item[key] = value
        end
    end
    
    return item
end

function Item:get_name()
    local name = self.data.name
    
    if self.forge ~= nil then
        name = name .. string.format(" +%s", self.forge)
    end
    
    return name
end

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, workspaces.Skill)

Skill.section = almanac.get("database/fe15/skill.json")

return {
    Character = Character,
    Job = Job,
    Item = Item,
    Skill = Skill
}