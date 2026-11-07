--[[
	Blur.lua  -  Background blur for Roblox GUI (v2)
	Dùng DepthOfField + các tấm kính (glass) bám theo Frame để làm mờ nền phía sau UI.

	Cải tiến so với bản cũ:
	  • Dùng chung 1 DepthOfField cho mọi cửa sổ (bản cũ tạo mới mỗi lần -> rò rỉ / blur chồng).
	  • Mỗi cửa sổ có bindId riêng (bản cũ dùng chung 1 id -> cửa sổ thứ 2 đè cửa sổ 1).
	  • Không còn vòng lặp chặn (while ... Wait) trong constructor.
	  • Có Show / Hide với fade mượt, tự ngắt RenderStep khi ẩn (không tốn FPS).
	  • Có Destroy dọn sạch hoàn toàn, tự dọn khi Frame bị xoá.
	  • Chống lỗi NaN, tự theo camera mới, bo góc nhẹ bằng Inset.

	API:
	  local Blur = require/loadstring(...)()
	  local b = Blur.new(Frame, Intensity?, Options?)   --// Intensity 0..1 (mặc định 1)
	  b:Show(Time?)    b:Hide(Time?)    b:SetIntensity(n)    b:Destroy()
	  b.root           --// Folder chứa các tấm kính (giữ để tương thích code cũ)

	Options: { Inset = 6, Depth = nil, Color = Color3.new(1,1,1), Transparency = 0.98, Visible = true }
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Blur = {}
Blur.__index = Blur

--// ─────────────────────────── Shared DepthOfField ───────────────────────────
local Shared = {
	DOF = nil,
	Instances = {}, -- [object] = true (chỉ những object đang hiển thị)
	Tween = nil,
}

local function sharedTarget()
	local Highest = 0
	for Object in pairs(Shared.Instances) do
		if Object._intensity > Highest then
			Highest = Object._intensity
		end
	end
	return Highest
end

local function sharedRefresh(Time)
	local Target = sharedTarget()

	if Target <= 0 and not next(Shared.Instances) then
		-- Không còn ai dùng -> fade rồi dọn
		local DOF = Shared.DOF
		if DOF then
			if Shared.Tween then Shared.Tween:Cancel() end
			Shared.Tween = TweenService:Create(DOF, TweenInfo.new(Time or 0.25, Enum.EasingStyle.Sine), { NearIntensity = 0 })
			local Current = Shared.Tween
			Current.Completed:Once(function()
				if Shared.DOF == DOF and not next(Shared.Instances) then
					Shared.DOF = nil
					DOF:Destroy()
				end
			end)
			Current:Play()
		end
		return
	end

	if not Shared.DOF or not Shared.DOF.Parent then
		local DOF = Instance.new("DepthOfFieldEffect")
		DOF.Name = "LateBlurDOF"
		DOF.FarIntensity = 0
		DOF.FocusDistance = 51.6
		DOF.InFocusRadius = 50
		DOF.NearIntensity = 0
		DOF.Parent = Lighting
		Shared.DOF = DOF
	end

	if Shared.Tween then Shared.Tween:Cancel() end
	Shared.Tween = TweenService:Create(Shared.DOF, TweenInfo.new(Time or 0.25, Enum.EasingStyle.Sine), { NearIntensity = Target })
	Shared.Tween:Play()
end

--// ─────────────────────────── Hình học (tam giác -> wedge) ───────────────────────────
local WEDGE = 0.2

local function newWedge()
	local Part = Instance.new("Part")
	Part.Name = "BlurGlass"
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = false
	Part.CanTouch = false
	Part.CastShadow = false
	Part.Locked = true
	Part.Material = Enum.Material.Glass
	Part.Size = Vector3.new(WEDGE, WEDGE, WEDGE)
	Part.TopSurface = Enum.SurfaceType.Smooth
	Part.BottomSurface = Enum.SurfaceType.Smooth

	local Mesh = Instance.new("SpecialMesh")
	Mesh.Name = "WedgeMesh"
	Mesh.MeshType = Enum.MeshType.Wedge
	Mesh.Parent = Part

	return Part
end

local function drawTriangle(v1, v2, v3, p0, p1)
	local s1 = (v1 - v2).Magnitude
	local s2 = (v2 - v3).Magnitude
	local s3 = (v3 - v1).Magnitude
	local smax = math.max(s1, s2, s3)

	local A, B, C
	if s1 == smax then
		A, B, C = v1, v2, v3
	elseif s2 == smax then
		A, B, C = v2, v3, v1
	else
		A, B, C = v3, v1, v2
	end

	local BA = B - A
	local base = (A - B).Magnitude
	if base < 1e-5 then
		return p0, p1
	end

	local para = BA:Dot(C - A) / base
	local perp = math.sqrt(math.max((C - A).Magnitude ^ 2 - para * para, 0))
	local difPara = base - para

	local st = CFrame.new(B, A)
	local za = CFrame.Angles(math.pi / 2, 0, 0)

	local cf0 = st
	local topLook = (cf0 * za).LookVector
	local midPoint = A + CFrame.new(A, B).LookVector * para
	local neededLook = CFrame.new(midPoint, C).LookVector
	local dot = math.clamp(topLook:Dot(neededLook), -1, 1)

	local ac = CFrame.Angles(0, 0, math.acos(dot))
	cf0 = cf0 * ac
	if ((cf0 * za).LookVector - neededLook).Magnitude > 0.01 then
		cf0 = cf0 * CFrame.Angles(0, 0, -2 * math.acos(dot))
	end
	cf0 = cf0 * CFrame.new(0, perp / 2, -(difPara + para / 2))

	local cf1 = st * ac * CFrame.Angles(0, math.pi, 0)
	if ((cf1 * za).LookVector - neededLook).Magnitude > 0.01 then
		cf1 = cf1 * CFrame.Angles(0, 0, 2 * math.acos(dot))
	end
	cf1 = cf1 * CFrame.new(0, perp / 2, difPara / 2)

	p0 = p0 or newWedge()
	p0.WedgeMesh.Scale = Vector3.new(0, perp / WEDGE, para / WEDGE)
	p0.CFrame = cf0

	p1 = p1 or p0:Clone()
	p1.WedgeMesh.Scale = Vector3.new(0, perp / WEDGE, difPara / WEDGE)
	p1.CFrame = cf1

	return p0, p1
end

--// ─────────────────────────── Object ───────────────────────────
function Blur.new(target: GuiObject, intensity: number?, options: { [string]: any }?)
	assert(typeof(target) == "Instance" and target:IsA("GuiObject"), "[Blur] target phải là GuiObject")
	options = options or {}

	local self = setmetatable({
		_intensity = math.clamp(intensity or 1, 0, 1),
		_visible = false,
		_destroyed = false,
		_bindId = "LateBlur_" .. HttpService:GenerateGUID(false),
		_options = {
			Inset = options.Inset or 6,
			Depth = options.Depth,
			Color = options.Color or Color3.new(1, 1, 1),
			Transparency = options.Transparency or 0.98,
		},

		target = target,
		root = Instance.new("Folder"),
		parts = {},
		_conns = {},
	}, Blur)

	self.root.Name = "LateBlur"

	-- Frame trung gian để thu nhỏ vùng blur một chút (đỡ lộ ra ngoài góc bo)
	local Inset = self._options.Inset
	local Area = Instance.new("Frame")
	Area.Name = "BlurArea"
	Area.BackgroundTransparency = 1
	Area.Active = false
	Area.AnchorPoint = Vector2.new(0.5, 0.5)
	Area.Position = UDim2.fromScale(0.5, 0.5)
	Area.Size = UDim2.new(1, -Inset * 2, 1, -Inset * 2)
	Area.Parent = target
	self.frame = Area

	-- Tự dọn khi UI bị xoá
	table.insert(self._conns, target.Destroying:Connect(function()
		self:Destroy()
	end))

	if options.Visible ~= false then
		self:Show(0)
	end

	return self
end

function Blur:_update()
	local Camera = workspace.CurrentCamera
	local Area = self.frame
	if not Camera or not Area or not Area.Parent then
		return
	end

	if self.root.Parent ~= Camera then
		self.root.Parent = Camera
	end

	-- Ẩn kính khi UI không hiển thị
	local Shown = self.target.Visible and Area.AbsoluteSize.X > 1 and Area.AbsoluteSize.Y > 1
	if not Shown then
		for _, Part in ipairs(self.parts) do
			Part.Parent = nil
		end
		return
	end

	local Probe = Camera:ScreenPointToRay(0, 0).Origin.X
	if Probe ~= Probe then
		return -- camera chưa sẵn sàng (NaN)
	end

	local Depth = self._options.Depth or math.max(1 - 0.05 * Area.ZIndex, 0.05)

	local tl = Area.AbsolutePosition
	local br = tl + Area.AbsoluteSize
	local tr, bl = Vector2.new(br.X, tl.Y), Vector2.new(tl.X, br.Y)

	-- Cộng dồn góc xoay của các cha
	local Rot = 0
	local Object = Area
	while Object and Object:IsA("GuiObject") do
		Rot += Object.Rotation
		Object = Object.Parent
	end

	if Rot ~= 0 and Rot % 180 ~= 0 then
		local mid = tl:Lerp(br, 0.5)
		local s, c = math.sin(math.rad(Rot)), math.cos(math.rad(Rot))
		local function rotate(p)
			local d = p - mid
			return Vector2.new(c * d.X - s * d.Y, s * d.X + c * d.Y) + mid
		end
		tl, tr, bl, br = rotate(tl), rotate(tr), rotate(bl), rotate(br)
	end

	local function ray(p)
		return Camera:ScreenPointToRay(p.X, p.Y, Depth).Origin
	end

	local Parts = self.parts
	local v1, v2, v3, v4 = ray(tl), ray(tr), ray(bl), ray(br)
	Parts[1], Parts[2] = drawTriangle(v1, v2, v3, Parts[1], Parts[2])
	Parts[3], Parts[4] = drawTriangle(v3, v2, v4, Parts[3], Parts[4])

	for _, Part in ipairs(Parts) do
		if Part.Parent ~= self.root then
			Part.Transparency = self._options.Transparency
			Part.Color = self._options.Color
			Part.Parent = self.root
		end
	end
end

function Blur:Show(Time: number?)
	if self._destroyed then return end
	self._visible = true

	Shared.Instances[self] = true
	sharedRefresh(Time)

	if not self._bound then
		self._bound = true
		self:_update()
		RunService:BindToRenderStep(self._bindId, 2000, function()
			self:_update()
		end)
	end
end

function Blur:Hide(Time: number?)
	if self._destroyed then return end
	self._visible = false

	if self._bound then
		self._bound = false
		pcall(RunService.UnbindFromRenderStep, RunService, self._bindId)
	end

	for _, Part in ipairs(self.parts) do
		Part.Parent = nil
	end

	Shared.Instances[self] = nil
	sharedRefresh(Time)
end

function Blur:IsVisible()
	return self._visible
end

function Blur:SetIntensity(Value: number)
	self._intensity = math.clamp(Value, 0, 1)
	if self._visible then
		sharedRefresh(0.2)
	end
end
Blur.setBlurIntensity = Blur.SetIntensity -- tương thích bản cũ

function Blur:Destroy()
	if self._destroyed then return end
	self:Hide(0.2)
	self._destroyed = true

	for _, Conn in ipairs(self._conns) do
		Conn:Disconnect()
	end
	table.clear(self._conns)

	for _, Part in ipairs(self.parts) do
		Part:Destroy()
	end
	table.clear(self.parts)

	if self.frame then self.frame:Destroy() end
	if self.root then self.root:Destroy() end
end

return Blur
