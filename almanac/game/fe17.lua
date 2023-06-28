local almanac = require("almanac")
local workspaces = almanac.workspaces

local util = almanac.util

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local pack = util.emoji.get("database/fe17/emoji.json")
local global_pack = util.emoji.global

local Character = {}
local Job = {}
local Ring = {}
local Item = {}
local Skill = {}
local Engrave = {}

---------------------------------------------------
-- Inventory --
---------------------------------------------------
local inventory = util.math.Inventory:new()

-- TODO: Move engage weapons to their own thing
local function inventory_atk(data, unit, item)
    if item.id == "runesword" then
        return util.floor(unit.stats.str / 2) + item.stats.mt
        
    elseif item.id == "swordofthecreator" then
        return unit.stats.str + unit.stats.mag + item.stats.mt
    
    elseif item:is_cannonball() then
        return unit.stats.dex + item.stats.mt
        
    elseif item:is_art() and item.id ~= "dragonsfist" then
        return util.floor((unit.stats.str + unit.stats.mag) / 2) + item.stats.mt
        
    elseif item:is_magic() then
        return unit.stats.mag + item.stats.mt
        
    else
        return unit.stats.str + item.stats.mt
        
    end
end
--
local function inventory_as(data, unit, item)
    return unit.stats.spd - math.max(item.stats.wt - unit.stats.bld, 0)
end
--
local function inventory_hit(data, unit, item)
    if item:is_cannonball() then
        return item.stats.hit + unit.stats.dex + unit.stats.str + unit.stats.bld + util.floor(unit.stats.lck / 2)
        
    else
        return item.stats.hit + (unit.stats.dex * 2) + util.floor(unit.stats.lck / 2)
    end
end
--
local function inventory_crit(data, unit, item)
    return item.stats.crit + util.floor(unit.stats.dex / 2)
end
--[[
local function inventory_avo(data, unit, item)
    return (data.result.as * 2) + util.floor(unit.stats.lck / 2) + item.stats.avo
end
--
local function inventory_ddg(data, unit, item)
    return unit.stats.lck + item.stats.ddg
end
--]]

inventory:item_calc("atk", inventory_atk)
inventory:item_calc("as", inventory_as)
inventory:item_calc("hit", inventory_hit)
inventory:item_calc("crit", inventory_crit)
--[[
inventory:item_calc("avo", inventory_avo)
inventory:item_calc("ddg", inventory_ddg)
--]]

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, workspaces.Character)

Character.section = almanac.get("database/fe17/char.json")

Character.helper_job_base = true
Character.helper_job_growth = true
Character.helper_job_cap = true

Character.helper_portrait = "database/fe17/images"

Character.inventory = inventory

Character.Job = Job
Character.Item = Item

function Character:default_options()
    return {
        class = self.data.job,
        starsphere = false,
        fixed = false,
        ring = false,
        rise = false,
        forge = false,
        engrave = false
    }
end

-- Equip ring
local ring_section = almanac.get("database/fe17/equip_ring.json")

function Character:setup()
    self.job = Job:new(self.options.class)
    
    self.starsphere = self.options.starsphere
    self.fixed = self.options.fixed
    
    if self.options.ring then
        local equip = ring_section:get(self.options.ring).data
        
        self.ring = Ring:new(equip.ring)
        self.ring_rank = tostring(equip.rank)
        
        -- Add weapons if ring is a emblem
        if self.ring:is_emblem() and not self:is_changed("weapon") then
            self.item = self.ring:get_equip(self.ring_rank, self.job.data.type)
        end
        
    end
    
    -- Apply forges/engrave to weapon
    if self.item and #self.item == 0 then
        local args = {}
        
        if self.options.forge then
            args.forge = self.options.forge
        end
        
        if self.options.engrave then
            args.engrave = self.options.engrave
        end
        
        if util.table_has(args) then
            self.item:set_options(args)
        end
    end
    
    -- Automatically enable rise up bonuses for Roy
    self.rise = self.options.rise
    
    if self.ring and self.ring.id == "roy" then
        self.rise = not(self.rise)
    end
    
    -- Automatically enable draconic form bonuses for Tiki if there's no item equipped
    self.draconic = self.options.rise
    
    if self.ring and self.ring.id == "tiki" and not self.item then
        self.draconic = not(self.draconic)
    end
