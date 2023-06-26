-------------------------------------
-- Ordered metatable
-------------------------------------
local ordered_table = {}

function ordered_table.__newindex(t, k, v)
    if v ~= nil then
        if t[k] == nil then
            rawset(t, #t + 1, k)
        end
        
        rawset(t, k, v)
        
    else
        for i, p in ipairs(t) do
            if p == k then
                table.remove(t, i)
                
                rawset(t, k, nil)
                
                return
            end
        end
    end
end

-- remove invalid keys
local function filter_invalid(t)
    local rm = {}
    
    for i=1, #t do
        local key = rawget(t, i)
        
        if rawget(t, key) == nil then
            table.insert(rm, key)
        end
    end
    
    for _, p in ipairs(rm) do
        ordered_table.__newindex(t, p, nil)
    end
 end
 
function ordered_table.__pairs(t)
    filter_invalid(t)
    
    local i = 1
    
    local function iter(t, k)
        k = t[i]
        i = i + 1
        
        local v = t[k]
        
        if v ~= nil then return k,v end
    end
    
    local function old_iter(t, k)
        local v
        
        k, v = next(t, k)
        
        if nil~=v then return k,v end
    end
    
    if t[1] then
        return iter, t, nil
    else
        return old_iter, t, nil
    end
end

function ordered_table.__index(tbl, key)
    filter_invalid(tbl)
    
    if type(key) == "number" and key < 0 then
        local value = rawget(tbl, #tbl + 1 + key)
        
        return value
    end
    
    return nil
end
-------------------------------------
-- Dummy metatable
-------------------------------------
function dummy_table(tbl)
    local obj = {}
    obj.__index = tbl
    setmetatable(obj, obj)
    
    return obj
end

-------------------------------------
-- shallow copy
-------------------------------------
function copy(tbl)
    local new = {}
    
    if getmetatable(tbl) then
        setmetatable(new, getmetatable(tbl))
    end
    
    for key, pair in pairs(tbl) do
        new[key] = pair
    end
    
    return new
end
--------------------------------------
-- debug jank
--------------------------------------
local _inspect = require("almanac.lib.inspect")

function inspect(tbl)
    print(_inspect(tbl, {depth = 2}))
end

--------------------------------------
-- other jank
--------------------------------------
function value_in_table(tbl, k)
    for i, p in ipairs(tbl) do
        if p == k then
            return true

        end
        
    end
    
    return false
end

-- if table is not empty in anyway
function table_has(tbl)
    return not(next(tbl) == nil)
end

function table_merge(tbl1, tbl2)
    local result = {}
    
    local function add(data)
        for i, pair in ipairs(data) do
            if not value_in_table(result, pair) then
                table.insert(result, pair)
            end
        end
    end
    
    add(tbl1)
    add(tbl2)
    
    return result
end

function table_size(tbl)
    local result = 0
    
    for key, value in pairs(tbl) do
        if type(key) ~= "number" then
            result = result + 1
        end
    end
    
    return result
end

return {
    ordered_table = ordered_table,
    dummy_table = dummy_table,
    copy = copy,
    inspect = inspect,
    value_in_table = value_in_table,
    table_has = table_has,
    table_merge = table_merge,
    table_size = table_size
}
