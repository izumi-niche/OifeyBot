import maji

import oifey.util as util

from oifey.command import Command
from oifey.pool import mix_pool, SearchResult
from lua import almanac

modules = {}

class Module:
    def __init__(self, name, data) -> None:
        self.name = name
        self.data = data
        
        self.display = data["name"]

        self.classic = {}
        
        # special commands (most joke ones)
        self.special = {}
        
        # default color
        self.color = data.get("color")
        if self.color: self.color = int(self.color, 16)

        # commands are created here
        for key, value in self.data["data"].items():
            # command object
            command = Command(self, key, value)

            self.classic[key] = command

        # which main pools are attached to which commands
        self.pools_children = {}
        
        # make sure commands don't overlap
        used_paths = []
        
        for key, value in self.classic.items():
            pool = value.main
            
            if not pool.path in used_paths:
                self.pools_children[pool] = value
                used_paths.append(pool.path)

        # mixed pool with all of them
        self.mix = mix_pool(*list(self.pools_children.keys()))

        # default classic command to go to if it's not specified
        self.default = self.classic[data["default"]]
        
        alias = data.get("alias") or []
        
        maji.commands.add_classic(self.callback, self.name, alias=alias)
        
    async def callback(self, ctx) -> None:
        msg = ctx.content.strip()
        
        if not msg:
            await self.help_command(ctx)
            
            return
        
        elif msg.lower() in self.special:
            embed = await self.special[msg.lower()](ctx)
            
            if embed:
                self.apply_color(embed)
            
                await embed.send(ctx)
            return
            
        call = self.find_command

        if " " in msg:
            # get the first word of it
            first, rest = msg.split(" ", 1)

            if first.lower() in self.classic:
                call = self.classic[first.lower()].classic_callback
                ctx.content = rest

        await call(ctx)
        
    async def help_command(self, ctx) -> None:
        embed = maji.MultiEmbed()
        
        for key, value in self.classic.items():
            page = value.get_help()
            self.apply_color(page)
            
            embed.button(len(embed.pages), label = value.name.title())
            embed.append(page)
        
        if len(embed.pages) > 1:
            await embed.send(ctx)
            
        else:
            await embed.pages[0].send(ctx)
        
    async def find_command(self, ctx) -> None:
        options = {}
        msg = ctx.content.strip()

        if "," in msg and msg[0] != ",":
            comma = [x.strip() for x in msg.split(",")]
            
            msg = comma[0]
            comma.pop(0)
            
            while "" in comma: comma.remove("")
            
            if comma:
                options["COMMA"] = comma
                
        # ignore only for FEH
        if self.name != "feh" and "!" in msg and msg[0] != "!":
            exclamation, msg = [x.strip() for x in msg.split("!", 1)]
            
            if exclamation:
                options["EXCLAMATION"] = exclamation

        msg = util.text.splice_spaces(msg)

        lsr = self.mix.search_list(msg, ctx)

        if lsr.is_found():
            sr = lsr.search

            if sr.is_multiple():
                await sr.pick_result(ctx)

            result = sr.get_result()
            command = self.pools_children[result.parent]

            options["name"] = result.id

            await command.callback_organize(ctx, options, lsr.invalid_word)

        else:
            await self.entry_error(ctx, self.name, msg)
            
    async def entry_error(self, ctx, name, search, options = {}):
    
        def get_text(stuff):
            if isinstance(stuff, SearchResult):
                return stuff.text
            
            elif isinstance(stuff, list):
                text = ""
                
                for x in stuff:
                    text += get_text(x) + " "
                    
                return text[:-1]
                
            else:
                return str(stuff)
        
        embed = maji.Embed(title=f"❌ No entries with \"{get_text(search)}\" found in {name.upper()}!", desc = "Check if you typed something wrong, or if you're using the right command.")
        
        if options:
            text = ""
            
            for key, value in options.items():
                text += f"`{key}`: `{get_text(value)}`\n"
                
            embed.add_field("Options", text, True)
            
        # add commands
        text = ""
        
        for key, value in self.classic.items():
            text += f"`@Oifey {self.name} {key}`\n"
            
        embed.add_field("You might be looking for...", text, True)
        
        self.apply_color(embed)
        
        if ctx.interaction:
            await embed.send(ctx, ephemeral=True)
            
        else:
            await embed.send(ctx, delete_after = 120.0)
        
    def apply_color(self, embed):
        if self.color:
            embed.set("color", self.color)

def get_module_file(file_path):
    file = util.file.json_read(file_path)

    for key, value in file.items():
        module = Module(key, value)

        modules[key] = module
