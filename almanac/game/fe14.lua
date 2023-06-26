local almanac = require("almanac")
local workspaces = almanac.workspaces

local util = almanac.util

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local pack = util.emoji.get("database/fe14/emoji.json")

local rank_exp = {
    E = 1,
    D = 21,
    C = 51,
    B = 96,
    A = 161,
    S = 251
}

local rank_bonus = {
    sword = {
        C = {atk = 1},
        B = {atk = 2},
        A = {atk = 3},
        S = {atk = 4, hit = 5}
    },
    lance = {
        C = {atk = 1},
        B = {atk = 1, hit = 5},
        A = {atk = 2, hit = 5},
        S = {atk = 3, hit = 10}
    },
    axe = {
        C = {hit = 5},
        B = {hit = 10},
        A = {atk = 1, hit = 10},
        S = {atk = 2, hit = 15}
    }
}

rank_bonus.katana = rank_bonus.sword
rank_bonus.dagger = rank_bonus.sword
rank_bonus.shuriken = rank_bonus.sword
rank_bonus.hidden = rank_bonus.sword

rank_bonus.naginata = rank_bonus.lance
rank_bonus.bow = rank_bonus.lance
rank_bonus.yumi = rank_bonus.lance
rank_bonus.tome = rank_bonus.lance
rank_bonus.scroll = rank_bonus.lance
rank_bonus.stone = rank_bonus.lance
rank_bonus.dragonstone = rank_bonus.lance
rank_bonus.beaststone = rank_bonus.lance
rank_bonus.claw = rank_bonus.lance
rank_bonus.saw = rank_bonus.lance
rank_bonus.breath = rank_bonus.lance

rank_bonus.club = rank_bonus.axe

local rank_same = {
    katana = "sword",
    naginata = "lance",
    club = "axe",
    yumi = "bow",
    scroll = "tome",
    dagger = "hidden",
    shuriken = "hidden"
}
--

local Character = {}
local Job = {}
local Skill = {}
local Item = {}

local Conquest = {}
local Birthright = {}
local Revelation = {}
local Redirect = {}

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
--
local function inventory_as(data, unit, item)
    return unit.stats.spd
end
--
local function inventory_hit(data, unit, item)
    return item.stats.hit + util.floor(unit.stats.skl * 1.5) + util.floor(unit.stats.lck / 2) + unit.job:hit_bonus()
end
--
local function inventory_crit(data, unit, item)
    return item.stats.crit + math.max(util.floor((unit.stats.skl-4) / 2), 0) + unit.job:crit_bonus()
end
--
local function inventory_followup(data, unit, item)
    local double = item.data.equip.doubling_speed or 0
    
    return string.format(">= %s", 5 + double)
end

inventory:item_calc("atk", inventory_atk)
inventory:item_calc("as", inventory_as)
inventory:item_calc("hit", inventory_hit)
inventory:item_calc("crit", inventory_crit)
inventory:item_calc("\nfollow-up", inventory_followup)

-----------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, workspaces.Character)

Character.section = almanac.get("database/fe14/cq.json")

Character.helper_job_base = true
Character.helper_job_growth = true
Character.helper_job_cap = true

Character.helper_portrait = "database/fe14/images"

Character.avatar_id = "corrin"
Character.avatar_child = "kana"
Character.avatar_mod = util.file.json_read("almanac/game/data/avatar.json").fe14

-- flips the aptitude bool
-- also checks for parents
Character.aptitude_id = "mozu"
Character.aptitude_bonus = 10

Character.rank_exp = rank_exp
Character.rank_bonus = rank_bonus

Character.swap_parent = "shigure"

Character.pack = pack

Character.inventory = inventory
Character.follow_up_warning = true

Character.helper_reset_promo = true

Character.Job = Job
Character.Skill = Skill
Character.Item = Item

function Character:default_options()
    return {
        class = self.data.job,
        difficulty = "lunatic",
        father = self.data.father or false,
        mother = self.data.mother or false,
        thirdgen = false,
        chapter = false,
        offspring = false,
        boon = false,
        bane = false,
        parent = self.data.target or false,
        forge = false,
        rank = false,
        aptitude = false
    }
