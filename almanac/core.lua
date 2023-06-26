local util = require("almanac.util")

local global_pack = util.emoji.get("global")

---------------------------------------------------
-- Entry Workspace --
---------------------------------------------------
local Workspace = {options = {}, section = nil}
Workspace.__index = Workspace

function Workspace:new(entry, section)
    local obj = {}
    setmetatable(obj, self)
    
    entry = obj:raw(entry, section)
    
    obj.entry = entry
    obj.id = entry.id
    obj.data = entry.data
    
    obj._changed = {}
    obj.tbl = self
    
    obj.ref = {__index = function(tbl, k) return obj.tbl.ref[k] end}
    
    return obj
end

-- Return only entry without needing the need to get a workspace
function Workspace:raw(entry, section)
    section = section or self.section
    
    -- Gets table from section if it's a string
    -- Uses self.section by default, but a section can be passed too
    -- Useful for code used for multiple games like GBAFE
    if type(entry) == "string" then
        entry = section:get(entry)
    end
    
    return entry
end

-- Return table with default options here
function Workspace:default_options() return {} end
-- Another layer of default options
function Workspace:special_options() return {} end

-- Set options, change values only if its on the default table
function Workspace:set_options(options)
    self.options = self:default_options()

    for k, v in pairs(self:special_options()) do
        self.options[k] = v
    end

    options = options or {}
    self.passed_options = options
    
    for k, p in pairs(options) do
        if self.options[k] ~= nil then
            self.options[k] = p
            
            self._changed[k] = true
            self._changed.any = true
        end
    end
    
    -- numbers from python can sometime be displayed as a float so math.floor them just to be safe
    local function check_number(data)
        if type(data) == "number" then
            return math.floor(data)
        
        elseif type(data) == "table" then
            for k, v in pairs(data) do
                if k ~= "compare" then
                    data[k] = check_number(v)
                end
            end
            
            return data
            
        else
            return data
        end
    end
    
    check_number(self.options)
    
    self:pre_setup()
    
    if util.debug then
        print("ENTRY TABLE")
        print(self.id)
        util.inspect(self.options)
        util.inspect(self.passed_options)
    end
    
    self:setup()
    self:post_setup()
end

-- Additional setup after settings options
function Workspace:pre_setup() end
function Workspace:setup() end
function Workspace:post_setup() end

-- Return data to show
function Workspace:show()
    return "Hello!"
end

-- Setup + Show combined
function Workspace:doit(options)
    self:set_options(options)
    return self:show()
end

-- Small things related to data
function Workspace:get(key)
    return self.entry:get(key)
end

-- Check if certain keys in options changed during setup
-- Can be a string or an array
function Workspace:is_changed(...)
    local args = {...}

    if #args == 0 then
        return (self._changed.any ~= nil)
    end
    
    for i, p in ipairs(args) do
        if self._changed[p] then
            return true
        end
    end
    
    return false
end

function Workspace:super()
    local tbl = getmetatable(self)

    if tbl ~= nil then
        return getmetatable(tbl)
    end
end

---------------------------------------------------
-- InfoBox --
---------------------------------------------------
local Infobox = {}
Infobox.__index = Infobox

function Infobox:new(args)
    local obj = {}
    setmetatable(obj, self)
    
    obj.has_pages = false
    
    obj.fields = {}
    obj.settings = args or {}
    obj.images = {}
    
    return obj
end

function Infobox:insert(name, value, inline)
    inline = inline or false
    
    if value then
        table.insert(self.fields, {name = name, value = value, inline = inline})
    end
end

function Infobox:set(key, value)
    self.settings[key] = value
end

function Infobox:get(key)
    return self.settings[key]
end

function Infobox:image(key, value)
    if value then
        self.images[key] = value
    end
end

function Infobox:has_set(key)
    return (self.settings[key])
end

function Infobox:set_field(index, key, value)
    self.fields[index][key] = value
end

---------------------------------------------------
-- InfoBox --
---------------------------------------------------
local Pagebox = {}
Pagebox.__index = Pagebox

function Pagebox:new()
    local obj = {}
    setmetatable(obj, self)
    
    obj.has_pages = true
    
    obj.pages = {}
    obj.buttons = {}
    
    return obj
end

function Pagebox:page(page)
    -- If page is also a pagebox, just transfers everything to this one
    if getmetatable(page) == getmetatable(self) then
        self.pages = page.pages
        self.buttons = page.buttons
    else
        table.insert(self.pages, page)
    end
    
    return #self.pages
end

function Pagebox:button(args)
    local button = {}
    
    button.page = args.page or #self.buttons
    button.section = args.section or -1
    button.show = args.show or {0}
    
    button.label = args.label or nil
    
    
    if util.emoji.config.enabled then
        button.emoji = args.emoji or "💾"
        
        if type(button.emoji) == "string" and global_pack:has(button.emoji) then
            button.emoji = global_pack:get(button.emoji)
        end
        
    else
        button.emoji = "💾"
    end
    
    button.color = args.color or "blurple"
    
    table.insert(self.buttons, button)
    
    return #self.buttons
end

function Pagebox:stats_button()
    self:button({page = 0, label = "Stats", emoji = "bond"})
end

-- This willl set it to all currently added infoboxes
function Pagebox:set(key, value)
    if type(key) == "table" then
        for k, p in pairs(key) do
            self:set(k, p)
        end
        
    else
        for i, page in ipairs(self.pages) do
            page:set(key, value)
        end
    end
    
end

-- Same thing but for images
function Pagebox:image(key, value)
    if type(key) == "table" then
        for k, p in pairs(key) do
            self:image(k, p)
        end
        
    else
        for i, page in ipairs(self.pages) do
            page:image(key, value)
        end
    end
    
end

-- Call insert on the first page
function Pagebox:insert(key, value, inline)
    return self.pages[1]:insert(key, value, inline)
end

---------------------------------------------------
-- Entry --
---------------------------------------------------
local Entry = {}
Entry.__index = Entry

function Entry:new(group, id, value)
    local obj = {}
    setmetatable(obj, self)
    
    obj.group = group
    obj.id = id
    obj.data = value
    
    return obj
end

function Entry:get(key)
    return self.data[key]
end

---------------------------------------------------
-- Section --
---------------------------------------------------
local Section = {}
Section.__index = Section

function Section:new(path)
    local obj = {}
    setmetatable(obj, self)
    
    obj.path = path
    
    obj:read()
    
    return obj
end

function Section:read()
    local raw = util.json_read(self.path)
    
    self.entries = {}
    setmetatable(self.entries, util.misc.ordered_table)
    
    for k, p in pairs(raw) do
        if type(p) == "table" then
            self.entries[k] = Entry:new(self, k, p)
        end
    end
end

function Section:get(entry)
    local e = self.entries[entry]
    
    if e ~= nil then
        return e
        
    else
        error( string.format("Entry not found: \"%s\", path = %s", entry, self.path) )
        
    end
end

---------------------------------------------------
-- Almanac --
---------------------------------------------------
local almanac = {
    Workspace = Workspace,
    Infobox = Infobox,
    Pagebox = Pagebox
}

local sections = {}

function almanac.get(path)
    if not sections[path] then
        sections[path] = Section:new(path)
    end
    
    return sections[path]
end


return almanac
