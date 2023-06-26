import discord, random
from discord.ext import tasks

OWNER_ID = 0

random_status = [
    "Support the bot -> ko-fi.com/izumi",
    "Don't believe in the liberal media: FE3 is not real",
    "Try out compare! @Oifey fe4 lewyn!ced, lewyn!arthur 14",
    "Play Advance Wars 1+2: Re-Boot Camp!",
    "@Oifey e sommie",
    "fe4 enemies are not so strong that you need ayra to attack 20 fucking times",
    "Cipher cards look pretty cool: @Oifey cipher",
    "I'm Marth. Emblem Marth, to be clear.",
    "90% of summoners quit right before they pull their favorite character",
    "It would be pretty cool if they added marth to fortnite ngl",
    "Smash Bros is old and boring, they should start adding FE characters to Fortnite instead",
    "\"Alcryst vs Etie\", the greatest thread in the history of forums, locked by a moderator after 12,239 pages of heated debate,"
]

discord.utils.setup_logging()

change_status = None


class Oifey(discord.AutoShardedClient):
    def __init__(self, **kwargs) -> None:
        #kwargs["activity"] = discord.Game("testing new stuff")
        super().__init__(**kwargs)

        self.debug = True
        self.maji = None
        
        self.owner = OWNER_ID

    async def on_ready(self) -> None:
        print(f"Logged in as {self.user} {self.user.id}!")
        change_status.start()
        
        ping = f"<@{self.user.id}> "
        
        if not ping in self.maji.prefix:
            self.maji.prefix.append(ping)

    async def on_interaction(self, interaction):
        if self.maji and interaction.type == discord.InteractionType.application_command:
            await self.maji.check_slash(interaction)

    async def on_message(self, ctx) -> None:
        if self.maji:
            await self.maji.check(ctx)


intents = discord.Intents.default()

intents.bans = False
intents.dm_reactions = False
intents.dm_typing = False
intents.guild_reactions = False
intents.guild_typing = False
intents.invites = False
intents.reactions = False
intents.typing = False
intents.voice_states = False
intents.webhooks = False
intents.message_content = False

client = Oifey(intents=intents, log_handler=None)

# random status
@tasks.loop(hours=1.0)
async def change_status():
    await client.change_presence(activity=discord.Game(random.choice(random_status)))