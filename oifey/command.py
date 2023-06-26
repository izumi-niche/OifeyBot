import maji
import oifey.util as util

from oifey.check import key_to_check, LevelCheck, EntryCheck
from oifey.pool import get_pool, SearchResult, mix_pool
from lua import almanac, lua, to_table

DEFAULT_KEYS = ["-", "--", "~~", "~"]

common_pars = {
    "personal": ["base"],
    "secret": ["sickomode", "sicko"],
    "class": ["job"],
    "hp": ["health", "robust", "sickly"],
    "atk": ["attack"],
    "str": ["strength", "strong", "weak"],
    "mag": ["magic", "clever", "dull"],
    "def": ["defence", "defense", "sturdy", "fragile"],
    "lck": ["luck", "lucky", "unlucky"],
    "res": ["resistance", "calm", "excitable"],
    "spd": ["speed", "quick", "slow"],
    "skl": ["skill", "deft", "clumsy"],
    "lunatic": ["lm", "lunaticmode"],
    "hard": ["hm", "hardmode"],
    "normal": ["nm", "normalmode"],
    "maniac": ["mm", "maniacmode"],
    "maddening": ["mm", "maddeningmode"]
}

class PickEntry:
    def __init__(self, options, key, search):
        self.options = options
        self.key = key
        self.search = search


