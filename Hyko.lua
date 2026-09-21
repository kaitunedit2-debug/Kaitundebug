--// MEGA v15 — Dual Anti-NPC: v6.1 (mềm) ⇄ v6.2 (cứng) — cả 2 mặc định TẮT
--// • Toggle 1: v6.1 — anchor HRP + Humanoid off + CanCollide off + filter AlertGui theo tên
--// • Toggle 2: v6.2 — thêm CFrame-lock mỗi Heartbeat, TouchTransmitter destroy,
--//              CanTouch/CanQuery off, part đặc biệt (Collider/EggPoint/CENTER/HeadProxy),
--//              tắt MỌI BillboardGui, tắt CanTouch trên player char
--// • Loại trừ nhau: bật cái này tự tắt cái kia (unlock toàn bộ trước khi đổi)
--// • Cả 2 OFF khi script mới load

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local LP               = Players.LocalPlayer

--============================================================--
-- [A] READ INPUT
--============================================================--
local Controls
pcall(function()
	local PM = require(LP.PlayerScripts:WaitForChild("PlayerModule", 5))
	Controls = PM:GetControls()
end)
local function readMove()
	if Controls then
		local ok, v = pcall(function() return Controls:GetMoveVector() end)
		if ok and v and v.Magnitude > 0.05 then
			return Vector3.new(v.X, 0, v.Z)
		end
	end
	local d = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then d += Vector3.new(0, 0, -1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then d += Vector3.new(0, 0, 1)  end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then d += Vector3.new(-1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then d += Vector3.new(1, 0, 0)  end
	return d
end

--============================================================--
-- [B] FAST LOOT
--============================================================--
local fastLootOn = true
local function fixPrompt(p)
	if p:IsA("ProximityPrompt") then pcall(function() p.HoldDuration = 0 end) end
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") then fixPrompt(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if fastLootOn and d:IsA("ProximityPrompt") then fixPrompt(d) end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe or not fastLootOn then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	local c = LP.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local best, bestDist = nil, math.huge
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled then
			local par = d.Parent
			local pos
			if par and par:IsA("BasePart") then pos = par.Position
			elseif par and par:IsA("Attachment") and par.Parent and par.Parent:IsA("BasePart") then
				pos = par.Parent.Position
			end
			if pos then
				local dist = (pos - hrp.Position).Magnitude
				if dist <= d.MaxActivationDistance + 4 and dist < bestDist then
					best, bestDist = d, dist
				end
			end
		end
	end
	if best then pcall(function() fireproximityprompt(best) end) end
end)

--============================================================--
-- [C] HOOK namecall
--============================================================--
local blockRouse = true

local mt = getrawmetatable(game)
local oldNC = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
	local m = getnamecallmethod()
	if blockRouse and m == "FireServer" and typeof(self) == "Instance" then
		local n = self.Name
		if n == "Rouse" or n == "ForestStrike" or n == "ForestHandoff"
		or n == "Alert" or n == "Wake" or n == "Chase" or n == "Detect"
		or n == "SpeedTollOffer" or n == "SpeedTollWarning" then
			return
		end
	end
	return oldNC(self, ...)
end)
setreadonly(mt, true)

--============================================================--
-- [D] ANTI-NPC — 2 MODE (loại trừ nhau, cả 2 mặc định OFF)
--============================================================--
local antiMode      = "off"   -- "off" | "v61" | "v62"
local frozenNPCs    = {}      -- [model] = data
local lockedCFrames = {}      -- [model] = CFrame (chỉ v62 dùng)
local playerChrs    = {}

local function refreshPlayerChrs()
	playerChrs = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then playerChrs[pl.Character] = true end
	end
end
refreshPlayerChrs()
Players.PlayerAdded:Connect(function(pl)
	pl.CharacterAdded:Connect(refreshPlayerChrs)
end)
Players.PlayerRemoving:Connect(refreshPlayerChrs)

local function isNPC(model)
	if not model or not model:IsA("Model") then return false end
	if playerChrs[model] then return false end
	if LP.Character == model then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	return true
end

