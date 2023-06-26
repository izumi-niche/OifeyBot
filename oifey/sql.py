import sqlite3, json

import oifey.util as util

util.file.create_folder(".oifey")

connection = sqlite3.connect(".oifey/lite.db")
cursor = connection.cursor()

banned_words = ['"', "'", "\\", "\n"]

class Table:
    def __init__(self, key):
        self.key = key
        
        # try pulling from table
        # if not, create one
        
        try:
            self.data = self.select()
            
        except sqlite3.OperationalError:
            cursor.execute(f"CREATE TABLE {self.key}(name, data)")
            
            self.data = self.select()
            
    def select(self):
        "Gets all of the data in the table and stores in a dict for easy use"
        current = cursor.execute(f"SELECT * FROM '{self.key}'")
        
        result = {}
        
        for value in current.fetchall():
           result[value[0]] = json.loads(value[1])

        return result
        
    def get(self, name):
        if not name in self.data:
            return {}
            
        else:
            return self.data[name]
            
    def update(self, name, value):
        text = json.dumps(value)
        
        if not name in self.data:
            cursor.execute(f"INSERT INTO '{self.key}' VALUES ({name}, '{text}');")
        
        else:
            cursor.execute(f"UPDATE '{self.key}' SET data = '{text}' WHERE name = {name}")
        
        connection.commit()

        self.data[name] = value
        
    def drop(self, name):
        if name in self.data: self.data.pop(name)
        
        cursor.execute(f"DELETE FROM '{self.key}' WHERE name = {name}")
        
        connection.commit()
        
# common used tables
user = Table("user")
server = Table("server")