--[[
	User Interface Library
	Made by Late
]]

--// Connections
local GetService = game.GetService
local Connect = game.Loaded.Connect
local Wait = game.Loaded.Wait
local Clone = game.Clone 
local Destroy = game.Destroy 

if (not game:IsLoaded()) then
	local Loaded = game.Loaded
	Loaded.Wait(Loaded);
end

--// Important 
local Setup = {
	Keybind = Enum.KeyCode.LeftControl,
	Transparency = 0.2,
	ThemeMode = "Dark",
	Size = nil,
}

local Theme = { --// (Dark Theme)
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
}

--// Services & Functions
local Type, Blur = nil
local LocalPlayer = GetService(game, "Players").LocalPlayer;
local Services = {
	Insert = GetService(game, "InsertService");
	Tween = GetService(game, "TweenService");
	Run = GetService(game, "RunService");
	Input = GetService(game, "UserInputService");
}

local Player = {
	Mouse = LocalPlayer:GetMouse();
	GUI = LocalPlayer.PlayerGui;
}

local Tween = function(Object : Instance, Speed : number, Properties : {},  Info : { EasingStyle: Enum?, EasingDirection: Enum? })
	local Style, Direction

	if Info then
		Style, Direction = Info["EasingStyle"], Info["EasingDirection"]
	else
		Style, Direction = Enum.EasingStyle.Sine, Enum.EasingDirection.Out
	end

	return Services.Tween:Create(Object, TweenInfo.new(Speed, Style, Direction), Properties):Play()
end

local SetProperty = function(Object: Instance, Properties: {})
	for Index, Property in next, Properties do
		Object[Index] = (Property);
	end

	return Object
end

local Multiply = function(Value, Amount)
	local New = {
		Value.X.Scale * Amount;
		Value.X.Offset * Amount;
		Value.Y.Scale * Amount;
		Value.Y.Offset * Amount;
	}

	return UDim2.new(unpack(New))
end

local Color = function(Color, Factor, Mode)
	Mode = Mode or Setup.ThemeMode

	if Mode == "Light" then
		return Color3.fromRGB((Color.R * 255) - Factor, (Color.G * 255) - Factor, (Color.B * 255) - Factor)
	else
		return Color3.fromRGB((Color.R * 255) + Factor, (Color.G * 255) + Factor, (Color.B * 255) + Factor)
	end
end

local Drag = function(Canvas)
	if Canvas then
		local Dragging;
		local DragInput;
		local Start;
		local StartPosition;

		local function Update(input)
			local delta = input.Position - Start
			Canvas.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + delta.Y)
		end

		Connect(Canvas.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch and not Type then
				Dragging = true
				Start = Input.Position
				StartPosition = Canvas.Position

				Connect(Input.Changed, function()
					if Input.UserInputState == Enum.UserInputState.End then
						Dragging = false
					end
				end)
			end
		end)

		Connect(Canvas.InputChanged, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch and not Type then
				DragInput = Input
			end
		end)

		Connect(Services.Input.InputChanged, function(Input)
			if Input == DragInput and Dragging and not Type then
				Update(Input)
			end
		end)
	end
end

Resizing = { 
	TopLeft = { X = Vector2.new(-1, 0),   Y = Vector2.new(0, -1)};
	TopRight = { X = Vector2.new(1, 0),    Y = Vector2.new(0, -1)};
	BottomLeft = { X = Vector2.new(-1, 0),   Y = Vector2.new(0, 1)};
	BottomRight = { X = Vector2.new(1, 0),    Y = Vector2.new(0, 1)};
}

Resizeable = function(Tab, Minimum, Maximum)
	task.spawn(function()
		local MousePos, Size, UIPos = nil, nil, nil

		if Tab and Tab:FindFirstChild("Resize") then
			local Positions = Tab:FindFirstChild("Resize")

			for Index, Types in next, Positions:GetChildren() do
				Connect(Types.InputBegan, function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						Type = Types
						MousePos = Vector2.new(Player.Mouse.X, Player.Mouse.Y)
						Size = Tab.AbsoluteSize
						UIPos = Tab.Position
					end
				end)

				Connect(Types.InputEnded, function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						Type = nil
					end
				end)
			end
		end

		local Resize = function(Delta)
			if Type and MousePos and Size and UIPos and Tab:FindFirstChild("Resize")[Type.Name] == Type then
				local Mode = Resizing[Type.Name]
				local NewSize = Vector2.new(Size.X + Delta.X * Mode.X.X, Size.Y + Delta.Y * Mode.Y.Y)
				NewSize = Vector2.new(math.clamp(NewSize.X, Minimum.X, Maximum.X), math.clamp(NewSize.Y, Minimum.Y, Maximum.Y))

				local AnchorOffset = Vector2.new(Tab.AnchorPoint.X * Size.X, Tab.AnchorPoint.Y * Size.Y)
				local NewAnchorOffset = Vector2.new(Tab.AnchorPoint.X * NewSize.X, Tab.AnchorPoint.Y * NewSize.Y)
				local DeltaAnchorOffset = NewAnchorOffset - AnchorOffset

				Tab.Size = UDim2.new(0, NewSize.X, 0, NewSize.Y)

				local NewPosition = UDim2.new(
					UIPos.X.Scale, 
					UIPos.X.Offset + DeltaAnchorOffset.X * Mode.X.X,
					UIPos.Y.Scale,
					UIPos.Y.Offset + DeltaAnchorOffset.Y * Mode.Y.Y
				)
				Tab.Position = NewPosition
			end
		end

		Connect(Player.Mouse.Move, function()
			if Type then
				Resize(Vector2.new(Player.Mouse.X, Player.Mouse.Y) - MousePos)
			end
		end)
	end)
