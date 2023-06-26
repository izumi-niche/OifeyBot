local almanac = require("almanac.core")

local Workspace = almanac.Workspace
local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local util = require("almanac.util")

---------------------------------------------------
-- Character --
---------------------------------------------------
local Character = {}
Character.__index = Character
setmetatable(Character, Workspace)

-----------------------------
-- Helpers
-- If is allowed to show growth/caps
Character.allow_show_growth = true
Character.allow_show_cap = true


-- Automatically add class's bases/growths in the default calc function
Character.helper_job_base = false
Character.helper_job_growth = false
Character.helper_job_cap = false 

-- Reset level when changing classes for default get_mod()
Character.helper_job_reset = true
-- Reset level only if unpromoted-promoted
Character.helper_reset_promo = false

-- Promotion bonuses
-- Used for multiple tiers of promotions like tellius
Character.allow_show_promo = false
Character.promo_progressive = false

-- Stats
Character.promo_use_fixed = true
Character.promo_use_negative = {"bld", "mov", "con"}
Character.promo_job_cap = false
Character.promo_inline = true

-- Thracia Jank
Character.promo_remove_hp = false

-- Weapon Ranks
Character.promo_rank_negative = true

-- Skills
Character.allow_promo_skill = true

-- Portrait location
Character.helper_portrait = false

--[[
-- Stat to compare
-- ex: final_[function]()
Character.compare_tasks = {
    {name = "Stats", func = "base"},
    {name = "Growths", func = "growth"}
}
--]]

Character.compare_base = true
Character.compare_growth = true
Character.compare_cap = true

-- Default average calculator, can be replaced
Character.avg = util.math.Averages:new()

-- If to use averages more suited for games without reclassing like fe8
Character.average_classic = false

-- Rise stats to base lvl instead of adding them
Character.average_rise_stat = false

-- Item warning
Character.item_warning = false

-----------------------------
-- Setup / Options
function Character:special_options()
    return {
        compare = {},
        personal = false,
        level = {},
        job_averages = {},
        weapon = false,
        modifiers = false
    }
end

function Character:pre_setup()
    self.minimal = self:is_changed()
    self.compare = self.options.compare
    self.personal = self.options.personal
    self.lvl = self.options.level
    self.job_averages = self.options.job_averages
    
    self.modifiers = self.options.modifiers
    if self.modifiers then
        self.modifiers.add = self.modifiers.add or {}
        self.modifiers.equal = self.modifiers.equal or {}
    end
    
    if self.options.weapon and self.inventory and self.Item then
        -- check if it is a weapon
        local function check(test)
            test = self.Item:new(test)
            
            if test:is_weapon() then
                return test
                
            else
                return nil
            end
        end
        
        -- Multiple Items
        if type(self.options.weapon) == "table" then
            self.item = {}
            
            for i, item in ipairs(self.options.weapon) do
                item = check(item)
                
                if item ~= nil then
                    table.insert(self.item, item)
                end
            end
        
        -- One Item
        else
            self.item = check(self.options.weapon)
            
            if self.item then
                local cast = self.item.data.equip.cast
                
                if cast then
                    cast = self.Item:new(cast)
                    
                    self.item = {self.item, cast}
                end
            end
        end
    end
    
    if self:has_averages() then
        self:averages_organize()
    end
    
end

-----------------------------
-- Show
function Character:show()
    -- Set compare here
    if self:is_compare() then
        return self:show_compare()
    
    elseif self.minimal then
        return self:show_mod()
        
    else
        return self:show_info()
    end
end

-- Show everything
function Character:show_info()
    local infobox = self:show_mod()
    
    -- do stuff here maybe?
    
    return infobox
end

