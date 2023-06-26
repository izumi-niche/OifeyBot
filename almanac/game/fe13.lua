local almanac = require("almanac")

local util = almanac.util

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local fe14 = require("almanac.game.fe14")

local rank_exp = {
    E = 1,
    D = 16,
    C = 36,
    B = 61,
    A = 91
}

local pack = util.emoji.get("database/fe13/emoji.json")

local Character = {}
local Job = {}
local Skill = {}
local Item = {}
local Shop = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = fe14.Character.inventory:use_as_base()

local function inventory_crit(data, unit, item)
    return item.stats.crit + util.floor(unit.stats.skl / 2)
end

inventory:get_calc("crit").func = inventory_crit

-- Remove follow up since awakening doesn't need it
table.remove(inventory.item_func, 5)

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, fe14.Character)

Character.section = almanac.get("database/fe13/char.json")

Character.helper_portrait = "database/fe13/images"

Character.avatar_id = "robin"
Character.avatar_child = "morgan"
Character.avatar_mod = util.file.json_read("almanac/game/data/avatar.json").fe13

Character.aptitude_id = "donnel"
Character.aptitude_bonus = 20

Character.pack = pack
Character.rank_exp = rank_exp

Character.swap_parent = "lucina"

Character.inventory = inventory
Character.follow_up_warning = false

Character.helper_reset_promo = false

Character.Job = Job
Character.Skill = Skill
Character.Item = Item

function Character:default_options()
    return {
        class = self.data.job,
        difficulty = "lunatic",
        father = self.data.father,
        mother = self.data.mother,
        thirdgen = false,
        chapter = false,
        offspring = false,
        boon = false,
        bane = false,
        parent = self.data.target or false,
        forge = false,
        mt = false,
        hit = false,
        crit = false,
        rank = false
    }
end

-- Mod
function Character:show_mod()
    local infobox = fe14.Character.show_mod(self)
    
    if self:has_pairup() and self:has_averages() and not self.item then
        local pairup = self:show_pairup()
        
        for i, pair in ipairs(pairup.fields) do
            infobox:insert(pair.name, pair.value, pair.inline)
        end
    end
    
    return infobox
end

-- Base
function Character:get_base()
    local base = util.copy(self.data.base[self.difficulty])
    setmetatable(base, util.math.Stats)
    
    -- Children Bases = (Father + Mother + Child) / 3
    if self:has_parents() then
        local function parent_step(v1, v2)
            return util.floor(v1) + util.floor(v2)
        end
        
        local parents = util.math.mod_stats(parent_step, self.father:calc_base(), self.mother:calc_base())
        
        local function step(v1, v2)
            return util.floor((v1 + v2) / 3)
        end
        
        base = util.math.mod_stats(step, base, parents)
    end
    
    -- Avatar Boon/Bane
    if self.boon and self.bane then
        local boon = self.avatar_mod.base[self.boon].boon
        local bane = self.avatar_mod.base[self.bane].bane
        
        base[self.boon] = base[self.boon] + boon
        base[self.bane] = base[self.bane] + bane
    end
    
    return base
end

function Character:get_growth()
    local growth = util.copy(self.data.growth)
    setmetatable(growth, util.math.Stats)
    
    -- Children Growths = (Father + Mother + Child) / 3
    if self:has_parents() then
        local parents = self.father:get_growth() + self.mother:get_growth()
        
        local function step(v1, v2)
            return util.floor((v1 + v2) / 3)
        end
        
        growth = util.math.mod_stats(step, growth, parents)
    end
    
    -- Avatar Boon/Bane
    if self.boon and self.bane then
        for key, value in pairs({[self.boon] = "boon", [self.bane] = "bane"}) do
            for x, y in pairs(self.avatar_mod.growth[key]) do
                y = y[value]
                
                growth[x] = growth[x] + y
            end
        end
    end
    
    return growth
end

-- Pair Up
function Character:show_pairup()
    local infobox = Infobox:new({title = self.data.name})
    
    local function get(rank)
        return util.table_stats(self:get_pairup(rank), {value_start = "+"})
    end
    
    infobox:insert("No Support", get())
    infobox:insert("Support C-B", get("c"))
    infobox:insert("Support A-S", get("a"))
    
    return infobox
end

function Character:get_pairup(rank)
    -- Get non zero pair-up stats
    local result = {}
    local base = self:final_base()
    
    for key, value in pairs(self.job.data.pairup) do
        if value ~= 0 then
            
            -- Increase value based on rank
            if rank == "c" or rank == "b" then
                value = value + 1
                
            elseif rank == "a" or rank == "s" then
                value = value + 2
            end
            
        end
        
        local total = value
        
        if base[key] ~= nil then
            local personal = base[key]
            
            if personal >= 30 then
                total = total + 3
            
            elseif personal >= 20 then
                total = total + 2
                
            elseif personal >= 10 then
                total = total + 1
            end
        end
        
        if total ~= 0 then
            result[key] = total
        end
    end
    
    return result
end

function Character:has_pairup()
    return true
end

-- Set
function Character:show_set()
    local set = self:get_set()
    
    if util.value_in_table(set, "fe13avatar") then
        local infobox = Infobox:new({title = self.data.name})
        
        infobox:insert("All classes", "This unit can reclass to all classes available for their gender.", true)
        
        return infobox
    
    else
        return fe14.Character.show_set(self)
    end
end
    
