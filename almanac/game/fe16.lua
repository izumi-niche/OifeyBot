local almanac = require("almanac")
local workspaces = almanac.workspaces

local util = almanac.util

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local rank_exp = {
    E = 0,
    ["E+"] = 40,
    D = 100,
    ["D+"] = 180,
    C = 300,
    ["C+"] = 460,
    B = 680,
    ["B+"] = 960,
    A = 1320,
    ["A+"] = 1760,
    S = 2520,
    ["S+"] = 3600
}

local pack = util.emoji.get("database/fe16/emoji.json")

local Character = {}
local Job = {}
local Item = {}
local Skill = {}
local Rank = {}
local Bat = {}

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
    return unit.stats.spd - math.max(item.stats.wt - util.floor(unit.stats.str / 5), 0)
end

local function inventory_hit(data, unit, item)
    if item:is_magic() then
        return item.stats.hit + util.floor((unit.stats.dex + unit.stats.lck) / 2)
    else
        return item.stats.hit + unit.stats.dex
    end
end

local function inventory_crit(data, unit, item)
    return item.stats.crit + util.floor((unit.stats.dex + unit.stats.lck) / 2)
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

Character.section = almanac.get("database/fe16/char.json")

Character.helper_job_growth = true

Character.helper_portrait = "database/fe16/images"
Character.helper_job_reset = false

Character.average_rise_stat = true

Character.inventory = inventory

Character.Job = Job
Character.Item = Item

Character.item_warning = true

function Character:default_options()
    return {
        chapter = self.data.chapter,
        difficulty = "maddening",
        class = false
    }
end

-- Chapter needs to be set up first to get the correct class
-- Crashes for averages if it's not in pre_setup
function Character:pre_setup()
    self.chapter = self.options.chapter or 1
    
    return workspaces.Character.pre_setup(self)
end

function Character:setup()
    local job = self.options.class
    
    if not job then job = self:get_job() end
    
    self.job = self.Job:new(job)
    
    self.difficulty = self.options.difficulty
end

-- Mod
local house_color = {
    deer = 10387465,
    lions = 675058,
    eagles = 9510175,
    wolves = 6579566,
    church = 15132897
}

local snow_text = {
    cyirl = "Note that Cyril uses his chapter 11 bases when he joins in Silver Snow.",
    catherine = "Note that Catherine uses her chapter 11 bases when she joins in Silver Snow."
}

-- Show
function Character:show_info()
    -- pagebox
    local pagebox = Pagebox:new()
    
    -- first page
    local infobox = self:show_mod()
    
    if self.data.personal then
        local skill = Skill:new(self.data.personal)

        infobox:insert(skill:get_fancy(), skill:get_desc(), true)
    end
    
    pagebox:page(infobox)
    pagebox:stats_button()
    
    -- second page
    local learnpage = self:show_learn()
    
    pagebox:page(learnpage)
    pagebox:button({label = "Skill/Art", emoji = "manual"})
    
    -- third page
    local spellpage = self:show_spell()
    
    pagebox:page(spellpage)
    pagebox:button({label = "Spells", emoji = "magic"})
    
    --
    pagebox:set("title", self:get_name())
    
    -- House color
    if self.data.color ~= nil then
        pagebox:set("color", house_color[self.data.color])
    end
    
    return pagebox
end

function Character:show_learn()
    local infobox = Infobox:new()
    
    local function dothing(rank, rank_value, skill)
        local skill = Skill:new(skill)
        
        local rank_emoji = pack:get("fe16_" .. rank)
        rank = util.title(rank)
        rank_value = util.text.rank_letter(rank_exp, rank_value, false)
        
        local name = string.format("%s%s %s", rank_emoji, rank, rank_value)
        local value = skill:get_fancy()
        
        infobox:insert(name, value, true)
    end
    
    local function loop(data)
        -- rank / skill table
        for key, value in pairs(data) do
            
            -- skill / rank value
            for x, y in pairs(value) do
                dothing(key, y, x)
            end
        end
    end
    
    loop(self.data.ability)
    loop(self.data.art)
    
    if self.data.buddy_rank then
        local rank = self.data.buddy_rank
        
        local rank_emoji = pack:get("fe16_" .. rank)
        
        local skill = Skill:new(self.data.buddy_skill)
        
        infobox:insert(string.format("%sBudding Talent", rank_emoji), skill:get_fancy(), true)
    end
    
    return infobox
end

function Character:show_spell()
    local infobox = Infobox:new()
    
    local function dothing(rank, rank_value, item)
        local item = Item:new(item)
        
        local rank_emoji = pack:get("fe16_" .. rank)
        rank = util.title(rank)
        rank_value = util.text.rank_letter(rank_exp, rank_value, false)
        
        local name = string.format("%s%s %s", rank_emoji, rank, rank_value)
        
        infobox:insert(name, item:get_emoji() .. item:get_name(), true)
    end
    
    local function loop(rank, data)
        for key, value in pairs(data) do
            dothing(rank, value, key)
        end
    end
    
    loop("reason", self.data.reason)
    loop("faith", self.data.faith)
    
    return infobox