end

-- Pre-setup required to set chapter and offspring for averages
function Character:pre_setup()
    -- Autolevel
    if self:is_autolevel() then
        local chapter = self.options.chapter or self.data.autolevel.default
        
        self.chapter = math.max(chapter, self.data.autolevel.join)
        
        if self.data.autolevel.type == "child" and self.chapter > 18 then
            -- Get the first promo class for offspring if it's not set
            self.offspring = self.options.offspring
            
            if not self.offspring then
                self.offspring = self.Job:new(self.data.job).data.promo[1]
            end
            
            self.offspring = self.Job:new(self.offspring)
            
            -- Change class to offspring if it's not touched for whatever reason
            if not self:is_changed("class") then self.options.class = self.offspring.id end
        end
    end
    
    workspaces.Character.pre_setup(self)
end

function Character:setup()
    self.job = self.Job:new(self.options.class)
    self.difficulty = self.options.difficulty
    
    -- Children
    if self.avatar_child == self.id then
        if not self.options.father then
            self.options.father = self.avatar_id

        elseif not self.options.mother then
            self.options.mother = self.avatar_id
        end
    end
    
    -- Don't allow boon and bane to be the same
    if self.boon == self.bane then
        self.bane = false
    end
    
    self.boon = self.options.boon
    self.bane = self.options.bane

    -- Child Units stuff
    self.father = self.options.father
    self.mother = self.options.mother
    
    if self.id == self.swap_parent and self:is_changed("mother", "father") then
        self.father, self.mother = self.mother, self.father
        
        if not self.father then
            self.father = self.data.father
            
        else
            self.mother = self.data.mother
        end
    end

    if self:has_parents() then
        local tbl = getmetatable(self)

        self.father = tbl:new(self.father)
        self.mother = tbl:new(self.mother)

        -- Swap them if gender is wrong (Avatar Child Only)
        if self.id == self.avatar_child then
            if self.father.id ~= self.avatar_id and self.father.data.gender ~= "m" then
                self.father, self.mother = self.mother, self.father

            elseif self.mother.id ~= self.avatar_id and self.mother.data.gender ~= "f" then
                self.mother, self.father = self.father, self.mother
            end
        end

        local function parent_options(parent)
            local options = {}

            -- Third Gen pairings
            if self.options.thirdgen and parent:is_child() then
                local missing = parent:get_missing_parent()

                options[missing] = self.options.thirdgen
            end
            
            -- Additional levels to pass
            if self.options.parent then
                options.level = {self.options.parent}
                
                if self.options.parent > 20 then
                    table.insert(options.level, self.options.parent - 20)
                end
            end

            -- Pass boon/bane if parent is avatar
            if parent.id == self.avatar_id then
                if self.boon then
                    options.boon = self.boon
                    self._changed.boon = nil

                    self.boon = false
                end

                if self.bane then
                    options.bane = self.bane
                    self._changed.bane = nil

                    self.bane = false
                end
            end
            
            return options
        end

        self.father:set_options(parent_options(self.father))
        self.mother:set_options(parent_options(self.mother))
    end
    
    -- Apply forges and item rank bonus
    if self.item then
        local args = {
            forge = self.options.forge or nil,
            mt = self.options.mt or nil,
            hit = self.options.hit or nil,
            crit = self.options.crit or nil
        }
        
        self.item:set_options(args)
        
        local wpn_type = self.item.data.type
        
        if rank_same[wpn_type] ~= nil then
            wpn_type = rank_same[wpn_type]
        end
        
        if self.rank_bonus[wpn_type] ~= nil then
            local bonus = self.rank_bonus[wpn_type]
            local rank = self.item.data.stats.rank
            
            -- Use item's rank or unit's rank, the one that is higher
            if not self.options.rank then
                local item_exp = self.rank_exp[rank] or 0
                local unit_exp = self:get_rank()[wpn_type] or 0
                
                local result
                
                if item_exp > unit_exp then
                    result = item_exp
                    
                else
                    result = unit_exp
                end
                
                result = util.text.rank_letter(self.rank_exp, result, false)
                
                self.rank_letter = result
                self.rank = bonus[result]
            
            else
                self.rank_letter = self.options.rank
                self.rank = bonus[self.options.rank]
            end
        end
    end
    
    -- Aptitude
    self.aptitude = self.options.aptitude
    
    if self.id == self.aptitude_id or 
    (self:has_parents() and
    (self.mother.id == self.aptitude_id or self.father.id == self.aptitude_id)) then
        self.aptitude = not(self.aptitude)
    end
    
    -- Gender
    -- Only used for avatar stuff for now
    if self.id == self.avatar_id then
        -- Random gender
        if math.random(1, 2) == 1 then self.gender = "m" else self.gender = "f" end

    elseif self.id == self.avatar_child then
        -- Gender based on where the avatar is
        if self:has_parents() then
            if self.father.id == self.avatar_id then
                self.gender = "f"

            else
                self.gender = "m"
            end
        
        else
            if math.random(1, 2) == 1 then self.gender = "m" else self.gender = "f" end
        end
        
    else
        self.gender = self.data.gender
        
    end

    -- Ignore father/mother/thirdgen for minimal
    self.minimal = false

    for key, value in pairs(self._changed) do
        if not util.misc.value_in_table({"father", "mother", "thirdgen", "any"}, key) then
            self.minimal = true
        end
    end
