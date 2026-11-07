-- AeroUI Glass Edition - example LocalScript
-- Rojo places AeroUI in ReplicatedStorage and this script in StarterPlayerScripts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AeroUI = require(ReplicatedStorage:WaitForChild("AeroUI"))

local window = AeroUI.CreateWindow({
    Title = "AeroUI Studio",
    Subtitle = "Glass interface / Example workspace",
    LogoText = "A",
    Theme = "Midnight", -- Midnight | Light | Azure
    Width = 720,
    Height = 490,
    LiquidGlass = true,
    Blur = true, -- Optional world blur. This affects the 3D scene behind the UI.
    ToggleKey = Enum.KeyCode.RightControl,
})

local overview = window:Tab({ Name = "Overview", Icon = "⌂", Selected = true })
local controls = overview:Section({ Name = "WELCOME" })
controls:Paragraph({
    Title = "AeroUI Glass Edition",
    Content = "A compact Roblox UI framework with a translucent glass surface, responsive window layout, smooth controls and a small, predictable API.",
})
controls:Button({
    Title = "Notification system",
    Description = "Send a toast using the built-in notification stack.",
    ButtonText = "Preview",
    Callback = function()
        window:Notify({
            Title = "Everything is ready",
            Content = "The notification component is working.",
            Duration = 4,
        })
    end,
})

local settingsTab = window:Tab({ Name = "Settings", Icon = "⚙" })
local preferences = settingsTab:Section({ Name = "PREFERENCES" })
preferences:Toggle({
    Title = "Example toggle",
    Description = "The control animates and reports its state.",
    Value = true,
    Callback = function(value)
        print("Toggle:", value)
    end,
})
preferences:Slider({
    Title = "Intensity",
    Description = "Drag the track to change the value.",
    Min = 0,
    Max = 100,
    Step = 5,
    Value = 45,
    Callback = function(value)
        print("Intensity:", value)
    end,
})
preferences:Dropdown({
    Title = "Theme preset",
    Description = "Switch the full interface palette.",
    Value = "Midnight",
    Options = { "Midnight", "Light", "Azure" },
    Callback = function(value)
        window:SetTheme(value)
    end,
})
preferences:Input({
    Title = "Display name",
    Description = "A simple text input example.",
    Placeholder = "Enter a name...",
    Value = "Guest",
    Callback = function(value)
        print("Display name:", value)
    end,
})
preferences:Keybind({
    Title = "Quick action",
    Description = "Click the key field, then press a keyboard key.",
    Key = Enum.KeyCode.G,
    Callback = function(key)
        window:Notify({ Title = "Key pressed", Content = key.Name, Duration = 2.5 })
    end,
})
preferences:Divider("WINDOW")
preferences:Button({
    Title = "Change accent",
    Description = "Apply a custom blue accent color.",
    ButtonText = "Apply",
    Callback = function()
        window:SetAccent(Color3.fromRGB(85, 177, 255))
    end,
})

window:Notify({
    Title = "Welcome to AeroUI",
    Content = "Press RightControl to show or hide the window.",
    Duration = 5,
})
