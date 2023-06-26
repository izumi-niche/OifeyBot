import os
import oifey.util as util
from lua import almanac

def check_command(value):  
    for command, command_value in value["data"].items():
        table = almanac.game
        
        for x in command_value["lua"]:
            table = table[x]
            
        main = command_value["main"]
        
        for x, y in util.file.json_read(main).items():
            if not y: continue
            
            print(main, x)
            res = table.new(table, x)
            res = res.doit(res)
    
def test():
    for root, dirs, files in os.walk("oifey/modules"):
        for file in files:
            if file == "mystery.json": continue
            
            path = root + "/" + file
            
            file = util.file.json_read(path)
            
            for x, y in file.items():
                check_command(y)
        
        break