end

--// Setup [UI]
--// Nguồn tải module khi chạy bằng executor. Đổi link thành repo của bạn (hoặc để file cùng tên trong workspace).
local Sources = {
	Blur = "https://raw.githubusercontent.com/lxte/lates-lib/main/Assets/Blur.lua",
	LiquidGlass = "", --// ví dụ: "https://raw.githubusercontent.com/<user>/<repo>/main/LiquidGlass.lua"
}

if getgenv and getgenv().LateLibSources then
	for Name, Url in next, getgenv().LateLibSources do
		Sources[Name] = Url
	end
end

--// Tải module an toàn: workspace file -> URL -> require (Studio). Lỗi thì trả nil chứ không làm sập UI.
local LoadModule = function(Name: string)
	local Ok, Result = pcall(function()
		if identifyexecutor then
			if isfile and readfile and isfile(Name .. ".lua") then
				return loadstring(readfile(Name .. ".lua"))()
			end

			local Url = Sources[Name]
			if Url and Url ~= "" then
				return loadstring(game:HttpGet(Url))()
			end

			error("không có nguồn cho " .. Name)
		else
			return require(script:WaitForChild(Name, 5))
		end
	end)

	if not Ok then
		warn(("[UI LIB]: Không tải được %s (%s)"):format(Name, tostring(Result)))
		return nil
	end

	return Result
end

if (identifyexecutor) then
	Screen = Services.Insert:LoadLocalAsset("rbxassetid://18490507748");
else
	Screen = (script.Parent);
end

Blur = LoadModule("Blur")
local LiquidGlass = LoadModule("LiquidGlass")

Screen.Main.Visible = false

xpcall(function()
	Screen.Parent = game.CoreGui
end, function() 
	Screen.Parent = Player.GUI
end)

--// Tables for Data
local Animations = {}
local Components = (Screen:FindFirstChild("Components"));
local Library = {};
local StoredInfo = {
	["Sections"] = {};
	["Tabs"] = {}
};

--// Animations [Window]
function Animations:Open(Window: CanvasGroup, Transparency: number, UseCurrentSize: boolean)
	local Original = (UseCurrentSize and Window.Size) or Setup.Size
	local Multiplied = Multiply(Original, 1.1)
	local Shadow = Window:FindFirstChildOfClass("UIStroke")


	SetProperty(Shadow, { Transparency = 1 })
	SetProperty(Window, {
		Size = Multiplied,
		GroupTransparency = 1,
		Visible = true,
	})

	Tween(Shadow, .25, { Transparency = 0.5 })
	Tween(Window, .25, {
		Size = Original,
		GroupTransparency = Transparency or 0,
	})
end

function Animations:Close(Window: CanvasGroup)
	local Original = Window.Size
	local Multiplied = Multiply(Original, 1.1)
	local Shadow = Window:FindFirstChildOfClass("UIStroke")

	SetProperty(Window, {
		Size = Original,
	})

	Tween(Shadow, .25, { Transparency = 1 })
	Tween(Window, .25, {
		Size = Multiplied,
		GroupTransparency = 1,
	})

	task.wait(.25)
	Window.Size = Original
	Window.Visible = false
end


function Animations:Component(Component: any, Custom: boolean)	
	Connect(Component.InputBegan, function() 
		if Custom then
			Tween(Component, .25, { Transparency = .85 });
		else
			Tween(Component, .25, { BackgroundColor3 = Color(Theme.Component, 5, Setup.ThemeMode) });
		end
	end)

	Connect(Component.InputEnded, function() 
		if Custom then
			Tween(Component, .25, { Transparency = 1 });
		else
			Tween(Component, .25, { BackgroundColor3 = Theme.Component });
		end
	end)
end

--// Helper blur an toàn: chạy được cả với Blur.lua cũ (không có Show/Hide) lẫn bản mới
local BlurShow = function(Object, Time)
	if not Object then return end

	pcall(function()
		if typeof(Object.Show) == "function" then
			Object:Show(Time)
		elseif Object.root then
			Object.root.Parent = workspace.CurrentCamera
		end
	end)
end