end

-- Show / Mod
function Character:show_info()
    local box = self:show_mod()
    
    if self.data.personal then
        local skill = self.Skill:new(self.data.personal)
        
        box:insert(skill:get_fancy(), skill:get_desc(), true)
    end

    if #self.data.set > 0 then
        local setbox = self:show_set()

        if not box.has_pages then
            local pagebox = Pagebox:new()

            pagebox:stats_button()

            pagebox:page(box)

            box = pagebox
        end

        self:apply_color(setbox)

        box:page(setbox)
        box:button({label = "Reclass", emoji = "master"})
    end
    
    return box
end

function Character:show_mod()
    local box = workspaces.Character.show_mod(self)
    
    if self:is_child() and not self:has_parents() then
        box:set("footer", string.format("Showing data without inheritance. To select a parent, try: parent!%s | Ex: %s!%s", 
                self.id, self.avatar_id, self.id))
    
    elseif self.id == self.avatar_id and (not self.boon or not self.bane) then
        box:set("footer", "Showing stats without boon/banes. To apply then, try: +boon -bane | Ex: +atk -def")
        
    elseif self.item and self.follow_up_warning then
        box:set("footer", "Follow-Up is how much speed you need to double.")
    end
    
    -- Difficulty
    if self.data.variable then
        box:set("footer", util.title(self.difficulty) .. " Mode")
    end
    
    if not self:has_averages() and self:has_pairup() and not self.item then
        local pairup = self:show_pairup()
        
        local pagebox = Pagebox:new()
        
        pagebox:page(box)
        pagebox:page(pairup)
        
        pagebox:stats_button()
        pagebox:button({label = "Pair-Up", emoji = "pairup"})
        
        box = pagebox
    end
    
    self:apply_color(box)
    
    return box
end

function Character:get_mod()
    local text = self:get_lvl_mod()
    
    -- Dragon Blood
    if self:has_blood() then
        text = pack:get("blood") .. text
    end
    
    -- Recruit display for autolevels
    if self:is_autolevel() then
        local add = string.format("\n**Recruitment**: Ch. %s", self.chapter)
        
        if self.offspring then
            add = add .. string.format(" | **Offspring**: %s", self.offspring:get_name())
        end
        
        text = text .. add
    end
    
    -- Parent display
    if self:is_child() then
        local add

        -- Has them
        if self:has_parents() then
            add = string.format("\n**Father**: %s | **Mother**: %s", self.father:get_parent_name(), self.mother:get_parent_name())

        -- Parents are missing
        else
            if self.data.father then
                add = string.format("\n**Father**: %s", util.title(self.data.father))

            elseif self.data.mother then
                add = string.format("\n**Mother**: %s", util.title(self.data.mother))
            else
                add = "\nNo parents set."
            end
        end

        text = text .. add
    end
    
    -- Boon/Bane
    if self.boon and self.bane then
        text = text .. string.format("\n**+**%s **-**%s", util.title(self.boon), util.title(self.bane))
    end
    
    -- Aptitude
    if self.aptitude then
        text = text .. "\n" .. util.emoji.global:get("aptitude") .. "Aptitude"
    end
    
    -- Weapon Rank
    if self.rank then
        text = text .. string.format("\n**%s Rank Bonus**: %s", self.rank_letter, util.table_stats(self.rank, {value_start = "+", separator= "; "}))
    end

    return text .. self:common_mods()