end

function Character:show_mod()
    local infobox = workspaces.Character.show_mod(self)

    -- House color
    if self.data.color ~= nil then
        infobox:set("color", house_color[self.data.color])
    end
    
    -- Difficulty
    -- TODO: Remove item check after weapons are fully implemented
    if self.chapter > 1 and not self.item then
        local footer =  util.title(self.difficulty) .. " Mode"
        
        -- Special Silver Snow text
        if snow_text[self.id] ~= nil and self.chapter == 12 then
            footer = footer .. "\n" .. snow_text[self.id]
        end
        
        infobox:set("footer", footer)
    end

    return infobox
end

function Character:get_mod()
    local text = self:get_lvl_mod()
    
    if self.chapter > 1 then
        text = text .. string.format("\n**Recruitment**: Ch. %s", self.chapter)
    end
    
    if not self:is_changed() then
        for key, value in pairs(self.data.crest) do
            key = util.title(key)
            
            if key == "Beast" then key = "the Beast" end
            
            -- major
            if value then
                text = text .. "\nMajor crest of " .. key
                
            else
                text = text .. "\nMinor crest of " .. key
            end
        end
    end
    
    text = text .. self:common_mods()
    
    return text
end

function Character:get_lvl_mod()
    if not self:has_averages() then
        return string.format("**Lv. %s** %s", self:get_lvl(), self.job:get_name())
        
    else
        local text = ""
        
        local current_lvl = self:get_lvl()
        local separator = " **=>** "
        
        for i, lvl in ipairs(self.lvl) do
            job = self.job_averages[i]
            
            local add = string.format("**Lv. %s - Lv. %s** %s %s", current_lvl, lvl, job:get_name(), separator)
            
            text = text .. add
            
            current_lvl = lvl
        end
        
        text = text:sub(1, (#separator * -1) + -1)
        
        return text
    end
end

-- Base
function Character:final_base()
    local base = self:calc_base()
    
    local job_base = self.job:get_base()
    
    if self:is_changed("class") then
        base = util.math.rise_stats(base, job_base)
    end
    
    base.mov = 4
    
    if not self:is_personal() then
        base = base + self.job:get_mod()
    end
    
    base = self:common_base(base)
    
    return base
end

function Character:calc_base()
    local base = self:get_base()
    
    local job = self.Job:new(self:get_job())

    if self.chapter > 1 then
        local growth = self:calc_growth()
        local enemy = job:get_enemy_growth()
        
        local lvl = self:get_lvl() - 1
        
        -- can't use mod_stats for this one
        for key, value in pairs(growth) do
            local g = value + enemy[key]
            
            -- growth checks
            if key == "def" then g = math.min(g, 60) end
            if key == "res" then g = math.min(g, 60) end
            
            if key == "spd" then g = math.max(5, g) end
            
            g = math.max(0, g)
            
            g = util.round(g / 100)
            g = util.round(lvl * g)
            
            base[key] = base[key] + util.round_closest(g)
        end
    end
    
    base = util.math.rise_stats(base, job:get_base())
    
    if self:has_averages() then
        base = self:calc_averages(base)
    end
    
    base.mov = nil
    
    return base
end

-- Growth
function Character:calc_growth()
    local base = self:get_growth()
    
    if self.id == "cyril" then
        base = base + 20
    end
    
    return base
end

-- Skill
function Character:show_skill()
    local text = ""
    
    -- Show personal skill here if minimal
    if self.minimal and self.data.personal then
        local skill = Skill:new(self.data.personal)
        
        text = text .. skill:get_fancy({bold = true}) .. "\n"
    end
    
    -- Current class skills
    for i, value in ipairs(self.job.data.skill) do
        local skill = Skill:new(value)
        
        text = text .. skill:get_fancy({italics = true}) .. "\n"
    end

    for i, value in ipairs(self:get_skill()) do
        local skill = Skill:new(value)

        text = text .. skill:get_fancy() .. "\n"
    end

    return text
end

local rank_order = {"sword", "lance", "axe", "bow", "brawling", "reason", "faith", "authority", "armor", "riding", "flying"}

-- i still dont know how it prioritize learning skills via level ups so idk if this is correct
-- but nobody cares enough about 3h to know if this is wrong for almost 3 years so yeah
function Character:get_skill()
    -- jeritza chapter hardcoded skills(?)
    if self.id == "jeritza" and self.chapter == 13 then
        return {"swordprowesslv4", "axebreaker", "lanceprowesslv5", "swordbreaker", "brawlingprowesslv3"}
    end
    
    local result = {}

    local personal_rank = self:get_rank()

    for i, rank in ipairs(rank_order) do
        -- prowess
        local value = personal_rank[rank.id] or 0
        local prowess = rank:get_prowess(value)

        if prowess then
            if #result < 3 then
                table.insert(result, prowess)
            end
        end
    end

    -- Reverse Order
    for i, rank in ipairs(rank_order) do
        rank = rank_order[#rank_order - (i - 1)]

        local value = personal_rank[rank.id] or 0

        for i, p in ipairs(rank:get_skill(value)) do
            if #result < 4 then
                table.insert(result, p)
            end
        end
    end
    
    -- Personal learned skills
    for key, value in pairs(self.data.ability) do
        local rank_value = personal_rank[key] or 0
        
        for x, y in pairs(value) do
            if rank_value >= y then
                if #result < 5 then
                    table.insert(result, x)
                end
            end
        end
        
    end

    return result
end

-- Rank
function Character:show_rank()
    local rank = self:get_rank()
    local growth = self.data.rank_growth
    
    local text = ""
    
    for key, value in pairs(rank) do
        local add = pack:get("fe16_" .. key, string.format("**%s**: ", util.title(key)))
        .. util.text.rank_letter(rank_exp, value)
        
        if growth[key] == "strong" then
            add = pack:get("fe16_strong") .. add
            
        elseif growth[key] == "weak" then
            add = pack:get("fe16_weak") .. add
        end
        
        text = text .. add .. "\n"
    end
    
    -- add growths later if they don't have any rank
    for key, value in pairs(growth) do
        if rank[key] == nil then
            local add = pack:get("fe16_" .. key, string.format("**%s**: ", util.title(key)))
            .. util.text.rank_letter(rank_exp, 0)
            
            add = pack:get("fe16_" .. value) .. add
            
            text = text .. add .. "\n"
        end
    end
    
    return text
end

local goal_boost = {
    normal = 64,
    hard = 56,
    maddening = 48
}

function Character:get_rank()
    local base = util.copy(self.data.rank_base)
    
    if self.chapter > 1 then
        local boost = goal_boost[self.difficulty] * self.chapter
        
        for i, goal in ipairs(self.data.goal) do
            if base[goal] == nil then base[goal] = 0 end
            
            base[goal] = base[goal] + boost
        end
    end
    
    -- lower hapi's lance rank
    -- this is in the older code and idk why hapi's rank is not correct in the first place
    if self.id == "hapi" then
        base.lance = base.lance - (self.chapter * 8)
    end
    
    -- increase rank to class exam requirements
    local exam = self.Job:new(self:get_job()).data.min_rank
    
    if exam ~= nil then
        for key, value in pairs(exam) do
            if (base[key] == nil) or (base[key] and value > base[key]) then
                base[key] = value
            end
        end
    end
    
    return base
end

-- Misc
function Character:get_lvl()
    local lvl = 1 + (2 * (self.chapter - 1))
    
    if self.chapter >= 13 then
        lvl = lvl + self.data.skip_lvl
    end
    
    return lvl
end

function Character:get_job()
    if self.chapter >= 6 then
        return self.data.job[3]
    
    elseif self.chapter >= 3 then
        return self.data.job[2]
        
    else
        return self.data.job[1]
    end
end

-- Averages use
function Character:get_base_class()
    return self:get_job()
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, workspaces.Job)

Job.section = almanac.get("database/fe16/job.json")

function Job:show()
    local infobox = almanac.Infobox:new({title = self.data.name})
    
    infobox:insert("Bases", self:show_base())
    infobox:insert("Growths", self:show_growth())
    infobox:insert("Enemy Growths", util.table_stats(self.data.enemy, {value_end = "%"}))
    
    -- Display
    local function display(data)
        local text = ""
        
        for i, pair in ipairs(data) do
            text = text .. Skill:new(pair):get_fancy() .. "\n"
        end
        
        return text
    end
    
    -- Skills
    infobox:insert("Skill", display(self.data.skill), true)
    
    -- Mastery
    local mastery = {}
    
    if self.data.ability then
        table.insert(mastery, self.data.ability)
    end
    
    if self.data.art then
        table.insert(mastery, self.data.art)
    end
    
    infobox:insert("Mastery", display(mastery), true)
    
    -- Rank
    local rank = ""
    
    for key, value in pairs(self.data.rank) do
        rank = rank .. string.format("%s%s +%s\n",
        pack:get("fe16_" .. key), util.title(key), value)
    end
    
    infobox:insert("Rank Bonus", rank, true)
    
    -- Rank
    if self.data.exam then
        local exam = ""
        
        for key, value in pairs(self.data.exam) do
            exam = exam .. string.format("%s%s %s\n",
            pack:get("fe16_" .. key), util.title(key), util.text.rank_letter(rank_exp, value, false))
        end
        
        infobox:insert("Exam Requirements", exam, true)
    end
    
    -- Modifiers
    local function display_mod(data)
        data = util.math.remove_zero(data)
        
        return "```" .. util.table_stats(data, {value_start = "+", between = ""}) .. "```"
    end
    
    if util.table_has(self.data.mount) then
        infobox:insert("Mounted Modifiers", display_mod(self:get_mod()), true)
        infobox:insert("Unmounted Modifiers", display_mod(self:get_mod(true)), true)
    
    else
        infobox:insert("Modifiers", display_mod(self:get_mod()), true)
    end
    
    return infobox
end

function Job:get_mod(foot)
    foot = foot or false
    
    local mod = self.data.mod
    setmetatable(mod, util.math.Stats)
    
    if not foot then
        mod = mod + self.data.mount
    end
    
    return mod
end

function Job:get_enemy_growth()
    return util.copy(self.data.enemy)
end

function Job:get_cap()
    return {}
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, workspaces.Item)

Item.section = almanac.get("database/fe16/item.json")

function Item:get_emoji()
    return pack:get("rank_" .. self.data.type, "")
end

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, workspaces.Skill)

