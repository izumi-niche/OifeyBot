local almanac = require("almanac")
local workspaces = almanac.workspaces

local util = almanac.util

local Infobox = almanac.Infobox

local rank_exp = {
    E = 0,
    D = 1,
    C = 2,
    B = 3,
    A = 4,
    ["☆"] = 5
}

local pack = util.emoji.get("database/emoji_jugdral.json")

local Character = {}
local Job = {}
local Item = {}
local Skill = {}
local Blood = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = util.math.Inventory:new()

inventory.allow_negative = {"as"}

inventory.eff_multiplier = 2
inventory.eff_might = false

local function inventory_atk(data, unit, item)
    if item:is_magic() then
        return unit.stats.mag + item.stats.mt
        
    else
        return unit.stats.str + item.stats.mt
    end
end

local function inventory_as(data, unit, item)
    return unit.stats.spd - item.stats.wt
end

local function inventory_hit(data, unit, item)
    return item.stats.hit + (unit.stats.skl * 2)
end

local function inventory_crit(data, unit, item)
    return unit.stats.skl
end

inventory:item_calc("atk", inventory_atk)
inventory:item_calc("as", inventory_as)
inventory:item_calc("hit", inventory_hit)
--inventory:item_calc("crit", inventory_crit)

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, workspaces.Character)

Character.section = almanac.get("database/fe4/char.json")
Character.helper_portrait = "database/fe4/images"

Character.helper_job_base = true
Character.helper_job_reset = false

Character.allow_show_cap = false
Character.compare_cap = false

Character.allow_show_promo = true
Character.promo_use_fixed = false
Character.promo_rank_negative = false

Character.pack = pack
Character.rank_exp = rank_exp
Character.inventory = inventory

Character.Job = Job
Character.Item = Item
Character.Skill = Skill

function Character:default_options()
    return {
        class = self.data.job,
        father = self.data.father or false,
        mother = self.data.mother or false,
        luck = math.random(1, 99),
        parent = 30,
        major = {},
        minor = {},
        none = {},
        secret = false
    }
end

local father_pool = {"alec", "naoise", "midir", "dew", "chulainn", "beowulf", "lewyn", "lex", "azelle", "jamke", "finn", "arden"}