--------------------------------------------------------------
-- LOCK v6.1 — MỀM
--------------------------------------------------------------
local function lockNPC_v61(npc)
	if frozenNPCs[npc] then return end
	if not npc.Parent then return end

	local hrp = npc:FindFirstChild("HumanoidRootPart")
		or npc:FindFirstChild("Torso")
		or npc:FindFirstChild("UpperTorso")
	local hum      = npc:FindFirstChildOfClass("Humanoid")
	local collider = npc:FindFirstChild("Collider")

	local data = { mode = "v61", collides = {}, alerts = {}, vfx = {} }

	-- 1) Network ownership + anchor
	if hrp and hrp:IsA("BasePart") then
		data.hrp = hrp
		data.origAnchored = hrp.Anchored
		pcall(function()
			hrp:SetNetworkOwner(LP)
			hrp.Anchored = true
		end)
	end

	-- 2) Humanoid off
	if hum then
		data.hum = hum
		data.origWalk = hum.WalkSpeed
		data.origJump = hum.JumpPower
		pcall(function()
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	-- 3) CanCollide off
	for _, p in ipairs(npc:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			data.collides[p] = p.CanCollide
			pcall(function() p.CanCollide = false end)
		end
	end
	if collider then
		data.collider = collider
		data.origCollide = collider.CanCollide
		pcall(function() collider.CanCollide = false end)
	end

	-- 4) AlertGui: filter theo tên alert/warn/detect
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BillboardGui") and (d.Name:lower():find("alert")
			or d.Name:lower():find("warn") or d.Name:lower():find("detect")) then
			data.alerts[d] = d.Enabled
			d.Enabled = false
		end
		if d:IsA("Sound") and d.Playing then
			pcall(function() d:Stop() end)
		end
	end

	-- 5) VFX detection
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("ParticleEmitter") and d.Enabled then
			local nm = d.Name:lower()
			if nm:find("alert") or nm:find("detect") or nm:find("wake")
				or nm:find("sleep") or nm:find("anger") then
				data.vfx[d] = d.Enabled
				d.Enabled = false
			end
		end
	end

	frozenNPCs[npc] = data
end

--------------------------------------------------------------
-- LOCK v6.2 — CỨNG
--------------------------------------------------------------
local function lockNPC_v62(npc)
	if frozenNPCs[npc] then return end
	if not npc.Parent then return end

	local hrp = npc:FindFirstChild("HumanoidRootPart")
		or npc:FindFirstChild("Torso")
		or npc:FindFirstChild("UpperTorso")
	local hum = npc:FindFirstChildOfClass("Humanoid")

	local data = { mode = "v62", parts = {}, alerts = {}, vfx = {} }

	-- 1) Network owner: unanchor → set owner → anchor → lock CFrame
	if hrp and hrp:IsA("BasePart") then
		data.hrp = hrp
		data.origAnchored = hrp.Anchored
		pcall(function()
			hrp.Anchored = false
			hrp:SetNetworkOwner(LP)
		end)
		task.wait(0.03)
		pcall(function()
			hrp.Anchored = true
			hrp.AssemblyLinearVelocity  = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end)
		lockedCFrames[npc] = hrp.CFrame
	end

	-- 2) Humanoid off toàn diện
	if hum then
		data.hum = hum
		data.origWalk = hum.WalkSpeed
		data.origJump = hum.JumpPower
		pcall(function()
			hum.WalkSpeed     = 0
			hum.JumpPower     = 0
			hum.AutoRotate    = false
			hum.PlatformStand = true
			hum:ChangeState(Enum.HumanoidStateType.Physics)
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,   false)
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			hum:SetStateEnabled(Enum.HumanoidStateType.Running,   false)
			hum:SetStateEnabled(Enum.HumanoidStateType.Climbing,  false)
		end)
	end

	-- 3) CanCollide / CanTouch / CanQuery off trên MỌI part
	for _, p in ipairs(npc:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(data.parts, {
				part = p,
				cc = p.CanCollide, ct = p.CanTouch, cq = p.CanQuery,
				tr = p.Transparency,
			})
			pcall(function()
				p.CanCollide = false
				p.CanTouch   = false
				p.CanQuery   = false
			end)
		end
	end

	-- 4) Destroy TouchTransmitter
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("TouchTransmitter") then
			pcall(function() d:Destroy() end)
		end
	end

	-- 5) Vô hiệu part đặc biệt
	for _, nm in ipairs({"Collider", "EggPoint", "CENTER", "HeadProxy"}) do
		local pt = npc:FindFirstChild(nm)
		if pt and pt:IsA("BasePart") then
			table.insert(data.parts, {
				part = pt,
				cc = pt.CanCollide, ct = pt.CanTouch, cq = pt.CanQuery,
				tr = pt.Transparency,
			})
			pcall(function()
				pt.CanCollide   = false
				pt.CanTouch     = false
				pt.CanQuery     = false
				pt.Transparency = 1
			end)
		end
	end

	-- 6) TẮT MỌI BillboardGui + dừng sound
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BillboardGui") then
			data.alerts[d] = d.Enabled
			d.Enabled = false
		end
		if d:IsA("Sound") and d.Playing then
			pcall(function() d:Stop() end)
		end
	end

	-- 7) VFX detection
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("ParticleEmitter") and d.Enabled then
			local nm = d.Name:lower()
			if nm:find("alert") or nm:find("detect") or nm:find("wake")
				or nm:find("sleep") or nm:find("anger") then
				data.vfx[d] = d.Enabled
				d.Enabled = false
			end
		end
	end

	frozenNPCs[npc] = data
