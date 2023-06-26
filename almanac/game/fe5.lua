local almanac = require("almanac")
local workspaces = almanac.workspaces

local util = almanac.util

local Infobox = almanac.Infobox

local pack = util.emoji.get("database/emoji_jugdral.json")

local rank_exp = {
    E = 50,
    D = 100,
    C = 150,
    B = 200,
    A = 250
}

local scroll_bonus = {
    od = {skl = 30},
    baldr = {hp = 5, str = 5, skl = 5, spd = 5, lck = 5, def = 5},
    hodr = {hp = 30, str = 10, lck = -10},
    dainn = {str = 5, spd = -10, def = 30, mov = 5},
    njorun = {str = 30, mag = -10, spd = 10, lck = -5, def = 5},
    nal = {hp = 10, str = 10, skl = -10, def = 10, con = 10},
    ullr = {skl = 10, spd = 10, lck = 10},
    thrud = {hp = 5, str = 5, mag = 5, skl = 10, lck = 5},
    fjalar = {str = 5, mag = 5, skl = 10, spd = 10},
    ced = {hp = -10, mag = 10, spd = 30},
    bragi = {str = -10, mag = 10, lck = 30},
    heim = {mag = 30, lck = 10, def = -10}
}

local Character = {}
local Job = {}
local Item = {}
local Skill = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = util.math.Inventory:new()

local function inventory_atk(data, unit, item)
    if item:is_magic() then
        return unit.stats.mag + item.stats.mt
        
    else
        return unit.stats.str + item.stats.mt
    end
end

local tome_types = {"wind", "fire", "thunder", "light", "dark"}

local function inventory_as(data, unit, item)
    if util.value_in_table(tome_types, item.data.type) then
        return unit.stats.spd - item.stats.wt
        
    else
        return unit.stats.spd - math.max(item.stats.wt - unit.stats.con, 0)
    end
end

local function inventory_hit(data, unit, item)
    return item.stats.hit + (unit.stats.skl * 2) + unit.stats.lck
end

local function inventory_crit(data, unit, item)
    return unit.stats.skl + item.stats.crit
end

inventory:item_calc("atk", inventory_atk)
inventory:item_calc("as", inventory_as)
inventory:item_calc("hit", inventory_hit)
inventory:item_calc("crit", inventory_crit)

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, workspaces.Character)

Character.section = almanac.get("database/fe5/char.json")
Character.helper_portrait = "database/fe5/images"

Character.helper_job_base = true

Character.allow_show_promo = true
Character.promo_use_fixed = false
Character.promo_remove_hp = true

Character.allow_show_cap = false
Character.compare_cap = false

Character.inventory = inventory
Character.pack = pack
Character.rank_exp = rank_exp

Character.Job = Job
Character.Item = Item
Character.Skill = Skill

function Character:default_options()
    return {
        class = self.data.job,
        scroll = false,
        secret = false
    }
end

function Character:setup()
    self.job = Job:new(self.options.class)
    self.scroll = self.options.scroll or {}
    
    if self.options.secret then
        self.scroll = {}
        
        for key, value in pairs(scroll_bonus) do
            table.insert(self.scroll, key)
        end

    end
end

-- Mod
function Character:get_mod()
    local text = self:get_lvl_mod()
    
    if #self.scroll > 0 then
        local add = "Scroll: "
        
        for i, pair in ipairs(self.scroll) do
            add = add .. pack:get("scroll_" .. pair)
        end
        
        text = text .. "\n" .. add
    end
    
    if not self.minimal then
        -- FCM
        if self.data.fcm > 0 then
            text = text .. "\n**FCM**: " .. tostring(self.data.fcm)
        end
        
        local function star_display(value, bonus)
            local result = ""
            
            for i=1, value do
                result = result .. "☆"
            end
            
            return result .. string.format(" (%s", bonus * value) .. "%)"
            
        end
        
        -- Vigor
        if self.data.vigor > 0 then
            text = text .. "\n**Vigor**: " .. star_display(self.data.vigor, 5)
        end
        
        -- Authority
        if self.data.authority > 0 then
            text = text .. "\n**Authority**: " .. star_display(self.data.authority, 3)
        end
    end
    
    text = text .. self:common_mods()
    
    return text