end

-- Base
function Character:get_base()
    local base = util.copy(self.data.base[self.difficulty])
    setmetatable(base, util.math.Stats)
    
    -- Autolevel bases
    if self:is_autolevel() then
        local growth = self:get_growth()
        
        -- Child
        if self.data.autolevel.type == "child" and self.chapter > 11 then
            -- Base Class Autolevel
            local lvl
            
            if self.offspring then lvl = 20 else lvl = self:get_autolevel_lvl() end
            lvl = lvl - 10
            
            local total = growth + self.Job:new(self.data.job):get_growth()
            
            base = util.math.growth_stats(base, total, lvl)
            
            -- Offspring autolevel
            if self.offspring then
                total = growth + self.offspring:get_growth()
                
                base = util.math.growth_stats(base, total, self:get_autolevel_lvl() - 1)
            end
            
        -- Castle
        elseif self.data.autolevel.type == "castle" then
            local lvl = self:get_autolevel_lvl() - self.data.lvl
            
            if lvl > 0 then
                local total = growth + self.Job:new(self.data.job):get_growth()
                
                base = util.math.growth_stats(base, total, lvl)
            end
        end
    end

    -- Children bases
    if self:has_parents() then
        local function parent_mod(v1, v2)
            return math.max(v2 - util.floor(v1), 0)
        end

        local father = util.math.mod_stats(parent_mod, base, self.father:calc_base())
        local mother = util.math.mod_stats(parent_mod, base, self.mother:calc_base())

        local function parent_total(v1, v2)
            -- Cannot be higher than base
            v1 = util.floor(v1 / 10) + 2

            v2 = util.floor(v2 / 4)

            return math.min(v1, v2)
        end

        local total = util.math.mod_stats(parent_total, base, father + mother)

        base = base + total
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

-- Growth
function Character:calc_growth()
    local growth = self:get_growth()
    
    if self.aptitude then
        growth = growth + self.aptitude_bonus
    end
    
    return growth
end
function Character:get_growth()
    local growth = util.copy(self.data.growth)
    setmetatable(growth, util.math.Stats)
    
    -- Children growths = (Variable Parent + Child) / 2
    if self:has_parents() then

        local function step(v1, v2)
            v1 = v1 + v2

            return util.floor(v1 / 2)

        end

        local variable = self:get_variable_parent()
        variable = variable:get_growth()

        growth = util.math.mod_stats(step, growth, variable)
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

-- Cap
function Character:get_cap()
    local cap = util.copy(self.data.cap)
    setmetatable(cap, util.math.Stats)
    
    -- Children Caps = Mother + Father (+1 if parent is not a child)
    if self:has_parents() then
        local changed = {}
        
        local function check(data)
            for key, value in pairs(data) do
                if value ~= 0 then
                    changed[key] = true
                end
            end
            
            return data
        end
        
        cap = check(self.father:get_cap()) + check(self.mother:get_cap())
        
        -- Only add +1 if the parents are not children
        if not self.father:is_child() and not self.mother:is_child() then
            for key, value in pairs(changed) do
                cap[key] = cap[key] + 1
            end
        end
        
    end
    
    -- Avatar Boon/Bane
    -- Yeah copy/pasted from above
    if self.boon and self.bane then
        for key, value in pairs({[self.boon] = "boon", [self.bane] = "bane"}) do
            for x, y in pairs(self.avatar_mod.cap[key]) do
                y = y[value]
                
                cap[x] = cap[x] + y
            end
        end
    end
    
    return cap
