import oifey.pool as pool
import random


class BaseCheck:
    def __init__(self, key, value, parent, allow_value = True):
        self.key = key
        self.value = value
        self.parent = parent
        
        # If it allows, this can get a value from parsing
        self.allow_value = allow_value
        
        self.prefix = None
        
    def check_key(self, key, options = {}):
        return key == self.key
        
    def get_classic(self, parameter, options):
        options[self.key] = parameter.value
        
    def slash_option(self):
        result = {
            "name": self.key,
            "description": "PLACEHOLDER",
            "type": 3,
            "required": False
        }
        
        return result
        
    def get_slash(self, value, options):
        pass
        
    def parse_value_keys(self):
        return [self.key]
        
    def classic_example(self):
        return None
        
    def get_prefix(self):
        if self.prefix:
            return self.prefix
            
        else:
            return "-"

stats_keys = {
    "+": "add",
    "-": "add",
    "=": "equal"
}

spectrum_boost = ["str", "mag", "atk", "skl", "lck", "spd", "def", "res", "dex"]

class StatsCheck(BaseCheck):
    def __init__(self, key, value, parent):
        super().__init__(key, value, parent)
        
        self.value = self.value + ["spec", "spectrum"]
        
    def check_key(self, key, options = {}):
        return key == self.key or self.is_stat(key)
    
    def get_classic(self, parameter, options):
        if self.is_stat(parameter.key):
            self.add_to_options(parameter.key, options)
            
    def get_slash(self, value, options):
        if isinstance(value, str):
            for x in value.split(","):
                x = x.strip().lower()
                
                if self.is_stat(x):
                    self.add_to_options(x, options)
            
    def add_to_options(self, key, options):
        key, value, task = self.check_stat_key(key)
        value = self.check(value)
        
        if not self.key in options or not isinstance(options[self.key], dict):
            options[self.key] = {}
        
        task_value = stats_keys[task]
        
        if not task_value in options[self.key]:
            options[self.key][task_value] = {}
        
        if task == "-":
            value = value * -1
        
        def apply_mod(k, v):
            op = options[self.key][task_value]
            
            if k in op:
                op[k] += v
                
            else:
                op[k] = v
        
        # spectrum applies boost to all stats (except hp)
        if key in ["spec", "spectrum"]:
            for stat in spectrum_boost:
                # Don't apply atk boost if str and mag exists
                if stat in self.value and (stat != "atk" or ("str" not in self.value and "mag" not in self.value)):
                    apply_mod(stat, value)
            
        else:
            apply_mod(key, value)
    
    def is_stat(self, key):
        key, value, task = self.check_stat_key(key)
        
        return (key is not None)
        
    def check_stat_key(self, key):
        for x in stats_keys:
            if x in key:
                test_key, test_value = [y.strip() for y in key.split(x, 1)]
                
                if test_key in self.value and self.check(test_value) is not None:
                    return test_key, test_value, x
                    
        return None, None, None
            
    def check(self, value):
        try:
            value = int(value.strip())
            
            value = min(value, 99)
            value = max(value, -99)
            
            return value
            
        except ValueError:
            return None

    def classic_example(self):
        text = ""
        i = 0
        
        for x, y in zip(self.value, ["+", "-", "="]):
            text += f"{self.get_prefix()}{x}{y}5 "
            
        return text[:-1]

class ChoiceCheck(BaseCheck):
    def __init__(self, key, value, parent):
        super().__init__(key, value, parent)
        
        self.valid = []
        
        for key, value in self.value.items():
            self.valid.append(value)
        
    def check_key(self, key, options = {}):
        return self.key not in options and (key == self.key or key in self.valid)
        
    def get_classic(self, parameter, options):
        if parameter.key in self.valid:
            options[self.key] = parameter.key
            
        elif parameter.value in self.valid:
            options[self.key] = parameter.value
        
    def slash_option(self):
        result = super().slash_option()
        
        result["choices"] = []
        
        for key, value in self.value.items():
            choice = {"name": key, "value": value}
            
            result["choices"].append(choice)
        
        return result
        
    def classic_example(self):
        text = f"`{self.get_prefix()}{random.choice(self.valid)}`\n**Valid Values**: "
        
        for x in self.valid:
            text += f"`{self.get_prefix()}{x}` "
            
        return text[:-1]


