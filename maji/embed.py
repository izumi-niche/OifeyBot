import discord
import os

default_color = 0x2570c2

root_keys = {
    "desc": "description",
    "color": "color"
}

image_keys = {
    "footer": "footer_icon",
    "icon": "author_icon"
}

class Embed(discord.Embed):
    def __init__(self, **kwargs) -> None:
        super().__init__()
        
        self.files = []
        
        if "color" not in kwargs: kwargs["color"] = default_color
        
        for key, value in kwargs.items():
            self.set(key, value)
            
        # keep track which images were set
        self.attach_keys = {}
        
    def set(self, key, value) -> None:
        """Set an embed value like, description or a image
        Attachments need to use Embed.attach"""
        
        def check_attachment(k, v):
            if "attachment://" in v:
                self.attach_keys[k] = v
        
        if key in root_keys:
            setattr(self, root_keys[key], value)
            
        elif key == "footer":
            if self.footer:
                icon_url = self.footer.icon_url
                
                self.set_footer(text=value, icon_url=icon_url)
                
            else:
                self.set_footer(text=value)
                
        elif key == "footer_icon":
            if self.footer:
                text = self.footer.text
                
                self.set_footer(text=text, icon_url=value)
                
            else:
                self.set_footer(icon_url=value)
                
            check_attachment(key, value)
        
        elif key == "title":
            if self.author:
                icon_url = self.author.icon_url
                
                self.set_author(name=value, icon_url=value)
                
            else:
                self.set_author(name=value)
            
        elif key == "author_icon":
            if self.author:
                author = self.author.name
                
                self.set_author(name=author, icon_url=value)
                
            else:
                self.set_author(name="placeholder", icon_url=value)
                
            check_attachment(key, value)
            
        elif key == "thumbnail":
            self.set_thumbnail(url=value)
            
            check_attachment(key, value)
            
        elif key == "image":
            self.set_image(url=value)
            
            check_attachment(key, value)
            
    def add_field(self, name, value, inline=False) -> None:
        if value:
            super().add_field(name=name, value=value, inline=inline)
    
    def attach(self, key, file_path) -> None:
        if not file_path: return
        
        if key in image_keys:
            key = image_keys[key]
            
        # If image is a file instead of a link
        if not "https://" in file_path:
            # check if file exists
            if not file_path or not os.path.isfile(file_path):
                return
            
            file_type = ""
            
            if "." in file_path:
                file_type = file_path.split(".")[-1]
            
            file_name = f"{key}.{file_type}"
            file = discord.File(file_path, filename=file_name)
            
            self.files.append(file)
            
            file_path = f"attachment://{file_name}"
            
        self.set(key, file_path)
        
    def infobox(self, infobox) -> None:
        for key, value in infobox.settings.items():
            self.set(key, value)
            
        for key in infobox.fields:
            field = infobox.fields[key]
            
            self.add_field(name=field.name, value=field.value, inline=field.inline)
            
        for key, value in infobox.images.items():
            self.attach(key, value)
            
    async def send(self, ctx, **kwargs) -> None:
        await ctx.send(embed=self, files=self.files, **kwargs)