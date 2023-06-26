import os, random, re
import oifey.util as util
import maji
import discord
import oifey.sql as sql
from lua import almanac


# add alt names to the lexicon
lexicon = {}

if os.path.exists("oifey/lexicon"):
    for root, dirs, files in os.walk("oifey/lexicon"):
        for file_path in files:
            if not file_path.endswith(".json"): continue
            
            file = util.file.json_read(f"{root}/{file_path}")
            
            for key, value in file.items():
                key = util.text.search_text(key)
                
                if not key in lexicon:
                    lexicon[key] = []
                
                [lexicon[key].append(x) for x in value]
        
        break


###############################
class Item:
    def __init__(self, parent, key, value, use_lexicon = True):
        self.parent = parent
        self.id = key
        self.name = value.name
        
        self.display = value["DISPLAY_NAME"] or self.name
        
        def table_array(k):
            result = []
            
            if value[k]:
                for i, p in value[k].items():
                    p = util.text.search_text(p)
                    
                    if not p in result:
                        result.append(p)
            
            return result
            
        self.alt = table_array("ALT_NAME")
        self.hard = table_array("HARD_ALT_NAME")
            
        if use_lexicon:
            lexicon_key = util.text.search_text(self.name)
            
            if lexicon_key in lexicon:
                for x in lexicon[lexicon_key]:
                    if not x in self.alt: self.alt.append(x)

################################
## Search results

class SearchResult:
    def __init__(self, finds, pool, text) -> None:
        self.finds = finds
        self.pool = pool
        self.text = text
        
    def has_results(self) -> bool:
        """If one entry or more has been found"""
        return (len(self.finds) > 0)
        
    def is_multiple(self) -> bool:
        """If it's necessary for the user to pick a entry"""
        return (len(self.finds) > 1)
        
    def get_result_key(self) -> str:
        """Get the result key"""
        return self.finds[0].id
        
    def get_result(self) -> Item:
        return self.finds[0]
        
    def len(self) -> int:
        return len(self.finds)
        
    async def pick_result(self, ctx) -> None:
        view = maji.View(timeout = 60.0)
        embed = maji.Embed(title = "Name | Bot ID")
        select = discord.ui.Select()
        
        choosen = False
        owner = ctx.author.id
        
        async def callback(interaction):
            if interaction.user.id == owner:
                value = interaction.data["values"][0]
                
                self.finds = [self.finds[int(value)]]

                choosen = True
                
                ctx.interaction = interaction
                
                view.stop()
            
        select.callback = callback
        text = ""
        i = 0
        
        for item in self.finds:
            if i == 25:
                break
            
            display = item.display
            
            if ">" in display:
                display = display.split(">")[1]
                
            add = f"**{i + 1}.** {item.display} | {item.id}\n"
            
            select.add_option(label = f"{i + 1}. {display}", value = i)
            
            text += add
            i += 1
            
        embed.set("desc", text)
        
        if len(self.finds) > 25:
            embed.set("footer", f"{len(self.finds)} results found. Maybe try narrowing down the search a bit?")
        
        view.add_item(select)
        await ctx.send(embed=embed, view=view)
        
        await view.wait()
        
class ListSearchResult:
    def __init__(self, found, result, found_word, not_word):
        self.search = result
        self.text = found
        
        self.word = found_word
        self.invalid_word = not_word
        
    def is_found(self):
        return not(self.search is None)
        
    def print(self):
        print(self.search, self.text, self.word, self.invalid_word)

##################################
## Pool