end

-- Skill
function Character:show_skill()
    local text = ""
    
    if self.minimal and self.data.personal then
        text = text .. self.Skill:new(self.data.personal):get_fancy({bold = true}) .. "\n"
    end
    
    for i, value in ipairs(self:get_skill()) do
        local skill = self.Skill:new(value)
        
        text = text .. skill:get_fancy() .. "\n"
    end
    
    return text
end

function Character:get_skill()
    local result = util.copy(self.data.skill[self.difficulty])
    
    -- Autolevel skills
    if self:is_autolevel() then
        local lvl, job
        
        -- Child
        if self.data.autolevel.type == "child" and self.chapter > 18 then
            lvl = self:get_autolevel_lvl()
            job = self.offspring
        
        -- Castle
        elseif self.data.autolevel.type == "castle" then
            lvl = self:get_autolevel_lvl()
            job = self.Job:new(self.data.job)
        end
        
        if job ~= nil then
            local skill = job.data.skill
            
            for key, value in pairs(skill) do
                if lvl >= value and not util.misc.value_in_table(result, key) then
                    table.insert(result, key) end
            end
        end
    end
    
    return result
end

-- Rank
function Character:show_rank()
    if self.job:has_rank() then
        return util.text.weapon_rank(self:get_rank(), {exp = self.rank_exp, pack = self.pack})
    end
end

function Character:get_rank()
    local result = self.job:get_rank()
    local rank = util.copy(self.data.rank[self.difficulty])
    
    if self:is_autolevel() then
        -- Child
        if self.data.autolevel.type == "child" and self.chapter > 11 then
            -- Base Class Autolevel
            local lvl
            
            if self.offspring then lvl = 20 else lvl = self:get_autolevel_lvl() end
            lvl = lvl - 10
            
            for key, value in pairs(rank) do
                rank[key] = rank[key] + (lvl * 4)
            end
            
            -- Offspring class autolevel
            if self.offspring then
                local offspring = self.offspring:get_rank()
                
                lvl = self:get_autolevel_lvl() - 1
                
                for key, value in pairs(offspring) do
                    if rank[key] == nil then
                        rank[key] = 1
                    end
                    
                    rank[key] = rank[key] + (lvl * 4)
                end
            end
            
        -- Castle
        elseif self.data.autolevel.type == "castle" then
            local lvl = self:get_autolevel_lvl() - self.data.lvl
            
            for key, value in pairs(rank) do
                rank[key] = rank[key] + (lvl * 4)
            end
            
        end
        
    end
    
    for key, value in pairs(result) do
        if rank[key] == nil then
            result[key] = 1
            
        else
            result[key] = math.min(rank[key], value)
        end
    end
    
    return result
end

-- Pair Up
function Character:show_pairup()
    local infobox = Infobox:new({title = self.data.name})
    
    -- combine class and personal pair ups, remove the 0s
    local function combine(pairup)
        local result = {}
        
        for key, value in pairs(self.job.data.pairup) do
            local r = value
            
            if pairup[key] ~= nil then r = r + pairup[key] end
            
            if r ~= 0 then
                result[key] = r
            end
        end
        
        return result
    end
    
    ---------
    for i, rank in ipairs({"c", "b", "a", "s"}) do
        local pairup = self:get_pairup(rank)
        
        if not self:is_personal() then
            pairup = combine(pairup)
        end
        
        local text = util.table_stats(pairup, {value_start = "+"})
        
        infobox:insert("Support " .. util.title(rank), text)
    end
    
    return infobox
end

function Character:get_pairup(rank)
    rank = rank or "s"
    
    -- Use pairup.raw over pairup.bonus, bonus will probably be never used again
    local raw = self:get_pairup_raw()

    -------------
    local result = {}
    local continue = true
    
    for i, key in ipairs({"c", "b", "a", "s"}) do
        local value = raw[key]
        
        if continue then
            if key == rank then continue = false end
            
            for x, y in pairs(value) do
                if result[x] == nil then result[x] = 0 end
                
                result[x] = result[x] + y
                
            end
            
        end
    end
    
    return result
