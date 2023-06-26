import maji

import oifey.sql as sql
import oifey.util as util

embed_color = 0xe364d0

search_text = util.text.search_text

character_min = 3
character_max = 30

alias_limit = 30

# ADD
async def add_alias(ctx, table, name, og, alias):
    row = table.get(name)
    if not "alias" in row: row["alias"] = []

    if len(row["alias"]) >= alias_limit:
        embed = maji.Embed(title = "Alias limit reached!", desc = "Maybe try removing old ones?", color = embed_color)
        
        await ctx.send(embed=embed)
        
        return
    
    def remove(data):
        for x in sql.banned_words:
            data = data.replace(x, "")
            
        return data

    og = remove(og)
    alias = remove(alias)
        
    def check(data):
        clean = search_text(data, ignore_space = True)
        
        # character size limits
        return len(clean) >= character_min and len(clean) <= character_max
        
    if check(og) and check(alias):
        add = {
            "og": {"clean": search_text(og, ignore_space = True), "display": og},
            "alias": {"clean": search_text(alias, ignore_space = True), "display": alias},
        }
        
        row["alias"].append(add)
        
        table.update(name, row)
        
        embed = maji.Embed(title = "Success", desc = "Alias added!", color = embed_color)
        await ctx.send(embed=embed)
        
    else:
        embed = maji.Embed(title = "Error", desc = f"Your alias couldn't be added. Please check if it is at least {character_min} characters, and most special characters are ignored!", color = embed_color)
        
        await ctx.send(embed=embed)
      
# SHOW
async def show_alias(ctx, table, name):
    row = table.get(name)
    row = row.get("alias") or []
    
    if not row:
        embed = maji.Embed(title = "No aliases yet!", desc = "There's still no aliases here.\nIf you're looking at adding alias for yourself, use /alias user.\nIf you're looking at adding aliases for a server, only people that can manage messages can add/remove them, with the command being /alias server.", color = embed_color)
        
        await ctx.send(embed=embed)
        
    else:
        text = ""
        
        i = 1
        for value in row:
            og = value["og"]["display"]
            alias = value["alias"]["display"]
            
            text += f"**{i}.** `{alias}` is an alias to `{og}`\n"
            
            i += 1
            
        embed = maji.Embed(title = f"Alias {len(row)}/{alias_limit}", desc = text, footer = "Type / if you want to add more or remove them!", color = embed_color)
        
        await ctx.send(embed=embed)

# REMOVE  
async def remove_alias(ctx, table, name, index = 0):
    row = table.get(name)
    if not "alias" in row: row["alias"] = []
    
    alias = row["alias"]
    
    index = max(index - 1, 0)
    
    if alias and index < len(alias):
        alias.pop(index)
        
        table.update(name, row)
        
        embed = maji.Embed(title = "Success", desc = "Alias removed!", color = embed_color)
        
        await ctx.send(embed=embed)
        
    else:
        embed = maji.Embed(title = "Invalid index!", desc = "It's too high, or maybe you didn't even add any aliases yet.", color = embed_color)
        
        await ctx.send(embed=embed)
    
# Command funcs
# user
async def user_add(ctx, options = {}):
    await add_alias(ctx, sql.user, ctx.author.id, options["name"], options["alias"])
    
async def user_show(ctx, options = {}):
    await show_alias(ctx, sql.user, ctx.author.id)
    
async def user_remove(ctx, options = {}):
    await remove_alias(ctx, sql.user, ctx.author.id, options["index"])
    
# server
async def server_add(ctx, options = {}):
    if ctx.guild is None or not ctx.channel.permissions_for(ctx.author).manage_messages: return
    
    await add_alias(ctx, sql.server, ctx.guild.id, options["name"], options["alias"])

async def server_show(ctx, options = {}):
    if ctx.guild is None: return
    
    await show_alias(ctx, sql.server, ctx.guild.id)

async def server_remove(ctx, options = {}):
    if ctx.guild is None or not ctx.channel.permissions_for(ctx.author).manage_messages: return
    
    await remove_alias(ctx, sql.server, ctx.guild.id, options["index"])
    

# Options
add_options = [
    {
        "name": "name",
        "description": "Original name of a thing.",
        "type": 3,
        "required": True
    },
    {
        "name": "alias",
        "description": "Alias for the thing.",
        "type": 3,
        "required": True
    }
]

remove_options = [
    {
        "name": "index",
        "description": "Which alias to remove (you can see the index in the show command).",
        "type": 4,
        "required": True
    }
]

# Add Commands
# user
maji.commands.add_slash(user_add, "add", desc="User | Adds an alias for something.", group="alias", subgroup="user", options=add_options)

maji.commands.add_slash(user_show, "show", desc="User | Shows all active aliases.", group="alias", subgroup="user")

maji.commands.add_slash(user_remove, "remove", desc="User | Removes an alias.", group="alias", subgroup="user", options=remove_options)

# server
maji.commands.add_slash(server_add, "add", desc="Server | Adds an alias for something.", group="alias", subgroup="server", options=add_options)

maji.commands.add_slash(server_show, "show", desc="Server | Shows all active aliases.", group="alias", subgroup="server")

maji.commands.add_slash(server_remove, "remove", desc="Server | Removes an alias.", group="alias", subgroup="server", options=remove_options)