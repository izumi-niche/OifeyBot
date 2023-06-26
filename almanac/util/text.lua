local module = {}
local misc = require("almanac.util.misc")

---------------
-- String functions to make some stuff easier
function module.title(s)
    function helper(first, rest)
        return first:upper() .. rest:lower()
    end
    
    local text = s:gsub("(%a)([%w_']*)", helper)
    
    if text == "Hp" then
        text = "HP"
    
    elseif text == "Sp" then
        text = "SP"
    end
    
    return text
end

function module.bold(s)
    return "**" .. s .. "**"
end

function module.italics(s)
    return "*" .. s .. "*"
end

---------------
-- Table to text
module.order = {
    stats = {"hp", "atk", "str", "mag", "dex", "skl", "spd", "lck", "wlv", "def", "res", "cha", "bld", "con", "wt", "sight", "vision", "mov", "bst", "eff", "as", "hit", "crit", "avo", "ddg"},
    equip = {"atk", "def", "eff", "as", "hit", "crit", "avo", "ddg", "avoid", "dodge"},
    item = {"rank", "mt", "hit", "wt", "crit", "avo", "ddg", "range", "rng", "uses"}
}
uppercase_key = {"Hp", "As"}

module.code_default = false

for i, p in ipairs(uppercase_key) do uppercase_key[p] = true end

function module.display_order(tbl, order)
    local result = {}
    
    -- add keys that already exist
    for i, key in ipairs(order) do
        if tbl[key] ~= nil then
            table.insert(result, key)
        end
    end
    
    -- add keys that don't exist last
    for key, value in pairs(tbl) do
        if not misc.value_in_table(order, key) then
            table.insert(result, key)
        end
    end
    
    return result
end

function module.stat_order(tbl, order)
    return module.display_order(tbl, module.order.stats)
end

function module.table_stats(t, args)
    args = args or {}
    
    local between = args.between or " "
    local separator = args.separator or " | "
    
    local code = args.code or module.code_default
    
    local order = args.order or module.order.stats
    
    if type(order) == "string" then
        order  = module.order[order]
    end
    
    local keys = {}
    local set_keys = {}
    
    -- Add order keys first
    for _, k in ipairs(order) do
        if type(t[k]) ~= "nil" then
            table.insert(keys, k)
            set_keys[k] = true
        end
    end
    
    -- Add missing keys later on whatever order
    -- Raise warning if there's more than one unordered
    local missing = 0
    
    for k, p in pairs(t) do
        if not set_keys[k] then
            table.insert(keys, k)
            set_keys[k] = true
            
            missing = missing + 1
        end
    end
    
    if missing >= 2 and getmetatable(t) ~= misc.ordered_table then
        print("Unordered keys!", t)
    end
    
    -- text stuff here
    local text = ""
    
    for _, k in ipairs(keys) do
        local p = t[k]
        
        local function clean(s)
            s = tostring(s)
            s = module.title(s)
            
            -- make some stats not look ugly
            if uppercase_key[s] then
                s = string.upper(s)
            end
            
            return s
        end
        
        local function check(s, key_name)
            s = clean(s)
            local c = key_name .. "_end"
            
            if args[c] then
                s = s .. args[c]
            end
            
            c = key_name .. "_start"
            
            if args[c] then
                s = args[c] .. s
            end
            
            return s
        end
        
        text = text .. check(k, "key") .. between .. check(p, "value") .. separator
        
        text = text:gsub("%+%-", "-")
    end
    
    text = string.sub(text, 1, (string.len(separator) * -1) + -1)
    
    if code then
        text = "`" .. string.gsub(text, "%*", "") .. "`"
    end
    
    return text
end

----------------
local fancy_stats_keys = {
    hp = "HP",
    atk = "attack",
    str = "strength",
    mag = "magic",
    spd = "speed",
    def = "defense",
    res = "resistance",
    skl = "skill",
    dex = "dexterity",
    lck = "luck",
    bld = "build",
    mov = "movement",
    cha = "charm",
    as = "attack speed",
    avo = "avoid",
    ddg = "dodge",
    eff = "effective attack",
    wt = "weight"
}

function module.fancy_stat(key)
    if fancy_stats_keys[key] ~= nil then
        return fancy_stats_keys[key]
        
    else
        return key
    end
end
--------------------
-- Remove text between ()
function module.remove_parentheses(text)
    local start = string.find(text, " (", 1, true)
    
    if start ~= nil then
        text = text:sub(1, start)
    end
    
    return text
end
----------------
-- Weapon ranks
function module.weapon_no_rank(tbl, args)
    args = args or {}
    
    local separator = args.separator or "\n"
    
    text = ""
    
    for i, p in ipairs(tbl) do
        text = module.title(p) .. "\n"
    end
    
    return text
end

function module.rank_letter(tbl, value, progress)
    -- ignore strings
    if type(value) == "string" then
        return value
    end
    
    local result
    local result_value = -1
    
    if progress == nil then progress = true end
    
    for k, p in pairs(tbl) do
        if value >= p and p > result_value then
            result = k
            result_value = p
        end
    end
    
    if progress and result ~= nil then
        local next_rank = 9999
        
        for k, p in pairs(tbl) do
            if p > result_value and next_rank > p then
                next_rank = p
            end
        end
        
        if next_rank ~= 9999 then
            local total = next_rank - result_value
            local progress_value = value - result_value
            
            result = result .. string.format(" (%s/%s)", progress_value, total)
        end
    end
    
    return result
end

function module.weapon_rank(tbl, args)
    args = args or {}
    
    args.exp = args.exp or false
    
    local text = ""
    
    for k, v in pairs(tbl) do
        local key = k
        local value = v
        
        key = module.title(key)
        key = module.bold(key)
        
        if args.exp then
            value = module.rank_letter(args.exp, value, args.progress)
        end
        
        local add = string.format("%s: %s\n", key, value)
        
        if args.pack ~= nil then
            add = args.pack:get(k, "") .. add
        end
        
        text = text .. add
    end
    
    return text
end

return module