end

--------------------------------------------------------------
-- UNLOCK (dùng chung cho cả 2)
--------------------------------------------------------------
local function unlockNPC(npc)
	local data = frozenNPCs[npc]
	if not data then return end

	if data.hrp and data.hrp.Parent then
		pcall(function() data.hrp.Anchored = data.origAnchored or false end)
	end
	if data.hum and data.hum.Parent then
		pcall(function()
			data.hum.WalkSpeed     = data.origWalk or 16
			data.hum.JumpPower     = data.origJump or 50
			data.hum.PlatformStand = false
			data.hum.AutoRotate    = true
		end)
	end

	for p, can in pairs(data.collides or {}) do
		if p and p.Parent then pcall(function() p.CanCollide = can end) end
	end
	if data.collider and data.collider.Parent then
		pcall(function() data.collider.CanCollide = data.origCollide ~= false end)
	end

	for _, rec in ipairs(data.parts or {}) do
		local p = rec.part
		if p and p.Parent then
			pcall(function()
				p.CanCollide   = rec.cc
				p.CanTouch     = rec.ct
				p.CanQuery     = rec.cq
				if rec.tr ~= nil then p.Transparency = rec.tr end
			end)
		end
	end

	for d, en in pairs(data.alerts or {}) do
		if d and d.Parent then d.Enabled = en end
	end
	for d, en in pairs(data.vfx or {}) do
		if d and d.Parent then d.Enabled = en end
	end

	lockedCFrames[npc] = nil
	frozenNPCs[npc] = nil
end

local function unlockAll()
	for npc in pairs(frozenNPCs) do unlockNPC(npc) end
end

--============================================================--
-- [E] HEARTBEAT FORCE — chỉ v62
--============================================================--
RunService.Heartbeat:Connect(function()
	if not next(lockedCFrames) then return end
	for npc, cf in pairs(lockedCFrames) do
		if not npc.Parent then
			lockedCFrames[npc] = nil
		else
			local hrp = npc:FindFirstChild("HumanoidRootPart")
				or npc:FindFirstChild("Torso")
				or npc:FindFirstChild("UpperTorso")
			if hrp and hrp:IsA("BasePart") then
				hrp.CFrame = cf
				hrp.AssemblyLinearVelocity  = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end)

--============================================================--
-- [F] SCAN
--============================================================--
local function scanAllNPCs()
	refreshPlayerChrs()
	local found = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and isNPC(obj) then
			table.insert(found, obj)
		end
	end
	return found
end

-- CanTouch=false cho player char (chỉ v62)
local function applyPlayerNoTouch()
	if antiMode ~= "v62" then return end
	local c = LP.Character
	if not c then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			pcall(function() p.CanTouch = false end)
		end
	end