end

-- Info
function Character:show_info()
    local infobox = self:show_mod()
    
    infobox:insert("Proficiency", self:show_prof(), true)
    
    if self.data.personal ~= nil then
        local skill = Skill:new(self.data.personal)
        
        infobox:insert(skill:get_fancy(), skill:get_desc(), true)
        
    end
    
    infobox:image("thumbnail", self:get_portrait())

    return infobox
end

-- Mod
function Character:show_mod()
    local infobox = workspaces.Character.show_mod(self)
    
    -- averages tip
    if self:has_averages() and not self.fixed then
        infobox:set("footer", "For stats more accurate to fixed mode, use -fixed or fixed: true.")
    end
    
    return infobox
end

function Character:get_mod()
    local text = self:get_lvl_mod()
    
    -- Info stuff
    if not self.minimal then
        if self.data.internal ~= 0 then
            text = text .. string.format(" (Internal: %s)",
            self.data.internal)
        end
        
        text = text .. string.format("\n**Base SP:** %s", self.data.sp)
    end
    
    -- Bond Rank
    if self.ring then
        text = text .. string.format(" | **Bond**: %s", self.ring_rank)
    end
    
    -- Starsphere
    if self.starsphere then
        text = text .. "\n\\🔮Starsphere"
    end
    
    -- Fixed Mode
    if self.fixed and self:has_averages() then
        text = text .. "\n\\⚙️Fixed Mode"
    end
    
    -- Rise Above
    if self.rise then
        text = text .. string.format("\n**Rise Above**: `%s`", 
        util.table_stats(self:get_rise_above(), {value_start = "+"}))
    end
    
    -- Draconic Form
    if self.draconic then
        text = text .. "\n**Draconic Form**"
    end
    
    text = text .. self:common_mods()
    
    return text
end

-- Bases
function Character:final_base()
    local base = workspaces.Character.final_base(self)
    
    -- Apply Ring bonuses last
    if self.ring then
        base = base + self.ring:get_bonus(self.ring_rank)
    end
    
    -- Rise Above
    if self.rise then
        base = base + self:get_rise_above()
    end
    
    -- Draconic Form
    if self.draconic then
        base = base + {hp=10, str=5, mag=5, dex=5, spd=5, def=5, res=5, lck=5, spd=5, bld=5}
    end
    
    return base
end

function Character:get_rise_above()
    local result = {}
    
    local lvl = 5
    
    if self.job.data.type == "Dragon" then lvl = 6 end
    
    for key, value in pairs(self:final_growth()) do
        value = value / 100
        value = util.floor(value * lvl)
        
        if value ~= 0 then
            result[key] = value
        end
    end
    
    if self.job.data.type == "Armored" then
        if result.hp ~= nil then
            result.hp = result.hp + 5
            
        else
            result.hp = 5
        end
    end
    
    result.bld = nil
    
    return result
end

local dlc_characters = {"rafal", "nel", "gregory", "zelestia", "madeline"}

function Character:get_base()
    -- there's no reason for this to not be in json file
    -- i keep forgetting to move the actual bases there
    local base = workspaces.Character.get_base(self)
    
    base.sight = nil
    base.mov = nil
    
    -- Ignore the dlc chars
    if util.value_in_table(dlc_characters, self.id) then
        return base
    end
    
    
    -- internal level 0 means it's unpromoted, else is promoted
    local level
    if self.data.internal == 0 then level = -1 else level = 18 end

    level = self.data.lvl + level

    local function step(v1, v2)
        v2 = util.round(v2 / 100)
        v2 = util.round(level * v2)

        v2 = util.round_closest(v2)

        return v1 + v2
    end

    base = util.math.mod_stats(step, base, self:get_growth())

    return base
end

-- Compare
-- Apply fiixed mode to everyone
function Character:show_compare()
    for i, character in ipairs(self.compare) do
        character.fixed = self.fixed
    end
    
    return workspaces.Character.show_compare(self)
end

