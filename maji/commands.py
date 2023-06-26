import discord
import asyncio
from discord.app_commands import Group, Command

from maji.context import MajiContext

from client import client


DEFAULT_COMMAND = ["o!", "O!"]


class Classic:
    """One classic command via text"""
    def __init__(self, name, function, alias=[]) -> None:
        self.name = name.lower()
        self.function = function
        self.alias = [x.lower() for x in alias]
        
    async def summon(self, ctx) -> None:
        await self.function(ctx)
        
    def check(self, msg) -> bool:
        msg = msg.lower()
        return (msg == self.name or msg in self.alias)


class Commands:
    """Custom-ish command system
    Helps make some hacky stuff less hacky, and avoid headache when creating a bunch of commands"""
    
    def __init__(self, bot) -> None:
        self.bot = bot
        self.bot.maji = self
        
        self.prefix = DEFAULT_COMMAND
        
        self.classic_data = {}
        
        self.slash_payload = {}
        self.slash_func = {}
        
        self.background = set()
        
    ###############################################
    ## Classic commands
    ###############################################
    
    def add_classic(self, function, name, alias=[]) -> Classic:
        """Classic commands via text"""
        classic = Classic(name, function, alias=alias)
        
        self.classic_data[name] = classic
        
        return classic
        
    def classic(self, name, **kwargs):
        """Decorator for classic commands"""
        
        def wrapper(func):
            self.add_classic(func, name, **kwargs)
                
            return func
        
        return wrapper
    
    async def check(self, ctx) -> None:
        """Check for classic in message"""
        
        if ctx.author.id == self.bot.user.id or ctx.author.bot: return

        msg = ctx.content.strip()
        
        for prefix in self.prefix:
            if msg.startswith(prefix):
                msg = msg[len(prefix):]
                
                msg = msg.split(" ", 1)
                
                command_check = msg[0].strip()
                
                if len(msg) == 1:
                    msg = ""
                    
                else:
                    msg = msg[1].strip()
                
                for key, value in self.classic_data.items():
                    if value.check(command_check):
                        ctx.content = msg
                        
                        maji_context = MajiContext(ctx)
                        
                        await self.task(value.summon, maji_context)
                        
                        break
                
                break
    
    ###############################################
    ## Slash commands
    ###############################################
    def add_slash(self, func, name, desc="PLACEHOLDER", options = [], group=None, subgroup=None, group_name=".") -> dict:
    
        class Group:
            def __init__(self, name, t = None):
                self.name = name
                self.commands = {}
                self.type = t
                
            def get(self):
                result = {
                    "name": self.name,
                    "description": group_name,
                    "options": []
                }
                
                if self.type:
                    result["type"] = self.type
                
                options = result["options"]
                
                for key, value in self.commands.items():
                    if isinstance(value, dict):
                        options.append(value)
                        
                    else:
                        options.append(value.get())
                        
                return result
        
        add_to = self.slash_payload
        func_to = self.slash_func
        
        if group:
            if not group in add_to:
                add_to[group] = Group(group)
                func_to[group] = {}
                
            add_to = add_to[group].commands
            func_to = func_to[group]
            
            if subgroup:
                if not subgroup in add_to:
                    add_to[subgroup] = Group(subgroup, 2)
                    func_to[subgroup] = {}
                    
                add_to = add_to[subgroup].commands
                func_to = func_to[subgroup]
        
        add_to[name] = {
            "name": name,
            "description": desc,
            "type": 1,
            "options": []
        }
        
        [add_to[name]["options"].append(x) for x in options]
        
        func_to[name] = func
        
        return add_to[name]
    
    def slash(self, name, *args, **kwargs):
        """Decorator for slash commands"""
        
        def wrapper(func):
            self.add_slash(func, name, *args, **kwargs)
            
            return func
            
        return wrapper
        
    async def check_slash(self, interaction) -> None: 
        def check(data, funcs):
            func = funcs[data["name"]]
            
            if isinstance(func, dict):
                return check(data["options"][0], func)
                
            else:
                return func, data
        
        func, data = check(interaction.data, self.slash_func)
        
        options = {}
        
        if "options" in data:
            for op in data["options"]:
                options[op["name"]] = op["value"]
                
        context = MajiContext(interaction)
        
        await self.task(func, context, options)
    
    async def task(self, func, *args, **kwargs):
        await func(*args, **kwargs)
    
        #task = asyncio.create_task(func(*args, **kwargs))
        
        #self.background.add(task)
        
        #task.add_done_callback(self.background.discard)
    
    async def sync(self, guild = None) -> dict:
        payload = []
        
        for key, value in self.slash_payload.items():
            if isinstance(value, dict):
                payload.append(value)
                
            else:
                payload.append(value.get())
        
        if guild is None:
            data = await self.bot.http.bulk_upsert_global_commands(self.bot.application_id, payload=payload)
            
        else:
            data = await self.bot.http.bulk_upsert_guild_commands(self.bot.application_id, guild, payload=payload)
        
        return data

commands = Commands(client)