end

-- Rank
function Character:show_rank()
    if self.job:has_rank() then
        if not self.job:can_dismount() then
            local rank = self:get_rank()
            
            return util.text.weapon_rank(rank, {exp=rank_exp, pack=pack})
            
        else
            return self.job:show_rank(self:get_rank())
        end
    end
end

function Character:get_rank()
    local result = self.job:get_rank()
    
    for k, v in pairs(self.data.rank) do
        if result[k] ~= nil then
            result[k] = result[k] + v
        end
    end
    
    return result
end

-- Base
function Character:calc_base()
    local base = workspaces.Character.calc_base(self)
    
    -- hp promo penalty bc of class bases
    if #self.lvl > 1 and self.job.id ~= self.data.job then
        local job = self.Job:new(self.data.job)
        
        local hp = job.data.base.hp - self.job.data.base.hp
        
        base.hp = base.hp - hp
    end
    
    return base
end

-- Growth
function Character:calc_growth()
    local growth = self:get_growth()
    
    for i, pair in ipairs(self.scroll) do
        growth = growth + scroll_bonus[pair]
    end
    
    return growth
end

-- Skill
function Character:get_skill()
    return util.misc.table_merge(self.data.skill, self.job.data.skill)
end

-- Cap
function Character:get_cap()
    return {hp = 80, str = 20, mag = 20, skl = 20, spd = 20, lck = 20, def = 20, con = 20, mov = 20}
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, workspaces.Job)

Job.rank_exp = rank_exp
Job.pack = pack

Job.Skill = Skill

Job.section = almanac.get("database/fe5/job.json")

function Job:can_dismount()
    return self.data.dismount
end

function Job:show_dismount()
    return "**Dismount**: " .. 
    util.table_stats(self:get_dismount(), {value_start = "+"})
end

function Job:get_dismount()
    local dismount = Job:new(self.data.dismount)
    
    local stats = dismount:get_base() - self:get_base()
    
    stats = util.math.remove_zero(stats)
    
    return stats
end

function Job:get_rank()
    local rank = util.copy(self.data.rank)
    
    if self:can_dismount() then
        for key, value in pairs(Job:new(self.data.dismount):get_rank()) do
            if rank[key] == nil then
                rank[key] = value
            end
        end
    end
    
    return rank
end

function Job:show_rank(rank)
    if not self:can_dismount() then
        return workspaces.Job.show_rank(self)
    end
    
    if rank == nil then rank = self:get_rank() end
    
    local rank_mounted, rank_dismounted = {}, {}
    
    local function get_rank_type(tbl, data)
        for key, value in pairs(data) do
            table.insert(tbl, key)
        end
    end
    
    get_rank_type(rank_mounted, self.data.rank)
    get_rank_type(rank_dismounted, Job:new(self.data.dismount).data.rank)
    
    util.inspect(rank_mounted)
    util.inspect(rank_dismounted)
    
    local text = ""
    
    for key, value in pairs(rank) do
        local letter = util.text.rank_letter(rank_exp, value)
        
        local progress = ""
        local check = string.find(letter, " (", 1, true)
        
        if check ~= nil then
            progress = letter:sub(check, #letter)
            letter = letter:sub(1, check - 1)
        end
        
        local result = ""
        
        local function exists(tbl)
            if util.value_in_table(tbl, key) then
                result = result .. letter
                
            else
                result = result .. "-"
            end
        end
        
        exists(rank_mounted)
        exists(rank_dismounted)
        
        result = result .. progress
        
        text = text .. string.format("%s**%s**: %s\n",
        pack:get(key), util.title(key), result)
    end
    
    return text
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, workspaces.Item)

Item.section = almanac.get("database/fe5/item.json")

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, workspaces.Skill)

Skill.section = almanac.get("database/fe5/skill.json")

function Skill:get_emoji()
    if util.emoji.config.enabled then
        return self.data.emoji
        
    else
        return ""
    end
end

return {
    Character = Character,
    Job = Job,
    Item = Item,
    Skill = Skill
}