function Character:setup()
    self.job = self.Job:new(self.options.class)

    if self:is_child() then
        self.luck = self.options.luck
        
        -- If father is missing, get a random one
        if not self.options.father then
            local i = math.random(1, #father_pool)
            
            self.options.father = father_pool[i]
            
            self.random_father = true
        else
        
            self.random_father = false
        end

        self.mother = Character:new(self.options.mother)
        self.father = Character:new(self.options.father)
        
        local options = {level = {self.options.parent}}
        
        self.mother:set_options(options)
        self.father:set_options(options)
    end
    
    -- Holy Blood Injection
    self.major = self.options.major
    self.minor = self.options.minor
    self.none = self.options.none
    
    if self.options.secret then
        self.major = {"hodr", "njorun", "od", "baldr", "nal", "thrud", "dainn", "ullr", "fjalar", "bragi", "forseti", "naga", "loptous"}
    end
    
    -- Ignore father/mother for minimal
    self.minimal = false

    for key, value in pairs(self._changed) do
        if not util.misc.value_in_table({"father", "mother", "any"}, key) then
            self.minimal = true
        end
    end
end

-- Mod
function Character:show_info()
    local infobox = self:show_mod()
    
    if self:is_child() and self.random_father then
        infobox:set("footer", string.format("A random father has been picked, if you wish to select one, try instead: parent!larcei | Ex: %s!larcei", self.father.id))
    end
    
    return infobox
end

function Character:show_mod()
    local infobox = workspaces.Character.show_mod(self)
    
    --[[
    if self.item then
        infobox:set("footer", "Unit can crit if they have the Critical skill or a weapon with >=50 kills.")
    end
    --]]

    return infobox
end

function Character:get_mod()
    local text = self:get_lvl_mod()
    
    if self:is_child() then
        local add = string.format("\n**Father**: %s | **Mother**: %s", 
                          self.father:get_parent_name(),
                          self.mother:get_parent_name())
        
        add = add .. string.format("\n:game_die:**Luck Roll**: %s", self.luck)
        
        if not self.minimal then
            add = add .. " (Min: 1 Max: 99)"
        end
        
        text = text .. add
    end
    
    if self:has_blood() then
        text = text .. "\n" .. self:show_blood()
    end

    text = text .. self:common_mods()

    return text
end

-- For automatically adding a promotion after level 20
function Character:averages_organize()
    if self.data.promo and #self.lvl == 1 and self.lvl[1] >= 20 then
        -- Move promoted level to last, and replace the first one
        local lvl = self.lvl[1]
        self.lvl[1] = 20

        table.insert(self.lvl, lvl)
        table.insert(self.job_averages, self.data.promo)
    end
    
    return workspaces.Character.averages_organize(self)
end

-- Base
function Character:get_base()
    if not self:is_child() then
        return workspaces.Character.get_base(self)

    else
        -- Parent additions
        local function parent_addition(tbl)
            local result = {}
            
            for key, value in pairs(tbl) do
                -- Floor in case of averages
                value = util.floor(value)

                if key == "hp" then
                    value = value - 20
                end

                result[key] = math.max(value, 0)
            end
            
            return result
        end
        
        -- Parent's addition
        local main = self:get_main_parent()
        local minor = self:get_minor_parent()
        
        -- TODO: not this
        if util.value_in_table({"leif", "altena", "febail", "patty"}, self.id) then
            main, minor = minor, main
        end
        
        main = parent_addition(main:calc_base())
        minor = parent_addition(minor:calc_base())
        
        -- Child's additions
        local child = {}
        local growth = self:calc_growth()
        local lvl = self.data.lvl

        for key, value in pairs(growth) do
            value = util.round(value / 100)

            if key == "hp" then
                value = lvl * value

            else
                value = (lvl - 1) * value
            end

            child[key] = util.floor(value)
        end

        -- Final stats
        local result = {}
        setmetatable(result, util.math.Stats)

        for key, value in pairs(child) do
            local parent = (main[key] * 2) + minor[key]
            local total
            
            if key == "hp" then
                parent = parent / 10
                
                total = util.floor(parent + value + 20)
            
            elseif key == "lck" then
                parent = parent + self.luck
                parent = parent / 10
                
                total = util.floor(parent + value + 1)
            else
                parent = parent / 10
                
                total = util.floor((parent + value) % 15)
            end
            
            result[key] = total
            
        end
        
        return result
    end
end

-- Growth
function Character:calc_growth()
    local growth = self:get_growth()
    
    -- Apply Holy Blood bonuses
    for blood, major in pairs(self:get_blood()) do
        local blood = Blood:new(blood)
        
        growth = growth + blood:get_growth(major)
    end
    
    return growth
end

function Character:get_growth()
    if not self:is_child() then
        return workspaces.Character.get_growth(self)

    else
        local main = self:get_main_parent()
        local minor = self:get_minor_parent()
        
        -- TODO: not this
        if util.value_in_table({"leif", "altena", "febail", "patty"}, self.id) then
            main, minor = minor, main
        end
        
        local function step(v1, v2)
            return v1 + util.floor(v2 / 2)
        end

        return util.math.mod_stats(step, main:get_growth(), minor:get_growth())
    end
end

-- Cap
-- Only used for averages
function Character:get_cap()
    return self.job:get_cap()
end

-- Ranks
function Character:show_rank()
    return util.text.weapon_rank(self:get_rank(), {exp = rank_exp, progress = false, pack = pack})
end

function Character:get_rank()
    local rank = self.job:get_rank()
    
    self:apply_rank_mods(rank)

    return rank
end

function Character:apply_rank_mods(rank)
    for blood, major in pairs(self:get_blood()) do
        local blood = Blood:new(blood)
        local brank = blood.data.rank

        if rank[brank] ~= nil then
            if major then
                rank[brank] = 5

            elseif not major and rank[brank] < 4 then
                rank[brank] = rank[brank] + 1
            end
        end
    end
end

-- Skills
function Character:show_skill()
    local skills = self:get_skill()
    
    -- add class skill
    for i, skill in ipairs(self.job.data.skill) do
        if not util.value_in_table(skills, skill) then
            table.insert(skills, skill)
        end
    end
    
    if #skills > 0 then
        local text = ""
        
        for i, skill in ipairs(skills) do
            local skill = Skill:new(skill)
            
            text = text .. skill:get_fancy() .. "\n"
        end
        
        return text
    end
end

local sword_skills = {"astra", "luna", "sol"}
local allow_sword = {"myrmidon", "hero", "swordmaster", "thief", "lord", "thieffighter", "dancer"}

function Character:get_skill()
    if not self:is_child() then
        return util.copy(self.data.skill)
        
    else
        local result = {}
        
        local function check(s)
            return not(util.value_in_table(sword_skills, s)) or (util.value_in_table(allow_sword, self.job.id))
        end
        
        local function add(data)
            for i, skill in ipairs(data) do
                if not util.value_in_table(result, skill) and check(skill) then
                    table.insert(result, skill)
                end
            end
        end
        
        add(self.mother:get_skill())
        add(self.father:get_skill())
        
        return result
    end
end

-- Holy Blood
function Character:show_blood()
    local blood = self:get_blood()

    local text = ""

    if util.misc.table_size(blood) < 6 then
        for blood, major in pairs(blood) do
            local blood = Blood:new(blood)

            text = text .. blood:get_fancy(major) .. "\n"
        end

        text = text:sub(1, -2)

    else
        local add = ""

        for blood, major in pairs(blood) do
            local blood = Blood:new(blood)

            add = add .. blood:get_emoji(major)
        end

        text = text .. add
    end

    return text
end

function Character:get_blood()
    local blood

    if not self:is_child() then
        blood = util.copy(self.data.blood)

    -- Seliph's hard coded holy blood
    elseif self.id == "seliph" then
        blood = {
            baldr = true,
            naga = false
        }

    else
        blood = {}

        -- Main Parent
        for key, value in pairs(self:get_main_influence():get_blood()) do
            blood[key] = value
        end

        -- Minor Parent
        for key, value in pairs(self:get_minor_influence():get_blood()) do
            -- Turn into major blood if both parents have it
            if blood[key] ~= nil then
                blood[key] = true

            -- else it's just minor blood
            elseif blood[key] == nil then
                blood[key] = false
            end
        end

    end
    
    -- Holy Blood Injection
    for i, pair in pairs(self.major) do
        blood[pair] = true
    end
    
    for i, pair in pairs(self.minor) do
        blood[pair] = false
    end
    
    for i, pair in pairs(self.none) do
        blood[pair] = nil
    end
    
    return blood
end

function Character:has_blood()
    return util.table_has(self:get_blood())
end

-- Misc
function Character:get_parent_name()
    local name = self:get_name()
    
    if #self.lvl > 0 then
        local lvl = self.data.lvl
        
        lvl = math.max(self.lvl[#self.lvl] - self.data.lvl, 0)
        
        if lvl > 0 then
            name = name .. string.format(" (Lv. +%s)", lvl)
        end
    end
    
    return name
end

function Character:is_child()
    return (self.data.type == "child")
end

-- For inheriting items/holy blood
function Character:get_main_influence()
    return self[self.data.influence]
end

function Character:get_minor_influence()
    if self.data.influence == "father" then
        return self.mother

    else
        return self.father
    end
end

-- For inheriting stats, it's always the same gender parent
-- TODO: Might be better to include the child's gender in the json file
function Character:get_main_parent()
    return self[self.data.influence]
end

function Character:get_minor_parent()
    if self.data.influence == "father" then
        return self.mother

    else
        return self.father
    end
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, workspaces.Job)

Job.section = almanac.get("database/fe4/job.json")

Job.rank_exp = rank_exp

-- Base
function Job:get_base(include_hp)
    local base = workspaces.Job.get_base(self)
    
    -- Hide HP by default
    if not include_hp then
        base.hp = nil
    end
    
    return base
end

function Job:show_cap()
    return util.table_stats(self:get_cap())
end

-- Cap
-- Caps are base stats + 15
-- HP is always 80, Luck is always 30
function Job:get_cap()
    local base = self:get_base()
    base = base + 15

    base.hp = 80
    base.lck = 30

    base.mov = nil

    return base
end

function Job:show_rank()
    if self:has_rank() then
        return util.text.weapon_rank(self:get_rank(), {pack = self.pack, exp = self.rank_exp, progress = false})
    end
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, workspaces.Item)

Item.section = almanac.get("database/fe4/item.json")

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, workspaces.Skill)