-- Averages
-- Account for Fixed Mode if it's enable
function Character:calc_averages(base)
    -- add personal growths
    if self.fixed then
        local growth = self:calc_growth()
        
        local function step(v1, v2)
            v2 = util.round(v2 / 100)
            
            return util.round(v1 + v2)
        end
        
        base = util.math.mod_stats(step, base, growth)
    end

    local args = {}

    if self.id == "jean" then
        args.double_class_growths = true
    end

    base = workspaces.Character.calc_averages(self, base, args)
    
    -- Floor the averages
    if self.fixed then
        for key, value in pairs(base) do
            base[key] = util.floor(value)
        end
    end
    
    return base
end


-- Growths
function Character:final_growth()
    local growth = workspaces.Character.final_growth(self)

    -- Apply class growths again for jean
    if self.id == "jean" and not self:is_personal() then
        growth = growth + self.job:get_growth()
    end

    return growth 
end

function Character:calc_growth()
    local growth = self:get_growth()
    
    if self.starsphere then
        growth = growth + 15
    end
    
    return growth
end

function Character:get_growth()
    local growth = workspaces.Character.get_growth(self)
    
    growth.sight = nil
    growth.mov = nil
    
    return growth
end

-- Caps
function Character:get_cap()
    local cap = workspaces.Character.get_cap(self)
    
    cap.sight = nil
    cap.mov = nil
    
    return cap
end

-- Ranks
function Character:show_rank()
    return self.job:show_rank(self.data.aptitude, not(self:is_changed("class")))
end

function Character:show_prof()
    local text = ""
    
    for i, weapon in ipairs(self.data.aptitude) do
        local add = pack:get(weapon, "") .. util.title(weapon)
        
        if i == 1 then
            add = add .. " (+1)"
        end
        
        text = text .. add .. "\n"
        
    end
    
    return text
end

-- Misc
function Character:get_name()
    local name = self.data.name
    
    if self.ring then
        name = name .. " & " .. self.ring.data.name
    end
    
    return name
end

function Character:get_compare_result_name()
    return self.data.name
end

function Character:get_portrait()
    local portrait = self.data.portrait
    
    if self.id == "alear" then
        local gender
        if math.random(1, 2) == 1 then gender = "m" else gender = "f" end
        
        portrait = "alear_" .. gender .. ".png"
    end
    
    return self.helper_portrait .. "/" .. portrait
end

---------------------------------------------------
-- Job --
---------------------------------------------------
Job.__index = Job
setmetatable(Job, workspaces.Job)

Job.section = almanac.get("database/fe17/job.json")

function Job:show()
    local infobox = workspaces.Job.show(self)
    
    if self.data.desc then
        local desc = self.data.desc
        
        if self.data.type then
            desc = desc .. "\n**Type**: " .. self.data.type
        end
        
        infobox:set("desc", desc)
    end
    
    if self.data.skill then
        local skill = Skill:new(self.data.skill)
        
        infobox:insert(skill:get_fancy(), skill:get_desc(), true)
    end
    
    return infobox
end

local rank_upgrade = {
    E = "D",
    D = "C",
    C = "B",
    B = "A",
    A = "S",
    S = "S"
}
function Job:show_rank(aptitude, base_class)
    local text = ""
    
    local function weapon_aptitude(rank, weapon)
        if #rank > 1 then
            rank = rank:sub(1, -2)
            
            if aptitude[1] == weapon then
                rank = string.format("**%s**", rank_upgrade[rank])
            end
            
        end
        
        return rank
    end
    
    -- Weapon to ignore if getting base class
    local ignore = {}
    
    for i, slot in ipairs(self.data.slot) do
        local add = ""
        
        -- If a weapon has been found for this slot
        local found = false
        
        for _, weapon in ipairs(slot) do
            -- If it's base class, add only if is in the aptitude table
            if (not base_class) or (not found and util.misc.value_in_table(aptitude, weapon)
                and not util.misc.value_in_table(ignore, weapon)) then
                local rank = self.data.rank[weapon]
                
                if aptitude then
                    rank = weapon_aptitude(rank, weapon)
                end
                
                add = add .. pack:get(weapon, util.title(weapon .. " ")) ..rank .. "/"
                
                found = true
                table.insert(ignore, weapon)
            end
        end
        
        text = text .. add:sub(1, -2) .. "\n"
    end
    
    return text
end

