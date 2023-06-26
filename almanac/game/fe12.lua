local almanac = require("almanac")
local workspaces = almanac.workspaces

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local util = almanac.util

local pack = util.emoji.get("database/fe12/emoji.json")

local kris_history = {
    merchant = {
        text = "Merchant's Child",
        base = {lck = 2, res = 2},
        growth = {lck = 5}
    },
    priest = {
        text = "Priest's Child",
        base = {def = 2},
        growth = {}
    },
    orphan = {
        text = "Orphan",
        base = {str = 2, mag = 2},
        growth = {str = 5, mag = 5}
    },
    farmer = {
        text = "Farmer's Child",
        base = {hp = 4},
        growth = {hp = 10}
    },
    noble = {
        text = "Noble's Child",
        base = {skl = 2, spd = 2},
        growth = {skl = 5, spd = 5}
    },
    beauty = {
        text = "Beauty",
        base = {skl = 1, spd = 1},
        growth = {spd = 10, spd = 10}
    },
    wisdom = {
        text = "Wisdom",
        base = {lck = 1, res = 1},
        growth = {lck = 10, res = 5}
    },
    diversity = {
        text = "Diversity",
        base = {str = 1, mag = 1},
        growth = {str = 10, mag = 10}
    },
    kindness = {
        text = "Kindness",
        base = {def = 1},
        growth = {def = 5}
    },
    strength = {
        text = "Strength",
        base = {hp = 2},
        growth = {hp = 20}
    },
    humane = {
        text = "Humane",
        base = {},
        growth = {def = 10}
    },
    honorable = {
        text = "Honorable",
        base = {},
        growth = {skl = 15, spd = 15}
    },
    enlightened = {
        text = "Enlightned",
        base = {},
        growth = {hp = 30}
    },
    wealthy = {
        text = "Wealthy",
        base = {},
        growth = {lck = 15, res = 10}
    },
    recluse = {
        text = "Recluse",
        base = {},
        growth = {str = 15, mag = 15}
    }
}

local rank_exp = {
    E = 1,
    D = 31,
    C = 76,
    B = 136,
    A = 196
}

local rank_bonus = {
    sword = {
        C = {atk = 1},
        B = {atk = 2},
        A = {atk = 3}
    },
    lance = {
        C = {atk = 1},
        B = {atk = 1, hit = 5},
        A = {atk = 2, hit = 10}
    },
    axe = {
        C = {hit = 5},
        B = {hit = 10},
        A = {hit = 15}
    }
}

rank_bonus.tome = rank_bonus.lance
rank_bonus.bow = rank_bonus.lance

local Character = {}
local Job = {}
local Item = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = util.math.Inventory:new()

--
local function inventory_atk(data, unit, item)
    if item:is_magic() then
        return unit.stats.mag + item.stats.mt
        
    else
        return unit.stats.str + item.stats.mt
    end
end

-- Add AS for FE11 and it looks weird without it
local function inventory_as(data, unit, item)
    return unit.stats.spd
end
--
local function inventory_hit(data, unit, item)
    return item.stats.hit + unit.stats.skl + util.floor(unit.stats.lck / 2) + unit.job:hit_bonus()
end
--
local function inventory_crit(data, unit, item)
    if unit.stats.skl >= 20 then
        return (unit.stats.skl - 10) + item.stats.crit + unit.job:crit_bonus()
        
    else
        return util.floor(unit.stats.skl / 2) + item.stats.crit + unit.job:crit_bonus()
    end
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

Character.section = almanac.get("database/fe12/char.json")
Character.helper_portrait = "database/fe12/images"

Character.helper_job_base = true
Character.helper_job_growth = true
Character.helper_job_cap = true

Character.allow_show_cap = false
Character.compare_cap = false

Character.helper_reset_promo = true

Character.inventory = inventory

Character.pack = pack

Character.Job = Job
Character.Item = Item

function Character:default_options()
    return {
        class = self.data.job,
        drop = false,
        rb = false,
        future = false,
        present = false,
        past = false,
        mt = false,
        wt = false,
        crit = false,
        hit = false,
        rank = false
    }
end

