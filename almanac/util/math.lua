local misc = require("almanac.util.misc")

local module = {}

-- Proper roundng
-- Best option is transforming into a string with format, then changing it back with tonumber
-- Need for a lot of stuff, even for math.floor and math.ciel
-- i love floats
function module.round(f)
    local result = string.format("%.2f", f)
    
    return tonumber(result)
end

-- Proper rounding helper for floor and ceil
function module.floor(f)
    return math.floor(module.round(f))
end

function module.ceil(f)
    return math.ceil(module.round(f))
end

function module.round_closest(f)
    f = module.round(f)
    f = f + 0.5

    return module.floor(f)
end

-- Declare early
local Stats = {}

-- Do stuff with all keys in stats
-- Returns a new table instead of changing the existing one
function module.mod_stats(func, base, mod, args)
    args = args or {}

    -- keys to ignore
    local ignore = args.ignore or {}
    
    for i, p in ipairs(ignore) do
        ignore[p] = true
    end
    
    local function check(value)
        return (not ignore[value])
    end
    
    -- custom check
    local custom_check = args.check or function(stat, v1, v2) return true end
    
    -- ignore bools
    local function get_bool(key)
        if args[key] ~= nil then
            return args[key]
            
        else
            return true
        end
    end
    
    local ignore_missing = args.ignore_missing or false
    local ignore_existing = args.ignore_existing or false
    local ignore_unchanged = args.ignore_unchanged or false
    
    -------------------------------------
    local result = {}
    setmetatable(result, Stats)
    
    -- If it's a number, use that number for all keys
    if type(mod) == "number" then
        for k, v in pairs(base) do
            result[k] = func(v, mod)
        end
    
    -- Table
    else
        -- First using the existing keys
        for k, v in pairs(base) do
            
            if check(k) and not ignore_existing and mod[k] ~= nil and custom_check(k, v, mod[k]) then
                result[k] = func(v, mod[k])
                
            elseif not ignore_unchanged then
                result[k] = v
            end
        end
        
        -- Now the only ones in mod
        if not ignore_missing then
            for k, v in pairs(mod) do
                if check(k) and base[k] == nil and custom_check(k, 0, v) then
                    local r = func(0, v)
                    
                    if (not ignore_unchanged) or (ignore_unchanged and r ~= 0) then
                        result[k] = r
                    end
                end
            end
        end
    end
    
    return result
end

---------------------------------
function module.add_stats(v1, v2, args)
    return module.mod_stats(function(x, y) return x + y end, v1, v2, args)
end

function module.sub_stats(v1, v2, args)
    return module.mod_stats(function(x, y) return x - y end, v1, v2, args)
end

function module.rise_stats(v1, v2, args)
    return module.mod_stats(math.max, v1, v2, args)
end

function module.multi_stats(v1, v2, args)
    return module.mod_stats(function(x, y) return x * y end, v1, v2, args)
end

function module.growth_stats(v1, v2, lvl, args)
    local function step(v1, v2)
        v2 = v2 / 100
        v2 = v2 * lvl
        
        return module.floor(v1 + v2)
    end
    
    return module.mod_stats(step, v1, v2, args)
end

function module.cap_stats(v1, v2, args)
    args = args or {}
    
    local bold = args.bold or false
    local higher = args.higher or false 
    
    -- not using math.min just because of the bold
    local function cap(x, y)
        if x >= y then
            local value
            
            if higher then
                value = x
                
            else
                value = y
            end
            
            if bold then
                value = string.format("**%s**", value)
            end
            
            return value
        else
            return x
        end
    end
    
    return module.mod_stats(cap, v1, v2, args)
end

function module.remove_zero(tbl)
    local result = {}
    setmetatable(result, Stats)

    for key, value in pairs(tbl) do
        if value ~= 0 then
            result[key] = value
        end
    end

    return result
end

function module.floor_stats(tbl)
    for key, value in pairs(tbl) do
        if type(value) == "number" then
            tbl[key] = module.floor(value)
        end
    end
end

