import json, os

def json_read(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.loads(f.read())
        
def json_write(path, data):
    with open(path, "w", encoding="utf-8") as f:
        return f.write(json.dumps(data, indent=4))
        
def create_folder(path):
    if not os.path.exists(path):
        os.makedirs(path)