-- Show mods
-- Only show minimal information, like for averages or equipping items/skills
function Character:show_mod()
    local infobox = Infobox:new({title = self:get_name(), desc = self:get_mod()})
    
    infobox:image("thumbnail", self:get_portrait())
    infobox:insert(self:get_field_stats_name(), self:show_base())
    
    if not self:has_averages() and not self:has_item() then
        infobox:insert("Growths", self:show_growth())
        infobox:insert("Caps", self:show_cap())
        infobox:insert("Ranks", self:show_rank(), true)
        infobox:insert("Skills", self:show_skill(), true)
    end
    
    if self:has_item() then
        local function doit(item)
            local name, text = self:mod_equip(item)
            
            infobox:insert(name, text, true)
        end
        
        if #self.item > 0 then
            for i, item in ipairs(self.item) do
                doit(item)
            end
            
        else
            doit(self.item)
        end
        
        if self.item_warning then
            infobox:set("footer", "Weapon equipping not fully implemented. Stats may not be accurate if there's any special effects.")
        end
    end
    
    -- Promotion
    if not self.minimal and self.allow_show_promo then
        local promo = self:show_promo()
        
        if promo ~= nil then
            for key, value in pairs(promo) do
                infobox:insert(key, value, self.promo_inline)
            end
        end
    end
    
    return infobox
end

function Character:mod_equip(item)
    local inventory = self.inventory:set_unit(self)
    
    local equip = inventory:equip_item(item)
    
    local text
    
    if self.item and #self.item > 0 then
        text = util.table_stats(equip.stats, {separator = "\n"})
        
    else
        text = util.table_stats(equip.stats)
    end
    
    text = "```" .. text .. "```"
    
    return item:get_name(), text
end

function Character:show_equip()
    return util.table_stats(self:get_equip())
end