class ListCheck(BaseCheck):
    def check_key(self, key, options = {}):
        return key == self.key or key in self.value
        
    def get_classic(self, parameter, options):
        if parameter.key in self.value:
            if not self.key in options:
                options[self.key] = []
            
            if not parameter.key in options[self.key]:
                options[self.key].append(parameter.key)
            
        elif parameter.value in self.value:
            options[self.key] = [parameter.value]
            
    def get_slash(self, value, options):
        if isinstance(value, str):
            result = []
            
            for x in value.split(","):
                x = x.strip().lower()
                
                if x in self.value:
                    result.append(x)
                    
            if len(result) > 0:
                options[self.key] = result
                
    def classic_example(self):
        text = f"`{self.get_prefix()}{random.choice(self.value)}`\n**Valid Values**: "
        
        for x in self.value:
            text += f"`{self.get_prefix()}{x}` "
            
        return text[:-1]


class IntCheck(BaseCheck):
    def slash_option(self):
        result = super().slash_option()
        
        result["type"] = 4
        
        return result
    
    def check_key(self, key, options = {}):
        return key == self.key or self.check(key) is not None
        
    def get_classic(self, parameter, options):
        if self.check(parameter.key) is not None:
            options[self.key] = self.check(parameter.key)
            
        elif self.check(parameter.value) is not None:
            options[self.key] = self.check(parameter.value)
    
    def get_slash(self, value, options):
        options[self.key] = self.check(value)
        
    def check(self, i):
        try:
            i = int(i)
            i = max(self.value[0], i)
            i = min(self.value[1], i)
            
            return i
            
        except:
            return None
            
    def classic_example(self):
        return f"{self.get_prefix()}{random.randint(self.value[0] + 1, self.value[1])}"


class EntryCheck(BaseCheck):
    def __init__(self, key, value, parent):
        super().__init__(key, value, parent)
        
        if isinstance(value, str):
            self.pool = pool.get_pool(value)
            
        else:
            self.pool = value
    
    def get_slash(self, value, options, ctx = None):
        if isinstance(value, list):
            options[self.key] = [self.check(x, ctx) for x in value]

        else:
            options[self.key] = self.check(value, ctx)

    def check(self, value, ctx = None):
        if isinstance(value, pool.SearchResult):
            return value
            
        result = self.pool.search(value, ctx)
        
        if result.has_results():
            if result.is_multiple():
                return result
                
            else:
                return result.get_result_key()
                
        else:
            return result
            
    def classic_example(self):
        item = self.pool.random_pick()
        
        text = item.display
        
        if self.parent.add and self.key in self.parent.add.values():
            return f"[{self.parent.name}] {text}"
            
        elif self.parent.exclamation and self.parent.exclamation == self.key:
            return f"{text}![{self.parent.name}]"
            
        else:
            return f"{self.get_prefix()}{self.key} {text}"


class BoolCheck(BaseCheck):
    def __init__(self, key, value, parent):
        super().__init__(key, value, parent)
        
        self.allow_value = False
        
    def get_classic(self, parameter, options):
        options[self.key] = True
        
    def slash_option(self):
        result = super().slash_option()
        
        result["type"] = 5
        
        return result
        
    def classic_example(self):
        return f"{self.get_prefix()}{self.key}"


class LevelCheck(BaseCheck):
    def __init__(self, key, value, parent):
        super().__init__(key, value, parent)

        if isinstance(self.value, dict):
            new = []

            for i in range(self.value["size"]):
                new.append(self.value["lvl"])

            self.value = new

    def get_slash(self, value, options):
        
        if isinstance(value, str):
            result = self.parse(value)
            
            if result:
                options[self.key] = self.check(result)
            
            # delete if it's empty
            else:
                options.pop(self.key)
                
        else:
            options[self.key] = self.check([max(1, min(x, self.value[0])) for x in value])
    
    def check(self, value):
        "Check to see if it's not over the limit"
        
        if len(value) > len(self.value):
            return value[:len(self.value)]
            
        else:
            return value
            
    def parse(self, value):
        result = []

        value = value.replace(" ", "/")
            
        # try to covert to int, if it doesn't work just ignore them
        for i in value.split("/"):
            try:
                i = int(i.strip())
                
                i = max(i, 1)
                i = min(i, self.value[len(result)])
                
                result.append(i)
                
                if len(result) == len(self.value):
                    break
                
            except ValueError:
                pass
                
        return result
        
    def classic_example(self):
        repeat = min(len(self.value), 3)
        
        text = ""
        
        last = 999
        for i in range(repeat):
            number = random.randint(1, self.value[i])
            
            number = min(last, number)
            last = number
            
            text += f"{number}/"
        
        return text[:-1]

key_to_check = {
    "entry": EntryCheck,
    "bool": BoolCheck,
    "int": IntCheck,
    "choice": ChoiceCheck,
    "list": ListCheck,
    "stats": StatsCheck
}