-- epic bandaid stat removal
function Job:get_base()
    local base = workspaces.Job.get_base(self)
    
    base.sight = nil

    return base
end

function Job:get_cap()
    local cap = workspaces.Job.get_cap(self)
    
    cap.sight = nil
    cap.mov = nil
    
    return cap
end

function Job:get_growth()
    local growth = workspaces.Job.get_growth(self)
    
    growth.sight = nil
    growth.mov = nil
    
    return growth
end

---------------------------------------------------
-- Ring --
---------------------------------------------------
Ring.__index = Ring
setmetatable(Ring, almanac.Workspace)

Ring.section = almanac.get("database/fe17/ring.json")

function Ring:show()
    if self:is_emblem() then
        return self:show_emblem()
        
    else
        return self:show_bond()
    end
end

local style_weapon = {
    blutgang = {"Backup"},
    areadbhar = {"Cavalry"},
    failnaught = {"Covert"},
    aegisshield = {"Armored"},
    luin = {"Flying"},
    thyrsus = {"Mystical"},
    rafailgem = {"Qi Adept"},
    aymr = {"Dragon"},
    fogbreath = {"Dragon"},
    darkbreath = {"Mystical"},
    flamebreath = {"Flying"},
    icebreath = {"Armored"},
    firebreath = {"Backup", "Cavalry", "Covert", "Qi Adept"}
}

local style_sequence = {}

for key, value in pairs(style_weapon) do
    table.insert(style_sequence, key)
end

function Ring:show_emblem()
    local infobox = Infobox:new({desc = self.data.desc})
    infobox:image("thumbnail", self:get_portrait())
    
    local otherbox = Infobox:new()
    
    local sync = ""
    local items = ""
    local inheritance = ""
    local stats = ""
    local aptitude = ""
    local main_stats = ""
    
    local function display_bonus(data)
        return util.table_stats(data, {value_start = "+", separator = "; "})
    end
    
    for key, value in pairs(self.data.rank) do
        -- Aptitude
        for i, weapon in ipairs(value.aptitude) do
            aptitude = aptitude .. string.format("%s (Lv. %s)\n", util.title(weapon),
                                                 key)
        end
        
        -- Sync
        for i, skill in ipairs(value.ring) do
            sync = sync .. string.format("%s (Lv. %s)\n", 
                           Skill:new(skill):get_fancy(), key)
        end
        
        -- Inheritance
        for i, skill in ipairs(value.inheritance) do
            inheritance = inheritance .. string.format("%s (Lv. %s)\n", 
                                         Skill:new(skill):get_fancy(), key)
        end
        
        -- Item
        for i, item in ipairs(value.item) do
            item = Item:new(item)
            local add
            
            if (self.id == "byleth" or self.id == "tiki") and 
            value_in_table(style_sequence, item.id) then
                add = ""
                
                for x, y in ipairs(style_weapon[item.id]) do
                    add = add .. string.format("%s, ", y)
                end
                
                add = add:sub(1, -3)
                
            else
                add = string.format("Lv. %s", key)
            end
            
            items = items .. string.format("%s (%s)\n",
                             item:get_name(), add)
        end
        
        -- Stats
        if util.table_has(value.stats) then
            local bonus = self:get_bonus(key)
            
            stats = stats .. string.format("**Lv. %s**: %s\n", key,
                                           display_bonus(bonus))
        end
        
        -- Only show stats in the first page if it's on the table
        if util.value_in_table({"1", "5", "10", "20"}, key) then
            local bonus = self:get_bonus(key)
            
            main_stats = main_stats .. string.format("**Lv. %s**: %s\n", key,
                                       display_bonus(bonus))
        end
    end
    
    -- First Page
    infobox:insert("Sync", sync, true)
    infobox:insert("Item", items, true)
    infobox:insert("Stats", main_stats, true)
    
    local engage = ""
    
    for i, skill in ipairs(self.data.engage) do
        local skill = Skill:new(skill)
        
        engage = engage .. skill:get_fancy({italics = true}) .. "\n" .. skill:get_desc()
        engage = engage .. "\n\n"
    end
    
    infobox:insert("Engage!", engage)
    
    -- Second Page
    otherbox:insert("Inheritance", inheritance, true)
    otherbox:insert("Proficiency", aptitude, true)
    otherbox:insert("Stats", stats, true)
    
    -- Engrave
    local engrave = Engrave:new(self.data.engrave)
    
    otherbox:insert(engrave:get_name() .. " Engrave", engrave:show_bonus(), true)
    
    -- Bond rings
    if #self.data.bond > 0 then
        text = ""
        
        for i, ring in ipairs(self.data.bond) do
            text = text .. Ring:new(ring).data.name .. ", "
        end
        
        otherbox:insert("Bond Rings", text:sub(1, -3), true)
    end
    
    -- Pagebox
    local pagebox = Pagebox:new()
    
    pagebox:page(infobox)
    pagebox:page(otherbox)
    
    pagebox:stats_button()
    pagebox:button({label = "Other", emoji = "manual"})
    
    pagebox:set("title", self.data.name)
    
    return pagebox
