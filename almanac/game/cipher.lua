local almanac = require("almanac")

local Infobox = almanac.Infobox
local Pagebox = almanac.Pagebox
local Workspace = almanac.Workspace

local card_url = "https://raw.githubusercontent.com/izumi-niche/OifeyImg/master/cipher/card/%s?raw"

local embed_color = {
    ["Blade of Light"] = 0xed2121,
    ["Brand"] = 0x4c94ed,
    ["Hoshido"] = 0xe6d8e8,
    ["Nohr"] = 0x49464a,
    ["Medallion"] = 0x60bf74,
    ["Legendary Weapons"] = 0xae4eb5,
    ["Holy War Flag"] = 0xdeb86d,
    ["Crest of the Goddess"] = 0x755739,
    ["Colorless"] = 0xffffff
}

local Card = {}
---------------------------------------------------
-- Card --
---------------------------------------------------
Card.__index = Card
setmetatable(Card, Workspace)

Card.section = almanac.get("database/cipher/card.json")

function Card:show()
    local pagebox = Pagebox:new()
    
    -- Card pages
    for k, v in pairs(self.data.cards) do
        local infobox = Infobox:new({title = string.format("%s (%s)", self:get_name(), k)})
        
        self:show_version(infobox, v)
        
        pagebox:page(infobox)
        pagebox:button({label = k, emoji = "manual"})
    end
    
    -- Add related page if card as other references
    if #self.data.reference > 0 then
        local infobox = Infobox:new({title = self:get_name()})
        local text = "**Related Cards | Bot ID**\n"
        
        -- Swap between the 5 and 4 star to make things easier to read
        local star = true
        
        for _, id in ipairs(self.data.reference) do
            local card = Card:new(id)
            
            local star_emoji
            
            if star then
                star_emoji = "star_5"
                star = false
            else
                star_emoji = "star_4"
                star = true
            end
            
            star_emoji = almanac.util.emoji.global:get(star_emoji)
            
            text = text .. string.format("%s%s | *%s*\n", star_emoji, card:get_name(), id)
        end
        
        infobox:set("desc", text)
        
        pagebox:page(infobox)
        pagebox:button({label = "Related Cards", emoji = "bubble"})
    end
    
    -- setting the thumbnail on the first page applies to all of them
    pagebox.pages[1]:image("icon", string.format("database/cipher/%s.png", self.data.symbol))
    
    pagebox:set("color", embed_color[self.data.symbol])
    return pagebox
end

-- Apply card info to a infobox
function Card:show_version(infobox, data)
    if data.quote then
        infobox:set("desc", "*" .. data.quote .. "*")
    end
    
    local artist
    
    if data.artist then
        artist = data.artist
    else
        artist = "Uncredited"
    end
    
    infobox:image("image", string.format(card_url, data.image))
    
    infobox:set("footer", "Artist: " .. artist .. " | Class: " .. self.data.job)
end

function Card:get_name()
    return string.format("%s: %s", self.data.name, self.data.title)
end

return {
    Card = Card
}