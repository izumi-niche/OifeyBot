import discord
from maji.embed import Embed


class View(discord.ui.View):
    pass
    

class Button(discord.ui.Button):
    
    def __init__(self, page, section, show, **kwargs) -> None:
        # Strings can be used to set the colors
        # Blurple by default
        if "color" in kwargs:
            color = kwargs["color"]
            
            if color == "blue":
                color = "blurple"
                
            kwargs["style"] = getattr(discord.ButtonStyle, color)
            kwargs.pop("color")
            
        else:
            kwargs["style"] = discord.ButtonStyle.blurple
        
        if "emoji" not in kwargs:
            kwargs["emoji"] = "✏️"
            
        elif ":" in kwargs["emoji"]:
            kwargs["emoji"] = discord.PartialEmoji.from_str(kwargs["emoji"])
        
        if "parent" in kwargs:
            self.parent = kwargs["parent"]
            kwargs.pop("parent")
            
        else:
            self.parent = None
            
        super().__init__(**kwargs)
        
        self.page = page
        self.section = section
        self.show = show
        
        self.label_value = self.label
        
    async def callback(self, interaction) -> None:
        """Callback function
        Calls parent to update embed
        If replacing and using multiembeds, use action instead"""
        if self.parent and self.parent.owner == interaction.user.id:
            self.action(interaction)
        
            await self.parent.update(interaction)
        
    def action(self, interaction) -> None:
        if self.page != -1:
            self.parent.page = self.page
            
        if self.section != -1:
            self.parent.section = self.section

    def update(self) -> None:
        """This gets called for all components if they're pressed
        Return true if it's to be included, false if it's not"""
        if self.parent.section in self.show:
            # disable if it is current page
            if self.page == self.parent.page:
                self.disable()
                
            else:
                self.enable()
            
            return True
            
        else:
            return False
            
    def disable(self) -> None:
        self.disabled = True
        self.label = None
        
    def enable(self) -> None:
        self.disabled = False
        self.label = self.label_value


class MultiEmbed:
    def __init__(self, pages=[], components=[]) -> None:
        """Embed that can flip pages and edit the messages with interactions
        The discord.py library recently added a thing for that but i'm not using it"""
        
        self.page = 0
        self.section = 0
        
        self.pages = {}
        [self.append(x) for x in pages]
        
        self.components = []
        [self.components.append(x) for x in components]
        
        self.ctx = None
        self.view = View(timeout = 300.0)
        
        # bool
        self.first_page_sent = False
        
        self.owner = None
    
    def append(self, page, index = None) -> int:
        """Using a dict  over a list makes some complicated things easier
        if necessary"""
        
        if index is None:
            i = 0
            
            while i in self.pages:
                i += 1
                
            index = i
            
        self.pages[index] = page
        
        return index
        
    def button(self, page = -1, section = -1, show = [0], **kwargs) -> None:
        if "button" in kwargs:
            Create = kwargs["button"]
            kwargs.pop("button")
            
        else:
            Create = Button
            
        button = Create(page, section, show, parent=self, **kwargs)
        
        self.components.append(button)
        
    async def send(self, ctx, interaction = None) -> None:
        self.ctx = ctx
        
        self.owner = ctx.author.id
        
        await self.update(interaction)
        
        await self.view.wait()
        
        # edit message now with all buttons disabled
        for component in self.view.children:
            component.disable()
            
        await self.ctx.send(embed=self.get_current_page(), view=self.view)
    
    def get_current_page(self) -> Embed:
        return self.pages[self.page]
    
    async def update(self, interaction = None) -> None:
        """Update button values and send/edit message
        If interaction is none, it's the first message being sent."""
        embed = self.get_current_page()
        
        for component in self.components:
            check = component.update()
            
            # if the component should be show
            if check:
                if not component in self.view.children:
                    self.view.add_item(component)
                    
            else:
                if component in self.view.children:
                    self.view.remove_item(component)
        
        if self.first_page_sent:
            # For some reason it gives a error if you respond without the new interaction
            await self.ctx.send(embed=embed, view=self.view, interaction=interaction)
            
        else:
            # Change all other pages to have the same attachments in the same place
            for i, page in self.pages.items():
                if page != embed:
                    for x, y in embed.attach_keys.items():
                        page.set(x, y)
                
            # Only send files for the first embed
            await self.ctx.send(embed=embed, view=self.view, files=embed.files, interaction=interaction)
            
            self.first_page_sent = True
            
    def pagebox(self, pagebox):
        for i, infobox in pagebox.pages.items():
            embed = Embed()
            embed.infobox(infobox)
            
            self.append(embed)
            
        for i, tbl in pagebox.buttons.items():
            show = []
            
            for _, v in tbl.show.items():
                show.append(v)

            self.button(page=tbl.page, section=tbl.section, show=show, label=tbl.label, emoji=tbl.emoji, color=tbl.color)