Skill.section = almanac.get("database/fe4/skill.json")

function Skill:get_emoji()
    if util.emoji.config.enabled then
        return self.data.emoji
        
    else
        return ""
    end
end

---------------------------------------------------
-- Blood --
---------------------------------------------------
Blood.__index = Blood
setmetatable(Blood, almanac.Workspace)

Blood.section = almanac.get("database/fe4/blood.json")

function Blood:show()
    local infobox = Infobox:new({title = self.data.name})
    
    local item = Item:new(self.data.weapon)
    
    infobox:insert(item:get_name(), item:show_item())
    
    infobox:insert(self:get_emoji(true) .. "Major Blood", self:show_blood(true), true)
    infobox:insert(self:get_emoji() .. "Minor Blood", self:show_blood(), true)
    
    infobox:insert("Bonus Rank", pack:get(self.data.rank) .. util.title(self.data.rank), true)
    
    return infobox
end

function Blood:show_blood(major)
    return util.table_stats(self:get_growth(major), {value_end = "%"})
end

function Blood:get_growth(major)
    local growth = util.copy(self.data.bonus)
    setmetatable(growth, util.math.Stats)
    
    if major then
        growth = growth * 2
    end
    
    return growth
end

function Blood:get_fancy(major)
    return self:get_emoji(major) .. self:get_name(major)
end

function Blood:get_name(major)
    local name = self.data.name

    if major then
        name = util.text.bold(name)
    end

    return name
end

function Blood:get_emoji(major)
    if util.emoji.config.enabled then
        if major then
            return self.data.major

        else
            return self.data.minor
        end
        
    else
        return ""
    end
end

return {
    Character = Character,
    Job = Job,
    Item = Item,
    Skill = Skill,
    Blood = Blood
}