local BlurHide = function(Object, Time)
	if not Object then return end

	pcall(function()
		if typeof(Object.Hide) == "function" then
			Object:Hide(Time)
		elseif Object.root then
			Object.root.Parent = nil
		end
	end)
end

local BlurSetIntensity = function(Object, Value)
	if not Object then return end

	pcall(function()
		if typeof(Object.SetIntensity) == "function" then
			Object:SetIntensity(Value)
		elseif typeof(Object.setBlurIntensity) == "function" then
			Object:setBlurIntensity(Value)
		end
	end)
end

--// Library [Window]

function Library:CreateWindow(Settings: { Title: string, Size: UDim2, Transparency: number, MinimizeKeybind: Enum.KeyCode?, Blurring: (boolean | number)?, LiquidGlass: (boolean | { [string]: any })?, Theme: string })
	local Window = Clone(Screen:WaitForChild("Main"));
	local Sidebar = Window:FindFirstChild("Sidebar");
	local Holder = Window:FindFirstChild("Main");
	local BG = Window:FindFirstChild("BackgroundShadow");
	local Tab = Sidebar:FindFirstChild("Tab");

	local Options = {};
	local Examples = {};
	local Maximized = false;
	local BlurEnabled = false

	for Index, Example in next, Window:GetDescendants() do
		if Example.Name:find("Example") and not Examples[Example.Name] then
			Examples[Example.Name] = Example
		end
	end

	--// UI Blur & More
	Drag(Window);
	Resizeable(Window, Vector2.new(411, 271), Vector2.new(9e9, 9e9));
	Setup.Transparency = Settings.Transparency or 0
	Setup.Size = Settings.Size
	Setup.ThemeMode = Settings.Theme or "Dark"

	--// Blur nền (Blur.lua) -- nhận Blurring = true hoặc số 0..1 (độ mạnh)
	local BlurObject
	local MakeBlur = function()
		if not Blur then return nil end

		local Ok, Result = pcall(Blur.new, Window, (typeof(Settings.Blurring) == "number" and Settings.Blurring) or 1, { Visible = false })
		if Ok then
			if typeof(Result.Show) ~= "function" then
				warn("[UI LIB]: Đang dùng Blur.lua CŨ - hãy đổi link Sources.Blur sang Blur.lua mới để có blur đẹp.")
				BlurHide(Result)
			end
			return Result
		end

		warn("[UI LIB]: Blur lỗi: " .. tostring(Result))
		return nil
	end

	if Settings.Blurring then
		BlurObject = MakeBlur()
		BlurEnabled = BlurObject ~= nil
	end

	--// Liquid Glass (LiquidGlass.lua) -- LiquidGlass = true hoặc { Intensity = 1, Tint = Color3, ... }
	local GlassObject
	local GlassSettings = Settings.LiquidGlass

	if GlassSettings and LiquidGlass then
		local Config = (typeof(GlassSettings) == "table" and table.clone(GlassSettings)) or {}

		Config.Corner = Config.Corner or (Window:FindFirstChildOfClass("UICorner") and Window:FindFirstChildOfClass("UICorner").CornerRadius)
		--// Không tự làm trong suốt các khung nữa (tránh UI bị trắng/trống). Muốn thì truyền Frames = { {Window, 0.5}, ... }

		local Ok, Result = pcall(LiquidGlass.new, Window, Config)
		if Ok then
			GlassObject = Result
		else
			warn("[UI LIB]: LiquidGlass lỗi: " .. tostring(Result))

			local Leftover = Window:FindFirstChild("LiquidGlass")
			if Leftover then Leftover:Destroy() end
		end
	end

	if Settings.MinimizeKeybind then
		Setup.Keybind = Settings.MinimizeKeybind
	end

	--// Minimize -> thanh "Show UI" (hoạt động cả PC lẫn mobile)
	local Minimized, Busy = false, true --// Busy = true trong lúc animation mở đầu chạy
	local Touch = Services.Input.TouchEnabled
	local PillSize = Touch and Vector2.new(138, 36) or Vector2.new(116, 30)
	local PillTop = Touch and 14 or 10
	local MinScale = 0.06
	local Saved = { Position = nil, Size = nil }

	local Play = function(Object: Instance, Time: number, Style: Enum.EasingStyle, Direction: Enum.EasingDirection, Properties: {})
		local Animation = Services.Tween:Create(Object, TweenInfo.new(Time, Style, Direction), Properties)
		Animation:Play()
		return Animation
	end

	--// UIScale giúp cả cửa sổ co lại đều như macOS (không bị méo layout)
	local WindowScale = Window:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	WindowScale.Scale = 1
	WindowScale.Parent = Window

	--// Thanh Show UI
	local Pill = SetProperty(Instance.new("TextButton"), {
		Name = "ShowUI",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, PillTop),
		Size = UDim2.fromOffset(PillSize.X * 0.4, PillSize.Y * 0.6),
		BackgroundColor3 = Theme.Primary,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "Show UI",
		TextColor3 = Theme.Title,
		TextTransparency = 1,
		TextSize = Touch and 15 or 13,
		Visible = false,
		ZIndex = 200,
		Parent = Screen,
	})

	SetProperty(Instance.new("UICorner"), { CornerRadius = UDim.new(1, 0), Parent = Pill })
	local PillStroke = SetProperty(Instance.new("UIStroke"), {
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = Pill,
	})
	local PillScale = SetProperty(Instance.new("UIScale"), { Scale = 1, Parent = Pill })

	--// Pill cũng dùng liquid glass + blur riêng nếu có
	local PillGlass, PillBlur
	if GlassSettings and LiquidGlass then
		local Ok, Result = pcall(LiquidGlass.new, Pill, { Corner = UDim.new(1, 0), RimThickness = 1.2, Intensity = 1, ZIndex = 201 })
		PillGlass = Ok and Result or nil

		if not Ok then
			local Leftover = Pill:FindFirstChild("LiquidGlass")
			if Leftover then Leftover:Destroy() end
		end
	end
	if BlurEnabled and Blur then
		local Ok, Result = pcall(Blur.new, Pill, 1, { Visible = false, Inset = 3 })
		PillBlur = Ok and Result or nil
		if PillBlur and typeof(PillBlur.Show) ~= "function" then BlurHide(PillBlur) end
	end

	--// Tâm của thanh -> điểm cửa sổ co về / bung ra
	local GetTarget = function()
		local Size = Window.AbsoluteSize / math.max(WindowScale.Scale, 0.001)
		local Anchor = Window.AnchorPoint
		local Center = Vector2.new(Screen.AbsoluteSize.X / 2, PillTop + PillSize.Y / 2)

		--// Bù AnchorPoint để TÂM cửa sổ rơi đúng tâm thanh (không phụ thuộc AnchorPoint)
		local Offset = (Vector2.new(0.5, 0.5) - Anchor) * Size * MinScale
		return UDim2.fromOffset(Center.X - Offset.X, Center.Y - Offset.Y)
	end

	local ShowPill = function()
		Pill.Visible = true
		PillScale.Scale = 1
		Pill.Size = UDim2.fromOffset(PillSize.X * 0.4, PillSize.Y * 0.6)

		Play(Pill, .5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Size = UDim2.fromOffset(PillSize.X, PillSize.Y), BackgroundTransparency = math.clamp(Setup.Transparency + 0.1, 0, 0.6) })
		Play(Pill, .3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, { TextTransparency = 0 })
		Play(PillStroke, .3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, { Transparency = 0.55 })

		if PillBlur then BlurShow(PillBlur, .3) end
	end

	local HidePill = function()
		if PillBlur then BlurHide(PillBlur, .2) end

		local Animation = Play(Pill, .28, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { Size = UDim2.fromOffset(PillSize.X * 0.4, PillSize.Y * 0.6), BackgroundTransparency = 1, TextTransparency = 1 })
		Play(PillStroke, .2, Enum.EasingStyle.Sine, Enum.EasingDirection.In, { Transparency = 1 })

		return Animation
	end

	local Minimize = function()
		if Minimized or Busy then return end
		Busy = true

		Saved.Position, Saved.Size = Window.Position, Window.Size
		local Shadow = Window:FindFirstChildOfClass("UIStroke")

		if BlurObject then BlurHide(BlurObject, .3) end
		if Shadow then Play(Shadow, .25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, { Transparency = 1 }) end

		--// Cửa sổ co lại + bay lên thanh (Position đi nhanh hơn Scale để tạo cảm giác "hút" vào)
		Play(Window, .42, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, { Position = GetTarget(), GroupTransparency = 1 })
		local Shrink = Play(WindowScale, .42, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { Scale = MinScale })

		task.delay(.26, function()
			if not Minimized then ShowPill() end
		end)

		Connect(Shrink.Completed, function()
			Window.Visible = false
			Minimized, Busy = true, false
		end)
	end

	local Restore = function()
		if not Minimized or Busy then return end
		Busy = true

		--// Bấm xuống tạo cảm giác "nhấn" rồi thanh thu lại, cửa sổ bung ra từ thanh
		Play(PillScale, .08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.92 })
		local Hidden = HidePill()

		Window.Visible = true
		local Shadow = Window:FindFirstChildOfClass("UIStroke")
		if Shadow then Play(Shadow, .4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, { Transparency = 0.5 }) end

		Play(Window, .45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = Saved.Position, GroupTransparency = Setup.Transparency or 0 })
		local Grow = Play(WindowScale, .5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })

		Connect(Hidden.Completed, function()
			Pill.Visible = false
		end)

		Connect(Grow.Completed, function()
			Minimized, Busy = false, false
			if BlurObject then BlurShow(BlurObject, .3) end
		end)
	end

	--// Phản hồi khi chạm / rê chuột
	Connect(Pill.MouseButton1Click, Restore)
	Connect(Pill.InputBegan, function(Input)
		if Busy then return end

		if Input.UserInputType == Enum.UserInputType.Touch or Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Play(PillScale, .1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.94 })
		elseif Input.UserInputType == Enum.UserInputType.MouseMovement then
			Play(PillScale, .2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1.05 })
		end
	end)
	Connect(Pill.InputEnded, function(Input)
		if Busy then return end

		if Input.UserInputType == Enum.UserInputType.Touch or Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.MouseMovement then
			Play(PillScale, .2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
		end
	end)

	--// Một logic ẩn/hiện duy nhất cho mọi cách ẩn (nút X, nút thu nhỏ, phím tắt PC)
	--// -> luôn để lại thanh "Show UI" để mobile bấm mở lại được
	local Toggle = function()
		if Minimized then
			Restore()
		else
			Minimize()
		end
	end

	for Index, Button in next, Sidebar.Top.Buttons:GetChildren() do
		if Button:IsA("TextButton") then
			local Name = Button.Name
			Animations:Component(Button, true)

			Connect(Button.MouseButton1Click, function() 
				if Name == "Close" then
					Minimize()
				elseif Name == "Maximize" then
					if Maximized then
						Maximized = false
						Tween(Window, .15, { Size = Setup.Size });
					else
						Maximized = true
						Tween(Window, .15, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5 )});
					end
				elseif Name == "Minimize" then
					Minimize()
				end
			end)
		end
	end

	Services.Input.InputBegan:Connect(function(Input, Focused) 
		if (Input == Setup.Keybind or Input.KeyCode == Setup.Keybind) and not Focused then
			Toggle()
		end
	end)

	--// Tab Functions

	function Options:SetTab(Name: string)
		for Index, Button in next, Tab:GetChildren() do
			if Button:IsA("TextButton") then
				local Opened, SameName = Button.Value, (Button.Name == Name);
				local Padding = Button:FindFirstChildOfClass("UIPadding");

				if SameName and not Opened.Value then
					Tween(Padding, .25, { PaddingLeft = UDim.new(0, 25) });
					Tween(Button, .25, { BackgroundTransparency = 0.9, Size = UDim2.new(1, -15, 0, 30) });
					SetProperty(Opened, { Value = true });
				elseif not SameName and Opened.Value then
					Tween(Padding, .25, { PaddingLeft = UDim.new(0, 20) });
					Tween(Button, .25, { BackgroundTransparency = 1, Size = UDim2.new(1, -44, 0, 30) });
					SetProperty(Opened, { Value = false });
				end
			end
		end

		for Index, Main in next, Holder:GetChildren() do
			if Main:IsA("CanvasGroup") then
				local Opened, SameName = Main.Value, (Main.Name == Name);
				local Scroll = Main:FindFirstChild("ScrollingFrame");

				if SameName and not Opened.Value then
					Opened.Value = true
					Main.Visible = true

					Tween(Main, .3, { GroupTransparency = 0 });
					Tween(Scroll["UIPadding"], .3, { PaddingTop = UDim.new(0, 5) });

				elseif not SameName and Opened.Value then
					Opened.Value = false

					Tween(Main, .15, { GroupTransparency = 1 });
					Tween(Scroll["UIPadding"], .15, { PaddingTop = UDim.new(0, 15) });	

					task.delay(.2, function()
						Main.Visible = false
					end)
				end
			end
		end
	end

	function Options:AddTabSection(Settings: { Name: string, Order: number })
		local Example = Examples["SectionExample"];
		local Section = Clone(Example);

		StoredInfo["Sections"][Settings.Name] = (Settings.Order);
		SetProperty(Section, { 
			Parent = Example.Parent,
			Text = Settings.Name,
			Name = Settings.Name,
			LayoutOrder = Settings.Order,
			Visible = true
		});
	end

	function Options:AddTab(Settings: { Title: string, Icon: string, Section: string? })
		if StoredInfo["Tabs"][Settings.Title] then 
			error("[UI LIB]: A tab with the same name has already been created") 
		end 

		local Example, MainExample = Examples["TabButtonExample"], Examples["MainExample"];
		local Section = StoredInfo["Sections"][Settings.Section];
		local Main = Clone(MainExample);
		local Tab = Clone(Example);

		if not Settings.Icon then
			Destroy(Tab["ICO"]);
		else
			SetProperty(Tab["ICO"], { Image = Settings.Icon });
		end

		StoredInfo["Tabs"][Settings.Title] = { Tab }
		SetProperty(Tab["TextLabel"], { Text = Settings.Title });

		SetProperty(Main, { 
			Parent = MainExample.Parent,
			Name = Settings.Title;
		});

		SetProperty(Tab, { 
			Parent = Example.Parent,
			LayoutOrder = Section or #StoredInfo["Sections"] + 1,
			Name = Settings.Title;
			Visible = true;
		});

		Tab.MouseButton1Click:Connect(function()
			Options:SetTab(Tab.Name);
		end)

		return Main.ScrollingFrame
	end
	
	--// Notifications
	
	function Options:Notify(Settings: { Title: string, Description: string, Duration: number }) 
		local Notification = Clone(Components["Notification"]);
		local Title, Description = Options:GetLabels(Notification);
		local Timer = Notification["Timer"];
		
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Notification, {
			Parent = Screen["Frame"],
		})
		
		task.spawn(function() 
			local Duration = Settings.Duration or 2
			local Wait = task.wait;
			
			Animations:Open(Notification, Setup.Transparency, true); Tween(Timer, Duration, { Size = UDim2.new(0, 0, 0, 4) });
			Wait(Duration);
			Animations:Close(Notification);
			Wait(1);
			Notification:Destroy();
		end)
	end

	--// Component Functions

	function Options:GetLabels(Component)
		local Labels = Component:FindFirstChild("Labels")

		return Labels.Title, Labels.Description
	end

	function Options:AddSection(Settings: { Name: string, Tab: Instance }) 
		local Section = Clone(Components["Section"]);
		SetProperty(Section, {
			Text = Settings.Name,
			Parent = Settings.Tab,
			Visible = true,
		})
	end
	
	function Options:AddButton(Settings: { Title: string, Description: string, Tab: Instance, Callback: any }) 
		local Button = Clone(Components["Button"]);
		local Title, Description = Options:GetLabels(Button);

		Connect(Button.MouseButton1Click, Settings.Callback)
		Animations:Component(Button)
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Button, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddInput(Settings: { Title: string, Description: string, Tab: Instance, Callback: any }) 
		local Input = Clone(Components["Input"]);
		local Title, Description = Options:GetLabels(Input);
		local TextBox = Input["Main"]["Input"];

		Connect(Input.MouseButton1Click, function() 
			TextBox:CaptureFocus()
		end)

		Connect(TextBox.FocusLost, function() 
			Settings.Callback(TextBox.Text)
		end)

		Animations:Component(Input)
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Input, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddToggle(Settings: { Title: string, Description: string, Default: boolean, Tab: Instance, Callback: any }) 
		local Toggle = Clone(Components["Toggle"]);
		local Title, Description = Options:GetLabels(Toggle);

		local On = Toggle["Value"];
		local Main = Toggle["Main"];
		local Circle = Main["Circle"];
		
		local Set = function(Value)
			if Value then
				Tween(Main,   .2, { BackgroundColor3 = Color3.fromRGB(153, 155, 255) });
				Tween(Circle, .2, { BackgroundColor3 = Color3.fromRGB(255, 255, 255), Position = UDim2.new(1, -16, 0.5, 0) });
			else
				Tween(Main,   .2, { BackgroundColor3 = Theme.Interactables });
				Tween(Circle, .2, { BackgroundColor3 = Theme.Primary, Position = UDim2.new(0, 3, 0.5, 0) });
			end
			
			On.Value = Value
		end 

		Connect(Toggle.MouseButton1Click, function()
			local Value = not On.Value

			Set(Value)
			Settings.Callback(Value)
		end)

		Animations:Component(Toggle);
		Set(Settings.Default);
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Toggle, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end
	
	function Options:AddKeybind(Settings: { Title: string, Description: string, Tab: Instance, Callback: any }) 
		local Dropdown = Clone(Components["Keybind"]);
		local Title, Description = Options:GetLabels(Dropdown);
		local Bind = Dropdown["Main"].Options;
		
		local Mouse = { Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3 }; 
		local Types = { 
			["Mouse"] = "Enum.UserInputType.MouseButton", 
			["Key"] = "Enum.KeyCode." 
		}
		
		Connect(Dropdown.MouseButton1Click, function()
			local Time = tick();
			local Detect, Finished
			
			SetProperty(Bind, { Text = "..." });
			Detect = Connect(game.UserInputService.InputBegan, function(Key, Focused) 
				local InputType = (Key.UserInputType);
				
				if not Finished and not Focused then
					Finished = (true)
					
					if table.find(Mouse, InputType) then
						Settings.Callback(Key);
						SetProperty(Bind, {
							Text = tostring(InputType):gsub(Types.Mouse, "MB")
						})
					elseif InputType == Enum.UserInputType.Keyboard then
						Settings.Callback(Key);
						SetProperty(Bind, {
							Text = tostring(Key.KeyCode):gsub(Types.Key, "")
						})
					end
				end 
			end)
		end)

		Animations:Component(Dropdown);
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Dropdown, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddDropdown(Settings: { Title: string, Description: string, Options: {}, Tab: Instance, Callback: any }) 
		local Dropdown = Clone(Components["Dropdown"]);
		local Title, Description = Options:GetLabels(Dropdown);
		local Text = Dropdown["Main"].Options;

		Connect(Dropdown.MouseButton1Click, function()
			local Example = Clone(Examples["DropdownExample"]);
			local Buttons = Example["Top"]["Buttons"];

			Tween(BG, .25, { BackgroundTransparency = 0.6 });
			SetProperty(Example, { Parent = Window });
			Animations:Open(Example, 0, true)

			for Index, Button in next, Buttons:GetChildren() do
				if Button:IsA("TextButton") then
					Animations:Component(Button, true)

					Connect(Button.MouseButton1Click, function()
						Tween(BG, .25, { BackgroundTransparency = 1 });
						Animations:Close(Example);
						task.wait(2)
						Destroy(Example);
					end)
				end
			end

			for Index, Option in next, Settings.Options do
				local Button = Clone(Examples["DropdownButtonExample"]);
				local Title, Description = Options:GetLabels(Button);
				local Selected = Button["Value"];

				Animations:Component(Button);
				SetProperty(Title, { Text = Index });
				SetProperty(Button, { Parent = Example.ScrollingFrame, Visible = true });
				Destroy(Description);

				Connect(Button.MouseButton1Click, function() 
					local NewValue = not Selected.Value 

					if NewValue then
						Tween(Button, .25, { BackgroundColor3 = Theme.Interactables });
						Settings.Callback(Option)
						Text.Text = Index

						for _, Others in next, Example:GetChildren() do
							if Others:IsA("TextButton") and Others ~= Button then
								Others.BackgroundColor3 = Theme.Component
							end
						end
					else
						Tween(Button, .25, { BackgroundColor3 = Theme.Component });
					end

					Selected.Value = NewValue
					Tween(BG, .25, { BackgroundTransparency = 1 });
					Animations:Close(Example);
					task.wait(2)
					Destroy(Example);
				end)
			end
		end)

		Animations:Component(Dropdown);
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Dropdown, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddSlider(Settings: { Title: string, Description: string, MaxValue: number, AllowDecimals: boolean, DecimalAmount: number, Tab: Instance, Callback: any }) 
		local Slider = Clone(Components["Slider"]);
		local Title, Description = Options:GetLabels(Slider);

		local Main = Slider["Slider"];
		local Amount = Main["Main"].Input;
		local Slide = Main["Slide"];
		local Fire = Slide["Fire"];
		local Fill = Slide["Highlight"];
		local Circle = Fill["Circle"];

		local Active = false
		local Value = 0
		
		local SetNumber = function(Number)
			if Settings.AllowDecimals then
				local Power = 10 ^ (Settings.DecimalAmount or 2)
				Number = math.floor(Number * Power + 0.5) / Power
			else
				Number = math.round(Number)
			end
			
			return Number
		end

		local Update = function(Number)
			local Scale = (Player.Mouse.X - Slide.AbsolutePosition.X) / Slide.AbsoluteSize.X			
			Scale = (Scale > 1 and 1) or (Scale < 0 and 0) or Scale
			
			if Number then
				Number = (Number > Settings.MaxValue and Settings.MaxValue) or (Number < 0 and 0) or Number
			end
			
			Value = SetNumber(Number or (Scale * Settings.MaxValue))
			Amount.Text = Value
			Fill.Size = UDim2.fromScale((Number and Number / Settings.MaxValue) or Scale, 1)
			Settings.Callback(Value)
		end

		local Activate = function()
			Active = true

			repeat task.wait()
				Update()
			until not Active
		end
		
		Connect(Amount.FocusLost, function() 
			Update(tonumber(Amount.Text) or 0)
		end)

		Connect(Fire.MouseButton1Down, Activate)
		Connect(Services.Input.InputEnded, function(Input) 
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Active = false
			end
		end)

		Fill.Size = UDim2.fromScale(Value, 1);
		Animations:Component(Slider);
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Slider, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddParagraph(Settings: { Title: string, Description: string, Tab: Instance }) 
		local Paragraph = Clone(Components["Paragraph"]);
		local Title, Description = Options:GetLabels(Paragraph);

		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Paragraph, {
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	local Themes = {
		Names = {	
			["Paragraph"] = function(Label)
				if Label:IsA("TextButton") then
					Label.BackgroundColor3 = Color(Theme.Component, 5, "Dark");
				end
			end,
			
			["Title"] = function(Label)
				if Label:IsA("TextLabel") then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Description"] = function(Label)
				if Label:IsA("TextLabel") then
					Label.TextColor3 = Theme.Description
				end
			end,
			
			["Section"] = function(Label)
				if Label:IsA("TextLabel") then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Options"] = function(Label)
				if Label:IsA("TextLabel") and Label.Parent.Name == "Main" then
					Label.TextColor3 = Theme.Title
				end
			end,
			
			["Notification"] = function(Label)
				if Label:IsA("CanvasGroup") then
					Label.BackgroundColor3 = Theme.Primary
					Label.UIStroke.Color = Theme.Outline
				end
			end,

			["TextLabel"] = function(Label)
				if Label:IsA("TextLabel") and Label.Parent:FindFirstChild("List") then
					Label.TextColor3 = Theme.Tab
				end
			end,

			["Main"] = function(Label)
				if Label:IsA("Frame") then

					if Label.Parent == Window then
						Label.BackgroundColor3 = Theme.Secondary
					elseif Label.Parent:FindFirstChild("Value") then
						local Toggle = Label.Parent.Value 
						local Circle = Label:FindFirstChild("Circle")
						
						if not Toggle.Value then
							Label.BackgroundColor3 = Theme.Interactables
							Label.Circle.BackgroundColor3 = Theme.Primary
						end
					else
						Label.BackgroundColor3 = Theme.Interactables
					end
				elseif Label:FindFirstChild("Padding") then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Amount"] = function(Label)
				if Label:IsA("Frame") then
					Label.BackgroundColor3 = Theme.Interactables
				end
			end,

			["Slide"] = function(Label)
				if Label:IsA("Frame") then
					Label.BackgroundColor3 = Theme.Interactables
				end
			end,

			["Input"] = function(Label)
				if Label:IsA("TextLabel") then
					Label.TextColor3 = Theme.Title
				elseif Label:FindFirstChild("Labels") then
					Label.BackgroundColor3 = Theme.Component
				elseif Label:IsA("TextBox") and Label.Parent.Name == "Main" then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Outline"] = function(Stroke)
				if Stroke:IsA("UIStroke") then
					Stroke.Color = Theme.Outline
				end
			end,

			["DropdownExample"] = function(Label)
				Label.BackgroundColor3 = Theme.Secondary
			end,

			["Underline"] = function(Label)
				if Label:IsA("Frame") then
					Label.BackgroundColor3 = Theme.Outline
				end
			end,
		},

		Classes = {
			["ImageLabel"] = function(Label)
				if Label.Image ~= "rbxassetid://6644618143" then
					Label.ImageColor3 = Theme.Icon
				end
			end,

			["TextLabel"] = function(Label)
				if Label:FindFirstChild("Padding") then
					Label.TextColor3 = Theme.Title
				end
			end,

			["TextButton"] = function(Label)
				if Label:FindFirstChild("Labels") then
					Label.BackgroundColor3 = Theme.Component
				end
			end,

			["ScrollingFrame"] = function(Label)
				Label.ScrollBarImageColor3 = Theme.Component
			end,
		},
	}

	function Options:SetTheme(Info)
		Theme = Info or Theme

		Window.BackgroundColor3 = Theme.Primary
		Holder.BackgroundColor3 = Theme.Secondary
		Window.UIStroke.Color = Theme.Shadow

		for Index, Descendant in next, Screen:GetDescendants() do
			local Name, Class =  Themes.Names[Descendant.Name],  Themes.Classes[Descendant.ClassName]

			if Name then
				Name(Descendant);
			elseif Class then
				Class(Descendant);
			end
		end
	end

	--// Changing Settings

	function Options:SetSetting(Setting, Value) --// Available settings - Size, Transparency, Blur, Theme
		if Setting == "Size" then
			
			Window.Size = Value
			Setup.Size = Value
			
		elseif Setting == "Transparency" then
			
			Window.GroupTransparency = Value
			Setup.Transparency = Value
			
			for Index, Notification in next, Screen:GetDescendants() do
				if Notification:IsA("CanvasGroup") and Notification.Name == "Notification" then
					Notification.GroupTransparency = Value
				end
			end
			
		elseif Setting == "Blur" then

			if Value then
				BlurEnabled = true

				if not BlurObject then
					BlurObject = MakeBlur()
					BlurEnabled = BlurObject ~= nil
				end

				if BlurObject and not Minimized then
					if typeof(Value) == "number" then BlurSetIntensity(BlurObject, Value) end
					BlurShow(BlurObject, .3)
				end
			elseif BlurObject then
				BlurEnabled = false
				BlurHide(BlurObject, .3)
			end

		elseif Setting == "LiquidGlass" then

			if GlassObject then
				if typeof(Value) == "number" then
					GlassObject:SetIntensity(Value)
				else
					GlassObject:SetVisible(Value and true or false)
				end
			else
				warn("[UI LIB]: LiquidGlass chưa được bật (cần LiquidGlass = true khi CreateWindow và file LiquidGlass.lua).")
			end

		elseif Setting == "Theme" and typeof(Value) == "table" then
			
			Options:SetTheme(Value)
			
		elseif Setting == "Keybind" then
			
			Setup.Keybind = Value
			
		else
			warn("Tried to change a setting that doesn't exist or isn't available to change.")
		end
	end

	SetProperty(Window, { Size = Settings.Size, Visible = true, Parent = Screen });
	Animations:Open(Window, Settings.Transparency or 0)

	task.delay(.4, function() Busy = false end)
	BlurShow(BlurObject, .4)

	return Options
end

return Library