Character.set_banlist = {"lordm", "lordf", "tactician", "dancer", "manakete", "taguelf", "taguelm", "conqueror", "bride", "lodestar", "dreadfighter"}

Character.set_alt = {
    m = {
        pegasusknight = {
            lissa = "myrmidon",
            maribelle = "cavalier",
            olivia = "barbarian"
        },
        troubadour = {
            lissa = "barbarian",
            miriel = "barbarian",
            maribelle = "priest",
            cherche = "fighter"
        },
        dancer = {
            olivia = "mercenary"
        },
        wyvernrider = {
            panne = "barbarian"
        },
        taguelf = {
            panne = "taguelm"
        }
    },
    f = {
        fighter = {
            vaike = "knight",
            gaius = "pegasusknight",
            donnel = "troubadour"
        },
        barbarian = {
            vaike = "mercenary",
            gregor = "troubadour",
            henry = "troubadour"
        },
        villager = {
            donnel = "pegasusknight"
        }
    }
}

Character.set_gender = {
    m = {cleric = "priest"},
    f = {priest = "cleric"}
}

local morgan_banlist = {"lordm", "lordf", "tactician", "dancer", "conqueror", "bride", "lodestar", "dreadfighter"}

function Character:get_set()
    local set = util.copy(self.data.set)
    
    local banlist = self.set_banlist
    if self.id == "morgan" then banlist = morgan_banlist end
    
    if self:has_parents() then
        local function try_adding(job, parent)
            -- gender-locked inheritance
            local try = self.set_alt[self.gender][job]
            
            if try ~= nil and try[parent] ~= nil then
                job = try[parent]
            end
            
            -- gender-different classes
            if self.set_gender[self.gender][job] ~= nil then
                job = self.set_gender[self.gender][job]
            end
            
            -- check if valid by:
            -- not in banlist
            -- doesn't exist in the current set
            if not util.value_in_table(banlist, job) and
            not util.value_in_table(set, job) then
                table.insert(set, job)
            end
        end
        
        local function parent_add(p)
            local id = p.id
            
            for i, pair in ipairs(p:get_set()) do
                try_adding(pair, id)
            end
        end
        
        parent_add(self.mother)
        parent_add(self.father)
    end
    
    return set
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, fe14.Job)

Job.section = almanac.get("database/fe13/job.json")

Job.pack = pack
Job.rank_exp = rank_exp
Job.Skill = Skill

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, fe14.Skill)

Skill.section = almanac.get("database/fe13/skill.json")

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, fe14.Item)

Item.section = almanac.get("database/fe13/item.json")

Item.forge_worth = {0.5, 1.5, 3.0, 5.0, 7.5}
Item.forge_increase = {mt = 1, hit = 5, crit = 3}

function Item:default_options()
    return {
        mt = false,
        hit = false,
        crit = false
    }
end

function Item:setup()
    if self:is_weapon() and self.data.stats.price ~= nil then
        local forge = {
            mt = self.options.mt or nil,
            hit = self.options.hit or nil,
            crit = self.options.crit or nil
        }
        
        if util.table_has(forge) then
            self.forge = forge
        end
    end
end

function Item:show()
    local infobox = fe14.Item.show(self)
    
    -- forge field
    if self.forge then
        local worth = 0
        
        for key, value in pairs(self.forge) do
            worth = worth + self.forge_worth[value]
        end
        
        worth = util.floor(worth * self.data.stats.price)
        
        infobox:insert("Forge Price", string.format("%sG", worth))
    end
    
    -- shop field
    if #self.data.shop > 0 then
        infobox:insert("Shop", self:show_shop(self.data.shop), true)
    end
    
    -- special shop page
    if #self.data.spotpass > 1 or #self.data.merchant > 1 then
        local shopbox = Infobox:new({title = self.data.name})
        
        shopbox:insert("Merchant", self:show_shop(self.data.merchant), true)
        shopbox:insert("Spotpass", self:show_shop(self.data.spotpass, true), true)
        
        local pagebox = Pagebox:new()
        
        pagebox:page(infobox)
        pagebox:page(shopbox)
        
        pagebox:stats_button()
        pagebox:button({label = "Special Shops", emoji = "gold"})
        
        return pagebox
    
    else
        return infobox
        
    end
end

function Item:show_shop(data, spotpass)
    local text = ""
    
    spotpass = spotpass or false
    
    for i, pair in ipairs(data) do
        if spotpass then
            text = text .. pair .. "\n"
            
        else
            local shop = Shop:new(pair)
            
            text = text .. shop.data.short_name .. "\n"
        end
    end
    
    return text
end

function Item:get_stats_raw()
    local item = util.copy(self.data.stats)
    
    if self.forge then
        for key, value in pairs(self.forge) do
            local increase = self.forge_increase[key]
            value = increase * value
            
            if item[key] ~= nil then
                item[key] = item[key] + value
                
            else
                item[key] = value
            end
        end

    end
    
    return item
end

function Item:get_name()
    local name = self.data.name
    
    if self.forge then
        local add = ""
        
        for key, value in pairs(self.forge) do
            add = add .. string.format("+%s %s ", value, util.title(key))
        end
        
        name = name .. " (" .. add .. ")"
    end
    
    return name
end

---------------------------------------------------
-- Shop --
---------------------------------------------------
Shop.__index = Shop
setmetatable(Shop, almanac.Workspace)

Shop.section = almanac.get("database/fe13/shop.json")

return {
    Character = Character,
    Job = Job,
    Skill = Skill,
    Item = Item
}