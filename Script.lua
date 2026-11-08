--// Services
local UserInputService = game:GetService("UserInputService");

--// Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/kaitunedit2-debug/Kaitundebug/refs/heads/main/Main.lua"))()
local Window = Library:CreateWindow({
	Title = "???",
	Theme = "Dark",
	
	Size = UDim2.fromOffset(570, 370),
	Transparency = 0.2,
	Blurring = true,
	LiquidGlass = true,
	LiquidGlassIntensity = 1,
	ShowButton = true, -- floating "Show UI" button (default: mobile only)

	--// Background image (optional - default is no background)
	--// Put a Roblox IMAGE id here (not a Decal id), for example:
	--// Background = "rbxassetid://1234567890",
	--// With a background, Liquid Glass bends the image along the window edges like a water droplet.
	Background = nil,
	BackgroundDim = 0.45,        -- 0 = image fully visible, 1 = fully covered by the theme color
	BackgroundTransparency = 0,  -- transparency of the image itself
	MinimizeKeybind = Enum.KeyCode.LeftAlt,
})

local Themes = {
	Light = {
		--// Frames:
		Primary = Color3.fromRGB(232, 232, 232),
		Secondary = Color3.fromRGB(255, 255, 255),
		Component = Color3.fromRGB(245, 245, 245),
		Interactables = Color3.fromRGB(235, 235, 235),

		--// Text:
		Tab = Color3.fromRGB(50, 50, 50),
		Title = Color3.fromRGB(0, 0, 0),
		Description = Color3.fromRGB(100, 100, 100),

		--// Outlines:
		Shadow = Color3.fromRGB(255, 255, 255),
		Outline = Color3.fromRGB(210, 210, 210),

		--// Image:
		Icon = Color3.fromRGB(100, 100, 100),
	},
	
	Dark = {
		--// Frames:
		Primary = Color3.fromRGB(30, 30, 30),
		Secondary = Color3.fromRGB(35, 35, 35),
		Component = Color3.fromRGB(40, 40, 40),
		Interactables = Color3.fromRGB(45, 45, 45),

		--// Text:
		Tab = Color3.fromRGB(200, 200, 200),
		Title = Color3.fromRGB(240,240,240),
		Description = Color3.fromRGB(200,200,200),

		--// Outlines:
		Shadow = Color3.fromRGB(0, 0, 0),
		Outline = Color3.fromRGB(40, 40, 40),

		--// Image:
		Icon = Color3.fromRGB(220, 220, 220),
	},
	
	Void = {
		--// Frames:
		Primary = Color3.fromRGB(15, 15, 15),
		Secondary = Color3.fromRGB(20, 20, 20),
		Component = Color3.fromRGB(25, 25, 25),
		Interactables = Color3.fromRGB(30, 30, 30),

		--// Text:
		Tab = Color3.fromRGB(200, 200, 200),
		Title = Color3.fromRGB(240,240,240),
		Description = Color3.fromRGB(200,200,200),

		--// Outlines:
		Shadow = Color3.fromRGB(0, 0, 0),
		Outline = Color3.fromRGB(40, 40, 40),

		--// Image:
		Icon = Color3.fromRGB(220, 220, 220),
	},

}

--// Set the default theme
Window:SetTheme(Themes.Dark)

--// Sections
Window:AddTabSection({
	Name = "Main",
	Order = 1,
})

Window:AddTabSection({
	Name = "Settings",
	Order = 2,
})

--// Tab [MAIN]

local Main = Window:AddTab({
	Title = "Components",
	Section = "Main",
	Icon = "rbxassetid://11963373994"
})

Window:AddSection({ Name = "Non Interactable", Tab = Main }) 


Window:AddParagraph({
	Title = "Paragraph",
	Description = "Insert any important text here.",
	Tab = Main
}) 

Window:AddSection({ Name = "Interactable", Tab = Main }) 

Window:AddButton({
	Title = "Button",
	Description = "I wonder what this does",
	Tab = Main,
	Callback = function() 
		Window:Notify({
			Title = "hi",
			Description = "i'm a notification", 
			Duration = 5
		})
	end,
}) 

Window:AddSlider({
	Title = "Slider",
	Description = "Sliding",
	Tab = Main,
	MaxValue = 100,
	Callback = function(Amount) 
		warn(Amount);
	end,
}) 

Window:AddToggle({
	Title = "Toggle",
	Description = "Switching",
	Tab = Main,
	Callback = function(Boolean) 
		warn(Boolean);
	end,
}) 

Window:AddInput({
	Title = "Input",
	Description = "Typing",
	Tab = Main,
	Callback = function(Text) 
		warn(Text);
	end,
}) 


Window:AddDropdown({
	Title = "Dropdown",
	Description = "Selecting",
	Tab = Main,
	Options = {
		["An Option"] = "hi",
		["And another"] = "hi",
		["Another"] = "hi",
	},
	Callback = function(Number) 
		warn(Number);
	end,
}) 

Window:AddKeybind({
	Title = "Keybind",
	Description = "Binding",
	Tab = Main,
	Callback = function(Key) 
		warn("Key Set")
	end,
}) 

--// Tab [SETTINGS]
local Keybind = nil
local Settings = Window:AddTab({
	Title = "Settings",
	Section = "Settings",
	Icon = "rbxassetid://11293977610",
})

Window:AddKeybind({
	Title = "Minimize Keybind",
	Description = "Set the keybind for Minimizing",
	Tab = Settings,
	Callback = function(Key) 
		Window:SetSetting("Keybind", Key)
	end,
}) 

Window:AddDropdown({
	Title = "Set Theme",
	Description = "Set the theme of the library!",
	Tab = Settings,
	Options = {
		["Light Mode"] = "Light",
		["Dark Mode"] = "Dark",
		["Extra Dark"] = "Void",
	},
	Callback = function(Theme) 
		Window:SetTheme(Themes[Theme])
	end,
}) 

--// Blur, Liquid Glass, Transparency and Background Image controls
--// (you can also change the background at any time with Window:SetSetting("Background", "rbxassetid://ID"))
Window:AddAppearanceSettings({
	Tab = Settings,
})

Window:Notify({
	Title = "Hello World!",
	Description = "Press Left Alt to Minimize and Open the tab!", 
	Duration = 10
})

--// Keybind Example
UserInputService.InputBegan:Connect(function(Key) 
	if Key == Keybind then
		warn("You have pressed the minimize keybind!");
	end
end)
