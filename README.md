# AeroUI — Glass Edition

**AeroUI** is an original Roblox Luau UI library focused on a refined desktop-style window, responsive layout, reusable controls and a layered Liquid Glass appearance.

It is built for normal Roblox client code. It does not require executor-only functions, remote asset URLs, icon packs or third-party packages.

## Features

- Draggable window with mouse and touch input.
- Responsive window sizing when the viewport changes.
- Liquid Glass surface: translucent layers, soft gradient, edge highlights and restrained borders.
- Optional world blur using Roblox `Lighting`'s `BlurEffect`.
- Three built-in palettes: `Midnight`, `Light` and `Azure`.
- Sidebar tabs and auto-sized sections.
- Button, toggle, slider, dropdown, text input, keybind, paragraph and divider.
- Toast notifications with automatic dismissal.
- Runtime theme and accent switching.
- Minimize, close, show/hide and configurable toggle key.
- No external assets or network calls.

## Project layout

```text
AeroUI-Glass/
├── src/
│   └── AeroUI.lua          # Editable ModuleScript source
├── dist/
│   └── AeroUI.lua          # Standalone distribution copy
├── example/
│   └── Demo.client.lua     # Working LocalScript example
├── docs/
│   ├── ARCHITECTURE.md
│   └── API.md
├── default.project.json    # Rojo project mapping
├── CHANGELOG.md
└── LICENSE
```

## Installation

### Option A — Rojo

1. Open this folder as a Rojo project.
2. Build or serve `default.project.json`.
3. Rojo maps `src/AeroUI.lua` to `ReplicatedStorage.AeroUI` and the demo to `StarterPlayerScripts`.
4. Run the place in Roblox Studio. The demo is a client LocalScript.

### Option B — Manual Studio setup

1. Create a `ModuleScript` named `AeroUI` under `ReplicatedStorage`.
2. Copy the contents of `src/AeroUI.lua` into it.
3. Create a `LocalScript` under `StarterPlayerScripts`.
4. Copy the contents of `example/Demo.client.lua` into that LocalScript.

## Quick start

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AeroUI = require(ReplicatedStorage:WaitForChild("AeroUI"))

local window = AeroUI.CreateWindow({
    Title = "My interface",
    Subtitle = "AeroUI Glass Edition",
    Theme = "Midnight",
    LiquidGlass = true,
    Blur = false,
    ToggleKey = Enum.KeyCode.RightControl,
})

local tab = window:Tab({ Name = "Main", Icon = "A" })
local section = tab:Section({ Name = "GENERAL" })

section:Paragraph({
    Title = "Hello",
    Content = "This is a paragraph component.",
})

section:Button({
    Title = "Run action",
    ButtonText = "Run",
    Callback = function()
        window:Notify({ Title = "Done", Content = "Your callback ran." })
    end,
})

section:Toggle({
    Title = "Enable feature",
    Value = false,
    Callback = function(enabled)
        print("Enabled:", enabled)
    end,
})
```

See [`docs/API.md`](docs/API.md) for the control methods and configuration fields.

## Liquid Glass and blur: an important distinction

Roblox does not expose a native per-`Frame` backdrop-filter property for `ScreenGui`. AeroUI therefore builds the glass appearance from layered translucent surfaces, gradients, edge highlights and strokes. When `Blur = true`, it also creates a managed `BlurEffect` in `Lighting`; this softens the **3D world behind the interface**, not individual UI panels. Multiple AeroUI windows share the effect, and the library removes it after the final owning window is destroyed.

The glass treatment remains visible with `Blur = false`. This avoids claiming a per-panel optical blur that the standard Roblox UI API does not provide.

## Performance and ownership

- Blur is opt-in. Enable it only when the experience benefits from it.
- No per-frame loops are used for controls. The glass sheen uses one lightweight rotation update while the window exists.
- `window:Destroy()` disconnects the library's tracked global connections and releases its blur ownership.
- Do not call `CreateWindow` from a server Script; create UI on the client.

## Compatibility

Designed for Roblox Studio client-side Luau. This project has not been executed inside a live Roblox client in this environment, so validate visual behavior and input handling in Studio before shipping it in a production experience.

## Credits and originality

WindUI 1.6.66 was reviewed as a reference for broad architectural ideas such as component separation, theming and acrylic-style layering. AeroUI's implementation, API, layout, code and styling are original for this project; no WindUI source files, images, textures or icons are bundled here.
