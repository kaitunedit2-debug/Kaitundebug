# API reference

## Create a window

```lua
local window = AeroUI.CreateWindow(config)
```

| Field | Type | Default | Description |
|---|---|---|---|
| `Title` | string | `AeroUI` | Main title. |
| `Subtitle` | string | `A clean interface for your experience` | Supporting title. |
| `LogoText` | string | `A` | Short text mark in the logo tile. |
| `Theme` | string | `Midnight` | `Midnight`, `Light` or `Azure`. |
| `Accent` | Color3 | theme accent | Optional custom accent color. |
| `Width` | number | `700` | Requested window width in pixels. |
| `Height` | number | `470` | Requested window height in pixels. |
| `LiquidGlass` | boolean | `true` | Enable the translucent glass layers. |
| `Blur` | boolean | `false` | Add the shared world `BlurEffect`. |
| `ToggleKey` | KeyCode | none | Keyboard shortcut to show/hide the window. |

## Window methods

- `window:Tab({ Name, Icon, Selected })` — create a sidebar tab.
- `window:SetTheme(name)` — switch to a built-in palette; returns `true` on success.
- `window:SetAccent(color3)` — set a custom accent; returns `true` for a Color3.
- `window:SetBlur(boolean)` — enable or release the world blur owned by this window.
- `window:SetVisible(boolean)` — show or hide the ScreenGui.
- `window:SetToggleKey(keyCode)` — change the keyboard shortcut after creation.
- `window:Toggle()` — invert visibility.
- `window:SetTitle(title, subtitle?)` — update the title and optionally the subtitle.
- `window:SetSize(width, height)` — request a new window size.
- `window:Notify({ Title, Content, Duration })` — show a toast; `Duration = 0` keeps it open until closed manually.
- `window:Destroy()` — clean up this window and its tracked connections.

## Tabs and sections

```lua
local tab = window:Tab({ Name = "Main", Icon = "M" })
local section = tab:Section({ Name = "GENERAL" })
```

## Controls

### `section:Paragraph(config)`

Fields: `Title`, `Content` (or `Description`). Returns an object with `Instance` and `:Set(text)`.

### `section:Divider(text?)`

Creates a subtle separator, optionally with a small label.

### `section:Button(config)`

Fields: `Title`, `Description`, `ButtonText`, `ButtonWidth`, `Callback`. Returns `Instance`, `Button` and `:SetText(text)`.

### `section:Toggle(config)`

Fields: `Title`, `Description`, `Value`, `Callback`. Callback receives a boolean. Returns `Value`, `:Set(value, fireCallback?)` and `:Get()`.

### `section:Slider(config)`

Fields: `Title`, `Description`, `Min`, `Max`, `Step`, `Value`, `Callback`. Callback receives the numeric value. Returns `Value`, `:Set(value, fireCallback?)` and `:Get()`.

### `section:Dropdown(config)`

Fields: `Title`, `Description`, `Options`, `Value`, `Width`, `MaxVisible`, `Callback`. Callback receives the selected option. Returns `Value`, `:Set(value, fireCallback?)`, `:Get()` and `:SetOptions(options)`.

### `section:Input(config)`

Fields: `Title`, `Description`, `Placeholder`, `Value`, `Width`, `ClearTextOnFocus`, `FireOnFocusLost`, `Callback`. Callback receives the text. Returns `Value`, `TextBox`, `:Set(value, fireCallback?)` and `:Get()`.

### `section:Keybind(config)`

Fields: `Title`, `Description`, `Key`, `Callback`. Click the key field and press a keyboard key to change it. Callback receives the pressed `KeyCode`. Returns `Key`, `Listening`, `:Set(keyCode)`.

## Callback behavior

Callbacks are invoked through `pcall`. A callback error is reported with `warn` and does not intentionally break the library's UI event handler. Control setters fire callbacks by default; pass `false` as the second argument to set silently.