function Character:setup()
    self.job = self.Job:new(self.options.class)
    
    self.rb = self.options.rb
    self.drop = self.options.drop
    
    self.future = self.options.future
    self.present = self.options.present
    self.past = self.options.past
    
    if self.item then
        local args = {
            mt = self.options.mt or nil,
            wt = self.options.wt or nil,
            crit = self.options.crit or nil,
            hit = self.options.hit or nil
        }
        
        self.item:set_options(args)
        
        -- Weapon rank bonuses for calculating item equips
        local wpn_type = self.item.data.type
        
        if rank_bonus[wpn_type] ~= nil then
            local bonus = rank_bonus[wpn_type]
            local rank = self.item.data.stats.rank
            
            -- Merric can use Excalibur at any rank
            if self.id == "merric" and self.item.id == "excalibur" then
                rank = "E"
            end
            
            -- Use item's rank or unit's rank, the one that is higher
            if not self.options.rank then
                local item_exp = rank_exp[rank] or 0
                local unit_exp = self:get_rank()[wpn_type] or 0
                
                local result
                
                if item_exp > unit_exp then
                    result = item_exp
                    
                else
                    result = unit_exp
                end
                
                result = util.text.rank_letter(rank_exp, result, false)
                
                self.rank_letter = result
                self.rank = bonus[result]
            
            else
                self.rank_letter = self.options.rank
                self.rank = bonus[self.options.rank]
            end
        end
    end
    
end
-- Show
function Character:show_info()
    local infobox = self:show_mod()

    if self.data.support and #self.data.support > 1 then
        local support = Infobox:new({title = self:get_name()})
        
        for key, value in pairs(self.data.support) do
            support:insert(key, value, true)
        end
        
        local pagebox = Pagebox:new()
        
        pagebox:page(infobox)
        pagebox:page(support)
        
        pagebox:stats_button()
        pagebox:button({label = "Supports", emoji = "bubble"})
        
        return pagebox
        
    else
        return infobox
    end
end

-- Mod
function Character:show_mod()
    local infobox = workspaces.Character.show_mod(self)
    
    infobox:image("icon", self.job:get_icon())

    return infobox
end

function Character:get_mod()
    local text = self:get_lvl_mod()
    
    -- History
    if self:has_history() then
        local add = ""
        
        for i, history in ipairs(self:get_history()) do
            add = add .. kris_history[history].text .. ", "
        end
        
        text = text .. "\n" .. add:sub(1, -3)
    end
    
    -- Rainbow Potion
    if self.rb then
        text = text .. "\n\\⚗️Rainbow Potion"
    end
    
    -- Growth Drop
    if self.drop then
        text = text .. "\n\\🔮Growth Drop"
    end
    
    -- Weapon Rank
    if self.rank then
        text = text .. string.format("\n**%s Rank Bonus**: %s", self.rank_letter, util.table_stats(self.rank, {value_start = "+", separator= "; "}))
    end
    
    return text .. self:common_mods()
end

-- Base
function Character:common_base(base)
    if self.rb then
        base = base + 2
    end
    
    return workspaces.Character.common_base(self, base)
end

function Character:calc_base()
    local base = self:get_base()
    
    if self:has_history() then
        for i, history in ipairs(self:get_history()) do
            base = base + kris_history[history].base
        end
    end
    
    if self:has_averages() then
        base = self:calc_averages(base)
    end
    
    return base
end

-- Growth
function Character:calc_growth()
    local growth = workspaces.Character.calc_growth(self)
    
    -- History bonuses
    if self:has_history() then
        for i, history in ipairs(self:get_history()) do
            growth = growth + kris_history[history].growth
        end
    end
    
    if self.drop then
        -- +10% to all stats, +20% to HP
        growth = growth + 10
        growth.hp = growth.hp + 10
    end
    
    return growth
end
-- Return empty cap for average use
function Character:get_cap() return {} end

-- Ranks
function Character:show_rank()
    if self.job:has_rank() then
        local result = self:get_rank()
        
        local args = {pack = self.pack}
        
         -- Display raw rank exp only if personal is enabled
        if not self:is_personal() then
            args.exp = rank_exp
        end
        
        return util.text.weapon_rank(result, args)
        
    end
end

function Character:get_rank()
    local result = self.job:get_rank()

    for key, value in pairs(self.data.rank) do
        if result[key] ~= nil then
            result[key] = result[key] + value
        end
    end
    
    return result
end

-- History
function Character:has_history()
    return (self.future or self.present or self.past)
end

function Character:get_history()
    local result = {}
    
    for i, p in ipairs({self.future, self.present, self.past}) do
        if p then
            table.insert(result, p)
        end
    end
    
    return result
end

