--[=[
    AeroUI - Glass Edition
    An original, lightweight Roblox Luau UI library.
    Runtime: LocalScript / client only. No executor-only APIs or external assets.
]=]

local AeroUI = {
    Name = "AeroUI",
    Version = "1.0.0",
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer

local THEMES = {
    Midnight = {
        Background = Color3.fromRGB(10, 14, 23),
        Surface = Color3.fromRGB(19, 25, 38),
        Surface2 = Color3.fromRGB(24, 32, 47),
        Card = Color3.fromRGB(31, 41, 59),
        Input = Color3.fromRGB(12, 18, 29),
        Text = Color3.fromRGB(239, 244, 252),
        Muted = Color3.fromRGB(151, 164, 184),
        Border = Color3.fromRGB(117, 144, 181),
        Accent = Color3.fromRGB(91, 157, 255),
        AccentText = Color3.fromRGB(255, 255, 255),
        Success = Color3.fromRGB(78, 202, 151),
        Danger = Color3.fromRGB(242, 104, 112),
        Glass = Color3.fromRGB(91, 128, 180),
    },
    Light = {
        Background = Color3.fromRGB(222, 231, 243),
        Surface = Color3.fromRGB(245, 248, 253),
        Surface2 = Color3.fromRGB(233, 239, 248),
        Card = Color3.fromRGB(255, 255, 255),
        Input = Color3.fromRGB(232, 238, 247),
        Text = Color3.fromRGB(28, 39, 57),
        Muted = Color3.fromRGB(99, 115, 139),
        Border = Color3.fromRGB(112, 134, 166),
        Accent = Color3.fromRGB(48, 119, 226),
        AccentText = Color3.fromRGB(255, 255, 255),
        Success = Color3.fromRGB(25, 155, 105),
        Danger = Color3.fromRGB(207, 73, 84),
        Glass = Color3.fromRGB(255, 255, 255),
    },
    Azure = {
        Background = Color3.fromRGB(8, 18, 34),
        Surface = Color3.fromRGB(13, 28, 49),
        Surface2 = Color3.fromRGB(17, 38, 64),
        Card = Color3.fromRGB(21, 45, 72),
        Input = Color3.fromRGB(8, 23, 41),
        Text = Color3.fromRGB(235, 246, 255),
        Muted = Color3.fromRGB(140, 171, 199),
        Border = Color3.fromRGB(74, 137, 190),
        Accent = Color3.fromRGB(65, 169, 255),
        AccentText = Color3.fromRGB(255, 255, 255),
        Success = Color3.fromRGB(79, 211, 163),
        Danger = Color3.fromRGB(246, 111, 125),
        Glass = Color3.fromRGB(72, 137, 196),
    },
}

local function create(className, properties, parent)
    local object = Instance.new(className)
    if properties then
        for property, value in pairs(properties) do
            object[property] = value
        end
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 12),
    }, parent)
end

local function addStroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = color or Color3.new(1, 1, 1),
        Transparency = transparency == nil and 0.72 or transparency,
        Thickness = thickness or 1,
    }, parent)
end

local function addPadding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function makeText(parent, text, size, color, properties)
    local defaults = {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = text or "",
        TextColor3 = color or Color3.new(1, 1, 1),
        TextSize = size or 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }
    if properties then
        for key, value in pairs(properties) do
            defaults[key] = value
        end
    end
    return create("TextLabel", defaults, parent)
end