end

-- big ass file with corrin's pairup bonuses
-- get the correct one with bane > boon as keys for the objects
local corrin_pairup = util.file.json_read("almanac/game/data/corrin.json")

function Character:get_pairup_raw()
    if self.data.pairup then
        return self.data.pairup.raw
        
    elseif self:has_parents() then
        local father = self.father:get_pairup_raw()
        local mother = self.mother:get_pairup_raw()
        
        return {
            c = father.c,
            b = mother.b,
            a = father.a,
            s = mother.s
        }
    
    elseif self.id == self.avatar_id then
        return corrin_pairup[self.bane][self.boon].raw
    end
end

function Character:has_pairup()
    return (self.data.pairup or
             (self:has_parents() and self.father:has_pairup() and self.mother:has_pairup()) or
             (self.id == self.avatar_id and self.boon and self.bane))
end

-- Class Sets
function Character:show_set()
    local set = self:get_set()

    local infobox = Infobox:new({title = self.data.name})

    for i, job in ipairs(set) do
        local job = self.Job:new(job)

        local text = job:show_skill() .. "\n"

        for _, promo in ipairs(job.data.promo) do
            local promo = self.Job:new(promo)

            text = text .. string.format("%s**%s**\n%s\n",
                    util.emoji.global:get("master"),
                    promo:get_name(),
                    promo:show_skill())
        end

        infobox:insert(job:get_name(), text, true)
    end

    return infobox
end

Character.set_banlist = {"songstress"}
Character.set_alt = {
    songstress = "troubadour",
    cavalier = "ninja",
    ninja = "cavalier",
    knight = "spearfighter",
    spearfighter = "knight",
    fighter = "onisavage",
    onisavage = "fighter",
    mercenary = "samurai",
    samurai = "mercenary",
    outlaw = "archer",
    archer = "outlaw",
    darkmage = "diviner",
    diviner = "darkmage",
    wyvernrider = "skyknight",
    skyknight = "wyvernrider",
    villager = "apothecary",
    wolfskin = "outlaw",
    kitsune = "apothecary"
}

Character.set_gender = {
    m = {shrinemaiden = "monk"},
    f = {monk = "shrinemaiden"}
}

function Character:get_set()
    local set = util.copy(self.data.set)

    if self:has_parents() then

        local function try_adding(data, alt)
            alt = alt or false

            for i, pair in ipairs(data) do
                -- alt classes
                if alt and self.set_alt[pair] ~= nil then
                    pair = self.set_alt[pair]
                end
                
                -- gender-different classes
                if self.set_gender[self.gender][pair] ~= nil then
                    pair = self.set_gender[self.gender][pair]
                end
                
                -- check if valid by:
                -- not in banlist
                -- doesn't exist in the current set
                if not util.value_in_table(self.set_banlist, pair) and
                not util.value_in_table(set, pair) then
                    table.insert(set, pair)

                    return true
                end
            end

            return false
        end

        local mother = self.mother:get_set()
        local father = self.father:get_set()

        local function parent(data)
            local result = try_adding(data)

            if not result then
                try_adding(data, true)
            end
        end

        parent(father)
        parent(mother)
    end

    return set
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

function Character:has_blood()
    return (self.data.blood or 
             (self:has_parents() and (self.father:has_blood() or self.mother:has_blood()) ))
end

function Character:get_parent_name()
    local name = self:get_name()

    if self:has_parents() then
        local variable = self:get_variable_parent()

        name = variable:get_name() .. "!" .. name
    end
    
    if self.boon and self.bane then
        name = name .. string.format(" (+%s -%s)", util.title(self.boon), util.title(self.bane))
    end
    
    if #self.lvl > 0 then
        local lvl = self:get_lvl()
        
        -- use first lvl instead of the second one
        -- second is reduced by 20
        lvl = math.max(self.lvl[1] - self.data.lvl, 0)
        
        if lvl > 0 then
            name = name .. string.format(" (Lv. +%s)", lvl)
        end
    end

    return name
