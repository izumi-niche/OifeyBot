from oifey.util.file import json_read

file = json_read("oifey/util/help_text.json")

def get_command(key, game):
    if game in file["exclusive_command"] and key in file["exclusive_command"][game]:
        return file["exclusive_command"][game][key]
        
    elif key in file["command"]:
        return file["command"][key]
        
    else:
        print("Help command not found! ", key, game)
        
        return ""
        
def get_arg(key, game):
    if game in file["exclusive_args"] and key in file["exclusive_args"][game]:
        return file["exclusive_args"][game][key]
        
    elif key in file["args"]:
        return file["args"][key]
        
    else:
        print("Help arg not found! ", key, game)
        
        return ""