local function tween(object, duration, properties, style, direction)
    local info = TweenInfo.new(
        duration or 0.18,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(object, info, properties)
    animation:Play()
    return animation
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[AeroUI] Callback error: " .. tostring(err))
    end
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function roundToStep(value, step)
    if not step or step <= 0 then
        return value
    end
    return math.floor((value / step) + 0.5) * step
end

local function formatNumber(value)
    if math.abs(value - math.floor(value)) < 0.000001 then
        return tostring(math.floor(value))
    end
    return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

-- Blur is shared between AeroUI windows and is removed when the final owner closes.
local blurEffect = nil
local blurOwners = 0

local function acquireWorldBlur()
    blurOwners = blurOwners + 1
    if not blurEffect or not blurEffect.Parent then
        blurEffect = create("BlurEffect", {
            Name = "AeroUI_WorldBlur",
            Size = 8,
            Enabled = true,
        }, Lighting)
    end
end

local function releaseWorldBlur()
    blurOwners = math.max(0, blurOwners - 1)
    if blurOwners == 0 and blurEffect then
        blurEffect:Destroy()
        blurEffect = nil
    end
end

local Window = {}
Window.__index = Window

function Window:_bindTheme(object, property, token)
    object[property] = self._theme[token]
    table.insert(self._themeBindings, {
        Object = object,
        Property = property,
        Token = token,
    })
end

function Window:_registerThemeRefresher(callback)
    table.insert(self._themeRefreshers, callback)
end

function Window:_refreshThemeState()
    for _, callback in ipairs(self._themeRefreshers) do
        local ok, err = pcall(callback)
        if not ok then
            warn("[AeroUI] Theme refresh error: " .. tostring(err))
        end
    end
end

function Window:SetTheme(themeName)
    local selected = THEMES[themeName]
    if not selected then
        warn("[AeroUI] Unknown theme: " .. tostring(themeName))
        return false
    end

    self._theme = table.clone(selected)
    if self._customAccent then
        self._theme.Accent = self._customAccent
    end

    for _, binding in ipairs(self._themeBindings) do
        if binding.Object and binding.Object.Parent then
            local value = self._theme[binding.Token]
            if value then
                binding.Object[binding.Property] = value
            end
        end
    end

    self.Theme = themeName
    if self._activeTab then
        local active = self._activeTab
        active.Button.BackgroundTransparency = 0.82
        active.Marker.BackgroundTransparency = 0
        active.TextLabel.TextColor3 = self._theme.Text
        active.IconLabel.TextColor3 = self._theme.Accent
    end
    self:_refreshThemeState()
    return true
end

function Window:SetAccent(color)
    if typeof(color) ~= "Color3" then
        return false
    end
    self._customAccent = color
    self._theme.Accent = color
    if self._activeTab then
        self._activeTab.IconLabel.TextColor3 = color
    end
    for _, binding in ipairs(self._themeBindings) do
        if binding.Token == "Accent" and binding.Object and binding.Object.Parent then
            binding.Object[binding.Property] = color
        end
    end
    self:_refreshThemeState()
    return true
end

function Window:SetBlur(enabled)
    enabled = enabled == true
    if enabled and not self._ownsBlur then
        acquireWorldBlur()
        self._ownsBlur = true
    elseif not enabled and self._ownsBlur then
        releaseWorldBlur()
        self._ownsBlur = false
    end
end

function Window:SetVisible(visible)
    if self._destroyed then
        return
    end
    self._visible = visible ~= false
    self.Gui.Enabled = self._visible
end

function Window:Toggle()
    self:SetVisible(not self._visible)
end

function Window:SetToggleKey(keyCode)
    self.ToggleKey = keyCode
end

function Window:SetTitle(title, subtitle)
    self.Title = tostring(title or self.Title)
    self.TitleLabel.Text = self.Title
    if subtitle ~= nil then
        self.SubtitleLabel.Text = tostring(subtitle)
    end
end

function Window:SetSize(width, height)
    width = math.max(300, tonumber(width) or 680)
    height = math.max(260, tonumber(height) or 460)
    self._width = width
    self._height = height
    local camera = workspace.CurrentCamera
    if camera then
        local viewport = camera.ViewportSize
        width = math.min(width, math.max(300, viewport.X - 24))
        height = math.min(height, math.max(260, viewport.Y - 48))
    end
    self.Main.Size = UDim2.fromOffset(width, height)
    self._expandedSize = self.Main.Size
    self.Shadow.Size = self.Main.Size
    self.Sidebar.Size = UDim2.new(0, clamp(width * 0.22, 86, 158), 1, 0)
    self.Content.Position = UDim2.new(0, self.Sidebar.Size.X.Offset, 0, 0)
    self.Content.Size = UDim2.new(1, -self.Sidebar.Size.X.Offset, 1, 0)
end

function Window:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    if self._ownsBlur then
        releaseWorldBlur()
        self._ownsBlur = false
    end
    for _, connection in ipairs(self._connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    for _, connection in ipairs(self._elementConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    if self.Gui then
        self.Gui:Destroy()
    end
end

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local function makeControlRow(section, height)
    local window = section.Window
    local row = create("Frame", {
        Name = "ControlRow",
        Size = UDim2.new(1, 0, 0, height or 58),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, section.Stack)
    return row, window
end

local function addRowLabels(row, window, title, description)
    local hasDescription = description ~= nil and tostring(description) ~= ""
    local titleLabel = makeText(row, title or "Element", 13, window._theme.Text, {
        Position = UDim2.new(0, 12, 0, hasDescription and 7 or 0),
        Size = UDim2.new(1, -190, 0, hasDescription and 20 or 56),
        Font = Enum.Font.GothamMedium,
    })
    window:_bindTheme(titleLabel, "TextColor3", "Text")

    local descriptionLabel
    if hasDescription then
        descriptionLabel = makeText(row, tostring(description), 11, window._theme.Muted, {
            Position = UDim2.new(0, 12, 0, 29),
            Size = UDim2.new(1, -190, 0, 17),
            Font = Enum.Font.Gotham,
        })
        window:_bindTheme(descriptionLabel, "TextColor3", "Muted")
    end
    return titleLabel, descriptionLabel
end

function Section:Paragraph(config)
    config = config or {}
    local window = self.Window
    local card = create("Frame", {
        Name = "Paragraph",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = window._theme.Surface2,
        BackgroundTransparency = 0.34,
        BorderSizePixel = 0,
    }, self.Stack)
    addCorner(card, 10)
    local stroke = addStroke(card, window._theme.Border, 0.86, 1)
    window:_bindTheme(card, "BackgroundColor3", "Surface2")
    window:_bindTheme(stroke, "Color", "Border")
    local inner = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, card)
    addPadding(inner, 13, 13, 10, 11)
    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, inner)
    local title = makeText(inner, config.Title or "Information", 13, window._theme.Text, {
        Size = UDim2.new(1, 0, 0, 20),
        Font = Enum.Font.GothamSemibold,
        LayoutOrder = 1,
    })
    window:_bindTheme(title, "TextColor3", "Text")
    local body = makeText(inner, config.Content or config.Description or "", 12, window._theme.Muted, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
    })
    window:_bindTheme(body, "TextColor3", "Muted")
    return {
        Instance = card,
        Set = function(_, value)
            body.Text = tostring(value)
        end,
    }
end

function Section:Divider(text)
    local window = self.Window
    local divider = create("Frame", {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    }, self.Stack)
    local line = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = window._theme.Border,
        BackgroundTransparency = 0.78,
    }, divider)
    window:_bindTheme(line, "BackgroundColor3", "Border")
    if text then
        local label = makeText(divider, tostring(text), 10, window._theme.Muted, {
            Position = UDim2.new(0, 8, 0, 2),
            Size = UDim2.new(0, 160, 0, 18),
            BackgroundTransparency = 0,
            BackgroundColor3 = window._theme.Surface,
            Font = Enum.Font.GothamMedium,
        })
        window:_bindTheme(label, "TextColor3", "Muted")
        window:_bindTheme(label, "BackgroundColor3", "Surface")
    end
    return divider
