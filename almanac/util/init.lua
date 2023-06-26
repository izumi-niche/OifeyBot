local init = {
    text = require("almanac.util.text"),
    file = require("almanac.util.file"),
    math = require("almanac.util.math"),
    misc = require("almanac.util.misc"),
    emoji = require("almanac.util.emoji")
}

-- shortcuts
init.table_stats = init.text.table_stats
init.title = init.text.title
init.json_read = init.file.json_read
init.ordered_table = init.misc.ordered_table
init.round = init.math.round
init.floor = init.math.floor
init.ciel = init.math.ciel
init.round_closest = init.math.round_closest
init.copy = init.misc.copy
init.inspect = init.misc.inspect
init.pairs_in_table = init.misc.pairs_in_table
init.table_has = init.misc.table_has
init.value_in_table = init.misc.value_in_table

init.debug = true

return init