class Command:
    def __init__(self, parent, name, data):
        self.parent = parent

        # id and command name
        self.name = name

        # lua table to summon
        self.table = almanac.game

        for key in data["lua"]:
            self.table = self.table[key]

        self.main = get_pool(data["main"])

        # default embed color
        self.color = self.parent.color

        """Parameters
        Both for slash commands and classic commands"""
        self.parameters = []

        for key, value in key_to_check.items():
            if key in data:

                for x, y in data[key].items():
                    self.parameters.append(value(x, y, self))

        # main parameter
        self.parameters.append( EntryCheck("name", self.main, self))

        # level
        if "level" in data:
            par = LevelCheck("level", data["level"], self)
            self.parameters.append(par)
            self.level = par

        else:
            self.level = None

        add = data.get("add")
        self.multiple = data.get("multiple") or {}
        
        if add:
            self.add = {}

            if not isinstance(add, list):
                par = self.get_parameter(add)
                
                self.add[par.pool] = add
                self.add_pool = par.pool
                
            else:
                self.add = {}
                
                for x in add:
                    par = self.get_parameter(x)
                    
                    self.add[par.pool] = x
                    
                self.add_pool = mix_pool(*list(self.add.keys()))
            
        else:
            self.add = False
        
        self.start_keys = DEFAULT_KEYS.copy()
        
        self.prefix = data.get("prefix") or {}
        
        for key, value in self.prefix.items():
            if not value in self.start_keys:
                self.start_keys.append(value)
            
            self.get_parameter(key).prefix = value

        self.comma = data.get("comma")
        
        self.exclamation = data.get("exclamation")
        self.required = data.get("required") or []
        
        self.pass_context = data.get("pass_context")
        
        # Parameter alt names
        self.par = data.get("par") or {}
        b = data.get("bool") or {}

        self.par = {**b, **self.par}
        
        for key, value in common_pars.items():
            if key in self.par:
                for x in value:
                    if not x in self.par[key]: self.par[key].append(x)
                    
            else:
                self.par[key] = value
        
        # slash command = game_name [group] + command_name
        if not data.get("NO_SLASH"):
            maji.commands.add_slash(self.slash_callback, 
            name=self.name, group=self.parent.name, 
            options=self.get_slash_options(), 
            desc= self.parent.name.upper() + " | " + util.help.get_command(self.name, self.parent.name),
            group_name=self.parent.display)
            
            self.slash_command = True
            
        else:
            self.slash_command = False
    
    def has_slash(self):
        return self.slash_command
        
    def has_classic(self):
        return True
        
    def get_parameter(self, name):
        for par in self.parameters:
            if par.key == name:
                return par
                
        return None
    
    async def classic_callback(self, ctx):
        if not ctx.content.strip():
            await self.parent.help_command(ctx)
            
            return
            
        options, word = await self.find_entry(ctx)
        
        if options is None:
            return
            
        await self.callback_organize(ctx, options, word)
        
    async def find_entry(self, ctx, content = None) -> None:
        if content is None:
            content = ctx.content
        
        options = {}
        msg = content.strip()
        
        if self.comma and "," in msg and msg[0] != ",":
            comma = [x.strip() for x in msg.split(",")]
            
            msg = comma[0]
            comma.pop(0)
            
            while "" in comma: comma.remove("")
            
            if comma:
                options["COMMA"] = comma
                
        if self.exclamation and "!" in msg and msg[0] != "!":
            exclamation, msg = [x.strip() for x in msg.split("!", 1)]
            
            if exclamation:
                options["EXCLAMATION"] = exclamation

        msg = util.text.splice_spaces(msg)
        lsr = self.main.search_list(msg, ctx)
        
        if lsr.is_found():
            sr = lsr.search
            
            if sr.is_multiple():
                await sr.pick_result(ctx)
                
            result = sr.get_result()
            
            options["name"] = result.id
            
            return options, lsr.invalid_word
            
        else:
            await self.parent.entry_error(ctx, self.name, lsr.invalid_word)
            return None, None
        

    async def callback_organize(self, ctx, options, words) -> None:
        """Step 2 of callback"""
        options, words = self.parse_parameters(ctx, options, words)
        
        if self.comma and "COMMA" in options:
            options[self.comma["name"]] = options["COMMA"]
            options.pop("COMMA")
            
        await self.slash_callback(ctx, options)
        
    def parse_parameters(self, ctx, options, words):
        result, words = util.text.get_parameters(words, self.parameters, self.start_keys)
        
        # Personal thing
        for x in ["base", "personal"]:
            if x in words:
                options["personal"] = True
                words.remove(x)
                
                break

        # Check parameters
        for value in result:
            # Replace Alt Result keys with the "main" ones
            for x, y in self.par.items():
                if value.key in y:
                    value.key = x
                    break
                    
            def do_thing():
                for par in self.parameters:
                    # if the parameter key is not the same, and it's not using the correct prefix
                    if par.check_key(value.key, options) and (not(par.key in self.prefix) or 
                    (par.key != value.key and self.prefix[par.key] == value.start)):
                        return par

                return None

            par = do_thing()
            
            if not par is None:
                # key, value = par.get_classic(value)

                # if not key is None:
                    # options[key] = value

                par.get_classic(value, options)
        
        # Check for exclamation
        if self.exclamation and "EXCLAMATION" in options:
            options[self.exclamation] = options["EXCLAMATION"]
            options.pop("EXCLAMATION")
            
        # Check for add
        if self.level:
            result = []
            
            while len(words) > 0:
                found = False
                
                def check(i):
                    try:
                        return int(i)
                        
                    except ValueError:
                        return None
                
                index = -1
                
                for word in words:
                    index += 1
                    
                    if "/" in word:
                        word = [x.strip() for x in word.split("/")]
                        while "" in word: word.remove("")
                        
                        popped = False
                        
                        for x in word:
                            find = check(x)

                            if find is not None:
                                result.append(find)
                                found = True
                                
                                if not popped:
                                    words.pop(index)
                                    popped = True
                        
                    else:
                        find = check(word)
                        
                        if find is not None:
                            result.append(find)
                            found = True
                            words.pop(index)
                    
                    if found: break
                    
                if not found:
                    break
            
            if len(result) > 0:
                options["level"] = result
        
        # Check for add
        if self.add:  
            while len(words) > 0:
                lsr = self.add_pool.search_list(words, ctx)
                
                if lsr.is_found():
                    search = lsr.search
                    
                    result = search
                    
                    if not result.is_multiple():
                        result = search.get_result().id
                    
                    parameter_key = self.add[search.get_result().parent]
                    
                    if parameter_key in self.multiple:
                        if not parameter_key in options:
                            options[parameter_key] = []
                            
                        options[parameter_key].append(result)
                        
                    else:
                        options[parameter_key] = result
                        
                    words = lsr.invalid_word
                
                else:
                    break
                    
        print(options, words)
        return options, words
    
    async def parse_slash(self, ctx, options = {}, raise_error = False):
        """Slash command entry point"""
        # Split multiple with commas
        for key, value in self.multiple.items():
            if key in options and isinstance(options[key], str) and "," in options[key]:
                result = [x.strip() for x in options[key].split(",")]
                
                while "" in result: result.remove("")
                
                options[key] = result
        
        # Check if they are valid
        # use keys() intead of items() to be able to delete stuff
        for key in options.keys():
            value = options[key]

            for par in self.parameters:
                if par.check_key(key):
                    if isinstance(par, EntryCheck):
                        par.get_slash(value, options, ctx)
                        
                    else:
                        par.get_slash(value, options)
                        
        # Averages = Last class needs to be in the class key, everything else in job_averages
        if "class" in options and isinstance(options["class"], list):
            jobs = options["class"]
            
            options["class"] = jobs[-1]
            jobs.pop(-1)
            
            if len(jobs) > 0:
                options["job_averages"] = jobs
                
        pick_entry = []
        
        # check if options has any search results
        for key, value in options.items():
            if isinstance(value, SearchResult):

                # pick entry and do stuff if there's multiple
                if value.has_results():
                    pick = PickEntry(options, key, value)
                    pick_entry.append(pick)

                # error out if nothing has been found
                else:
                    if raise_error:
                        raise ValueError("Entry not found!")
                        
                    else:
                        await self.parent.entry_error(ctx, key, value, options)
                        return None, None
                        
            elif isinstance(value, list):
                i = 0
                
                for x in value:
                    if not isinstance(value, SearchResult):
                        pass
                        
                    elif x.has_results():
                        pick = PickEntry(value, i, x)
                        pick_entry.append(pick)
                        
                    else:
                        if raise_error:
                            raise ValueError("Entry not found!")
                        
                        else:
                            await self.parent.entry_error(ctx, key, value.text, options)
                            return None, None

                    i += 1
        
        return options, pick_entry
        
    async def slash_callback(self, ctx, options = {}) -> None:
        options, pick_entries = await self.parse_slash(ctx, options)
        
        if options is None:
            return
        
        # Comma aka the thing used for detecting multiple chars for averages
        if self.comma is not None and self.comma["name"] in options:
            comma =  self.comma["name"]
            value = options[comma]
            
            if isinstance(value, str):
                value = [x.strip() for x in value.split(",")]
                while "" in value: comma.remove("")
                
            result = []
            value = value[:self.comma["size"] - 1]
            
            for x in value:
                new_options, new_words = await self.find_entry(ctx, x)
                
                if new_options is None:
                    return
                
                new_options, new_words = self.parse_parameters(ctx, new_options, new_words)
                
                new_options, new_pick = await self.parse_slash(ctx, new_options)
                
                if new_options is None:
                    return
                
                for pick in new_pick:
                    await pick.search.pick_result(ctx)
                    
                    pick.options[pick.key] = pick.search.get_result().id
                
                table = self.summon(new_options)
                result.append(table)
                
            if len(result) > 0:
                options[comma] = result
        
        for pick in pick_entries:
            await pick.search.pick_result(ctx)
            
            pick.options[pick.key] = pick.search.get_result().id
        
        # context
        if self.pass_context:
            if ctx.author.display_name:
                options["context"] = ctx.author.display_name.strip()
                
            else:
                options["context"] = "Kiran"
            
        # Summon table here
        table = self.summon(options)
        infobox = table.show(table)

        def set_color(box):
            if self.color and not box.has_set(box, "color"):
                box.set(box, "color", self.color)

        if infobox.has_pages:
            embed = maji.MultiEmbed()

            for i, p in infobox.pages.items():
                set_color(p)

            embed.pagebox(infobox)

        else:
            embed = maji.Embed()

            set_color(infobox)
            embed.infobox(infobox)
            
        await embed.send(ctx)

    def summon(self, options = {}):
        """Get the lua table with the options organized and set"""
        new = options.copy()
        
        print(self.parent.name, self.name)
        table = self.table.new(self.table, new["name"])
        new.pop("name")
        
        # filter out empty lists or dicts
        for key in options.keys():
            value = options[key]

            if (isinstance(value, list) or isinstance(value, dict)) and not value:
                options.pop(key)
                
            elif isinstance(value, SearchResult):
                options[key] = value.get_result_key()

        new = to_table(new)
        table.set_options(table, new)

        return table

    def get_slash_options(self) -> dict:
        game = self.parent.name
         
        required = [
            {
                "name": "name",
                "description": util.help.get_command(self.name, game),
                "type": 3,
                "required": True
            }
        ]
        non_required = []
        
        for par in self.parameters:
            if par.key == "name": continue

            result = par.slash_option()
            
            result["required"] = par.key in self.required
            
            result["description"] = util.help.get_arg(par.key, game)
            
            if result["required"]:
                required.append(result)
                
            else:
                non_required.append(result)

        if self.comma is not None:
            comma = {
                "name": self.comma["name"],
                "description": "Compare two units or more.",
                "type": 3,
                "required": False
            }

            non_required.append(comma)

        return required + non_required
        
    def get_help(self):
        title = f"{self.parent.display} | {self.name.title()}"
        desc = util.help.get_command(self.name, self.parent.name) + "\n\n"
        
        desc += f"`{self.parent.name} [{self.name}]`\n"
        desc += f"`{self.parent.name} {self.name} [{self.name}]`"
        
        if self.comma:
            desc += "\n\nTo compare units, separate them by using `,`, like so:\n"
            desc += f"`{self.parent.name} [{self.name}], [{self.name}]`"
        
        embed = maji.Embed(title = title, desc = desc)
        
        for par in self.parameters:
            if par.key == "name": continue
            
            value = util.help.get_arg(par.key, self.parent.name)
            
            example = par.classic_example()
            
            if example:
                if not "`" in example:
                    example = "`" + example + "`"
                    
                value += f"\n***Ex.***\n{example}"
            
            embed.add_field(f"<:manual:877378772393922672>{par.key.title()}", value, True)
        
        embed.set("footer", "Slash commands are also available, type / to see a list of them.")
        return embed