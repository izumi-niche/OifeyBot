import discord

class MajiContext:
    """An easy to use context for common stuff like editing messages and editing them
    Handles sending for classic commands and slash ones"""
    def __init__(self, ctx):
        self.src = ctx
        
        # Some shortcuts for stuff
        if isinstance(ctx, discord.Interaction):
            self.interaction = True
            
            self.content = ""
            self.author = ctx.user
            
        else:
            self.interaction = False
            
            self.content = ctx.content
            self.author = ctx.author
        
        self.guild = ctx.guild
        self.channel = ctx.channel
        
        try:
            if "o!NoRandom" in self.channel.topic:
                self.allow_random = False
                
            else:
                self.allow_random = True
                
        except:
            self.allow_random = True
        
        self.sent = None
        
        self.view_sent = False
        
    async def send(self, *args, **kwargs):
        if "interaction" in kwargs:
            if not kwargs["interaction"] is None:
                interaction = kwargs["interaction"]
                
            else:
                interaction = self.interaction
                
            kwargs.pop("interaction")
            
        else:
            interaction = self.interaction
        
        if not interaction and "ephemeral" in kwargs:
            kwargs.pop("ephemeral")
        
        # always remove view if it's not there
        if not "view" in kwargs and self.view_sent:
            kwargs["view"] = None
            self.view_sent = False
            
        elif not self.view_sent and "view" in kwargs:
            self.view_sent = True
            
        # need the new interaction to properly work
        if interaction:
            if not self.sent:
                await self.src.response.send_message(*args, **kwargs)
                self.sent = await self.src.original_response()
                
            else:
                if "files" in kwargs:
                    kwargs["attachments"] = kwargs["files"]
                    kwargs.pop("files")
                    
                if isinstance(interaction, discord.Interaction) and not interaction.response.is_done():
                    await interaction.response.edit_message(*args, **kwargs)
                    
                else:
                    await self.sent.edit(*args, **kwargs)
            
        else:
            if not self.sent:
                kwargs["mention_author"] = False
                self.sent = await self.src.reply(*args, **kwargs)
                
            else:
                if "files" in kwargs:
                    kwargs["attachments"] = kwargs["files"]
                    kwargs.pop("files")
                    
                await self.sent.edit(*args, **kwargs)