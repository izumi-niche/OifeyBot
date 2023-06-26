replace_blank = ['(', ' ', ')', "'", '"', '-', '~', '_', '.', '&', '?', '!', '%', "$", '—', '’', '@', '+', '/', '\\', '·', ':', ',', '|', 'Ω', 'Θ', '*', "}", "{", ";", "*"]
replace_char = {'%27': '', '%C3%A1': 'a', '%C3%AD': 'i', '%C3%BA': 'u', '%C3%A7': 'c', '%22': '', '%C3%A9': 'e', 'é': 'e', 'ð': 'd', 'á': 'a', 'ö': 'o',
'ý': 'y', 'þ': 'p', 'ú': 'u', 'ó': 'o', 'í': 'i', 'ø': 'o', 'æ': 'ae', 'Þ': 'p', 'ò': 'o', 'ù': 'u', 'ñ': 'n', 'ä': 'a'}

def search_text(text, ignore_plus = False, ignore_space = False, blank = '') -> str:
    text = text.lower()
    
    plus = ""
    
    while not ignore_plus and len(text) > 1 and text[-1] == "+":
        plus += "+"
        text = text[:-1]

    for x in replace_blank:
        if ignore_plus and x == '+': continue
        elif ignore_space and x == ' ': continue

        text = text.replace(x, blank)

    for key, value in replace_char.items():
        text = text.replace(key, value)
    
    text += plus
    return text.strip()
    
def splice_spaces(text) -> list:
    result = [x.strip() for x in text.split(" ")]
    
    if "" in result:
        result.remove("")
        
    return result


class ParameterValue:
    def __init__(self, option, option_start, option_value):
        self.key = option.lower()
        self.start = option_start.lower()
        self.value = option_value.strip().lower()
        
    def print(self):
        print(self.key, self.start, self.value)

def get_parameters(words, parameters, start_keys = ["-", "~"]) -> list:
    """Get parameters
    Janky as hell but it works"""
    
    result = []
    invalid_words = []
    
    # It doesn't matter much but this rly shouldn't be done more than
    # one time
    valid_value = {}
    
    for par in parameters:
        if par.allow_value:
            values = par.parse_value_keys()
            
            if isinstance(values, list):
                for x in values:
                    valid_value[x] = None
                    
            else:
                valid_value = {**valid_value, **values}
    
    option = None
    option_start = None
    option_value = ""
    
    
    for word in words:
    
        def check_start():
            for x in start_keys:
                if word.startswith(x):
                    return x
                
            return False
        
        start = check_start()
        
        if start:
            if not option is None:
                if option_value:
                    pv = ParameterValue(option, option_start, option_value)
        
                    result.append(pv)
                
                option_value = ""
            
            check = word[len(start):]
            
            if check in valid_value and (valid_value[check] is None or
            (valid_value[check] == start)):
                option = check
                option_start = start
                
            else:
                pv = ParameterValue(check, start, "")
                result.append(pv)
                
                option = None
                option_value = ""
 
            
        else:
            if option is None:
                invalid_words.append(word)
                
            else:
                option_value = " " + word
                
    if option:
        pv = ParameterValue(option, option_start, option_value)
        
        result.append(pv)
        
        option_value = ""
    
    return result, invalid_words