Skill.section = almanac.get("database/fe16/skill.json")

function Skill:get_name()
    local name = self.data.name
    
    -- Hide Prowess bc it's too big and ppl only type [Something] Lv. 3
    local start_index, end_index = string.find(name, " Prowess ", 1, true)
    
    if start_index ~= nil then
        name = name:sub(1, start_index) .. name:sub(end_index, #name)
    end
    
    return name
end

function Skill:get_icon()
    return string.format("database/fe16/images/skill/fe16_%s.png", self.data.icon)
end

function Skill:get_emoji()
    -- combat arts emoji
    if self.data.rank then
        return pack:get("art_" .. self.data.rank)
        
    else
        return pack:get("fe16_" .. tostring(self.data.icon))
    end
end

---------------------------------------------------
-- Rank --
---------------------------------------------------
Rank.__index = Rank
setmetatable(Rank, almanac.Workspace)

Rank.section = almanac.get("database/fe16/rank.json")

function Rank:show()
    local infobox = Infobox:new({title = self.data.name})
    
     -- Display
    local function display(data)
        data = self.data[data]
        
        local text = ""
        
        for key, pair in pairs(data) do
            local add = string.format("%s (%s)\n",
            Skill:new(key):get_fancy(),
            util.text.rank_letter(rank_exp, pair, false))
            
            text = text .. add
        end
        
        return text
    end
    
    infobox:insert("Prowess", display("prowess"), true)
    infobox:insert("Art", display("art"), true)
    infobox:insert("Skill", display("ability"), true)
    
    return infobox
end

function Rank:get_name()
    return self.data.name
end

-- Get highest rank prowess possible
function Rank:get_prowess(rank)
    for key, value in pairs(self.data.prowess) do
        if rank >= value then
            return key
        end
    end

    return false
end

-- Get skills equal or lower to the character's rank
function Rank:get_skill(rank)
    local result = {}

    for key, value in pairs(self.data.ability) do
        if rank >= value then
            table.insert(result, key)
        end
    end

    return result
end

for i, p in ipairs(rank_order) do
    rank_order[i] = Rank:new(p)
end

---------------------------------------------------
-- Battalion --
---------------------------------------------------
Bat.__index = Bat
setmetatable(Bat, almanac.Workspace)

Bat.section = almanac.get("database/fe16/bat.json")

local bat_order = {"phys", "mag", "hit", "crit", "avo", "prot", "res", "cha"}

function Bat:show()
    local infobox = Infobox:new({title = self.data.name})
    
    local desc = string.format("%sAuthority %s\nGambit: %s\nEndurance: %s",
    pack:get("fe16_authority"), self.data.authority,
    self.data.gambit,
    self.data.endurance)
    
    infobox:set("desc", desc)
    
    for i=1, 5 do
        local stats = self:get(i)
        
        infobox:insert("Level " .. tostring(i), util.table_stats(stats, {order = bat_order, value_start = "+"}))
    end
    
    return infobox
end

function Bat:get(level)
    level = level or 1
    
    local result = {}
    setmetatable(result, util.math.Stats)
    
    for i, pair in ipairs(bat_order) do
        local base = self.data.base[pair] or 0
        local growth = self.data.growth[pair] or 0
        
        if growth > 0 then
            growth = util.floor(growth * (level - 1))
        end
        
        value = base + growth
        
        if value ~= 0 then
            result[pair] = value
        end
    end
    
    return result
end

return {
    Character = Character,
    Job = Job,
    Item = Item,
    Skill = Skill,
    Rank = Rank,
    Bat = Bat
}