function module.affinity_calc(aff1, aff2, level, round_up)
    level = level or 1
    
    local round = module.floor
    if round_up then round = module.ceil end
    
    local result = {}
    
    local function add(aff)
        for key, value in pairs(aff) do
            value = value * level
            
            if result[key] == nil then
                result[key] = value
                
            else
                result[key] = result[key] + value
            end
        end
    end
    
    add(aff1)
    add(aff2)
    
    for key, value in pairs(result) do
        result[key] = round(value)
    end
    
    return module.remove_zero(result)
end

---------------------------------
-- Inventory
-- For item or/and skill equips
local Inventory = {}
Inventory.__index = Inventory
module.Inventory = Inventory

Inventory.allow_negative = {}

Inventory.eff_multiplier = 3
-- If true it doubles the weapon might, false double the total attack
Inventory.eff_might = true

function Inventory:new()
    local obj = {}
    setmetatable(obj, self)
    
    obj.item_func = {}
    
    return obj
end

function Inventory:use_as_base()
    local obj = Inventory:new()
    
    obj.item_func = {}
    
    for i, p in ipairs(self.item_func) do
        table.insert(obj.item_func, {name = p.name, func = p.func})
    end
    
    return obj
end

function Inventory:get_calc(key)
    for i, p in ipairs(self.item_func) do
        if p.name == key then
            return p
        end
    end
end

function Inventory:item_calc(name, func)
    local t = {
        name = name,
        func = func
    }
    
    table.insert(self.item_func, t)
end

function Inventory:set_unit(character)
    -- create a new table that goes to this one to use the same stat calcs
    local obj = misc.dummy_table(self)
    
    -- unit table that is just character
    local unit = misc.dummy_table(character)
    
    obj.unit = unit
    
    return obj
end