function Character:get_equip()
    local item = self.item
    
    if #item > 0 then
        item = self.item[#self.item]
    end
    
    local inventory = self.inventory:set_unit(self)
    local equip = inventory:equip_item(item)
    
    return equip.stats
end

-- Average Use
function Character:final_equip()
    return self:get_equip()
end

------------------------------
-- Compare
function Character:show_compare()
    local compare = {}
    table.insert(compare, self)
    
    self._compare = true
    
    for i, p in ipairs(self.compare) do
        if p.redirect then
            p = p:get()
        end
        
        p._compare = true
        
        p._changed.compare = true
        p._changed.any = true
        
        table.insert(compare, p)
    end
    -- Get and set names
    -- Add (x) at the end if there's duplicates
    local used = {}
    
    -- Compare weapon stats if all units have them
    local equip_check = true
    
    for i, character in pairs(compare) do
        -- Get name
        local name = character:get_compare_result_name()
        
        if used[name] == nil then
            used[name] = 1
        
        else
            used[name] = used[name] + 1
            
            name = name .. string.format(" (%s)", used[name])
        end
        
        character._compare_name = name
        
        -- If not weapon equipped, set to false
        if not character:has_item() then
            equip_check = false
        end
    end
    
    -- Get which stats need to be done
    local tasks = {}
    
    if equip_check then
        table.insert(tasks, {name = "Weapon", func = "equip"})
    end
    
    if self.compare_base then
        table.insert(tasks, {name = "Stats", func = "base"})
    end
    
    if self.compare_growth then
        table.insert(tasks, {name = "Growths", func = "growth"})
    end
    
    if self.compare_cap then
        table.insert(tasks, {name = "Caps", func = "cap"})
    end
    
    --------------------
    -- Store the box to return here
    local box
    
    -- Only one task
    if #tasks == 1 then
        local task = tasks[1]
        
        local infobox = self:show_compare_task(compare, task.func)
        
        box = infobox
    
    -- Multiple tasks
    else
        local pagebox = Pagebox:new()
        
        for i, task in ipairs(tasks) do
            local infobox = self:show_compare_task(compare, task.func)
            
            pagebox:page(infobox)
            pagebox:button({label = task.name, emoji = "bond"})
        end
        
        box = pagebox
    end
    
    local portraits = {}
    
    for _, character in ipairs(compare) do
        local p = character:get_portrait()
        
        if p ~= nil then
            table.insert(portraits, p)
        end
        
    end
    
    -- add random portrait here, if possible
    if #portraits > 0 then
        local i = math.random(1, #portraits)
        
        if box.has_pages then
            box.pages[1]:image("thumbnail", portraits[i])
            
        else
            box:image("thumbnail", portraits[i])
        end
        
    end
    
    return box
end

-- Compare calcs happens here
-- Returs infobox with results and stuff
function Character:show_compare_task(compare, task)
     -- stats goes here
    local result = {}
    setmetatable(result, util.ordered_table)
    
    -- Run function using the task value
    function task_func(c, key)
        local func = c[key .. "_" .. task]
        
        return func(c)
    end
    
    -- get the stat keys from all characters first
    for i, character in pairs(compare) do
        for k, v in pairs(task_func(character, "final")) do
            -- hardcoded: ignore follow-up from fates
            if k ~= "\nfollow-up" and result[k] == nil then
                result[k] = {name = "Dummy", value = -99, diff = -99, lowest = 9999, lowest_name}
            end
        end
    end
    
    -- infobox
    local infobox = Infobox:new()
    
    -- loop through the chars and do stuff
    for _, character in ipairs(compare) do
        -- Field values
        local name = character:get_compare_name()
        local desc = string.format("%s\n%s", character:get_compare_mod(), task_func(character, "show"))
        
        infobox:insert(name, desc)
        
        -- now to actually calc the stats
        local stats =  task_func(character, "final")
        
        for k, stat in pairs(result) do
            v = stats[k]
            
            -- Treat as 0 if number is null
            -- Use atk for eff it it is null instead
            if v == nil then
                if k == "eff" then
                    v = stats.atk
                    
                else
                    v = 0
                end
            end
            
            v = util.round_closest(v)
            
            -- if the stats are higher
            if v > stat.value then
                -- only do the calc if it has been modified
                if stat.value ~= -99 then
                    stat.diff = v - stat.value
                end
                
                stat.value = v
                stat.name = character._compare_name
            
            -- if the stats are the same
            elseif v == stat.value then
                stat.name = stat.name .. " **&** " .. character._compare_name
            end
            
            -- lowest value, if the first hero has more stats than the other ones
            if v < stat.lowest then
                stat.lowest = v
                stat.lowest_name = character._compare_name
            
            elseif v == stat.lowest then
                stat.lowest_name = stat.lowest_name .. " **&** " .. character._compare_name
            end
            
        end
    end
    
    -- Show results here
    local text = ""
    
    local highest = ""
    local lowest = ""
    
    -- use the order from text to display them correctly 
    for i, k in pairs(util.text.stat_order(result)) do
        local v = result[k]
        -- If the first hero has the highest stat, the diff would be -99. to prevent that, calc it using the lowest one
        if v.diff == -99 then
            v.diff = v.value - v.lowest
        end
        
        
        
        if #compare == 2 then
            local add
            
            -- stats are different
            if v.diff ~= 0 then
                local diff = string.format("+%s", v.diff)
                
                if task == "growth" then
                    diff = diff .. "%"
                end
                
                -- [Emoji][Name] has +[Diff] [Stat].
                add = string.format("%s**%s** has **%s** %s.", util.emoji.global:get(k, ""), v.name, diff, util.text.fancy_stat(k))
            else
                -- [Emoji]Equal [Stat].
                add = string.format("%s**Equal** %s.", util.emoji.global:get(k, ""), util.text.fancy_stat(k))
            end
            
            text = text .. add .. "\n"
            
        else
            local highest_add = string.format("%s**%s**: %s (%s)\n", util.emoji.global:get(k, ""), util.title(k), v.name, v.value)
            highest = highest .. highest_add
            
            local lowest_add = string.format("%s**%s**: %s (%s)\n", util.emoji.global:get(k, ""), util.title(k), v.lowest_name, v.lowest)
            lowest = lowest .. lowest_add
        end
    end
    
    if #compare == 2 then
        infobox:insert("Results", text)
        
    else
        infobox:insert("Highest", highest, true)
        infobox:insert("Lowest", lowest, true)
    end
    
    return infobox
end

function Character:get_compare_name()
    return util.text.remove_parentheses(self:get_name())
end

function Character:get_compare_result_name()
    return util.text.remove_parentheses(self:get_name())
end

function Character:get_compare_mod()
    local field = self:get_field_stats_name()
    
    if field == "Stats" then
        return self:get_mod()
        
    else
        local mod = self:get_mod()
        
        if mod == nil or #mod == 0 then
            return field
            
        else
            return field .. self:get_mod()
        end
    end
end

----------------------------------------------------------
-- Averages
----------------------------------------------------------
function Character:calc_averages(base, args)
    args = args or {}

    local calculator = self.avg:set_character(self)

    for k, v in pairs(args) do
        calculator[k] = v
    end

    base = calculator:calculate(base, self:get_lvl(), self.lvl, self.job_averages)
    return base
end

-- Averages more suited for games without reclassing
function Character:calc_averages_classic(base)
    local growth = self:final_growth()
    
    local current_lvl = self:get_lvl()
    local last_job
    
    for i, lvl in ipairs(self.lvl) do
        job = self.job_averages[i]
        
        -- reset level and class promo bonuses if it's not the first class
        if i ~= 1 then
            current_lvl = 1
            
            base = base + self:get_promo_bonus(last_job, job)
        end
        
        local lvl_diff = math.max(0, lvl - current_lvl)
        
        current_lvl = math.max(current_lvl, lvl)
        
        if lvl_diff > 0 then
            local function step(v1, v2)
                v2 = util.round(v2 / 100)
                v2 = util.round(v2 * lvl_diff)
                
                v1 = util.round(v1 + v2)
                
                return v1
            end
            
            base = util.math.mod_stats(step, base, growth)
            
        end
        
        base = util.math.cap_stats(base, job:get_cap())
        
        last_job = job
    end
    
    base.con = self.data.base.con + self.job.data.base.con 
    base.mov = self.job.data.base.mov
    
    return base
end

-- Averages classes are organized pre-setup
function Character:averages_organize()
    -- add base class
    table.insert(self.job_averages, 1, self:get_base_class())
    
    -- add current class at the end if it's different
    if self:is_changed("class") then
        table.insert(self.job_averages, self.options.class)
    end
    
    -- add character promos if lvl is higher
    if self:get_promo() then
        local promo = self:get_promo()
        
        for i, p in ipairs(promo) do
            if #self.lvl > #self.job_averages then
                table.insert(self.job_averages, p)
            end
        end
        
    end
    
    -- get their tables if they are strings
    for i, p in ipairs(self.job_averages) do
        if type(p) == "string" then
            self.job_averages[i] = self.Job:new(p)
        end
    end
    
    while #self.job_averages > #self.lvl do
        table.insert(self.lvl, 1)
    end
    
    -- add last class promo first
    while #self.lvl > #self.job_averages do
        local last_job = self.job_averages[#self.job_averages]
        
        if last_job:can_promo() then
            table.insert(self.job_averages, self.Job:new(last_job:get_promo()))
        
        else
            break
        end
    end
    
    -- add class promotions if they're missing
    local already_checked = {}
    
    while #self.lvl > #self.job_averages do
    
        local function try_finding_promo()
        
            for i, job in ipairs(self.job_averages) do
                
                if already_checked[job] == nil then
                    already_checked[job] = true
                    
                    if job:can_promo() then
                        table.insert(self.job_averages, i + 1, self.Job:new(job:get_promo()))
                        return true
                    end
                    
                end
            end
            
            return false
        end
        
        -- temp remove this
        --local promo_found = try_finding_promo()
        local promo_found = false
        
        -- If no promo is found just add the last class again
        if not promo_found then
            table.insert(self.job_averages, self.Job:new(self.job_averages[#self.job_averages]))
        end
    end
    
    -- Change's main class if none has been passed
    self.options.class = self.job_averages[#self.job_averages]
    
    --[[
    local testing = {}
    for i, p in pairs(self.job_averages) do table.insert(testing, p.id) end
    
    util.inspect(self.lvl)
    util.inspect(testing)
    --]]
end

function Character:get_promo()
    if self.data.promo then
        local promo = self.data.promo
        
        if type(promo) ~= "table" then
            local new = {}
            table.insert(new, promo)
            
            promo = new
        end
        
        if #promo > 0 then
            return promo
        end
    end
end

function Character:get_base_class()
    return self.data.job
end

function Character:get_lvl()
    return self.data.lvl
end

-----------------------------
-- Bases functions
-- Their uses are as follows:
-- Show: Convert the already calculated stats to a fancy string
-- Final Base: add class stats here too
-- Calc Base: Averages go here
-- Get Base: Raw base, and calculate ones for children units and the like
function Character:show_base()
    local base = self:final_base()
    
    if not self.personal then
        base = util.math.cap_stats(base, self:final_cap(), {bold = true, higher = true})
    end
    
    local text = util.table_stats(base)
    
    if self.job:can_dismount() then
        text = text .. "\n" .. self.job:show_dismount()
    end
    
    return text
end

function Character:final_base()
    local base = self:calc_base()
    
    -- For reclass games
    if not self.average_classic then
        if self.helper_job_base and not self:is_personal() then
            base = util.math.add_stats(base, self.job:get_base())
        end
    
    -- Non reclass games
    else
        -- Apply base class stats
        local job = self.data.job
        if self:is_changed("class") then job = self.job else job = self.Job:new(self.data.job) end
        
        base = base + job:get_base()
        
        if self:has_averages() then
            base = self:calc_averages_classic(base)
        end
        
        if self.personal then
            base = base - job:get_base()
        end
    end
    
    base = self:common_base(base)
    
    return base
end

function Character:common_base(base)
    if not self:is_personal() then
        base = util.math.rise_stats(base, 0)
        base = util.math.cap_stats(base, self:final_cap())
    end
    
    if self:has_item() and (#self.item == 0 or self:is_compare()) then
        local item = self.item
        
        if #item > 0 then
            item = item[#item]
        end
        
        if item:has_bonus() then
            item:apply_bonus(base)
        end
    end
    
    if self.modifiers then
        self:apply_modifiers(base)
    end
    
    return base
end

function Character:apply_modifiers(base)
    for key, value in pairs(self.modifiers.add) do
        if base[key] ~= nil then
            base[key] = value + base[key]
        end
    end
    
    for key, value in pairs(self.modifiers.equal) do
        if base[key] ~= nil then
            base[key] = value
        end
    end
end

function Character:calc_base()
    local base = self:get_base()

    if not self.average_classic and self:has_averages() then
        base = self:calc_averages(base)
    end

    return base
end

function Character:get_base()
    local base = util.copy(self.data.base)
    setmetatable(base, util.math.Stats)
    
    return base
end

-----------------------------
-- Growths functions
-- Same as above
function Character:show_growth()
    if self.allow_show_growth then
        return util.table_stats(self:final_growth(), {value_end = "%"})
    end
end

function Character:final_growth()
    local growth = self:calc_growth()
    
    if self.helper_job_growth and not self:is_personal() then
        growth = growth + self.job:get_growth()
    end
    
    if not self:is_personal() then
        growth = util.math.rise_stats(growth, 0)
    end
    
    return growth
end

function Character:calc_growth()
    return self:get_growth()
end

function Character:get_growth()
    local growth = util.copy(self.data.growth)
    setmetatable(growth, util.math.Stats)
    
    return growth
end

-----------------------------
-- Cap functions
-- Yeah
function Character:show_cap()
    if self.allow_show_cap then
        return util.table_stats(self:final_cap())
    end
end

function Character:final_cap()
    local cap = self:calc_cap()
    
    if self.helper_job_cap and not self:is_personal() then
        cap = cap + self.job:get_cap()
    end
    
    return cap
end

function Character:calc_cap()
    return self:get_cap()
end

function Character:get_cap()
    if self.data.cap then
        local cap = util.copy(self.data.cap)
        setmetatable(cap, util.math.Stats)
        
        return cap
        
    else
        return {}
    end
end

------------------------------
-- Unit modifiers
function Character:get_mod()
    local text = self:get_lvl_mod()

    text = text .. self:common_mods()
    
    return text
end

function Character:get_lvl_mod()
    local text = ""
    
    if self.job then
        if not self:has_averages() then
            local base_job = self.Job:new(self:get_base_class())
            
            if self.helper_job_reset and self.job.id ~= base_job.id and (not self.helper_reset_promo or self.job:is_promoted() ~= base_job:is_promoted()) then
                text = text .. string.format("**Lv. %s/1** %s", self:get_lvl(), self.job:get_name())
                
            else
                text = text .. string.format("**Lv. %s** %s", self:get_lvl(), self.job:get_name())
            end
            
        else
            local current_lvl = self:get_lvl()
            local separator = " **=>** "
            local promoted
            
            for i, lvl in ipairs(self.lvl) do
                job = self.job_averages[i]
                
                if self.helper_job_reset then
                    if i ~= 1 then
                        if not self.helper_reset_promo or promoted ~= job:is_promoted() then
                            current_lvl = 1
                            promoted = job:is_promoted()
                        end
                        
                    else
                        promoted = job:is_promoted()
                    end
                end
                
                lvl = math.max(current_lvl, lvl)

                -- Text
                local add = string.format("Lv. %s", current_lvl)

                if current_lvl ~= lvl then
                    add = add .. string.format(" - Lv. %s", lvl)
                end

                add = util.text.bold(add)
                add = add .. string.format(" %s %s", job:get_name(), separator)
                
                text = text .. add
                current_lvl = lvl
            end
            
            text = text:sub(1, (#separator * -1) + -1)
        end
    end
    
    return text
end

-- Common mods used by pretty much everything
function Character:common_mods()
    local text = ""

    if self:is_personal() then
        text = text .. "\n*Personal Stats*"
    end
    
    if self:has_item() and (#self.item == 0 or self:is_compare()) then
        local item = self.item
        
        if #item > 0 then
            item = item[#item]
        end
        
        text = text .. string.format("\n%s%s", util.emoji.global:get("weapon"), item:get_name())
    end
    
    if self.modifiers then
        text = text .. "\n`Modifiers`"
        
        if self.modifiers.add then
            text = text .. " " .. util.table_stats(self.modifiers.add, {
                                        key_start = "`",
                                        between = "+",
                                        value_end = "`",
                                        separator = " "})
        end
        
        if self.modifiers.equal then
            text = text .. " " .. util.table_stats(self.modifiers.equal, {
                                        key_start = "`",
                                        between = "=",
                                        value_end = "`",
                                        separator = " "})
        end
    end

    return text
end

------------------------------
-- Portrait

-- Path to the portrait file
function Character:get_portrait()
    if self.helper_portrait and self.data.portrait then
        return self.helper_portrait .. "/" .. self.data.portrait
    end
end

------------------------------
-- Misc
function Character:show_promo()
    local promo = self:get_promo_list()
    
    if not self.minimal and promo ~= nil and self.job then
        local result = {}
        setmetatable(result, util.ordered_table)
        
        local job = self.job
        local skill
        
        if self.allow_promo_skill then
            skill = self:get_skill() or {}
        end
        
        for i, pair in ipairs(promo) do
            local promoted = self.Job:new(pair)
            
            local bonus = self:get_promo_bonus(job, promoted)
            
            -- Stats
            local text = util.table_stats(bonus, {value_start = "+"})
            
            -- Rank
            local rank = self:get_rank_bonus(job, promoted)
            
            if #rank > 0 then
                text = rank .. "\n" .. text
            end
            
            -- Skill
            if self.Skill and self.allow_promo_skill then
                local promoted_skill = promoted:get_skill() or {}
                
                local add = ""
                
                for i, pair in ipairs(promoted_skill) do
                    if not util.value_in_table(skill, pair) then
                        local current = self.Skill:new(pair)
                        local emoji = current:get_emoji()
                        
                        if emoji == "" then
                            emoji = string.format("*%s* ", current:get_name())
                        end
                        
                        add = add .. emoji
                        
                        if self.promo_progressive then
                            table.insert(skill, pair)
                        end
                    end
                end
                
                if #add > 0 then
                    text = add .. text
                end
            end
            
            -- Caps
            if self.promo_job_cap then
                text = text .. "\n**Caps**\n" .. promoted:show_cap()
            end
            
            if promoted:can_dismount() then
                text = text .. "\n" .. promoted:show_dismount()
            end
            
            -- Result
            result[promoted:get_name()] = text
            
            if self.promo_progressive then
                job = promoted
            end
        end
        
        return result
    end
end

function Character:get_rank_bonus(job1, job2)
    local rank1 = job1:get_rank()
    local rank2 = job2:get_rank()
    
    self:apply_rank_mods(rank1)
    self:apply_rank_mods(rank2)
    
    local text = ""
    
    for key, value in pairs(rank2) do
        local add
        
        if self.promo_rank_negative and rank1[key] ~= nil then
            local total = value - rank1[key]
            
            if total > 0 then
                add = string.format("+%s", total)
            end
            
        else
            if self.rank_exp then
                add = util.text.rank_letter(self.rank_exp, value, false)
                
            else
                add = tostring(value)
            end
        end
        
        if add then
            if self.pack then
                add = self.pack:get(key, string.format("**%s:** ", util.title(key))) .. add
            end
            
            text = text .. add .. " "
        end
    end
    
    return text
end

function Character:apply_rank_mods(rank) end

function Character:get_promo_bonus(job1, job2)
    local promo
    
    local job1_base = job1:get_base()
    local job2_base = job2:get_base()
    
    if self.promo_use_fixed then
        promo = job2:get_promo_bonus()
        
        for i, pair in ipairs(self.promo_use_negative) do
            if job2_base[pair] ~= nil then
                promo[pair] = job2_base[pair] - job1_base[pair]
            end
        end
    
    else
        promo = util.math.sub_stats(job2:get_base(), job1:get_base())
    end
    
    if self.promo_remove_hp then
        promo.hp = nil
    end
    
    promo = util.math.remove_zero(promo)
    
    return promo
end

function Character:get_promo_list()
    if self.data.promo then
        if type(self.data.promo) == "string" then
            return {self.data.promo}
            
        elseif type(self.data.promo) == "table" 
        and #self.data.promo > 0 then
            return self.data.promo
        end
    end
end

function Character:show_rank() end
function Character:show_skill()
    if self.Skill and self:get_skill() ~= nil then
        local text = ""
        
        for i, pair in ipairs(self:get_skill()) do
            text = text .. self.Skill:new(pair):get_fancy() .. "\n"
        end
        
        return text
    end
end

function Character:get_skill()
    if self.data.skill then
        if type(self.data.skill) == "string" then
            return {self.data.skill}
            
        elseif type(self.data.skill) == "table" and #self.data.skill > 0 then
            return util.copy(self.data.skill)
        end
    end
end

function Character:apply_item_bonus(item, stats) end

function Character:get_field_stats_name()
    return "Stats"
end

function Character:is_personal()
    if self.personal == nil then
        return false

    else
        return self.personal
    end
end

function Character:get_name()
    return self.data.name
end

function Character:is_compare()
    return (self.compare and #self.compare > 0) or self._compare
end

function Character:has_averages()
    return (#self.lvl > 0 or #self.job_averages > 0)
end

function Character:has_item()
    return (self.inventory and self.item)
end

return Character