end

function Character:get_portrait()
    if self:has_parents() then
        local variable = self:get_variable_parent()
        
        local id = self.id

        if id == self.avatar_child then
            id = id .. "_" .. self.gender
        end

        local path = string.format("%s/child/%s/%s.png", self.helper_portrait, id, variable.id)

        if util.file.exists(path) then
            return path
            
        else
            return workspaces.Character.get_portrait(self)
        end
        
    else
        if self.id == self.avatar_id or self.id == self.avatar_child then
            local id = self.id .. "_" .. self.gender

            return string.format("%s/%s.png", self.helper_portrait, id)

        else
            return workspaces.Character.get_portrait(self)
        end
    end
end

function Character:is_child()
    return (self.data.father or self.data.mother) or (self.id == self.avatar_child)
end

function Character:has_parents()
    return (self:is_child() and self.father and self.mother)
end

function Character:get_variable_parent()
    if self.data.father then
        return self.mother
    else
        return self.father
    end
end

function Character:get_fixed_parent()
    if self.data.father then
        return self.father
    else
        return self.mother
    end
end

function Character:get_missing_parent()
    if self.data.father then
        return "mother"

    else
        return "father"
    end
end

function Character:get_forced_parent()
    if self.data.father then
        return "father"

    else
        return "mother"
    end
end

------
-- Autolevel
function Character:is_autolevel()
    return (self.data.autolevel ~= nil)
end

local children_join = {
    [8] = 10,
    [9] = 10,
    [10] = 10,
    [11] = 10,
    [12] = 11,
    [13] = 12,
    [14] = 14,
    [15] = 15,
    [16] = 17,
    [17] = 18,
    [18] = 20
}

function Character:get_autolevel_lvl()
    -- Child
    if self.data.autolevel.type == "child" then
        local lvl
        
        if self.offspring then lvl = (self.chapter - 18) * 2 else lvl = children_join[self.chapter] end
        
        return lvl
        
    -- Castle
    elseif self.data.autolevel.type == "castle" then
        local lvl = self.data.lvl
        
        -- Add for each chapter
        for key, value in pairs(self.data.autolevel.bonus) do
            if self.chapter >= tonumber(key) then
                lvl = lvl + value
            end
        end
        
        return lvl
        
    end
end

function Character:get_lvl()
    if self:is_autolevel() then
        return self:get_autolevel_lvl()
        
    else
        return self.data.lvl
    end
end

function Character:get_base_class()
    if self.offspring then
        return self.offspring.id
        
    else
        return self.data.job
    end
end

-- Fancy Infobox colors
local box_color = {
    cq = 0x745196,
    br = 0x963e3e,
    rev = 0x2f7575
}

function Character:apply_color(infobox)
    if self.route ~= nil and box_color[self.route] ~= nil then
        infobox:set("color", box_color[self.route])
        infobox:image("icon", string.format("database/fe14/icon_%s.png", self.route) )
    end
end
---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, workspaces.Job)

Job.section = almanac.get("database/fe14/job.json")

Job.pack = pack
Job.rank_exp = rank_exp
Job.Skill = Skill

function Job:show()
    local infobox = almanac.Infobox:new({title = self.data.name})
    
    infobox:insert("Bases", self:show_base())
    infobox:insert("Growths", self:show_growth())
    
    if self.data.generic then
        infobox:insert("Generic Growth", util.table_stats(self.data.generic, {value_end = "%"}))
    end
    
    infobox:insert("Caps", self:show_cap())
    
    infobox:insert("Skills", self:show_skill(), true)
    infobox:insert("Ranks", self:show_rank(), true)
    
    infobox:insert("Pair-Up", util.table_stats(self:get_pairup(), {value_start = "+"}), true)
    
    if self.data.bonus then
        local bonus = util.math.remove_zero(self.data.bonus)
        
        infobox:insert("Bonus", util.table_stats(bonus, {value_start = "+"}), true)
    end
    
    return infobox
end

