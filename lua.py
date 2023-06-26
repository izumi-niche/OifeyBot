import lupa
from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
almanac, _ = lua.eval('require("almanac")')
almanac.load_game()

def to_table(d):
    new = {}
    
    for key, value in d.items():
        if isinstance(value, list):
            new[key] = lua.table_from(value)
            
        elif isinstance(value, dict):
            new[key] = to_table(value)
            
        else:
            new[key] = value
            
    return lua.table_from(new)