end

function Section:Button(config)
    config = config or {}
    local window = self.Window
    local row = makeControlRow(self, config.Description and 64 or 56)
    addRowLabels(row, window, config.Title or "Button", config.Description)

    local button = create("TextButton", {
        Name = "ActionButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(config.ButtonWidth or 104, 32),
        BackgroundColor3 = window._theme.Accent,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = config.ButtonText or "Execute",
        TextColor3 = window._theme.AccentText,
        TextSize = 11,
        Font = Enum.Font.GothamSemibold,
    }, row)
    addCorner(button, 9)
    window:_bindTheme(button, "BackgroundColor3", "Accent")
    window:_bindTheme(button, "TextColor3", "AccentText")
    button.MouseEnter:Connect(function()
        tween(button, 0.12, { BackgroundTransparency = 0.12 })
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.12, { BackgroundTransparency = 0 })
    end)
    button.Activated:Connect(function()
        safeCallback(config.Callback)
    end)
    return {
        Instance = row,
        Button = button,
        SetText = function(_, value)
            button.Text = tostring(value)
        end,
    }
end

function Section:Toggle(config)
    config = config or {}
    local window = self.Window
    local row = makeControlRow(self, config.Description and 64 or 56)
    addRowLabels(row, window, config.Title or "Toggle", config.Description)

    local hitbox = create("TextButton", {
        Name = "ToggleHitbox",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(48, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)
    local track = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(42, 24),
        BackgroundColor3 = window._theme.Input,
        BorderSizePixel = 0,
    }, hitbox)
    addCorner(track, 20)
    local trackStroke = addStroke(track, window._theme.Border, 0.76, 1)
    window:_bindTheme(track, "BackgroundColor3", "Input")
    window:_bindTheme(trackStroke, "Color", "Border")
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = window._theme.Text,
        BorderSizePixel = 0,
    }, track)
    addCorner(knob, 20)
    window:_bindTheme(knob, "BackgroundColor3", "Text")

    local control = { Value = config.Value == true, Instance = row }
    local function renderState()
        tween(track, 0.16, {
            BackgroundColor3 = control.Value and window._theme.Accent or window._theme.Input,
        })
        tween(knob, 0.16, {
            Position = control.Value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = control.Value and window._theme.AccentText or window._theme.Text,
        })
    end
    function control:Set(value, fireCallback)
        control.Value = value == true
        renderState()
        if fireCallback ~= false then
            safeCallback(config.Callback, control.Value)
        end
    end
    function control:Get()
        return control.Value
    end
    hitbox.Activated:Connect(function()
        control:Set(not control.Value, true)
    end)
    control:Set(control.Value, false)
    window:_registerThemeRefresher(renderState)
    return control
end