end

function Ring:show_bond()
    local infobox = Infobox:new({title = self.data.name, desc = self.data.desc})
    
    for key, value in pairs(self.data.rank) do
        infobox:insert(key .. " Rank", util.table_stats(self:get_bonus(key), {value_start = "+"}), true)
    end
    
    if self.data.rank.S.skill then
        local skill = Skill:new(self.data.rank.S.skill)
        
        infobox:insert(skill:get_fancy(), skill:get_desc())
    end
    
    if self.data.parent then
        infobox:set("footer", self:show_parent() .. " Ring")
    end
    
    if #self.data.shared > 0 then
        local rigbox = Infobox:new({title = self.data.name})
        
        for i, ring in ipairs(self.data.shared) do
            ring = Ring:new(ring)
            
            local text = ""
            
            if ring.data.rank.S.skill then
                local skill = Skill:new(ring.data.rank.S.skill)
                text = skill:get_fancy({bold = true}) .. "\n"
            end
            
            text = text .. "```" .. util.table_stats(ring:get_bonus("S"), {value_start = "+"}) .. "```"
            
            local title = string.format("%s (%s)", ring.data.name, ring:show_parent())
            rigbox:insert(title, text, true)
        end
        
        rigbox:set("footer", "These rings share the same slot as this one. All stats are displayed according to S rank.")
        
        local pagebox = Pagebox:new()
        
        pagebox:page(infobox)
        pagebox:page(rigbox)
        
        pagebox:stats_button()
        pagebox:button({label = "Rigging", emoji = "manual"})
        
        return pagebox
        
    else
        return infobox
    end
end

function Ring:show_parent()
    return util.title(self.data.parent)
end

function Ring:get_bonus(target)
    if self:is_emblem() then
        target = target or "20"
        
        if type(target) == "number" then target = tostring(target) end
        
    else
        target = target or "S"
    end
    
    local result = {}
    
    local continue = true
    
    for rank, value in pairs(self.data.rank) do
        if continue then
            if rank == target then continue = false end
            
            for x, y in pairs(value.stats) do
                result[x] = y
            end
        end
    end
    
    return result
end

function Ring:get_equip(target, style)
    target = target or "20"
    
    local result = {}
    local continue = true
    
    for rank, value in pairs(self.data.rank) do
        if continue then
            if rank == target then continue = false end
            
            for i, item in ipairs(value.item) do
                item = Item:new(item)
                
                if (self.id == "byleth" or self.id == "tiki") and
                (value_in_table(style_sequence, item.id)) and
                not(value_in_table(style_weapon[item.id], style)) then
                    -- do nothing
                
                elseif item:is_weapon() then table.insert(result, item) end
            end
        end
    end
    
    if #result == 0 then
        return nil
        
    else
        return result
    end
end

function Ring:get_portrait()
    return string.format("database/fe17/images/%s", self.data.portrait)
end

function Ring:is_emblem()
    return (self.data.emblem)
end

---------------------------------------------------
-- Item --
---------------------------------------------------
Item.__index = Item
setmetatable(Item, workspaces.Item)

Item.pack = pack

Item.section = almanac.get("database/fe17/item.json")

function Item:default_options()
    return {
        forge = false,
        engrave = false
    }
end

