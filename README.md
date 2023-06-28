# OifeyBot

Oifey is a bot for Discord that shows data based on the Fire Emblem games. Can be used with slash commands or text commands (if it has the permission to read messages).

Made with [Discord.py](https://github.com/Rapptz/discord.py) to handle basic Discord API stuff, has a custom command system for an easier time when generating a lot of commands and some custom behavior.

Uses [Almanac](https://github.com/izumi-niche/Almanac) for game calculations.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/W7W415DE4)

## Setting it up

### Requirements
Lua >= 5.3

Python >= 3.9.1

Make sure Lua and Python are in your PATH.

### Running

After downloading the source code and extracting it, go to the folder and type in the console `pip install -r requirements.txt` to get the necessary libraries.

Create a file named `token.txt` in the same folder, open it and paste your Discord Bot token there. Make sure there's nothing else, including no spaces or new lines.

After all of this is done and everything is correct, use `python main.py` to run the bot. Type this command anytime you need to start the bot, you don't need to do all of this again.

To register the slash commands, go to `client.py` and replace the value of `OWNER_ID` with your Discord user ID. Afterwards, type `o!sync` to register them to all servers.