function Section:Slider(config)
    config = config or {}
    local window = self.Window
    local minimum = tonumber(config.Min) or 0
    local maximum = tonumber(config.Max) or 100
    if maximum <= minimum then
        maximum = minimum + 1
    end
    local step = tonumber(config.Step) or 1
    local initial = clamp(tonumber(config.Value) or minimum, minimum, maximum)
    local row = makeControlRow(self, 82)
    local title = makeText(row, config.Title or "Slider", 13, window._theme.Text, {
        Position = UDim2.new(0, 12, 0, 7),
        Size = UDim2.new(1, -100, 0, 20),
        Font = Enum.Font.GothamMedium,
    })
    window:_bindTheme(title, "TextColor3", "Text")
    if config.Description then
        local desc = makeText(row, config.Description, 11, window._theme.Muted, {
            Position = UDim2.new(0, 12, 0, 27),
            Size = UDim2.new(1, -24, 0, 16),
        })
        window:_bindTheme(desc, "TextColor3", "Muted")
    end
    local valueLabel = makeText(row, formatNumber(initial), 12, window._theme.Accent, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 7),
        Size = UDim2.fromOffset(76, 20),
        TextXAlignment = Enum.TextXAlignment.Right,
        Font = Enum.Font.GothamSemibold,
    })
    window:_bindTheme(valueLabel, "TextColor3", "Accent")
    local track = create("TextButton", {
        Name = "SliderTrack",
        Position = UDim2.new(0, 12, 0, 54),
        Size = UDim2.new(1, -24, 0, 6),
        BackgroundColor3 = window._theme.Input,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    addCorner(track, 10)
    window:_bindTheme(track, "BackgroundColor3", "Input")
    local fill = create("Frame", {
        Size = UDim2.fromScale((initial - minimum) / (maximum - minimum), 1),
        BackgroundColor3 = window._theme.Accent,
        BorderSizePixel = 0,
    }, track)
    addCorner(fill, 10)
    window:_bindTheme(fill, "BackgroundColor3", "Accent")
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((initial - minimum) / (maximum - minimum), 0, 0.5, 0),
        Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = window._theme.Text,
        BorderSizePixel = 0,
    }, track)
    addCorner(knob, 20)
    addStroke(knob, window._theme.Accent, 0.1, 2)
    window:_bindTheme(knob, "BackgroundColor3", "Text")

    local control = { Value = initial, Instance = row }
    local dragging = false
    local function setValue(value, fireCallback)
        value = clamp(roundToStep(tonumber(value) or minimum, step), minimum, maximum)
        control.Value = value
        local progress = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(progress, 1)
        knob.Position = UDim2.new(progress, 0, 0.5, 0)
        valueLabel.Text = formatNumber(value)
        if fireCallback then
            safeCallback(config.Callback, value)
        end
    end
    local function updateFromX(x, fireCallback)
        local width = math.max(1, track.AbsoluteSize.X)
        local alpha = clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        setValue(minimum + (maximum - minimum) * alpha, fireCallback)
    end
    function control:Set(value, fireCallback)
        setValue(value, fireCallback ~= false)
    end
    function control:Get()
        return control.Value
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X, true)
        end
    end)
    local changedConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X, true)
        end
    end)
    local endedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    table.insert(window._elementConnections, changedConnection)
    table.insert(window._elementConnections, endedConnection)
    control:Set(initial, false)
    return control
end

