local almanac = require("almanac")
local workspaces = almanac.workspaces
local util = almanac.util

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox

local heroes_pack = util.emoji.get("database/feh/emoji.json")
local pack = util.emoji.global

local embed_color = {
    Red = 0xCD2846,
    Blue = 0x2764DD,
    Green = 0x0AAB25,
    Colorless = 0x55656D
}


local Character = {}
local Display = {}
local Quotes = {}
local Skill = {}
local Artist = {}
local Voice = {}
local Equip = {}

---------------------------------------------------
-- Character --
---------------------------------------------------
Character.__index = Character
setmetatable(Character, workspaces.Character)

Character.section = almanac.get("database/feh/char.json")

Character.allow_show_growth = false
Character.allow_show_cap = false

Character.compare_growth = false
Character.compare_cap = false

function Character:default_options()
    return {
        rarity = 5,
        merge = 0,
        flower = 0,
        resplendent = false,
        max = false,
        secret = false,
        boon = false,
        bane = false,
        ascended = false,
        wpn = false,
        bonus = false,
        support = false,
    }
end

function Character:setup()
    if self.options.max or self.options.secret then
        self.options.flower = self:flower_limit()
        self.options.merge = 10
        
        if self:has_resplendent() then
            self.options.resplendent = true
        end
        
        if self.options.secret then
            self.options.bonus = true
            self.options.support = "s"
            self.options.wpn = "prf"
            
            if not self.options.boon then
                self.options.boon = "atk"
            end
            
            if not self.options.ascended then
                self.options.ascended = "spd"
            end
            
            self.options.bane = "hp"
        end
    end
    
    self.rarity = self.options.rarity
    self.merge = self.options.merge
    self.flower = self.options.flower
    
    self.resplendent = self.options.resplendent
    self.bonus = self.options.bonus
    
    self.support = self.options.support
    
    self.boon = self.options.boon
    self.bane = self.options.bane
    self.ascended = self.options.ascended
    
    -- weapon equips
    self.wpn = self.options.wpn
    
    if self.wpn then
        if self.wpn:sub(1, 3) == "prf" then
            self.wpn = self.wpn:sub(4, #self.wpn)
            
            self.wpn = self.data.prf[self.wpn]
        end
        
        self.wpn = Equip:new(self.wpn)
    end
end

----------------------------------------
function Character:show_info()
    local infobox = Infobox:new({desc = self:get_info()})
    
    infobox:insert(self:star_level(), self:show_base())
    
    infobox:image("thumbnail", self:get_portrait())
    infobox:image("icon", self:weapon_path())
    
    --infobox:image("footer", self:get_chibi())
    infobox:set("footer", string.format("%s | Version %s", self.data.origin, self.data.version))
    
    infobox:insert("Base Kit", self:get_base_kit(), true)
    
    --------------------
    -- Skill Page
    local skillbox = Infobox:new()

    -- desc
    local skillbox_desc = string.format("%sHeroic Ordeal: %s\nAvailable rarities: ", self:flower_icon(), self:heroic_ordeal())
    
   
    if self.data.rarity ~= 5 then
        skillbox_desc = skillbox_desc .. string.format("%s%s-%s5", heroes_pack:get("star_" .. self.data.rarity), self.data.rarity, heroes_pack:get("star_5"))
        
    else
        skillbox_desc = skillbox_desc .. string.format("%s5", heroes_pack:get("star_5"))
    end
    
    -- Duo skill desc
    if self:is_duo() then
        local duo = self:duo_type()
        
        skillbox_desc = string.format("%s**%s Skill**\n%s\n", heroes_pack:get("feh_" .. duo), util.title(duo), self:duo_effect()) .. skillbox_desc
    end

    skillbox:set("desc", skillbox_desc)
    
    -- Skills
    local function skill_field(name, emoji, data)
        if #data > 0 then
            local text = ""
            
            for key, value in pairs(data) do
                text = text .. string.format("%s%s\n", heroes_pack:get("star_" .. value), key)
            end
            
            skillbox:insert(string.format("%s%s", heroes_pack:get("feh_" .. emoji), name), text, true)
        end
    end
    
    skill_field("Weapon", "weapons", self.data.weapons)
    skill_field("Assist", "assist", self.data.assist)
    skill_field("Special", "special", self.data.special)
    skill_field("Passive A", "A", self.data.passive.A)
    skill_field("Passive B", "B", self.data.passive.B)
    skill_field("Passive C", "C", self.data.passive.C)
    
    --------------------
    -- Misc Page
    local miscbox = Infobox:new({desc = "*" .. self.data.description .. "*"})
    
    -- Desc
    
    miscbox:insert("Credits", string.format("**Artist**: %s\n**VA**: %s", self.data.artist, self.data.voice), true)
    
    if self:has_resplendent() then
        miscbox:insert(heroes_pack:get("resplendent") .. "Resplendent", string.format("**Artist**: %s\n**VA**: %s", self.data.resplendent, self.data.resplendent_voice), true)
    end
    
    -- Alts
    if #self.data.reference > 0 then
        local alts_text = ""
        
        for i, p in ipairs(self.data.reference) do
            local ref = Character:new(p)
            
            alts_text = alts_text .. string.format("%s | *%s*\n", ref:fancy_short(), ref.id)
        end
        
        miscbox:insert("Alts | Bot ID", alts_text, false)
        
        miscbox:set("footer", "Using the Bot ID saves you use some typing, but if you don't remember it just use the Hero's name instead!")
    end
    
    -------------------
    -- Similar Page
    --[[
    local similarbox = Infobox:new()
    
    for key, value in pairs(self.data.close) do
        similarbox:insert(key, value, true)
    end
    --]]
    --------------------
    -- Page box
    local pagebox = Pagebox:new()
    
    pagebox:page(infobox)
    pagebox:page(skillbox)
    pagebox:page(miscbox)
    --pagebox:page(similarbox)
    
    pagebox:stats_button()
    pagebox:button({label = "Skills", page = 1, emoji = "manual"})
    pagebox:button({label = "Misc.", page = 2, emoji = "bubble"})
    --pagebox:button({label = "Similar", page = 3, emoji = "bubble"})
    
    pagebox:set({title = self:fancy_name(), color = embed_color[self.data.color]})
    
    return pagebox
end

function Character:get_chibi()
    return string.format("database/feh/images/chibi/%s.png", self.data.chibi)
end

function Character:get_base_kit()
    text = ""
    
    local function kit(name, data)
        local last = data[-1]
        
        if last then
            text = text .. string.format("%s%s\n", heroes_pack:get("feh_" .. name), last)
        end
    end
    
    kit("weapons", self.data.weapons)
    kit("assist", self.data.assist)
    kit("special", self.data.special)
    kit("A", self.data.passive.A)
    kit("B", self.data.passive.B)
    kit("C", self.data.passive.C)
    
    return text
end

function Character:heroic_ordeal()
    local id = tonumber(self.data.id)
    
    if id >= 317 then
        return 40
        
    elseif id >= 191 then
        return 8
        
    else
        return 2
    end
    
end

function Character:get_info()
    -- [Infantry Icon] MoveType Color Weapon
    local text = string.format("%s%s %s %s\n", self:movement_icon(), self.data.move, self.data.color, self.data.weapon)
    
    text = text .. string.format("%sMax Flowers: %s\n", self:flower_icon(), self:flower_limit())
    
    -- Check for resplendent
    if self:has_resplendent() then
        text = text .. string.format("%sResplendent Outfit\n", heroes_pack:get("resplendent"))
    end
    
    -- Check for rearmed
    if self:is_rearmed() then
        text = text .. string.format("%sRearmed Hero\n", heroes_pack:get("arm"))
    end
    
    -- Check for Legendary/Mythic and show the bonuses
    if self:is_legendary() then
        text = text .. string.format("%s%s\n", self:blessing_icon(), util.table_stats(self.data.boost, {value_start = "+"}))
    end
    
     -- Check for Duo Hero
    if self:is_duo() then
        local duo = self:duo_type()
        
        text = text .. string.format("%s%s Hero - Check *Skills* page for the %s skill effect.\n", heroes_pack:get("feh_" .. duo), util.title(duo), util.title(duo))
    end
    
    -- Check for Duel
    if self.data.duel then
        -- Add PairUp icon if it's a legendary hero
        if self:is_legendary() then
            text = text .. heroes_pack:get("feh_pairup")
        end
        
        text = text .. string.format("Duel: %s\n", self.data.duel)
    end
    
    return text
end

----------------------------------------
function Character:show_mod()
    local infobox = workspaces.Character.show_mod(self)
    
    infobox:image("icon", self:weapon_path())
    
    infobox:set("title", self:fancy_name())
    infobox:set("color", embed_color[self.data.color])
    
    return infobox
end

function Character:get_mod()
    local text = ""
    
    if self.boon or self.ascended or self.bane then
        local add = ""
        
        if self.boon then
            add = add .. string.format("+%s", util.title(self.boon))
        end
        
        if self.ascended then
            add = heroes_pack:get("floret") .. add .. string.format(" +%s", util.title(self.ascended))
        end
        
        if self.bane then
            add = add .. string.format(" -%s", util.title(self.bane))
        end
        
        text = text .. "\n" .. add
    end
    
    -- other mods
    local add = ""
    
    if self.resplendent then
        add = add .. string.format("%s+2 ", heroes_pack:get("resplendent"))
    end
    
    if self.bonus then
        add = add .. ":trophy:+4 "
    end
    
    if self.support then
        add = add .. string.format("%sSup. ", heroes_pack:get("feh_" .. util.title(self.support)))
    end
    
    -- add them here
    if #add > 0 then
        text = text .. "\n" .. add
    end
    
    -- weapon
    if self.wpn then
        text = text .. "\n" .. heroes_pack:get("feh_weapons") .. self.wpn.data.name
    end
    
    text = text .. self:common_mods()
    
    return text
end

----------------------------------------
function Character:star_level()
    local text = heroes_pack:get("star_" .. self.rarity) .. "Lv. 40"
    
    if self.merge > 0 then
        text = text .. "+" .. tostring(self.merge) .. " "
    else
        text = text .. " "
    end
    
    if self.flower > 0 then
        text = text .. string.format("%s+%s", self:flower_icon(), self.flower)
    end
    
    return text
end

----------------------------------------
function Character:show_base()
    local base = self:final_base()
    
    local bst = base.bst
    base["bst"] = nil
    
    if not self.minimal then
        -- add + for superboons and - for superbanes
        local function trait(data, form)
            for i, p in ipairs(data) do
                base[p] = string.format(form, base[p])
            end
        end
        
        trait(self.data.superboon, "%s**+**")
        trait(self.data.superbane, "%s**-**")
    end
    
    local text = util.table_stats(base) .. string.format("\n**BST**: %s", bst)
    
    return text
end

local summoner_bonus = {
    c = {hp = 3, res = 2},
    b = {hp = 4, def = 2, res = 2},
    a = {hp = 4, spd = 2, def = 2, res = 2},
    s = {hp = 5, atk = 2, spd = 2, def = 2, res = 2}
}

function Character:final_base()
    local base = self:calc_base()
    
    -- Resplendent Bonus
    if self.resplendent then
        base = base + 2
    end
    
    -- Summoner support bonus
    if self.support then
        base = base + summoner_bonus[self.support]
    end
    
    -- Arena Bonus
    if self.bonus then
        base = base + 4
        
        -- total hp bonus is 10
        base.hp = base.hp + 6
    end
    
    -- BST
    local bst = 0
    
    for key, value in pairs(base) do
        bst = bst + value
    end
    
    base["bst"] = bst
    
    -- Everything after this is not counted for bst
    if self.wpn then
        base = base + self.wpn.data.bonus
    end
    
    base = self:common_base(base)
    
    return base
end

----------------------------------------
local rarity_modifier = {0.86, 0.93, 1.00, 1.07, 1.14}

local merge_increase = {
    {1, 2}, -- +1
    {3, 4}, -- +2
    {5, 1}, -- +3
    {2, 3}, -- +4
    {5, 4}, -- +5
    {1, 2}, -- +6
    {3, 4}, -- +7
    {5, 1}, -- +8
    {2, 3}, -- +9
    {5, 4}, -- +10
}

function Character:calc_base()
    local base = self:get_base()
    local growth = self:get_growth()
    
    -- Level 40
    local function growth_calc(x, y)
        -- Growth x Rarity
        local r = x * y
        
        r = util.floor(r)
        
        -- Growth%
        r = r / 100
        r = util.round(r)
        
        -- Level * Growth%
        r = 39 * r
        r = util.floor(r)
        
        return r
    end
    
    local mod = util.math.mod_stats(growth_calc, growth, rarity_modifier[self.rarity])
    base = base + mod
    
    -- Stat boosts that use the stat order
    local order = self:stat_order()
    
    local function boost(i)
            local stat = order[i]
            
            base[stat] = base[stat] + 1
    end
        
    -- Merge
    if self.merge > 0 then
        
        local function loop()
            
            for i, pair in ipairs(merge_increase) do
                boost(pair[1])
                boost(pair[2])
                
                -- Neutral merge boost
                if i == 1 and not self.boon and not self.bane then
                    boost(1)
                    boost(2)
                    boost(3)
                end
            
                if i == self.merge then return end
            end
        end
        
        loop()
    end
    
    -- Dragonflower
    if self.flower > 0 then
        local increase = 1
        
        for i = 1, self.flower do
            if increase == 6 then
                increase = 1
            end
            
            boost(increase)
            
            increase = increase + 1
        end
    end
    
    return base
end

function Character:stat_order()
    local base = self:get_base(true)
    
    local keys = {}
    
    for key, _ in pairs(base) do
        table.insert(keys, key)
    end
    
    table.sort(keys, function(keyL, keyR) return base[keyL] > base[keyR] end)
    
    return keys
end

----------------------------------------
function Character:get_base(order)
    -- Order will not ignore banes if the merge is 0 and will totally ignore ascended boons
    order = order or false
    
    local base = workspaces.Character.get_base(self)
    
    if self.boon then
        base[self.boon] = base[self.boon] + 1
    end
    
    if self.bane and (order or (not order and self.merge == 0)) then
        base[self.bane] = base[self.bane] - 1
    end
    
    if self.ascended and not order then
        base[self.ascended] = base[self.ascended] + 1
    end
    
    return base
end

--
function Character:get_growth()
    local growth = workspaces.Character.get_growth(self)
    
    if self.boon then
        growth[self.boon] = growth[self.boon] + 5
    end
    
    if self.bane and self.merge == 0 then
        growth[self.bane] = growth[self.bane] - 5
    end
    
    if self.ascended then
        growth[self.ascended] = growth[self.ascended] + 5
    end
    
    return growth
end

---------------------
function Character:flower_limit()
    local id = tonumber(self.data.id)
    
    local flower = 5
    
    -- Heroes released after or during CYL6
    
    if id <= 838 then
        flower = flower + 5
        
        -- Heroes released after or during CYL5
        if id <= 694 then
            flower = flower + 5
            
            -- Heroes released after or during CYL4
            if id <= 553 then
                flower = flower + 5
                
                -- Gen 1 Heroes that are also infantry
                if id <= 338 and self.data.move == "Infantry" then
                    flower = flower + 5
                end
            end
        end
    end
    
    return flower
end
---------------------
function Character:fancy_short()
    local text = self:weapon_icon() .. self:get_name()
    
    if self:is_legendary() then
        text = self:blessing_icon() .. text
    end
    
    return text
end

function Character:get_name()
    return self.data.short_name
end

function Character:fancy_name()
    return string.format("%s: %s", self.data.name, self.data.title)
end

function Character:get_field_stats_name()
    return self:star_level()
end

---------------------
function Character:is_duo()
    return (self.data.duo or self.data.harmonized)
end

function Character:duo_type()
    if self.data.duo then
        return "duo"
        
    else
        return "harmonized"
        
    end
end

function Character:duo_effect()
    return self.data[self:duo_type()]
end

---------------------
function Character:is_legendary()
    return (self.data.type == "legendary")
end

function Character:blessing_icon()
    return heroes_pack:get( string.format("Blessing_%s", self.data.blessing) )
end

---------------------

function Character:get_compare_name()
    return self:fancy_short()
end

function Character:is_rearmed()
    return (self.data.type == "rearmed")
end

function Character:has_resplendent()
    return (self.data.resplendent)
end

function Character:flower_icon()
    return heroes_pack:get( string.format("feh_flower%s", self.data.move) )
end

function Character:movement_icon()
    return heroes_pack:get( string.format("feh_%s", self.data.move) )
end

function Character:weapon_icon()
    return heroes_pack:get(string.format("%s_%s", self.data.color, self.data.weapon))
end

function Character:weapon_path()
    return string.format("database/feh/icon/%s_%s.png", self.data.color, self.data.weapon)
end

function Character:get_portrait()
    if self.resplendent and self:has_resplendent() then
        return string.format("database/feh/images/heroes/%sr.webp", self.data.id)
    
    else
        return string.format("database/feh/images/heroes/%s.webp", self.data.id)
    end
end

---------------------------------------------------
-- Skill --
---------------------------------------------------
Skill.__index = Skill
setmetatable(Skill, almanac.Workspace)

Skill.section = almanac.get("database/feh/skill.json")

local skill_display = {
    Weapon = {
        color = 0xa31d29,
        icon = "feh_weapons"
    },
    Assist = {
        color = 0x1bcf9f,
        icon = "feh_assist"
    },
    Special = {
        color = 0xb818b2,
        icon = "feh_special"
    },
    ["Passive A"] = {
        color = 0xCD2846,
        icon = "feh_A"
    },
    ["Passive B"] = {
        color = 0x2764DD,
        icon = "feh_B"
    },
    ["Passive C"] = {
        color = 0x0AAB25,
        icon = "feh_C"
    },
    ["Sacred Seal"] = {
        color = 0xe6a40b,
        icon = "feh_S"
    }
}

function Skill:show()
    local pagebox = Pagebox:new()
    
    -- first page
    local name, desc = self:show_tier(#self.data.skill)
    
    local infobox = Infobox:new({title = name, desc = desc})
    infobox:image("thumbnail", self:get_portrait())
    
    -- weapon refine icon
    if self.data.slot == "Weapon" and self.data.icon then
        infobox:image("icon", string.format(
        "database/feh/images/passive/%s.png", self.data.icon))
    end
    
    pagebox:page(infobox)
    pagebox:stats_button()
    
    -- learned skills
    local skillbox = Infobox:new()
    
    local add_skill_page = false
    local freemium = false
    local footer_freemium = false
    
    for key, value in pairs(self.data.reference) do
        local result = self:organize_learn(value)
        
        if result.freemium then
            freemium = true
        end
        
        for i, field in ipairs(result.fields) do
            skillbox:insert(key, field, true)
            
            if result.count > 10 then
                add_skill_page = true
                
            elseif not add_skill_page then
                infobox:insert(key, field, true)
                
                footer_freemium = true
            end
        end
    end
    
    if freemium then
        if footer_freemium then
            infobox:set("footer", "Heroes with an underlined name can be obtained at 4 stars rarity or lower.")
        end
        
        skillbox:set("footer", "Heroes with an underlined name can be obtained at 4 stars rarity or lower.")
    end
    
    if add_skill_page then
        pagebox:page(skillbox)
        pagebox:button({label = "Inheritance", emoji = "manual"})
    end
    
    -- skill tiers
    if #self.data.skill > 1 then
        local tierbox = Infobox:new()
        
        for i = #self.data.skill, 1, -1 do
            local tier_name, tier_desc = self:show_tier(i, true)
            
            tierbox:insert(tier_name, tier_desc)
        end
        
        pagebox:page(tierbox)
        pagebox:button({label = "Tiers", emoji = "star"})
    end
    
    ------
    if self.data.slot == "Weapon" then
        if self.data.refine then
            -- special refine
            if self.data.refine.special then
                local refine = self.data.refine.special[1]
                
                table.insert(infobox.fields, 1, {
                name=heroes_pack:get("dew") .. "Special Refine", value=refine, inline=false})
            end
            
            -- og effect page
            if self.data.refine.description then
                local desc = self.data.skill[1].description
                
                local effectpage = Infobox:new({title = self.data.name, desc = desc})
                
                pagebox:page(effectpage)
                pagebox:button({label = "OG Effect", emoji = "star"})
            end
            
        end
        
        local color = self.data.skill[1].weapon_type
        
        local start = string.find(color, "_", 1, true)
        
        color = color:sub(1, start - 1)
        
        pagebox:set("color", embed_color[color])
        
    else
        pagebox:set("color", skill_display[self.data.slot].color)
    end
    ------
    if #pagebox.pages == 1 then
        return pagebox.pages[1]
        
    else
        return pagebox
    end
end

local pool_order = {"grail", "global", "seasonal", "legend", "special"}

function Skill:organize_learn(data)
    local result = {}
    local freemium = false
    
    for key, value in pairs(data) do
        local character = Character:new(key)
        
        local rarity = math.max(tonumber(value), character.data.rarity)
        
        local pool = character.data.pool
        
        -- name
        local name = character.data.short_name
        
        if character.data.rarity < 5 then
            name = "__" .. name .. "__"
            freemium = true
        end
        
        name = name .. " | *" .. key .. "*"
        
        -- emoji
        local emoji = "star_"
        
        if pool ~= "global" then
            emoji = emoji .. pool .. "_"
        end
        
        emoji = emoji .. tostring(rarity)
        
        -- table stuff
        if result[rarity] == nil then result[rarity] = {} end
        
        local stuff = result[rarity]
        
        if stuff[pool] == nil then stuff[pool] = {} end
        
        table.insert(stuff[pool], string.format("%s%s\n", 
        heroes_pack:get(emoji), name))
    end
    
    local fields = {}
    
    local current = ""
    local count = 0
    
    local function loop(rarity, pool, line)
        local new = current .. line
        
        count = count + 1
        
        if #new > 1024 then
            table.insert(fields, current)
            
            current = line
            
        else
            current = new
        end
    end
    
    -- big ass loop
    for i=1, 5 do
        if result[i] ~= nil then
            for _, pool in ipairs(pool_order) do
                if result[i][pool] ~= nil then
                    for _, line in ipairs(result[i][pool]) do
                        loop(i, pool, line)
                    end
                end
            end
        end
    end
    
    -- add current if it's not empty
    if #current > 0 then
        table.insert(fields, current)
    end
    
    return {fields=fields, freemium=freemium, count=count}
end

function Skill:show_tier(index, minimal)
    minimal = minimal or false

    local tier = self.data.skill[index]
    
    -- emoji
    local emoji
    
    if tier.slot == "Weapon" then
        emoji = heroes_pack:get(tier.weapon_type)
        
    else
        emoji = heroes_pack:get(skill_display[tier.slot].icon)
    end
    
    -- stats
    local text = emoji .. util.table_stats(tier.stats, {key_start = "**", key_end = "**"})
    
    if tier.exclusive then
        text = text .. " | __***Not***__ **Inheritable**"
        
    else
        text = text .. " | **Inheritable**"
    end
    
    -- desc
    local desc
    
    if self.data.refine and self.data.refine.description then
        desc = self.data.refine.description
    
    else
        desc = tier.description
    end
    
    text = text .. "\n" .. desc
    
    local function restriction(data, add)
        add = add or ""
        
        if not data then return "" end
        
        local result = data[1]
        
        for _, pair in ipairs(data[2]) do
            result = result .. heroes_pack:get(add .. pair)
        end
        
        return result
    end
    
    if not minimal then
        text = text .. "\n\n" .. restriction(tier.restriction_weapon)
        
        text = text .. "\n" .. restriction(tier.restriction_movement, "feh_")
    end
    
    return tier.name, text
end

function Skill:get_portrait()
    if self.data.slot == "Weapon" and self.data.wpn then
        return string.format("database/feh/images/wpn/%s.png", self.data.wpn)
        
    elseif self.data.slot ~= "Weapon" and self.data.icon then
        return string.format("database/feh/images/passive/%s.png", self.data.icon)
    end
end

---------------------------------------------------
-- Display --
---------------------------------------------------
Display.__index = Display
setmetatable(Display, Character)

function Display:default_options()
    return {}
end

function Display:setup()
end

local display_url = "https://raw.githubusercontent.com/izumi-niche/OifeyImg/master/heroes/%s/%s%s.webp?raw"

local display_order = {"portrait", "attack", "special", "damage"}

local display_emoji = {
    portrait = "alf0",
    attack = "alf1",
    special = "alf2",
    damage = "alf3"
}

local display_button = {
    Red = "red",
    Green = "green",
    Blue = "blue",
    Colorless = "gray"
}

function Display:show()
    local pagebox = Pagebox:new()
    
    local function display(section, artist, resplendent)
        if resplendent then
            resplendent = "r"
            
        else
            resplendent = ""
        end
        
        for i, pair in ipairs(display_order) do
            local infobox = Infobox:new({title = self:fancy_name(), color = embed_color[self.data.color]})
            
            local url = string.format(display_url, pair, self.data.id, resplendent)
            
            infobox:image("image", url)
            infobox:set("footer", "Artist: " .. artist)
            
            pagebox:page(infobox)
            
            pagebox:button({emoji = heroes_pack:get(display_emoji[pair]), 
            show = {section}, color = display_button[self.data.color]})
        end
    end
    
    display(0, self.data.artist)
    
    if self:has_resplendent() then
        display(1, self.data.resplendent, true)
        
        pagebox:button({emoji = heroes_pack:get("resplendent"), 
        section = 1, page = 4})
        
        pagebox:button({emoji = "bond", section = 0,
        show = {1}, page = 0})
    end
    
    pagebox.pages[1]:image("icon", self:weapon_path())
    
    return pagebox
end

---------------------------------------------------
-- Quotes --
---------------------------------------------------
Quotes.__index = Quotes
setmetatable(Quotes, Display)

function Quotes:default_options()
    return {context = false}
end

function Display:setup()
    self.context = self.options.context or "Kiran"
end

function Quotes:show()
    local pagebox = Pagebox:new()
    
    local function quote_page(name, emoji, fields, check)
        local infobox = Infobox:new()
        
        check = check or self.data.quotes
        
        for i, pair in ipairs(fields) do
            if check[pair] then
                local text = ""
                
                for _, quote in ipairs(check[pair]) do
                    quote = string.gsub(quote, "%[S%]", self.context)
                    quote = string.gsub(quote, "%[F%]", "Kiran")
                    
                    text = text .. string.format("%s%s\n", 
                    pack:get("bubble"), quote)
                end
                
                infobox:insert(pair, text)
            end
        end
        
        if #infobox.fields > 0 then
            if #infobox.fields == 1 then
                infobox:set("desc", infobox.fields[1].value)
                table.remove(infobox.fields, 1)
            end
            
            pagebox:page(infobox)
            pagebox:button({label = name, emoji = emoji})
        end
    end
    
    quote_page("Castle", pack:get("bond"), {"Summon", "Castle Hall", "Learn Skill", "Visit"})
    quote_page("Status", pack:get("bubble"), {"Status"})
    quote_page("Conversation", pack:get("pairup"), {"Conversation"})
    quote_page("Battle", pack:get("manual"), {"Special", "Level", "Map Select", "Back Unit Supporting", "Duo Skill"})
    quote_page("Confession", pack:get("star"), {"Confession"})
    
    if self:has_resplendent() then
        quote_page("Resplendent", heroes_pack:get("resplendent"),
        {"Special", "Status", "Map Select"}, self.data.quotes.resplendent)
    end
    
    pagebox:set("title", self:fancy_name())
    pagebox:set("color", embed_color[self.data.color])
    
    pagebox.pages[1]:image("icon", self:weapon_path())
    pagebox.pages[1]:image("thumbnail", self:get_portrait())
    
    return pagebox
end

---------------------------------------------------
-- Artist --
---------------------------------------------------
Artist.__index = Artist
setmetatable(Artist, almanac.Workspace)

Artist.section = almanac.get("database/feh/artist.json")

function Artist:show()
    local text = ""
    local portrait = {}
    
    for key, value in pairs(self.data.heroes) do
        text = text .. value .. "\n"
        
        if string.sub(key, -1) ~= "R" then
            table.insert(portrait, key)
        end
    end
    
    local infobox = Infobox:new({title = self.data.name, desc = text})
    
    if #portrait > 0 then
        local character = Display:new(portrait[math.random(1, #portrait)])
        
        infobox:image("thumbnail", character:get_portrait())
    end
    
    -- it's a organized dict so you can just get the len
    infobox:set("footer", string.format("%s Heroes", #self.data.heroes))
    
    return infobox
end

---------------------------------------------------
-- Voice--
---------------------------------------------------
Voice.__index = Voice
setmetatable(Voice, Artist)

Voice.section = almanac.get("database/feh/va.json")

---------------------------------------------------
-- Equip--
---------------------------------------------------
Equip.__index = Equip
setmetatable(Equip, almanac.Workspace)

Equip.section = almanac.get("database/feh/equip.json")

---------------------------------------------------
-- Init --
---------------------------------------------------
-- Thing used to determine which units are the closest to each other

-- Sort the heroes by ID
local table_id = {}

for key, value in pairs(Character.section.entries) do
    local data = value.data
    
    local hero_id = tonumber(data.id)
    
    table_id[hero_id] = key
end

local SEARCH_LIMIT = 3

-- Uncomment this to enable it again
-- Bot takes a long time to boot up if this is a thing
local search_tasks = {
    --{name = "Task1", same = {"weapon", "color", "move"}},
    --{name = "Task2", same = {"weapon", "color"}},
    --{name = "Task3", same = {"move"}}
}

-- Find closest heroes that share the same class and move
for key, value in pairs(Character.section.entries) do
    local hero = value.data
    
    local hero_id = tonumber(hero.id)
    
    -- The pools are as follows:
    -- Premium = 5 star-locked units that have a prf weapon.
    -- Fodder = 5 star-locked units that don't have a prf weapon.
    -- Freemium = Non 5 star-locked units.
    local function get_pool(data)
        if 5 == data.rarity then
            local has_prf = string.sub(data.weapons[-1], -1) ~= "+"
            
            if has_prf then
                return "premium"
                
            else
                return "fodder"
            end
        else
            return "freemium"
        end
    end
    
    local hero_pool = get_pool(hero)
    
    local function check_lots(check_keys, add_loop)
        add_loop = add_loop or 1
        
        local results = {}
        
        -- Check forward
        local search = hero_id
        
        while #results < SEARCH_LIMIT do
            search = search + add_loop
            
            -- If ID exists
            if table_id[search] ~= nil then
                local hero_compare = Character.section.entries[table_id[search]].data
                
                local function check_same()
                    for i, k in ipairs(check_keys) do
                        if hero[k] ~= hero_compare[k] then
                            return false
                        end
                    end
                    
                    return true
                end
                
                local function check_pool(compare)
                    if hero_pool == "fodder" and compare == "premium" then
                        return true
                    else
                        return (hero_pool == compare)
                    end
                end
                
                if check_pool(get_pool(hero_compare)) and check_same() then
                    table.insert(results, hero_compare)
                end
                
            else
                break
                
            end
        end
        
        return results
    end
    
    hero.oifey_pool = hero_pool
    hero.close = {}
    setmetatable(hero.close, util.ordered_table)
    
    for i, search in ipairs(search_tasks) do
        local newer = check_lots(search.same)
        local older = check_lots(search.same, -1)
        
        local function check(data, title)
            local text
            
            if #data > 0 then
                text = ""
                
                for i, compare in ipairs(data) do
                    text = text .. compare.DISPLAY_NAME .. "\n"
                end
                
            else
                text = "None"
            end
            
            hero.close[title] = text
        end
        
        check(newer, search.name .. " Newer")
        check(older, search.name .. " Older")
    end
end

return {
    Character = Character,
    Display = Display,
    Skill = Skill,
    Artist = Artist,
    Voice = Voice,
    Quotes = Quotes
}