end

--============================================================--
-- [G] INVISIBLE
--============================================================--
local invisOn = false
local function setInvis(on)
	local c = LP.Character
	if not c then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = on and 1 or 0
		elseif p:IsA("Decal") then
			p.Transparency = on and 1 or 0
		end
	end
end

--============================================================--
-- [H] UI
--============================================================--
local ScreenGui = LP:WaitForChild("PlayerGui"):FindFirstChild("MegaGui")
if not ScreenGui then
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "MegaGui"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Parent = LP:WaitForChild("PlayerGui")
end
local oldUI = ScreenGui:FindFirstChild("MegaWindow")
if oldUI then oldUI:Destroy() end

local U = {
	cardBg     = Color3.fromRGB(255, 255, 255),
	cardStroke = Color3.fromRGB(225, 228, 235),
	text       = Color3.fromRGB(28, 32, 40),
	sub        = Color3.fromRGB(140, 146, 158),
	accent     = Color3.fromRGB(10, 132, 255),
	green      = Color3.fromRGB(52, 199, 89),
	amber      = Color3.fromRGB(255, 159, 10),
	red        = Color3.fromRGB(255, 69, 58),
	off        = Color3.fromRGB(200, 204, 210),
}

local WINDOW_W = 300
local WINDOW_H = 470

local function mkCorner(parent, radius)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = parent; return c
end
local function mkStroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color; s.Transparency = transparency or 0
	s.Thickness = thickness or 1; s.Parent = parent; return s
end

local Window = Instance.new("Frame", ScreenGui)
Window.Name = "MegaWindow"
Window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
Window.Position = UDim2.new(0, 20, 0.5, -WINDOW_H/2)
Window.BackgroundColor3 = Color3.fromRGB(248, 249, 252)
Window.BackgroundTransparency = 0.04
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = true
mkCorner(Window, 12)
mkStroke(Window, U.cardStroke, 0.2, 1)

local header = Instance.new("Frame", Window)
header.Size = UDim2.new(1, -16, 0, 48)
header.Position = UDim2.fromOffset(8, 8)
header.BackgroundColor3 = U.cardBg
header.BackgroundTransparency = 0.06
header.BorderSizePixel = 0
header.ZIndex = 3
mkCorner(header, 8)
mkStroke(header, U.cardStroke, 0.35, 1)

local hDot = Instance.new("Frame", header)
hDot.Size = UDim2.fromOffset(6, 6)
hDot.Position = UDim2.fromOffset(12, 12)
hDot.BackgroundColor3 = U.accent
hDot.BorderSizePixel = 0
hDot.ZIndex = 4
mkCorner(hDot, 3)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -120, 0, 16)
title.Position = UDim2.fromOffset(24, 8)
title.BackgroundTransparency = 1
title.Text = "MEGA v15"
title.TextColor3 = U.text
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 4

local subtitle = Instance.new("TextLabel", header)
subtitle.Size = UDim2.new(1, -120, 0, 12)
subtitle.Position = UDim2.fromOffset(24, 26)
subtitle.BackgroundTransparency = 1
subtitle.Text = "v6.1 ⇄ v6.2 (dual, mặc định tắt)"
subtitle.TextColor3 = U.sub
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 4

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.fromOffset(24, 24)
closeBtn.Position = UDim2.new(1, -32, 0.5, -12)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 240, 240)
closeBtn.Text = "×"
closeBtn.TextColor3 = U.red
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 4
mkCorner(closeBtn, 12)
closeBtn.MouseButton1Click:Connect(function() Window.Visible = false end)

-- Kéo cửa sổ
local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Window.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then
		local d = input.Position - dragStart
		Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local content = Instance.new("Frame", Window)
content.Size = UDim2.new(1, -16, 1, -68)
content.Position = UDim2.fromOffset(8, 60)
content.BackgroundTransparency = 1
content.ZIndex = 3