function Section:Input(config)
    config = config or {}
    local window = self.Window
    local row = makeControlRow(self, config.Description and 64 or 56)
    addRowLabels(row, window, config.Title or "Input", config.Description)
    local box = create("TextBox", {
        Name = "InputBox",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(config.Width or 158, 33),
        BackgroundColor3 = window._theme.Input,
        BorderSizePixel = 0,
        ClearTextOnFocus = config.ClearTextOnFocus == true,
        Font = Enum.Font.Gotham,
        PlaceholderText = config.Placeholder or "Type here...",
        PlaceholderColor3 = window._theme.Muted,
        Text = tostring(config.Value or ""),
        TextColor3 = window._theme.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    addCorner(box, 8)
    local stroke = addStroke(box, window._theme.Border, 0.82, 1)
    addPadding(box, 10, 10, 0, 0)
    window:_bindTheme(box, "BackgroundColor3", "Input")
    window:_bindTheme(box, "TextColor3", "Text")
    window:_bindTheme(box, "PlaceholderColor3", "Muted")
    window:_bindTheme(stroke, "Color", "Border")

    local control = { Value = box.Text, Instance = row, TextBox = box }
    function control:Set(value, fireCallback)
        control.Value = tostring(value or "")
        box.Text = control.Value
        if fireCallback ~= false then
            safeCallback(config.Callback, control.Value)
        end
    end
    function control:Get()
        return control.Value
    end
    box.FocusLost:Connect(function(enterPressed)
        control.Value = box.Text
        if config.FireOnFocusLost ~= false or enterPressed then
            safeCallback(config.Callback, control.Value)
        end
    end)
    return control
end

function Section:Dropdown(config)
    config = config or {}
    local window = self.Window
    local options = config.Options or {}
    local initial = config.Value
    if initial == nil and #options > 0 then
        initial = options[1]
    end
    local row = create("Frame", {
        Name = "DropdownRow",
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
    }, self.Stack)
    addRowLabels(row, window, config.Title or "Dropdown", config.Description)

    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 10),
        Size = UDim2.fromOffset(config.Width or 150, 34),
        BackgroundColor3 = window._theme.Input,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
    }, row)
    addCorner(button, 8)
    local stroke = addStroke(button, window._theme.Border, 0.82, 1)
    window:_bindTheme(button, "BackgroundColor3", "Input")
    window:_bindTheme(stroke, "Color", "Border")
    local selectedText = makeText(button, tostring(initial or "Select an option"), 11, window._theme.Text, {
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -28, 1, 0),
    })
    window:_bindTheme(selectedText, "TextColor3", "Text")
    local arrow = makeText(button, "⌄", 16, window._theme.Muted, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -9, 0.5, -1),
        Size = UDim2.fromOffset(14, 22),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    window:_bindTheme(arrow, "TextColor3", "Muted")

    local menu = create("Frame", {
        Name = "DropdownMenu",
        Position = UDim2.new(0, 0, 0, 50),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = window._theme.Surface2,
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 8,
    }, row)
    addCorner(menu, 8)
    local menuStroke = addStroke(menu, window._theme.Border, 0.68, 1)
    window:_bindTheme(menu, "BackgroundColor3", "Surface2")
    window:_bindTheme(menuStroke, "Color", "Border")
    local menuLayout = create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, menu)
    addPadding(menu, 5, 5, 5, 5)

    local control = { Value = initial, Instance = row, Open = false }
    local function closeMenu()
        control.Open = false
        menu.Visible = false
        row.Size = UDim2.new(1, 0, 0, 54)
        arrow.Text = "⌄"
    end
    local function setValue(value, fireCallback)
        control.Value = value
        selectedText.Text = tostring(value)
        closeMenu()
        if fireCallback ~= false then
            safeCallback(config.Callback, value)
        end
    end
    local function rebuildOptions()
        for _, child in ipairs(menu:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        local visibleCount = math.min(#options, config.MaxVisible or 6)
        local menuHeight = visibleCount * 30 + 10
        menu.Size = UDim2.new(1, 0, 0, menuHeight)
        for index, option in ipairs(options) do
            if index > (config.MaxVisible or 6) then
                break
            end
            local optionButton = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = window._theme.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = tostring(option),
                TextColor3 = window._theme.Text,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                LayoutOrder = index,
                ZIndex = 9,
            }, menu)
            addCorner(optionButton, 6)
            window:_bindTheme(optionButton, "TextColor3", "Text")
            optionButton.MouseEnter:Connect(function()
                optionButton.BackgroundTransparency = 0.82
            end)
            optionButton.MouseLeave:Connect(function()
                optionButton.BackgroundTransparency = 1
            end)
            optionButton.Activated:Connect(function()
                setValue(option, true)
            end)
        end
    end
    rebuildOptions()
    function control:Set(value, fireCallback)
        setValue(value, fireCallback)
    end
    function control:Get()
        return control.Value
    end
    function control:SetOptions(newOptions)
        options = newOptions or {}
        rebuildOptions()
    end
    button.Activated:Connect(function()
        control.Open = not control.Open
        menu.Visible = control.Open
        row.Size = UDim2.new(1, 0, 0, control.Open and (54 + menu.Size.Y.Offset) or 54)
        arrow.Text = control.Open and "⌃" or "⌄"
    end)
    return control
end

function Section:Keybind(config)
    config = config or {}
    local window = self.Window
    local row = makeControlRow(self, config.Description and 64 or 56)
    addRowLabels(row, window, config.Title or "Keybind", config.Description)
    local initialKey = config.Key or Enum.KeyCode.Unknown
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(96, 32),
        BackgroundColor3 = window._theme.Input,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = initialKey == Enum.KeyCode.Unknown and "None" or initialKey.Name,
        TextColor3 = window._theme.Text,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
    }, row)
    addCorner(button, 8)
    local stroke = addStroke(button, window._theme.Border, 0.82, 1)
    window:_bindTheme(button, "BackgroundColor3", "Input")
    window:_bindTheme(button, "TextColor3", "Text")
    window:_bindTheme(stroke, "Color", "Border")

    local control = { Key = initialKey, Listening = false, Instance = row }
    function control:Set(key)
        control.Key = key or Enum.KeyCode.Unknown
        button.Text = control.Key == Enum.KeyCode.Unknown and "None" or control.Key.Name
    end
    button.Activated:Connect(function()
        control.Listening = true
        button.Text = "Press key..."
    end)
    table.insert(window._keybinds, {
        Control = control,
        Callback = config.Callback,
        Button = button,
    })
    return control
end