function Item:setup()
    self.forge = self.options.forge or nil
    
    if self.forge then
        if #self.data.forge == 0 then
            self.forge = nil
            
        else
            self.forge = math.min(self.forge, #self.data.forge)
        end
    end
    
    self.engrave = self.options.engrave or nil
    
    if self.engrave then
        self.engrave = Engrave:new(self.engrave)
    end
end

-- Mod
function Item:show()
    local infobox = workspaces.Item.show(self)
    
    local function upgrade_price(data)
        local text = ""
        
        for i, pair in ipairs({"Iron", "Steel", "Silver"}) do
            if data[pair] ~= nil then
                text = text .. string.format("%s%s ",pack:get(pair, string.format("**%s:** ", pair)),
                data[pair])
            end
        end
        
        return text
    end
    
    if not self:is_changed() and (#self.data.forge ~= 0 or util.table_has(self.data.upgrade)) then
        local forgebox = Infobox:new({title = self.data.name})
        
        ------------
        local text = ""
        
        for i, pair in ipairs(self.data.forge) do
            local add = string.format("%s**+%s**: ", global_pack:get("star_" .. tostring(i)), i)
            
            if pair.cost.Price then
                add = add .. string.format("%sG ", pair.cost.Price)
            end
            
            add = add .. upgrade_price(pair.cost)
            
            local stats = self:get_stats_raw(i)
            
            stats.rank = nil
            stats.price = nil
            stats.range = nil
            
            add = add .. "\n" .. util.table_stats(stats, {order = "item"})
            
            text = text .. add .. "\n\n"
        end
        
        forgebox:insert("Forging", text, true)
        
        ----------
        text = ""
        
        for key, value in pairs(self.data.upgrade) do
            text = text .. string.format("**%s**: %s\n", key, upgrade_price(value))
        end
        
        forgebox:insert("Upgrade", text, true)
        
        local pagebox = Pagebox:new()
        
        pagebox:page(infobox)
        pagebox:page(forgebox)
        
        pagebox:stats_button()
        pagebox:button({label = "Forging", emoji = "gold"})
        
        return pagebox
    end
    
    return infobox
end

-- Stats
function Item:get_stats_raw(forge)
    forge = forge or self.forge
    local item = util.copy(self.data.stats)
    
    local function add_stats(data)
        for key, value in pairs(data) do
            if item[key] ~= nil then
                item[key] = item[key] + value
                
            else
                item[key] = value
            end
        end
    end
    
    -- Apply forges
    if forge ~= nil then
        result = {}
        
        local continue = true
        
        for i, pair in ipairs(self.data.forge) do
            if continue then
                if i == forge then continue = false end
                
                for key, value in pairs(pair.stats) do
                    result[key] = value
                end
            end
        end
        
        add_stats(result)
    end
    
    -- Apply Engrave
    if self.engrave then
        add_stats(self.engrave.data.stats)
    end
    
    return item
end

function Item:get_name()
    local name = self.data.name
    
    if self.forge ~= nil then
        name = name .. string.format(" +%s", self.forge)
    end
    
    if self.engrave ~= nil then
        name = self.engrave:get_name() .. " " .. name
    end
    
    return name
end

function Item:is_art()
    return (self.data.type == "art")
end

function Item:is_cannonball()
    if self.data.equip.cannonball ~= nil then
        return self.data.equip.cannonball
        
    else
        return false
    end
end

---------------------------------------------------
-- Engrave --
---------------------------------------------------
Engrave.__index = Engrave
setmetatable(Engrave, almanac.Workspace)

Engrave.section = almanac.get("database/fe17/engrave.json")

function Engrave:show_bonus()
    return util.table_stats(self.data.stats, {value_start = "+", order = "item"})
end

function Engrave:get_name()
    return self.data.name
end

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, workspaces.Skill)

Skill.section = almanac.get("database/fe17/skill.json")

function Skill:show()
    local infobox = workspaces.Skill.show(self)

    if self.data.cost ~= 0 then
        infobox:set("desc", infobox:get("desc") .. "\n\n**Cost**: " .. tostring(self.data.cost))
    end

    return infobox
end

function Skill:get_icon()
    if self.data.icon ~= nil then
        return string.format("database/fe17/images/skill/%s.png", self.data.icon)
    end
end

return {
    Character = Character,
    Job = Job,
    Skill = Skill,
    Item = Item,
    Ring = Ring
}