function Inventory:equip_item(item)
    -- only contains info about unit and item
    -- can contain more stuff in the future if necessary
    local data = {
        unit = self.unit,
        item = dummy_table(item)
    }
    
    data.unit.stats = data.unit:final_base()
    
    -- floor stats because of averages
    for key, value in pairs(data.unit.stats) do
        data.unit.stats[key] = module.floor(data.unit.stats[key])
    end
    
    -- apply item bonuses
    if item:has_bonus() and not(#data.unit.item == 0 or data.unit:is_compare()) then
        item:apply_bonus(data.unit.stats)
    end
    
    -- Treat unit's str/mag/atk as 0 if it's fixed damage
    if item:is_fixed_dmg() then
        data.unit.stats.str = 0
        data.unit.stats.mag = 0
        data.unit.stats.atk = 0
    end
    
    data.item.stats = data.item:get_stats()
    
    -----------------------
    local stats = {}
    setmetatable(stats, misc.ordered_table)
    
    data.result = stats
    
    local multipler = item.data.equip.eff_multiplier or self.eff_multiplier
    
    for i, tbl in ipairs(self.item_func) do
        local r = tbl.func(data, data.unit, data.item)
        
        if type(r) == "number" and not misc.value_in_table(self.allow_negative, tbl.name) then
            r = math.max(r, 0)
        end
        
        stats[tbl.name] = r
        
        -- Effective Damage
        if tbl.name == "atk" and item:is_effective() then
            -- Increase might
            if self.eff_might then
                local old_mt = data.item.stats.mt
                data.item.stats.mt = old_mt * multipler
                
                stats["eff"] = math.max(tbl.func(data, data.unit, data.item), 0)
                
                data.item.stats.mt = old_mt
            
            -- Increase Total ttack
            else
                stats["eff"] = math.max(stats.atk * multipler, 0)
            end
        end
        
        --print(tbl.name, r)
    end
    
    -- Apply unit bonuses
    data.unit:apply_item_bonus(data.item, stats)
    
    -- Apply modifiers
    -- Ignore atk if unit also has it
    if data.unit.modifiers then
        if stats.atk ~= nil and data.unit.stats.atk ~= nil then
            local old_atk = stats.atk
            
            data.unit:apply_modifiers(stats)
            
            stats.atk = old_atk
            
        else
            data.unit:apply_modifiers(stats)
        
        end
    end
    
    local result = {}
    result.stats = stats
    
    return result
    
end
---------------------------------
-- Stats meta table
module.Stats = Stats

function Stats.__add(v1, v2)
    return module.add_stats(v1, v2)
end

function Stats.__sub(v1, v2)
    return module.sub_stats(v1, v2)
end

function Stats.__mul(v1, v2)
    return module.multi_stats(v1, v2)
end

function Stats.__call()
    local obj = {}
    setmetatable(obj, Stats)
    
    return obj
end
 
Stats.__pairs = misc.ordered_table.__pairs
Stats.__newindex = misc.ordered_table.__newindex

---------------------------------
-- Averages
local Averages = {}
Averages.__index = Averages
module.Averages = Averages

-- If to reset the level after the first class change
Averages.reset_level = true
-- Double class growths
Averages.double_class_growths = false

local misc = require("almanac.util.misc")

function Averages:new(args)
    local obj = {}
    setmetatable(obj, self)
    
    args = args or {}
    
    return obj
end

function Averages:set_character(character)
    local obj = misc.dummy_table(self)
    
    local character = misc.dummy_table(character)
    
    obj.character = character
    
    return obj
end

function Averages:calculate(base, current_lvl, lvls, jobs)
    local stats = {
        base = base,
        growth = self.character:calc_growth(),
        cap = self.character:calc_cap()
    }
    
    local add_check = {"growth", "cap"}
    
    if not self.character.average_rise_stat then
        table.insert(add_check, 1, "base")
    end
    
    local promoted
    
    -- for some reason fe4 brigid gets one additional level sometimes
    -- weird
    while #lvls > #jobs do
        table.remove(lvls, #lvls)
        
        print("LVL SEQUENCE BIGGER THAN JOB SEQUENCE:", self.character.id)
    end
    
    for i, lvl in ipairs(lvls) do
        local job = jobs[i]
        
        if self.character.helper_job_reset then
            if i ~= 1 then
                if not self.character.helper_reset_promo or promoted ~= job:is_promoted() then
                    current_lvl = 1
                    promoted = job:is_promoted()
                end
                
            else
                promoted = job:is_promoted()
            end
        end
        
        local job_stats = {
            base = job:get_base()
        }

        --------------------
        if self.character.helper_job_growth then
            job_stats.growth = job:get_growth()
        end

        if self.character.helper_job_cap then
            job_stats.cap = job:get_cap()
        end

        ------------------------
        -- Double class growths
        if self.double_class_growths then
            job_stats.growth = job_stats.growth * 2
        end
        
        -- Rise bases if it's not first loop
        if self.character.average_rise_stat and i > 1 then
            stats.base = module.rise_stats(stats.base, job_stats.base)
        end
        
        -- Add class bases/growths/caps if necessary
        for _, p in pairs(add_check) do
            if self.character["helper_job_" .. p] then
                stats[p] = stats[p] + job_stats[p]
            end
        end
        
        ---------------------------------------------
        --print(job.id, lvl - current_lvl, lvl, current_lvl)
        
        local lvl_diff = math.max(0, lvl - current_lvl)
        current_lvl = math.max(current_lvl, lvl)
        
        if lvl_diff > 0 then
            local function step(v1, v2)
                -- ignore if growth is 0 or negative
                if 0 >= v2 then return v1 end
                
                v2 = module.round(v2 / 100)
                v2 = module.round(v2 * lvl_diff)
                
                v1 = module.round(v1 + v2)
                
                return v1
            end
            
            stats.base = module.mod_stats(step, stats.base, stats.growth)
            
            stats.base = module.cap_stats(stats.base, stats.cap)
        end
        
        ---------------------------------------------
        -- Remove class bases/growths/caps if necessary
        for _, p in pairs(add_check) do
            if self.character["helper_job_" .. p] then
                stats[p] = stats[p] - job_stats[p]
            end
        end
        
    end
    
    return stats.base
end

return module
