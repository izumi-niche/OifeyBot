local almanac = require("almanac")
local workspaces = almanac.workspaces

local util = almanac.util

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local pack = util.emoji.get("database/fe10/emoji.json")

local rank_exp = {
    E = 1,
    D = 31,
    C = 71,
    B = 121,
    A = 181,
    S = 251,
    SS = 331
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

local function inventory_as(data, unit, item)
    return unit.stats.spd - math.max(item.stats.wt - unit.stats.con, 0)
end

local function inventory_hit(data, unit, item)
    return item.stats.hit + (unit.stats.skl * 2) + unit.stats.lck
end

local function inventory_crit(data, unit, item)
    return util.floor(unit.stats.skl / 2) + item.stats.crit
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

Character.section = almanac.get("database/fe10/char.json")
Character.helper_portrait = "database/fe10/images"

Character.helper_job_base = true

Character.average_classic = true

Character.allow_show_promo = true
Character.promo_job_cap = true
Character.promo_inline = false
Character.promo_progressive = true
Character.promo_rank_negative = false

Character.inventory = inventory

Character.rank_exp = rank_exp
Character.pack = pack

Character.Job = Job
Character.Skill = Skill
Character.Item = Item

Character.item_warning = true

function Character:default_options()
    return {
        class = self.data.job,
        halfshift = false,
        untransform = false,
        support = false
    }
end

function Character:setup()
    self.job = self.Job:new(self.options.class)
    
    -- Halfshift
    self.halfshift = self.options.halfshift
    
    if self.id == "volug" then
        self.halfshift = not(self.halfshift)
    end
    
    -- If to transform when calculating stats
    self.transform = true
    
    if self.options.untransform then self.transform = false end
    
    -- Auto equip laguz strikes
    if self:has_averages() and not self.item and self:is_laguz() and self.job.data.laguz_weapon then
        local weapon = self.job.data.laguz_weapon
        
        if type(weapon) == "table" then
            self.item = {}
            
            for i, pair in ipairs(weapon) do
                table.insert(self.item, self.Item:new(pair))
            end
        
        else
            self.item = self.Item:new(weapon)
        end
    end
    
    -- Support
    self.support = self.options.support
    
    if self.support then
        self.support = getmetatable(self):new(self.support)
    end
end

-- Show
Character.affinity_bonus = {
    fire = {atk = 0.5, hit = 2.5},
    thunder = {def = 0.5, avoid = 2.5},
    wind = {hit = 2.5, avoid = 2.5},
    water = {atk = 0.5, def = 0.5},
    dark = {atk = 0.5, avoid = 2.5},
    light = {def = 0.5, hit = 2.5},
    heaven = {hit = 9.0},
    earth = {avoid = 7.5}
}

function Character:show()
    if self.support then
        return self:show_support()
        
    else
        return workspaces.Character.show(self)
    end
end

-- Support
function Character:show_support()
    local name1 = util.text.remove_parentheses(self.data.name)
    local name2 = util.text.remove_parentheses(self.support.data.name)
    
    local infobox = Infobox:new({title = string.format("%s & %s Bonuses", 
    name1, name2)})
    
    name1 = self:get_affinity() .. name1
    name2 = self.support:get_affinity() .. name2
    
    infobox:set("desc", string.format("%s\n%s", name1, name2))
    
    local aff1 = self.affinity_bonus[self.data.affinity]
    local aff2 = self.affinity_bonus[self.support.data.affinity]
    
    
    for i, pair in ipairs({"C", "B", "A"}) do
        local result = util.math.affinity_calc(aff1, aff2, i, true)
        
        infobox:insert("Support " .. pair, util.table_stats(result, 
        {value_start="**+", value_end="**", order = "equip"}))
    end
    
    infobox:image("thumbnail", self:get_portrait())
    
    return infobox
end
-- Mod
function Character:show_info()
    local infobox = self:show_mod()
    
    local text = infobox:get("desc")
    
    if self.data.affinity then
        text = text .. string.format("\n%s%s", self.pack:get("aff_" .. self.data.affinity), util.title(self.data.affinity))
    end
    
    infobox:set("desc", text)
    
    --
    local pagebox = Pagebox:new()
    
    pagebox:page(infobox)
    pagebox:stats_button()
    
    -- Laguz strike
    if self:is_laguz() and self.job.data.laguz_weapon then
        local laguzbox = self:show_strike()
        
        pagebox:page(laguzbox)
        pagebox:button({label="Strike", emoji="manual"})
    end
    
    -- Support
    if self.data.support and util.table_has(self.data.support) then
        local supportbox = Infobox:new({title = self.data.name})
        
        local text = ""
        
        for key, value in pairs(self.data.support) do
            local add = string.format("%s**%s: **", self.pack:get("aff_" .. value.affinity), key)
            
            if type(value.bonus) == "table" then
                for i, pair in ipairs({"C", "B", "A"}) do
                    add = add .. string.format("%s-%s | ", pair, value.bonus[i])
                end
                
                add = add:sub(1, -4)
                
            else
                add = add .. tostring(value.bonus)
            end
            
            text = text .. add .. "\n"
        end
        
        supportbox:set("desc", text)
        
        pagebox:page(supportbox)
        pagebox:button({label = "Supports", emoji="bubble"})
    end
    
    if #pagebox.pages > 1 then
        return pagebox
        
    else
        return infobox
    end
end

--
function Character:show_mod()
    local infobox = workspaces.Character.show_mod(self)
    
    if self.minimal and not self:has_averages() and not self.item then
        local pagebox = Pagebox:new()
        
        pagebox:page(infobox)
        pagebox:stats_button()
        
        local laguzbox = self:show_strike()
        
        pagebox:page(laguz_weapon)
        pagebox:button({label="Strike", emoji="manual"})
        
        return pagebox
    end
    
    return infobox
end

function Character:show_strike()
    local weapon = self.job.data.laguz_weapon
    
    if type(weapon) ~= "table" then
        weapon = {weapon}
    end
    
    local infobox = Infobox:new({title = self.data.name})
    
    for i, pair in ipairs(weapon) do
        local item = self.Item:new(pair)
        
        local v1, v2 = self:mod_equip(item)
        
        infobox:insert(v1, v2)
    end
    
    infobox:set("footer", string.format("Using untransformed stats. To see them with transformed stats, set %s's level to 1.", self.data.name))
    
    return infobox
end

-- Base
function Character:show_base()
    local base = self:final_base()
    
    if not self:is_personal() and self:is_laguz() and not self.item and not self._compare then
        local trans = self:get_transform_bonus(base)
        trans = base + trans
        
        for key, value in pairs(trans) do
            if base[key] ~= nil and base[key] ~= value then
                base[key] = string.format("%s***»%s***", base[key], value)
            end
        end
    
    elseif not self:is_laguz() then
        base = util.math.cap_stats(base, self:final_cap(), {bold = true, higher = true})
    end
    
    return util.table_stats(base)
end

function Character:final_base()
    local base = self:calc_base()
    
    -- Apply base class stats
    local job = self.data.job
    if self:is_changed("class") then job = self.job else job = self.Job:new(self.data.job) end
    
    base = base + job:get_base()
    
    if self:has_averages() then
        base = self:calc_averages_classic(base)
    end
    
    if self.transform and self:is_laguz() and (self.item or self._compare) then
        base = base + self:get_transform_bonus(base)
    end
    
    job = self.job.data.base
    
    base.con = job.con + self.data.base.con
    base.mov = job.mov
    base.wt = job.wt + self.job.data.wtmod
    
    base.vision = nil
    
    return base
end

function Character:get_transform_bonus(base)
    local result = {}
    setmetatable(result, util.math.Stats)
    
    local modifier = 1
    if self.halfshift then modifier = 0.5 end
    
    for key, value in pairs(base) do
        if key ~= "lck" and key ~= "hp" then
            result[key] = util.floor(value * modifier)
        end
    end
    
    local trans = self.job.data.trans
    
    result.con = trans.con
    result.wt = trans.wt
    result.mov = trans.mov
    result.vision = trans.vision
    
    return result
end

-- Cap
function Character:get_cap()
    return self.job:get_cap()
end

-- Rank Display
function Character:show_rank()
    if self.job:has_rank() then
        local rank = self:get_rank()
        
        return util.text.weapon_rank(rank, {exp = self.rank_exp, pack = self.pack})
    end
end

function Character:get_rank()
    local result = self.job:get_rank()
    
    for k, v in pairs(self.data.rank) do
        if result[k] ~= nil then
            result[k] = v
        end
    end
    
    return result
end

-- Skills
function Character:show_skill()
    local text = ""
    
    for i, skill in ipairs(self:get_skill()) do
        local skill = self.Skill:new(skill)
        
        text = text .. skill:get_fancy() .. "\n"
    end
    
    return text
end

function Character:get_skill()
    return util.misc.table_merge(self.data.skill, self.job.data.skill)
end

-- Misc
function Character:is_laguz()
    return self.job:is_laguz()
end

function Character:get_affinity()
    return self.pack:get("aff_" .. self.data.affinity)
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, workspaces.Job)

Job.section = almanac.get("database/fe10/job.json")

Job.rank_exp = rank_exp
Job.pack = pack

function Job:is_laguz()
    return self.data.type == "laguz"
end

function Job:get_rank()
    return util.copy(self.data.rank.min)
end

function Job:get_skill()
    return util.copy(self.data.skill)
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, workspaces.Item)

Item.section = almanac.get("database/fe10/item.json")

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, workspaces.Skill)

Skill.section = almanac.get("database/fe10/skill.json")

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