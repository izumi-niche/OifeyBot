local init = {
    util = require("almanac.util"),
    core = require("almanac.core"),
    workspaces = require("almanac.workspaces")
}

init.__index = init.core
setmetatable(init, init)

function init.load_game()
    init.game = require("almanac.game")
end

--init.Workspace = init.core.Workspace
--init.Infobox = init.core.Infobox
--init.get = init.core.get

return init