local function makeCard(yPos, height)
	local card = Instance.new("Frame", content)
	card.Size = UDim2.new(1, 0, 0, height)
	card.Position = UDim2.fromOffset(0, yPos)
	card.BackgroundColor3 = U.cardBg
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.ZIndex = 4
	mkCorner(card, 8)
	mkStroke(card, U.cardStroke, 0.35, 1)
	return card
end

local function addCardLabel(card, name, yOffset)
	local dot = Instance.new("Frame", card)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.Position = UDim2.fromOffset(12, yOffset + 5)
	dot.BackgroundColor3 = U.accent
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	mkCorner(dot, 3)

	local lbl = Instance.new("TextLabel", card)
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(24, yOffset)
	lbl.Size = UDim2.new(1, -120, 0, 16)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 11
	lbl.TextColor3 = U.text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Text = name
	lbl.ZIndex = 5
	return dot, lbl
end

local function makeToggle(card, name, defaultState, yOffset, callback)
	local dot, lbl = addCardLabel(card, name, yOffset)
	local switchBg = Instance.new("Frame", card)
	switchBg.Size = UDim2.fromOffset(40, 22)
	switchBg.Position = UDim2.new(1, -52, 0, yOffset + 2)
	switchBg.BackgroundColor3 = defaultState and U.green or U.off
	switchBg.BorderSizePixel = 0
	switchBg.ZIndex = 5
	mkCorner(switchBg, 11)

	local thumb = Instance.new("Frame", switchBg)
	thumb.Size = UDim2.fromOffset(18, 18)
	thumb.Position = defaultState and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.ZIndex = 6
	mkCorner(thumb, 9)

	local btn = Instance.new("TextButton", card)
	btn.Size = UDim2.new(1, 0, 0, 26)
	btn.Position = UDim2.fromOffset(0, yOffset - 5)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 7

	local state = defaultState
	local function applyState(s, fireCallback)
		state = s
		TweenService:Create(switchBg, TweenInfo.new(0.2, Enum.EasingStyle.Quart),
			{BackgroundColor3 = state and U.green or U.off}):Play()
		TweenService:Create(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Quart),
			{Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)}):Play()
		if fireCallback and callback then callback(state) end
	end

	btn.MouseButton1Click:Connect(function()
		applyState(not state, true)
	end)

	return {
		setState = function(s) applyState(s, false) end,
		getState = function() return state end,
	}
end