-- Misc
function Character:apply_item_bonus(item, stats)
    
    if self.rank then
        for key, value in pairs(self.rank) do
            stats[key] = stats[key] + value
        end
        
        if stats.eff ~= nil and self.rank.atk ~= nil then
            stats.eff = stats.eff + self.rank.atk
        end
    end
end

function Character:get_portrait()
    if self.id == "kris" then
        local gender = "m"
        
        if math.random(1, 2) == 2 then gender = "f" end
        
        return string.format("%s/kris_%s.png", self.helper_portrait, gender)
    
    else
        return workspaces.Character.get_portrait(self)
    end
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, workspaces.Job)

Job.section = almanac.get("database/fe12/job.json")

Job.pack = pack
Job.rank_exp = rank_exp

Job.icon = "database/fe12/images/icon/%s"

function Job:show()
    local infobox = workspaces.Job.show(self)
    
    infobox:image("icon", self:get_icon())
    
    return infobox
end

function Job:get_icon()
    if self.data.ally then
        return string.format(self.icon, self.data.ally)
    end
end

function Job:hit_bonus()
    if self.id == "sniper" then
        return 5
        
    else
        return 0
    end
end

function Job:crit_bonus()
    if self.id == "berserker" then
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
setmetatable(Item, workspaces.Item)

Item.section = almanac.get("database/fe12/item.json")

local forge_cost = {
    mt = {0.5, 1.5, 3.0, 5.0, 7.5, 10.5, 14.0, 18.0, 22.5, 27.5},
    wt = {0.5, 1.5, 3.0, 5.0, 7.5, 10.5, 14.0, 18.0, 22.5, 27.5},
    hit = {0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 0.9, 1.1, 1.3, 1.5, 1.8, 2.1, 2.4, 2.7, 3.0, 3.4, 3.8, 4.2, 4.6, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.1, 8.7, 9.3, 9.9, 10.5, 11.2, 11.9, 12.6, 13.3, 14.0, 14.8, 15.6, 16.4, 17.2, 18.0, 18.9, 19.8, 20.7, 21.6, 22.5, 23.5, 24.5, 25.5, 26.5, 27.5},
    crit = {0.165, 0.3325, 0.5, 0.8325, 1.165, 1.5, 2.0, 2.5, 3.0, 3.665, 4.3325, 5.0, 5.8325, 6.665, 7.5, 8.5, 9.5, 10.5, 11.665, 12.8325, 14.0, 15.3325, 16.665, 18.0, 19.5, 21.0, 22.5, 24.165, 25.8325, 27.5}
}

function Item:default_options()
    return {
        mt = false,
        wt = false,
        hit = false,
        crit = false
    }
end

function Item:setup()
    local price = self.data.stats.price
    
    if self:is_weapon() and price ~= nil and price > 0 then
        self.forge = {
            mt = self.options.mt or nil,
            wt = self.options.wt or nil,
            hit = self.options.hit or nil,
            crit = self.options.crit or nil
        }
    else
        self.forge = {}
    end
end

function Item:show()
    local infobox = workspaces.Item.show(self)
    
    if util.table_has(self.forge) then
        local price = self.data.stats.price
        local fee = util.floor(price / 2)
        
        local total = fee
        local text = ""
        
        for stat, forge in pairs(self.forge) do
            local i = util.floor(price * forge_cost[stat][forge])
            
            total = total + i
            
            text = text .. string.format("**%s %s**: %sG\n", forge, util.title(stat), i)
        end
        
        text = text .. string.format("\n**Fee**: %sG", fee)
        text = text .. string.format("\n**Total**: %sG", total)
        
        infobox:insert("Forge Price", text)
    end
    
    return infobox
end

function Item:get_stats_raw()
    local item = util.copy(self.data.stats)
    
    for key, value in pairs(self.forge) do
        if key == "wt" then value = value * -1 end
        
        if item[key] ~= nil then
            item[key] = item[key] + value
            
        else
            item[key] = value
        end
    end
    
    return item
end

function Item:get_name()
    local name = self.data.name
    
    if util.table_has(self.forge) then
        local add = ""
        
        for stat, forge in pairs(self.forge) do
            local symbol = "+"
            
            if stat == "wt" then symbol = "-" end
            
            add = add .. string.format("%s%s %s ", symbol, forge, util.title(stat))
            
        end
        
        name = name .. " (" .. add .. ")"
    end
    
    return name
end

return {
    Character = Character,
    Job = Job,
    Item = Item
}