function Job:get_pairup()
    if self.data.pairup then
        local pairup = util.copy(self.data.pairup)
        
        return util.math.remove_zero(pairup)
        
    else
        return {}
    end
end

function Job:hit_bonus()
    if self.data.bonus and self.data.bonus.hit then
        return self.data.bonus.hit
        
    else
        return 0
    end
end

function Job:crit_bonus()
    if self.data.bonus and self.data.bonus.crit then
        return self.data.bonus.crit
        
    else
        return 0
    end
end

function Job:get_name()
    return self.data.name
end

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, workspaces.Skill)

Skill.section = almanac.get("database/fe14/skill.json")

function Skill:get_emoji()
    if util.emoji.config.enabled then
        return self.data.emoji
        
    else
        return ""
    end
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, workspaces.Item)

Item.section = almanac.get("database/fe14/item.json")

Item.forge_pattern = {
    -- Pattern 1
    {{mt = 2, hit = 0, crit = 0}, {mt = 4, hit = 2, crit = 0}, {mt = 6, hit = 4, crit = 1}, {mt = 8, hit = 6, crit = 3}, {mt = 9, hit = 10, crit = 6}, {mt = 10, hit = 15, crit = 10}, {mt = 11, hit = 20, crit = 15}},
    -- Pattern 2
    {{mt = 2, hit = 0}, {mt = 4, hit = 2}, {mt = 6, hit = 5}, {mt = 8, hit = 9}, {mt = 9, hit = 15}, {mt = 10, hit = 22}, {mt = 11, hit = 30}}
}

function Item:default_options()
    return {forge = false}
end

function Item:setup()
    if self.options.forge and self:is_weapon() then
        self.forge = self.options.forge
    end
end

function Item:get_stats_raw()
    local item = util.copy(self.data.stats)
    
    if self.forge then
        local pattern = self.data.forge + 1
        
        for key, value in pairs(self.forge_pattern[pattern][self.forge]) do
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
        name = name .. string.format(" +%s", self.forge)
    end
    
    return name
end

---------------------------------------------------
-- Redirect --
---------------------------------------------------
Redirect.__index = Redirect
setmetatable(Redirect, almanac.Workspace)

Redirect.section = almanac.get("database/fe14/redirect.json")

Redirect.redirect = true

function Redirect:default_options()
    return {route = false}
end

function Redirect:setup()
    self.route = self.options.route
end

local redirect_table = {
    cq = Conquest,
    br = Birthright,
    rev = Revelation
}

function Redirect:show()
    local character = self:get()
    
    return character:show()
end

function Redirect:get()
    if not self.route then
        self.route = self.data.routes[1]
    
    elseif route and not util.misc.value_in_table(self.data.routes, self.route) then
        self.route = self.data.routes[1]
    end
    
    -- default to rev if it doesn't exist anywhere else
    local function check(id)
        local character = Redirect:new(id)
        
        if not util.misc.value_in_table(character.data.routes, self.route) then
            self.route = "rev"
        end
    end
    
    for i, pair in ipairs({"mother", "father", "thirdgen"}) do
        if self.passed_options[pair] then
            check(self.passed_options[pair])
        end
    end
    
    local character = redirect_table[self.route]:new(self.id)
    character:set_options(self.passed_options)
    
    return character
end
---------------------------------------------------
-- Route Characters --
---------------------------------------------------
-- Conquest
Conquest.__index = Conquest
setmetatable(Conquest, Character)

Conquest.section = almanac.get("database/fe14/cq.json")

Conquest.route = "cq"

-- Birthright
Birthright.__index = Birthright
setmetatable(Birthright, Character)

Birthright.section = almanac.get("database/fe14/br.json")

Birthright.route = "br"

-- Revelation
Revelation.__index = Revelation
setmetatable(Revelation, Character)

Revelation.section = almanac.get("database/fe14/rev.json")

Revelation.route = "rev"

return {
    Character = Character,
    Job = Job,
    Skill = Skill,
    Item = Item,
    Birthright = Birthright,
    Conquest = Conquest,
    Revelation = Revelation,
    Redirect = Redirect
}