local function makeSlider(card, name, minVal, maxVal, defaultVal, yOffset, callback)
	local dot, lbl = addCardLabel(card, name, yOffset)
	lbl.Text = name .. ": " .. defaultVal

	local track = Instance.new("TextButton", card)
	track.Size = UDim2.new(1, -24, 0, 4)
	track.Position = UDim2.fromOffset(12, yOffset + 26)
	track.BackgroundColor3 = Color3.fromRGB(232, 235, 240)
	track.Text = ""
	track.AutoButtonColor = false
	track.ZIndex = 5
	mkCorner(track, 2)

	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
	fill.BackgroundColor3 = U.accent
	fill.BorderSizePixel = 0
	fill.ZIndex = 6
	mkCorner(fill, 2)

	local thumb = Instance.new("Frame", track)
	thumb.Size = UDim2.fromOffset(12, 12)
	thumb.Position = UDim2.new((defaultVal - minVal) / (maxVal - minVal), -6, 0.5, -6)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.ZIndex = 7
	mkCorner(thumb, 6)
	mkStroke(thumb, U.cardStroke, 0, 1)

	local draggingSlider = false
	local function updateSlider(input)
		local tw = track.AbsoluteSize.X
		local tx = track.AbsolutePosition.X
		local pct = math.clamp((input.Position.X - tx) / tw, 0, 1)
		local val = math.floor(minVal + pct * (maxVal - minVal))
		fill.Size = UDim2.new(pct, 0, 1, 0)
		thumb.Position = UDim2.new(pct, -6, 0.5, -6)
		lbl.Text = name .. ": " .. val
		if callback then callback(val) end
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			updateSlider(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not draggingSlider then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			updateSlider(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = false
		end
	end)
end

local y = 0
local gap = 8

-- SPEED card
local curSpeed = 60
local speedOn  = false
local savedHum, savedCollide, mainConn = nil, {}, nil
local yLockOn = true
_G.curSpeed = curSpeed

local speedCard = makeCard(y, 62)
makeSlider(speedCard, "Speed", 10, 800, 60, 8, function(val)
	curSpeed = val
	_G.curSpeed = val
end)
y = y + 62 + gap

-- SPEED TOGGLE + INVISIBLE
local boostCard = makeCard(y, 62)

local function enableSpeed()
	local c = LP.Character
	if not c then return false end
	local hrp = c:FindFirstChild("HumanoidRootPart")
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hrp then return false end
	if hum then savedHum = hum; hum.Parent = nil end
	pcall(function() workspace.CurrentCamera.CameraSubject = hrp end)
	savedCollide = {}
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p ~= hrp then
			savedCollide[p] = p.CanCollide
			p.CanCollide = false
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {c}
	rayParams.IgnoreWater = true
	mainConn = RunService.Heartbeat:Connect(function(dt)
		local ch = LP.Character
		if not ch then return end
		local root = ch:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.new(root.Position, root.Position + flat.Unit)
		end
		root.AssemblyAngularVelocity = Vector3.zero
		local v = readMove()
		if v.Magnitude < 0.05 then
			root.AssemblyLinearVelocity = Vector3.zero
		else
			local camCF = cam.CFrame
			local worldDir = camCF.LookVector * (-v.Z) + camCF.RightVector * v.X
			worldDir = Vector3.new(worldDir.X, 0, worldDir.Z)
			if worldDir.Magnitude > 0.01 then
				root.AssemblyLinearVelocity = worldDir.Unit * curSpeed
			end
		end
		if yLockOn then
			local origin = root.Position + Vector3.new(0, 4, 0)
			local result = workspace:Raycast(origin, Vector3.new(0, -80, 0), rayParams)
			if result then
				local targetY = result.Position.Y + 3.5
				local delta = targetY - root.Position.Y
				if math.abs(delta) < 8 and delta > 0 then
					root.CFrame = CFrame.new(root.Position.X, targetY, root.Position.Z)
						* (root.CFrame - root.Position)
					root.AssemblyLinearVelocity = Vector3.new(
						root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
				end
			end
		end
	end)
	return true
end

local function disableSpeed()
	if mainConn then mainConn:Disconnect() mainConn = nil end
	local c = LP.Character
	if not c then savedHum = nil savedCollide = {} return end
	local hrp = c:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity  = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	for part, can in pairs(savedCollide) do
		if part and part.Parent then part.CanCollide = can end
	end
	savedCollide = {}
	if savedHum and savedHum.Parent == nil then
		pcall(function()
			savedHum.Parent = c
			savedHum.WalkSpeed = 16
			savedHum.JumpPower = 50
		end)
	end
	savedHum = nil
	task.wait(0.1)
	pcall(function() LP:LoadCharacter() end)
end

makeToggle(boostCard, "Speed Boost", false, 8, function(state)
	if state then
		if enableSpeed() then speedOn = true end
	else
		speedOn = false
		disableSpeed()
	end
end)
makeToggle(boostCard, "Invisible", false, 34, function(state)
	invisOn = state
	setInvis(invisOn)
end)
y = y + 62 + gap

-- ANTI-NPC card: 2 anti + block rouse = 88px
local protCard = makeCard(y, 88)

local anti61Handle, anti62Handle

local function switchAntiMode(newMode)
	if antiMode == newMode then newMode = "off" end
	if antiMode == newMode then return end
	unlockAll()
	antiMode = newMode
	anti61Handle.setState(newMode == "v61")
	anti62Handle.setState(newMode == "v62")
	if newMode == "v62" then applyPlayerNoTouch() end
end

anti61Handle = makeToggle(protCard, "Anti-NPC v6.1 (mềm)", false, 8, function(state)
	if state then switchAntiMode("v61") else switchAntiMode("off") end
end)

anti62Handle = makeToggle(protCard, "Anti-NPC v6.2 (cứng)", false, 34, function(state)
	if state then switchAntiMode("v62") else switchAntiMode("off") end
end)

makeToggle(protCard, "Block Rouse", true, 60, function(state)
	blockRouse = state
end)

y = y + 88 + gap

-- ESP + Fast Loot card
local espCard = makeCard(y, 62)
makeToggle(espCard, "Player ESP", false, 8, function(state)
	if state then enableESP() else disableESP() end
end)
makeToggle(espCard, "Fast Loot", true, 34, function(state)
	fastLootOn = state
end)

--============================================================--
-- [I] ESP
--============================================================--
local espOn = false
local ESP_MAX_DISTANCE = 5000
local ESP_UPDATE_INTERVAL = 0.20
local espEntries = {}
local espConnections = {}
local espFolder = Instance.new("Folder")
espFolder.Name = "MegaESP"
espFolder.Parent = workspace

local T = {
	accent = Color3.fromRGB(10, 132, 255),
	text   = Color3.fromRGB(28, 32, 40),
	sub    = Color3.fromRGB(140, 146, 158),
	green  = Color3.fromRGB(52, 199, 89),
	amber  = Color3.fromRGB(255, 159, 10),
	red    = Color3.fromRGB(255, 69, 58),
	cardBg = Color3.fromRGB(255, 255, 255),
	cardStroke = Color3.fromRGB(225, 228, 235),
}

local function safeDestroy(x) if x then pcall(function() x:Destroy() end) end end
local function disconnect(x)
	if x and typeof(x) == "RBXScriptConnection" then pcall(function() x:Disconnect() end) end
end

local function getRootHum(char)
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum  = char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then return root, hum end
end

local function makeESP(plr)
	if not espOn or plr == LP then return end
	local char = plr.Character
	local root, hum = getRootHum(char)
	if not root then return end
	local old = espEntries[plr]
	if old and old.character == char then return end
	if old then safeDestroy(old.highlight); safeDestroy(old.billboard) end

	local highlight = Instance.new("Highlight")
	highlight.Adornee = char
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillTransparency = 0.92
	highlight.OutlineTransparency = 0.15
	highlight.FillColor = T.accent
	highlight.OutlineColor = T.accent
	highlight.Parent = espFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = ESP_MAX_DISTANCE
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.StudsOffset = Vector3.new(0, 3.1, 0)
	billboard.Parent = espFolder

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = T.cardBg
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.Parent = billboard
	mkCorner(card, 8)
	mkStroke(card, T.cardStroke, 0.35, 1)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(12, 6)
	nameLabel.Size = UDim2.new(1, -20, 0, 16)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 11
	nameLabel.TextColor3 = T.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = plr.DisplayName
	nameLabel.Parent = card

	local distLabel = Instance.new("TextLabel")
	distLabel.BackgroundTransparency = 1
	distLabel.Position = UDim2.fromOffset(12, 25)
	distLabel.Size = UDim2.fromOffset(42, 12)
	distLabel.Font = Enum.Font.Gotham
	distLabel.TextSize = 9
	distLabel.TextColor3 = T.sub
	distLabel.TextXAlignment = Enum.TextXAlignment.Left
	distLabel.Text = "-- m"
	distLabel.Parent = card

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.new(1, -78, 0, 28)
	barBg.Size = UDim2.fromOffset(58, 4)
	barBg.BackgroundColor3 = Color3.fromRGB(232, 235, 240)
	barBg.BorderSizePixel = 0
	barBg.Parent = card
	mkCorner(barBg, 2)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = T.green
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	mkCorner(barFill, 2)

	local hpLabel = Instance.new("TextLabel")
	hpLabel.BackgroundTransparency = 1
	hpLabel.Position = UDim2.new(1, -78, 0, 12)
	hpLabel.Size = UDim2.fromOffset(58, 12)
	hpLabel.Font = Enum.Font.Gotham
	hpLabel.TextSize = 8
	hpLabel.TextColor3 = T.sub
	hpLabel.TextXAlignment = Enum.TextXAlignment.Right
	hpLabel.Text = "100%"
	hpLabel.Parent = card

	espEntries[plr] = {
		player = plr, character = char, root = root, hum = hum,
		highlight = highlight, billboard = billboard,
		nameLabel = nameLabel, distLabel = distLabel,
		barFill = barFill, hpLabel = hpLabel,
	}
end

local function removeESP(plr)
	local e = espEntries[plr]
	if not e then return end
	safeDestroy(e.highlight)
	safeDestroy(e.billboard)
	espEntries[plr] = nil
end

local function updateESPEntry(e, myRoot)
	if not e or not e.player then return end
	local plr = e.player
	local char = plr.Character
	local root, hum = getRootHum(char)
	if not root then removeESP(plr); return end
	if e.character ~= char then
		makeESP(plr)
		e = espEntries[plr]
		if not e then return end
		root, hum = getRootHum(char)
		if not root then return end
	end
	e.billboard.MaxDistance = ESP_MAX_DISTANCE
	e.nameLabel.Text = plr.DisplayName
	local distance = myRoot and (myRoot.Position - root.Position).Magnitude or 0
	local visible  = distance <= ESP_MAX_DISTANCE
	e.highlight.Enabled = visible
	e.billboard.Enabled = visible
	local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
	e.distLabel.Text = string.format("%dm", math.floor(distance + 0.5))
	e.hpLabel.Text   = string.format("%d%%", math.floor(hp * 100 + 0.5))
	local col
	if hp > 0.6 then col = T.green
	elseif hp > 0.3 then col = T.amber
	else col = T.red end
	e.barFill.BackgroundColor3 = col
	e.barFill.Size = UDim2.fromScale(hp, 1)
end

local function bindPlayerESP(plr)
	if plr == LP then return end
	disconnect(espConnections[plr])
	espConnections[plr] = plr.CharacterAdded:Connect(function()
		task.wait(0.15)
		if espOn then makeESP(plr) end
	end)
	task.defer(function() if espOn then makeESP(plr) end end)
end

local function enableESP()
	if espOn then return end
	espOn = true
	for _, plr in ipairs(Players:GetPlayers()) do bindPlayerESP(plr) end
	espConnections.added = Players.PlayerAdded:Connect(bindPlayerESP)
	espConnections.removing = Players.PlayerRemoving:Connect(function(plr)
		disconnect(espConnections[plr])
		espConnections[plr] = nil
		removeESP(plr)
	end)
end

local function disableESP()
	if not espOn then return end
	espOn = false
	for plr, conn in pairs(espConnections) do
		if typeof(conn) == "RBXScriptConnection" then disconnect(conn) end
		espConnections[plr] = nil
	end
	for plr in pairs(espEntries) do removeESP(plr) end
end

task.spawn(function()
	while true do
		task.wait(ESP_UPDATE_INTERVAL)
		if espOn then
			local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LP then
					local e = espEntries[plr]
					if e then updateESPEntry(e, myRoot) else makeESP(plr) end
				end
			end
		end
	end
end)

--============================================================--
-- [J] INVIS LOOP
--============================================================--
task.spawn(function()
	while task.wait(0.5) do
		if invisOn then setInvis(true) end
	end
end)

--============================================================--
-- [K] MAIN LOOP — quét & khoá NPC
--============================================================--
task.spawn(function()
	while task.wait(0.4) do
		if antiMode ~= "off" then
			local list = scanAllNPCs()
			for _, npc in ipairs(list) do
				if antiMode == "v61" then
					pcall(lockNPC_v61, npc)
				else
					pcall(lockNPC_v62, npc)
				end
			end
			if antiMode == "v62" then applyPlayerNoTouch() end
		end
		if invisOn then setInvis(true) end
	end
end)

--============================================================--
-- [L] RESPAWN
--============================================================--
LP.CharacterAdded:Connect(function()
	task.wait(0.5)
	refreshPlayerChrs()
	if invisOn then setInvis(true) end
	if antiMode == "v62" then applyPlayerNoTouch() end
	if speedOn then
		pcall(function()
			if mainConn then mainConn:Disconnect() mainConn = nil end
			enableSpeed()
		end)
	end
end)

print("[MEGA v15] Loaded • v6.1 ⇄ v6.2 dual anti-NPC (cả 2 OFF) + Speed + ESP + Loot")