class Pool:
    def __init__(self) -> None:
        self.items = {}
    
    def mix(self, *pools) -> None:
        for pool in pools:
            
            for key, value in pool.items.items():
                if not key in self.items:
                    self.items[key] = value
        
        self.organize()
        
    def section(self, file_path) -> None:
        section = almanac.get(file_path)
        
        self.path = file_path
        
        for key, value in section.entries.items():
            if not isinstance(key, int): continue
            
            key = value
            value = section.get(section, value).data
            
            item = Item(self, key, value)
            self.items[key] = item
            
        self.organize()
            
    def organize(self) -> None:
        """Organize the pool in a series of loops"""
        self.hard = {}
        self.alt = {}
        
        # common function to add hard alt names
        def append_hard(k, v):
            k = util.text.search_text(k)
            
            if k not in self.hard:
                self.hard[k] = v
                return True
                
            else:
                return False
        
        def append_alt(k, v):
            k = util.text.search_text(k)
            
            if not value.id in self.alt:
                self.alt[value.id] = []
                
            alts = self.alt[value.id]
            
            if not k in alts:
                alts.append(k)
            
        # Add IDs first
        for key, value in self.items.items():
            append_hard(value.id, value)
            
        # Add names
        for key, value in self.items.items():
            append_hard(value.name, value)
            
        # Add hard alt names
        for key, value in self.items.items():
            for hard in value.hard:
                append_hard(hard, value)
                
        # Now try alt adding normal alt names, including name and id
        for key, value in self.items.items():
            alts = [value.id, value.name] + value.alt
            
            for x in alts:
                append_alt(x, value)
                
                # try adding as hard alt names
                append_hard(x, value)
                
        
    def search(self, og_text, ctx = None) -> SearchResult:
        # if context exists to get aliases from
        if ctx:
            text = util.text.search_text(og_text, ignore_space = True)
            
            # organize aliases
            aliases = sql.user.get(ctx.author.id).get("alias") or []
            
            if ctx.guild:
                guild = sql.server.get(ctx.guild.id).get("alias") or []
                
                aliases = aliases + guild
            
            for value in aliases: # loop in order
                original = value["og"]["clean"] #original
                alias = value["alias"]["clean"] #alias 
                
                # find alias that is between whitespace or/and
                # has 0-2 numbers in the end
                regex = r"\b" + alias + r"\d{0,2}\b"
                
                regex = re.search(regex, text)
                
                # ^ regex jank to find if the name is in the text
                
                # if it finds it, replace it with the alias
                if regex:
                    new = regex.group(0).replace(alias, original)
                    
                    text = text[:regex.start()] + new + text[regex.end():]
            
            text = util.text.search_text(text)
            
        else:
            text = util.text.search_text(og_text)
        
        finds = []
        
        # Pick a random entry
        if text.startswith("random") and (not(ctx) or ctx.allow_random):
            finds.append(self.random_pick())
            
        #  try searching if it's a hard alt name
        elif text in self.hard:
            finds.append(self.hard[text])
            
        elif text:
            for key, value in self.alt.items():
                for name in value:
                    if text in name:
                        finds.append(self.items[key])
                        break
            
        return SearchResult(finds, self, og_text)
    
    def random_pick(self):
        item = random.choice(list(self.items.keys()))
        
        return self.items[item]
    
    def search_list(self, words, ctx = None) -> ListSearchResult:
        found = ""
        current = ""
        
        result = None
        
        found_word = []
        current_word = []
        
        for word in words:
            # ignore common parameters if there's already one result
            if result and result.len() == 1 and word[0] in ["-", "~", "+", "?", "$"]:
                break
                
            new = current + " " + word
            
            current_word.append(word)
            current = new.strip()
            
            search = self.search(new, ctx)
            
            if search.has_results():
                if (result is None) or (search.len() <= result.len()):
                    result = search
                
                found_word = current_word.copy()
                found = current
                
            
        not_word = []
        
        if len(found_word) != len(words):
            not_word += words[len(found_word):]
            
        return ListSearchResult(found, result, found_word, not_word)
        

loaded_pools = {}

def get_pool(file_path):
    if not file_path in loaded_pools:
        pool = Pool()
        pool.section(file_path)
        
        loaded_pools[file_path] = pool
        
    return loaded_pools[file_path]
    
# TODO: Make a way to store these
def mix_pool(*pools):
    pool = Pool()
    pool.mix(*pools)
    
    return pool