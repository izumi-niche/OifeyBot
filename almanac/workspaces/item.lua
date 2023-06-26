local almanac = require("almanac.core")

local util = require("almanac.util")

local Workspace = almanac.Workspace
local Infobox = almanac.Infobox

local Item = {}

Item.__index = Item
setmetatable(Item, Workspace)

-- Add equip/stats to data if it doesn't exist
function Item:raw(entry, section)
    local entry = Workspace.raw(self, entry, section)
    
    if entry.data.stats == nil then
        entry.data.stats = {}
    end
    
    if entry.data.equip == nil then
        entry.data.equip = {}
    end
    
    if entry.data.stats == nil then
        entry.data.stats = {}
    end
    
    return entry
end

-- Show
function Item:show()
    local infobox = Infobox:new({title = self:get_name(), desc = self:show_item()})
    
    if not self:is_changed() then
        self:apply_reference(infobox)
    end
    
    return infobox
end

function Item:apply_reference(infobox)
    if self.data.reference then
        for key, value in pairs(self.data.reference) do
            infobox:insert(key, value, true)
        end
    end
end

function Item:show_item()
    local new = self:get_stats_raw()
    
    local start = ""
    local final = "\n"
    
    -- Type and Rank Display
    if new.rank ~= nil then
        start = string.format("%s %s | ", util.title(self.data.type), util.title(new.rank))
        
        -- Apply emoji if it exists
        if self.pack then
            start = self.pack:get(new.rank, "") .. start
        end
        
        new.rank = nil
    else
        start = string.format("%s | ", util.title(self.data.type))
    end
    
    -- Desc
    if self.data.desc then
        final = final .. self.data.desc .. "\n"
    end
    
    -- Prices
    for i, price in ipairs({"price", "price per use", "sell"}) do
        if new[price] then
            -- Only display prices if has no changes
            if not self:is_changed() then
                final = final .. string.format("\n**%s**: %sG", util.title(price), new[price])
            end
            
            new[price] = nil
        end
    end
    
    return start .. util.table_stats(new, {order = "item"}) .. final
end

-- Stats
function Item:get_stats_raw()
    local stats = util.copy(self.data.stats)
    
    return stats
end

function Item:get_stats()
    local raw = self:get_stats_raw()
    
    local stats = self:stats_meta(raw)
    
    return stats
end

function Item:stats_meta(stats)
    local t = {}
    
    t.__index = function(tbl, key)
        if stats[key] ~= nil then
            return stats[key]
            
        else
            return 0
        end
    end
    
    setmetatable(t, t)
    return t
end

-- Equip
local magic_values = {"tome", "magic", "white", "black", "wind", "fire", "thunder",
                              "dark", "light", "anima", "scroll"}

function Item:is_magic()
    if self.data.equip.magical ~= nil then
        return self.data.equip.magical
        
    else
        return util.value_in_table(magic_values, self.data.type)
    end
end

function Item:is_weapon()
    return self.data.weapon
end

function Item:is_effective()
    if self.data.equip.effective then
        return self.data.equip.effective
        
    else
        return false
    end
end

function Item:has_bonus()
    return (self.data.equip.stats ~= nil)
end

function Item:apply_bonus(base)
    for key, value in pairs(self.data.equip.stats) do
        base[key] = base[key] + value
    end
end

function Item:is_fixed_dmg()
    if self.data.equip.fixed_dmg then
        return self.data.equip.fixed_dmg
        
    else
        return false
    end
end

-- Misc
function Item:get_name()
    return self.data.name
end

return Item