function Tab:Section(config)
    config = config or {}
    local window = self.Window
    local panel = create("Frame", {
        Name = "Section",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = window._theme.Surface,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
    }, self.Page)
    addCorner(panel, 12)
    local outline = addStroke(panel, window._theme.Border, 0.88, 1)
    window:_bindTheme(panel, "BackgroundColor3", "Surface")
    window:_bindTheme(outline, "Color", "Border")
    addPadding(panel, 11, 11, 9, 10)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, panel)
    local heading = makeText(panel, config.Name or config.Title or "Section", 12, window._theme.Muted, {
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.GothamSemibold,
        LayoutOrder = 1,
    })
    window:_bindTheme(heading, "TextColor3", "Muted")
    local stack = create("Frame", {
        Name = "Controls",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
    }, panel)
    create("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, stack)
    return setmetatable({ Window = window, Tab = self, Panel = panel, Stack = stack }, Section)
end

function Window:Tab(config)
    config = config or {}
    local window = self
    local name = tostring(config.Name or config.Title or ("Tab " .. (#self.Tabs + 1)))
    local index = #self.Tabs + 1

    local nav = create("TextButton", {
        Name = "Tab_" .. index,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = window._theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = index,
    }, self.TabList)
    addCorner(nav, 8)
    local marker = create("Frame", {
        Position = UDim2.new(0, 0, 0.5, -8),
        Size = UDim2.fromOffset(3, 16),
        BackgroundColor3 = window._theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, nav)
    addCorner(marker, 4)
    window:_bindTheme(marker, "BackgroundColor3", "Accent")
    local iconText = config.Icon and tostring(config.Icon) or string.sub(name, 1, 1)
    local icon = makeText(nav, iconText, 13, window._theme.Muted, {
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.fromOffset(20, 38),
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    window:_bindTheme(icon, "TextColor3", "Muted")
    local label = makeText(nav, name, 12, window._theme.Muted, {
        Position = UDim2.new(0, 39, 0, 0),
        Size = UDim2.new(1, -46, 1, 0),
        Font = Enum.Font.GothamMedium,
    })
    window:_bindTheme(label, "TextColor3", "Muted")

    local page = create("ScrollingFrame", {
        Name = "Page_" .. index,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = window._theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, self.Content)
    addPadding(page, 17, 17, 16, 18)
    create("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    window:_bindTheme(page, "ScrollBarImageColor3", "Accent")

    local tab = setmetatable({
        Window = window,
        Name = name,
        Index = index,
        Button = nav,
        Marker = marker,
        IconLabel = icon,
        TextLabel = label,
        Page = page,
    }, Tab)

    local function selectThisTab()
        if window._activeTab == tab then
            return
        end
        if window._activeTab then
            local previous = window._activeTab
            previous.Page.Visible = false
            tween(previous.Button, 0.14, { BackgroundTransparency = 1 })
            tween(previous.Marker, 0.14, { BackgroundTransparency = 1 })
            previous.TextLabel.TextColor3 = window._theme.Muted
            previous.IconLabel.TextColor3 = window._theme.Muted
        end
        window._activeTab = tab
        page.Visible = true
        tween(nav, 0.16, { BackgroundTransparency = 0.82 })
        tween(marker, 0.16, { BackgroundTransparency = 0 })
        label.TextColor3 = window._theme.Text
        icon.TextColor3 = window._theme.Accent
    end

    nav.Activated:Connect(selectThisTab)
    nav.MouseEnter:Connect(function()
        if window._activeTab ~= tab then
            tween(nav, 0.12, { BackgroundTransparency = 0.92 })
        end
    end)
    nav.MouseLeave:Connect(function()
        if window._activeTab ~= tab then
            tween(nav, 0.12, { BackgroundTransparency = 1 })
        end
    end)

    tab.Select = selectThisTab
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 or config.Selected then
        selectThisTab()
    end
    return tab
end

function Window:Notify(config)
    config = config or {}
    if self._destroyed then
        return nil
    end
    local duration = tonumber(config.Duration)
    if duration == nil then
        duration = 4
    end
    local toast = create("Frame", {
        Name = "AeroUI_Notification",
        Size = UDim2.fromOffset(292, config.Content and 82 or 62),
        BackgroundColor3 = self._theme.Surface2,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, self.NotificationStack)
    addCorner(toast, 12)
    local outline = addStroke(toast, self._theme.Border, 0.64, 1)
    self:_bindTheme(toast, "BackgroundColor3", "Surface2")
    self:_bindTheme(outline, "Color", "Border")
    local accent = create("Frame", {
        Size = UDim2.new(0, 3, 1, -22),
        Position = UDim2.new(0, 0, 0, 11),
        BackgroundColor3 = self._theme.Accent,
        BorderSizePixel = 0,
    }, toast)
    addCorner(accent, 3)
    self:_bindTheme(accent, "BackgroundColor3", "Accent")
    local title = makeText(toast, config.Title or "AeroUI", 12, self._theme.Text, {
        Position = UDim2.new(0, 15, 0, 11),
        Size = UDim2.new(1, -48, 0, 19),
        Font = Enum.Font.GothamSemibold,
    })
    self:_bindTheme(title, "TextColor3", "Text")
    if config.Content then
        local body = makeText(toast, config.Content, 11, self._theme.Muted, {
            Position = UDim2.new(0, 15, 0, 33),
            Size = UDim2.new(1, -28, 0, 35),
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        self:_bindTheme(body, "TextColor3", "Muted")
    end
    local close = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -9, 0, 8),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        Text = "×",
        TextSize = 17,
        Font = Enum.Font.Gotham,
        TextColor3 = self._theme.Muted,
        AutoButtonColor = false,
    }, toast)
    self:_bindTheme(close, "TextColor3", "Muted")

    local closed = false
    local function dismiss()
        if closed or not toast.Parent then
            return
        end
        closed = true
        local animation = tween(toast, 0.16, {
            BackgroundTransparency = 1,
            Position = UDim2.new(1, 24, 0, 0),
        })
        animation.Completed:Connect(function()
            if toast.Parent then
                toast:Destroy()
            end
        end)
    end
    close.Activated:Connect(dismiss)
    if duration > 0 then
        task.delay(duration, dismiss)
    end
    return {
        Instance = toast,
        Close = dismiss,
    }
end

function AeroUI.CreateWindow(config)
    config = config or {}
    if not LOCAL_PLAYER then
        error("AeroUI.CreateWindow must be called from a client LocalScript.", 2)
    end

    local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local requestedWidth = tonumber(config.Width) or 700
    local requestedHeight = tonumber(config.Height) or 470
    local width = math.min(requestedWidth, math.max(300, viewport.X - 24))
    local height = math.min(requestedHeight, math.max(260, viewport.Y - 48))
    local themeName = THEMES[config.Theme] and config.Theme or "Midnight"
    local theme = table.clone(THEMES[themeName])
    if typeof(config.Accent) == "Color3" then
        theme.Accent = config.Accent
    end
    local useLiquidGlass = config.LiquidGlass ~= false

    local self = setmetatable({
        Title = config.Title or "AeroUI",
        Theme = themeName,
        _theme = theme,
        _customAccent = typeof(config.Accent) == "Color3" and config.Accent or nil,
        _themeBindings = {},
        _themeRefreshers = {},
        _connections = {},
        _elementConnections = {},
        _keybinds = {},
        _tabs = {},
        Tabs = {},
        _visible = true,
        _destroyed = false,
        _ownsBlur = false,
        ToggleKey = config.ToggleKey,
        _width = requestedWidth,
        _height = requestedHeight,
        LiquidGlass = useLiquidGlass,
    }, Window)

    self.Gui = create("ScreenGui", {
        Name = "AeroUI_GlassEdition",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 40,
        Enabled = true,
    }, playerGui)

    self.Shadow = create("Frame", {
        Name = "WindowShadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 7),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.57,
        BorderSizePixel = 0,
    }, self.Gui)
    addCorner(self.Shadow, 17)

    self.Main = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = useLiquidGlass and 0.12 or 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, self.Gui)
    addCorner(self.Main, 16)
    local mainStroke = addStroke(self.Main, theme.Border, 0.42, 1)
    self:_bindTheme(self.Main, "BackgroundColor3", "Surface")
    self:_bindTheme(mainStroke, "Color", "Border")

    if useLiquidGlass then
        local glass = create("Frame", {
            Name = "LiquidGlassLayer",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = theme.Glass,
            BackgroundTransparency = 0.84,
            BorderSizePixel = 0,
            ZIndex = 1,
        }, self.Main)
        addCorner(glass, 16)
        self:_bindTheme(glass, "BackgroundColor3", "Glass")
        create("UIGradient", {
            Rotation = 118,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.35, Color3.fromRGB(220, 235, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(95, 130, 180)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.82),
                NumberSequenceKeypoint.new(0.46, 0.96),
                NumberSequenceKeypoint.new(1, 0.88),
            }),
        }, glass)
        local topSheen = create("Frame", {
            Name = "GlassTopSheen",
            Size = UDim2.new(1, -2, 0, 1),
            Position = UDim2.new(0, 1, 0, 1),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.48,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, self.Main)
        local sideSheen = create("Frame", {
            Name = "GlassEdgeSheen",
            Size = UDim2.new(0, 1, 1, -36),
            Position = UDim2.new(1, -1, 0, 18),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.72,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, self.Main)
        table.insert(self._connections, RunService.RenderStepped:Connect(function(dt)
            if self._destroyed or not glass.Parent then
                return
            end
            local gradient = glass:FindFirstChildOfClass("UIGradient")
            if gradient then
                gradient.Rotation = (gradient.Rotation + dt * 2.2) % 360
            end
        end))
    end

    self.Topbar = create("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = theme.Surface2,
        BackgroundTransparency = useLiquidGlass and 0.24 or 0,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, self.Main)
    self:_bindTheme(self.Topbar, "BackgroundColor3", "Surface2")
    local topbarLine = create("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = theme.Border,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, self.Topbar)
    self:_bindTheme(topbarLine, "BackgroundColor3", "Border")

    local logo = create("Frame", {
        Position = UDim2.new(0, 16, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.fromOffset(31, 31),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, self.Topbar)
    addCorner(logo, 10)
    self:_bindTheme(logo, "BackgroundColor3", "Accent")
    makeText(logo, config.LogoText or "A", 15, theme.AccentText, {
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        Font = Enum.Font.GothamBold,
        ZIndex = 6,
    })

    self.TitleLabel = makeText(self.Topbar, self.Title, 14, theme.Text, {
        Position = UDim2.new(0, 58, 0, 10),
        Size = UDim2.new(1, -160, 0, 20),
        Font = Enum.Font.GothamSemibold,
        ZIndex = 5,
    })
    self:_bindTheme(self.TitleLabel, "TextColor3", "Text")
    self.SubtitleLabel = makeText(self.Topbar, config.Subtitle or "A clean interface for your experience", 10, theme.Muted, {
        Position = UDim2.new(0, 58, 0, 31),
        Size = UDim2.new(1, -160, 0, 15),
        Font = Enum.Font.Gotham,
        ZIndex = 5,
    })
    self:_bindTheme(self.SubtitleLabel, "TextColor3", "Muted")

    local minimize = create("TextButton", {
        Name = "Minimize",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -48, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = theme.Card,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Text = "–",
        TextColor3 = theme.Text,
        TextSize = 19,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        ZIndex = 6,
    }, self.Topbar)
    addCorner(minimize, 8)
    self:_bindTheme(minimize, "BackgroundColor3", "Card")
    self:_bindTheme(minimize, "TextColor3", "Text")

    local close = create("TextButton", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -13, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = theme.Danger,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Text = "×",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 18,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        ZIndex = 6,
    }, self.Topbar)
    addCorner(close, 8)
    self:_bindTheme(close, "BackgroundColor3", "Danger")

    self.Body = create("Frame", {
        Name = "Body",
        Position = UDim2.new(0, 0, 0, 58),
        Size = UDim2.new(1, 0, 1, -58),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, self.Main)

    self.Sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, clamp(width * 0.22, 86, 158), 1, 0),
        BackgroundColor3 = theme.Surface2,
        BackgroundTransparency = useLiquidGlass and 0.34 or 0,
        BorderSizePixel = 0,
    }, self.Body)
    self:_bindTheme(self.Sidebar, "BackgroundColor3", "Surface2")
    create("Frame", {
        Position = UDim2.new(1, -1, 0, 10),
        Size = UDim2.new(0, 1, 1, -20),
        BackgroundColor3 = theme.Border,
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
    }, self.Sidebar)
    self.TabList = create("ScrollingFrame", {
        Name = "Tabs",
        Position = UDim2.new(0, 10, 0, 14),
        Size = UDim2.new(1, -20, 1, -28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, self.Sidebar)
    addPadding(self.TabList, 0, 0, 2, 2)
    create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, self.TabList)
    self:_bindTheme(self.TabList, "ScrollBarImageColor3", "Accent")

    self.Content = create("Frame", {
        Name = "Content",
        Position = UDim2.new(0, self.Sidebar.Size.X.Offset, 0, 0),
        Size = UDim2.new(1, -self.Sidebar.Size.X.Offset, 1, 0),
        BackgroundTransparency = 1,
    }, self.Body)

    self.NotificationStack = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 0, 18),
        Size = UDim2.new(0, 300, 1, -36),
        BackgroundTransparency = 1,
        ZIndex = 50,
    }, self.Gui)
    create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top,
    }, self.NotificationStack)

    local collapsed = false
    self._expandedSize = UDim2.fromOffset(width, height)
    minimize.Activated:Connect(function()
        collapsed = not collapsed
        if collapsed then
            self._expandedSize = self.Main.Size
        end
        self.Body.Visible = not collapsed
        local targetSize = collapsed and UDim2.new(0, self.Main.AbsoluteSize.X, 0, 58) or self._expandedSize
        tween(self.Main, 0.2, { Size = targetSize })
        self.Shadow.Size = targetSize
        minimize.Text = collapsed and "+" or "–"
    end)
    close.Activated:Connect(function()
        self:Destroy()
    end)

    -- Dragging is handled by Roblox input events and works with mouse and touch.
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil
    self.Topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPosition = self.Main.Position
        end
    end)
    self.Topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and dragInput and input == dragInput then
            local delta = input.Position - dragStart
            self.Main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
            self.Shadow.Position = UDim2.new(
                self.Main.Position.X.Scale,
                self.Main.Position.X.Offset,
                self.Main.Position.Y.Scale,
                self.Main.Position.Y.Offset + 7
            )
        end
    end))
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            dragInput = nil
        end
    end))

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if self._destroyed then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if UserInputService:GetFocusedTextBox() then
            return
        end
        if self.ToggleKey and input.KeyCode == self.ToggleKey and not gameProcessed then
            self:Toggle()
        end
        for _, bind in ipairs(self._keybinds) do
            local control = bind.Control
            if control.Listening then
                control:Set(input.KeyCode)
                control.Listening = false
            elseif control.Key ~= Enum.KeyCode.Unknown and input.KeyCode == control.Key and not gameProcessed then
                safeCallback(bind.Callback, input.KeyCode)
            end
        end
    end))

    self:SetSize(requestedWidth, requestedHeight)
    if camera then
        table.insert(self._connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if not self._destroyed then
                self:SetSize(self._width, self._height)
            end
        end))
    end
    if config.Blur == true then
        self:SetBlur(true)
    end
    return self
end

AeroUI.Themes = THEMES
AeroUI.CreateWindow = AeroUI.CreateWindow

function AeroUI:GetVersion()
    return self.Version
end

function AeroUI:GetThemes()
    return table.clone(THEMES)
end

return AeroUI
