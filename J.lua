--[[
    Executor UI v4.0 — Flint only
    - Model: recursive/flint-v1.0:free (hardcoded)
    - Tabs: EXECUTOR | CHAT | THINKING | PLUGINS
    - THINKING tab shows the model's reasoning stream
    - Typewriter chat effect preserved
    - Clean/pro layout, responsive UIScale
--]]

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace   = game:GetService("Workspace")
local Lighting    = game:GetService("Lighting")
local UIS         = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("ExecutorUI") then
    playerGui.ExecutorUI:Destroy()
end

--============================================================
-- CONSTANTS
--============================================================
local MODEL_ID = "recursive/flint-v1.0:free"
local OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

local SYSTEM_PROMPT =
    "You are a Roblox Luau assistant inside an executor UI. " ..
    "Reply with runnable Luau code or concise analysis. No markdown fences unless asked."

--============================================================
-- RESPONSIVE ROOT
--============================================================
local BASE_W, BASE_H = 820, 540

local gui = Instance.new("ScreenGui")
gui.Name = "ExecutorUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Size = UDim2.new(0, BASE_W, 0, BASE_H)
holder.Position = UDim2.new(0.5, -BASE_W/2, 0.5, -BASE_H/2)
holder.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
holder.BorderSizePixel = 0
holder.Active = true
holder.Draggable = true
holder.Parent = gui

Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 10)
do
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(64, 64, 72)
    s.Thickness = 1
    s.Transparency = 0.15
    s.Parent = holder
end

local uiScale = Instance.new("UIScale", holder)
local function fitScale()
    local vp = Workspace.CurrentCamera.ViewportSize
    local pad = 28
    uiScale.Scale = math.min(1, (vp.X - pad) / BASE_W, (vp.Y - pad) / BASE_H)
    holder.Position = UDim2.new(0.5, -BASE_W/2, 0.5, -BASE_H/2)
end
fitScale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)

--============================================================
-- TOP BAR
--============================================================
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
topBar.BorderSizePixel = 0
topBar.Parent = holder
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -180, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "EXECUTOR  ·  flint"
title.TextColor3 = Color3.fromRGB(210, 210, 220)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local cfgBtn = Instance.new("TextButton")
cfgBtn.Size = UDim2.new(0, 64, 0, 24)
cfgBtn.Position = UDim2.new(1, -104, 0, 6)
cfgBtn.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
cfgBtn.Font = Enum.Font.Gotham
cfgBtn.TextSize = 11
cfgBtn.Text = "⚙ config"
cfgBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
cfgBtn.BorderSizePixel = 0
cfgBtn.Parent = topBar
Instance.new("UICorner", cfgBtn).CornerRadius = UDim.new(0, 5)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(56, 34, 34)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.TextColor3 = Color3.fromRGB(220, 120, 120)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

--============================================================
-- CONFIG PANEL (API key only)
--============================================================
local cfgPanel = Instance.new("Frame")
cfgPanel.Size = UDim2.new(0, 420, 0, 100)
cfgPanel.Position = UDim2.new(1, -420, 0, 36)
cfgPanel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
cfgPanel.BorderSizePixel = 0
cfgPanel.Visible = false
cfgPanel.ZIndex = 20
cfgPanel.Parent = holder
Instance.new("UICorner", cfgPanel).CornerRadius = UDim.new(0, 8)
do
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(76, 76, 86); s.Parent = cfgPanel
end
local function setZ(parent, z)
    for _, c in ipairs(parent:GetDescendants()) do
        if c:IsA("GuiObject") then c.ZIndex = z end
    end
end
setZ(cfgPanel, 20)

cfgBtn.MouseButton1Click:Connect(function()
    cfgPanel.Visible = not cfgPanel.Visible
end)

local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.new(0, 70, 0, 22)
keyLabel.Position = UDim2.new(0, 12, 0, 14)
keyLabel.BackgroundTransparency = 1
keyLabel.Font = Enum.Font.Gotham
keyLabel.TextSize = 11
keyLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
keyLabel.Text = "API Key"
keyLabel.TextXAlignment = Enum.TextXAlignment.Left
keyLabel.ZIndex = 21
keyLabel.Parent = cfgPanel

local keyBox = Instance.new("TextBox")
keyBox.Size = UDim2.new(1, -100, 0, 24)
keyBox.Position = UDim2.new(0, 80, 0, 12)
keyBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
keyBox.Font = Enum.Font.Code
keyBox.TextSize = 11
keyBox.TextColor3 = Color3.fromRGB(220, 220, 230)
keyBox.PlaceholderText = "sk-or-v1-..."
keyBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 90)
keyBox.TextXAlignment = Enum.TextXAlignment.Left
keyBox.ClearTextOnFocus = false
keyBox.Text = ""
keyBox.ZIndex = 21
keyBox.Parent = cfgPanel
Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 4)
Instance.new("UIPadding", keyBox).PaddingLeft = UDim.new(0, 6)

local modelInfo = Instance.new("TextLabel")
modelInfo.Size = UDim2.new(1, -24, 0, 20)
modelInfo.Position = UDim2.new(0, 12, 0, 48)
modelInfo.BackgroundTransparency = 1
modelInfo.Font = Enum.Font.Code
modelInfo.TextSize = 10
modelInfo.TextColor3 = Color3.fromRGB(150, 150, 160)
modelInfo.TextXAlignment = Enum.TextXAlignment.Left
modelInfo.Text = "model: " .. MODEL_ID .. "  ·  reasoning: mandatory"
modelInfo.ZIndex = 21
modelInfo.Parent = cfgPanel

local cfgStatus = Instance.new("TextLabel")
cfgStatus.Size = UDim2.new(1, -24, 0, 20)
cfgStatus.Position = UDim2.new(0, 12, 0, 70)
cfgStatus.BackgroundTransparency = 1
cfgStatus.Font = Enum.Font.Code
cfgStatus.TextSize = 10
cfgStatus.TextColor3 = Color3.fromRGB(140, 200, 140)
cfgStatus.TextXAlignment = Enum.TextXAlignment.Left
cfgStatus.Text = "ready"
cfgStatus.ZIndex = 21
cfgStatus.Parent = cfgPanel

--============================================================
-- TABS
--============================================================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 30)
tabBar.Position = UDim2.new(0, 10, 0, 44)
tabBar.BackgroundTransparency = 1
tabBar.Parent = holder

local function makeTab(name, x, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 1, 0)
    b.Position = UDim2.new(0, x, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = name
    b.TextColor3 = Color3.fromRGB(160, 160, 170)
    b.BorderSizePixel = 0
    b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local tabExec    = makeTab("EXECUTOR", 0, 100)
local tabChat    = makeTab("CHAT",     104, 80)
local tabThink   = makeTab("THINKING", 188, 90)
local tabPlugin  = makeTab("PLUGINS",  282, 90)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -84)
content.Position = UDim2.new(0, 10, 0, 78)
content.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
content.BorderSizePixel = 0
content.Parent = holder
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 6)

--============================================================
-- PAGE: EXECUTOR
--============================================================
local execPage = Instance.new("Frame")
execPage.Size = UDim2.new(1, 0, 1, 0)
execPage.BackgroundTransparency = 1
execPage.Parent = content

local codeScroll = Instance.new("ScrollingFrame")
codeScroll.Size = UDim2.new(1, -16, 1, -56)
codeScroll.Position = UDim2.new(0, 8, 0, 8)
codeScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
codeScroll.BorderSizePixel = 0
codeScroll.ScrollBarThickness = 6
codeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
codeScroll.Parent = execPage
Instance.new("UICorner", codeScroll).CornerRadius = UDim.new(0, 5)
local cp = Instance.new("UIPadding", codeScroll)
cp.PaddingLeft = UDim.new(0, 8); cp.PaddingRight = UDim.new(0, 8)
cp.PaddingTop = UDim.new(0, 8); cp.PaddingBottom = UDim.new(0, 8)

local codeBox = Instance.new("TextBox")
codeBox.Size = UDim2.new(1, -6, 0, 0)
codeBox.BackgroundTransparency = 1
codeBox.Font = Enum.Font.Code
codeBox.TextSize = 13
codeBox.TextColor3 = Color3.fromRGB(200, 220, 200)
codeBox.PlaceholderText = "-- luau here..."
codeBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 90)
codeBox.TextXAlignment = Enum.TextXAlignment.Left
codeBox.TextYAlignment = Enum.TextYAlignment.Top
codeBox.MultiLine = true
codeBox.ClearTextOnFocus = false
codeBox.TextWrapped = false
codeBox.AutomaticSize = Enum.AutomaticSize.Y
codeBox.Parent = codeScroll

local runBtn = Instance.new("TextButton")
runBtn.Size = UDim2.new(0, 90, 0, 30)
runBtn.Position = UDim2.new(0, 8, 1, -40)
runBtn.BackgroundColor3 = Color3.fromRGB(52, 130, 82)
runBtn.Font = Enum.Font.GothamBold
runBtn.TextSize = 12
runBtn.Text = "▶ RUN"
runBtn.TextColor3 = Color3.fromRGB(240, 255, 240)
runBtn.BorderSizePixel = 0
runBtn.Parent = execPage
Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 5)

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0, 70, 0, 30)
clearBtn.Position = UDim2.new(0, 106, 1, -40)
clearBtn.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
clearBtn.Font = Enum.Font.GothamBold
clearBtn.TextSize = 12
clearBtn.Text = "CLEAR"
clearBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
clearBtn.BorderSizePixel = 0
clearBtn.Parent = execPage
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 5)
clearBtn.MouseButton1Click:Connect(function() codeBox.Text = "" end)

local execStatus = Instance.new("TextLabel")
execStatus.Size = UDim2.new(1, -220, 0, 30)
execStatus.Position = UDim2.new(0, 184, 1, -40)
execStatus.BackgroundTransparency = 1
execStatus.Font = Enum.Font.Code
execStatus.TextSize = 11
execStatus.TextColor3 = Color3.fromRGB(160, 160, 170)
execStatus.TextXAlignment = Enum.TextXAlignment.Left
execStatus.Text = "ready"
execStatus.Parent = execPage

local function setExecStatus(msg, color)
    execStatus.Text = msg
    execStatus.TextColor3 = color or Color3.fromRGB(160, 160, 170)
end

local function runCode()
    local code = codeBox.Text
    if code == "" then setExecStatus("✕ empty", Color3.fromRGB(220, 100, 100)); return end
    setExecStatus("running...", Color3.fromRGB(140, 200, 140))
    local fn, err = loadstring(code)
    if not fn then setExecStatus("✕ syntax: " .. tostring(err):sub(1, 55), Color3.fromRGB(220, 100, 100)); return end
    local ok, runErr = pcall(fn)
    if ok then setExecStatus("✓ executed", Color3.fromRGB(120, 220, 140))
    else setExecStatus("✕ runtime: " .. tostring(runErr):sub(1, 55), Color3.fromRGB(220, 100, 100)) end
end
runBtn.MouseButton1Click:Connect(runCode)

--============================================================
-- PAGE: CHAT
--============================================================
local chatPage = Instance.new("Frame")
chatPage.Size = UDim2.new(1, 0, 1, 0)
chatPage.BackgroundTransparency = 1
chatPage.Visible = false
chatPage.Parent = content

local chatScroll = Instance.new("ScrollingFrame")
chatScroll.Size = UDim2.new(1, -16, 1, -112)
chatScroll.Position = UDim2.new(0, 8, 0, 8)
chatScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
chatScroll.BorderSizePixel = 0
chatScroll.ScrollBarThickness = 6
chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
chatScroll.Parent = chatPage
Instance.new("UICorner", chatScroll).CornerRadius = UDim.new(0, 5)

local chatLayout = Instance.new("UIListLayout", chatScroll)
chatLayout.Padding = UDim.new(0, 4)
chatLayout.SortOrder = Enum.SortOrder.LayoutOrder

local chatPad = Instance.new("UIPadding", chatScroll)
chatPad.PaddingLeft = UDim.new(0, 8); chatPad.PaddingRight = UDim.new(0, 8)
chatPad.PaddingTop = UDim.new(0, 8); chatPad.PaddingBottom = UDim.new(0, 8)

local chatLog = {}

local function addBubble(role, text)
    local isUser = role == "user"
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundColor3 = isUser and Color3.fromRGB(28, 40, 60) or Color3.fromRGB(28, 28, 32)
    frame.BorderSizePixel = 0
    frame.Parent = chatScroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 5)

    local fp = Instance.new("UIPadding", frame)
    fp.PaddingLeft = UDim.new(0, 8); fp.PaddingRight = UDim.new(0, 8)
    fp.PaddingTop = UDim.new(0, 6); fp.PaddingBottom = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextColor3 = isUser and Color3.fromRGB(180, 200, 255) or Color3.fromRGB(200, 220, 200)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextWrapped = true
    lbl.Text = (isUser and "you › " or "ai › ") .. text
    lbl.Parent = frame

    if not isUser then
        table.insert(chatLog, { role = "assistant", content = text })
    end
    task.wait()
    chatScroll.CanvasPosition = Vector2.new(0, chatScroll.AbsoluteCanvasSize.Y)
    return lbl
end

local function addUserMsg(text)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundColor3 = Color3.fromRGB(28, 40, 60)
    frame.BorderSizePixel = 0
    frame.Parent = chatScroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 5)

    local fp = Instance.new("UIPadding", frame)
    fp.PaddingLeft = UDim.new(0, 8); fp.PaddingRight = UDim.new(0, 8)
    fp.PaddingTop = UDim.new(0, 6); fp.PaddingBottom = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(180, 200, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextWrapped = true
    lbl.Text = "you › " .. text
    lbl.Parent = frame

    table.insert(chatLog, { role = "user", content = text })
    task.wait()
    chatScroll.CanvasPosition = Vector2.new(0, chatScroll.AbsoluteCanvasSize.Y)
end

local chatInput = Instance.new("TextBox")
chatInput.Size = UDim2.new(1, -96, 0, 62)
chatInput.Position = UDim2.new(0, 8, 1, -84)
chatInput.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
chatInput.Font = Enum.Font.Code
chatInput.TextSize = 12
chatInput.TextColor3 = Color3.fromRGB(220, 220, 230)
chatInput.PlaceholderText = "message (enter send · shift+enter newline)..."
chatInput.PlaceholderColor3 = Color3.fromRGB(80, 80, 90)
chatInput.TextXAlignment = Enum.TextXAlignment.Left
chatInput.TextYAlignment = Enum.TextYAlignment.Top
chatInput.MultiLine = true
chatInput.ClearTextOnFocus = false
chatInput.TextWrapped = true
chatInput.Parent = chatPage
Instance.new("UICorner", chatInput).CornerRadius = UDim.new(0, 5)
local cip = Instance.new("UIPadding", chatInput)
cip.PaddingLeft = UDim.new(0, 6); cip.PaddingRight = UDim.new(0, 6)
cip.PaddingTop = UDim.new(0, 4); cip.PaddingBottom = UDim.new(0, 4)

local sendChatBtn = Instance.new("TextButton")
sendChatBtn.Size = UDim2.new(0, 80, 0, 62)
sendChatBtn.Position = UDim2.new(1, -88, 1, -84)
sendChatBtn.BackgroundColor3 = Color3.fromRGB(52, 90, 160)
sendChatBtn.Font = Enum.Font.GothamBold
sendChatBtn.TextSize = 12
sendChatBtn.Text = "SEND"
sendChatBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
sendChatBtn.BorderSizePixel = 0
sendChatBtn.Parent = chatPage
Instance.new("UICorner", sendChatBtn).CornerRadius = UDim.new(0, 5)

--============================================================
-- PAGE: THINKING
--============================================================
local thinkPage = Instance.new("Frame")
thinkPage.Size = UDim2.new(1, 0, 1, 0)
thinkPage.BackgroundTransparency = 1
thinkPage.Visible = false
thinkPage.Parent = content

local thinkScroll = Instance.new("ScrollingFrame")
thinkScroll.Size = UDim2.new(1, -16, 1, -16)
thinkScroll.Position = UDim2.new(0, 8, 0, 8)
thinkScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
thinkScroll.BorderSizePixel = 0
thinkScroll.ScrollBarThickness = 6
thinkScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
thinkScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
thinkScroll.Parent = thinkPage
Instance.new("UICorner", thinkScroll).CornerRadius = UDim.new(0, 5)

local thinkPad = Instance.new("UIPadding", thinkScroll)
thinkPad.PaddingLeft = UDim.new(0, 10); thinkPad.PaddingRight = UDim.new(0, 10)
thinkPad.PaddingTop = UDim.new(0, 10); thinkPad.PaddingBottom = UDim.new(0, 10)

local thinkLabel = Instance.new("TextLabel")
thinkLabel.Size = UDim2.new(1, -6, 0, 0)
thinkLabel.AutomaticSize = Enum.AutomaticSize.Y
thinkLabel.BackgroundTransparency = 1
thinkLabel.Font = Enum.Font.Code
thinkLabel.TextSize = 12
thinkLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
thinkLabel.TextXAlignment = Enum.TextXAlignment.Left
thinkLabel.TextYAlignment = Enum.TextYAlignment.Top
thinkLabel.TextWrapped = true
thinkLabel.Text = "-- reasoning will appear here after a response --"
thinkLabel.Parent = thinkScroll

local function setThinking(text)
    thinkLabel.Text = text
    task.wait()
    thinkScroll.CanvasPosition = Vector2.new(0, thinkScroll.AbsoluteCanvasSize.Y)
end

--============================================================
-- PAGE: PLUGINS
--============================================================
local pluginPage = Instance.new("Frame")
pluginPage.Size = UDim2.new(1, 0, 1, 0)
pluginPage.BackgroundTransparency = 1
pluginPage.Visible = false
pluginPage.Parent = content

local pluginScroll = Instance.new("ScrollingFrame")
pluginScroll.Size = UDim2.new(1, -16, 1, -16)
pluginScroll.Position = UDim2.new(0, 8, 0, 8)
pluginScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
pluginScroll.BorderSizePixel = 0
pluginScroll.ScrollBarThickness = 6
pluginScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
pluginScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
pluginScroll.Parent = pluginPage
Instance.new("UICorner", pluginScroll).CornerRadius = UDim.new(0, 5)

local plLayout = Instance.new("UIListLayout", pluginScroll)
plLayout.Padding = UDim.new(0, 6)
local plPad = Instance.new("UIPadding", pluginScroll)
plPad.PaddingLeft = UDim.new(0, 8); plPad.PaddingRight = UDim.new(0, 8)
plPad.PaddingTop = UDim.new(0, 8); plPad.PaddingBottom = UDim.new(0, 8)

local function addPluginCard(name, desc, onRun)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 80)
    card.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    card.BorderSizePixel = 0
    card.Parent = pluginScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -100, 0, 20)
    t.Position = UDim2.new(0, 10, 0, 8)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 12
    t.TextColor3 = Color3.fromRGB(220, 220, 230)
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = name
    t.Parent = card

    local d = Instance.new("TextLabel")
    d.Size = UDim2.new(1, -100, 0, 42)
    d.Position = UDim2.new(0, 10, 0, 30)
    d.BackgroundTransparency = 1
    d.Font = Enum.Font.Gotham
    d.TextSize = 10
    d.TextColor3 = Color3.fromRGB(150, 150, 160)
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextYAlignment = Enum.TextYAlignment.Top
    d.TextWrapped = true
    d.Text = desc
    d.Parent = card

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 70, 0, 26)
    b.Position = UDim2.new(1, -80, 0, 27)
    b.BackgroundColor3 = Color3.fromRGB(52, 90, 160)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = "RUN"
    b.TextColor3 = Color3.fromRGB(240, 240, 255)
    b.BorderSizePixel = 0
    b.Parent = card
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(onRun)

    return card
end

--============================================================
-- TAB SWITCH
--============================================================
local pages = {
    Executor = execPage,
    Chat     = chatPage,
    Thinking = thinkPage,
    Plugins  = pluginPage,
}
local btns = {
    Executor = tabExec,
    Chat     = tabChat,
    Thinking = tabThink,
    Plugins  = tabPlugin,
}

local function switchTab(name)
    for k, p in pairs(pages) do p.Visible = (k == name) end
    for k, b in pairs(btns) do
        b.BackgroundColor3 = (k == name) and Color3.fromRGB(68, 88, 138) or Color3.fromRGB(34, 34, 40)
        b.TextColor3       = (k == name) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 170)
    end
end
tabExec.MouseButton1Click:Connect(function() switchTab("Executor") end)
tabChat.MouseButton1Click:Connect(function() switchTab("Chat") end)
tabThink.MouseButton1Click:Connect(function() switchTab("Thinking") end)
tabPlugin.MouseButton1Click:Connect(function() switchTab("Plugins") end)
switchTab("Executor")

--============================================================
-- HTTP
--============================================================
local function httpPost(url, headers, body)
    if syn and syn.request then
        return syn.request({ Url = url, Method = "POST", Headers = headers, Body = body }).Body
    elseif http and http.request then
        return http.request({ Url = url, Method = "POST", Headers = headers, Body = body }).Body
    elseif request then
        return request({ Url = url, Method = "POST", Headers = headers, Body = body }).Body
    else
        error("no http client")
    end
end

local function stripFences(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("^```[%w]*\r?\n", ""):gsub("\r?\n```%s*$", "")
    return s
end

--============================================================
-- OPENROUTER CALL (Flint only) — FIXED
--============================================================
local function callFlint(messages, key)
    local body = HttpService:JSONEncode({
        model = MODEL_ID,
        messages = messages,
        temperature = 0.3,
        reasoning = { enabled = true }
    })
    local raw = httpPost(OPENROUTER_URL, {
        ["Content-Type"]  = "application/json",
        ["Authorization"] = "Bearer " .. key,
        ["HTTP-Referer"]  = "https://localhost",
        ["X-Title"]       = "ExecutorUI",
    }, body)
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or not data then return nil, nil, "bad json" end
    if data.error then return nil, nil, tostring(data.error.message or data.error) end
    if not data.choices or not data.choices[1] then return nil, nil, "no choices" end
    local msg = data.choices[1].message
    local content = msg.content
    local reasoning = msg.reasoning
        or (msg.reasoning_details and msg.reasoning_details[1] and msg.reasoning_details[1].text)
        or ""
    return content, reasoning, nil
end

--============================================================
-- TYPEWRITER
--============================================================
local function typewriter(label, text, speed)
    speed = speed or 0.005
    label.Text = ""
    local i = 0
    task.spawn(function()
        while i < #text do
            i = i + 1
            if not label or not label.Parent then return end
            label.Text = string.sub(text, 1, i)
            task.wait(speed)
        end
    end)
end

--============================================================
-- CHAT SEND
--============================================================
local function chatSend()
    local prompt = chatInput.Text
    local key    = keyBox.Text

    if prompt == "" then return end
    if key == "" then
        addBubble("assistant", "! set API key in ⚙ config")
        return
    end

    addUserMsg(prompt)
    chatInput.Text = ""

    local aiLbl = addBubble("assistant", "")
    task.spawn(function()
        for _, w in ipairs({ "h", "he", "hel", "hell", "hello" }) do
            if not aiLbl.Parent then return end
            aiLbl.Text = "ai › " .. w
            task.wait(0.09)
        end
        if aiLbl.Parent then aiLbl.Text = "ai › hello... thinking" end
    end)

    local msgs = { { role = "system", content = SYSTEM_PROMPT } }
    for _, m in ipairs(chatLog) do
        if m.content ~= "" then
            table.insert(msgs, { role = m.role, content = m.content })
        end
    end

    local content, reasoning, err = callFlint(msgs, key)
    if not content then
        aiLbl.Text = "ai › ✕ " .. tostring(err)
        return
    end

    if reasoning and reasoning ~= "" then
        setThinking(reasoning)
    end

    aiLbl.Text = "ai › "
    typewriter(aiLbl, "ai › " .. content, 0.006)
    table.insert(chatLog, { role = "assistant", content = content })
end

sendChatBtn.MouseButton1Click:Connect(chatSend)
chatInput.FocusLost:Connect(function(enter)
    if enter and not UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
        chatSend()
    end
end)

--============================================================
-- PLUGIN: GAME DUMP
--============================================================
local function dumpGame()
    local lines = {}
    local function push(s) table.insert(lines, s) end

    push("== GAME ID: " .. tostring(game.PlaceId) .. " ==")
    local okName, name = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    push("Name: " .. (okName and tostring(name) or "unknown"))

    push("\n== WORKSPACE TREE (depth<=3) ==")
    local function walk(obj, d)
        if d > 3 then return end
        push(string.rep("  ", d) .. obj.Name .. " [" .. obj.ClassName .. "]")
        for _, c in ipairs(obj:GetChildren()) do
            if c.Name ~= "Camera" then walk(c, d + 1) end
        end
    end
    walk(Workspace, 0)

    push("\n== PLAYERS ==")
    for _, p in ipairs(Players:GetPlayers()) do
        push(p.Name .. " | id=" .. p.UserId .. " | hrp=" ..
            tostring(p.Character and p.Character:FindFirstChild("HumanoidRootPart") ~= nil))
    end

    push("\n== NON-EMPTY SERVICES ==")
    for _, s in ipairs(game:GetChildren()) do
        if s:IsA("Instance") and #s:GetChildren() > 0 then
            push(s.ClassName .. " (" .. #s:GetChildren() .. ")")
        end
    end

    push("\n== LIGHTING ==")
    push("ClockTime=" .. tostring(Lighting.ClockTime) ..
         " Brightness=" .. tostring(Lighting.Brightness) ..
         " FogEnd=" .. tostring(Lighting.FogEnd))

    push("\n== REMOTES ==")
    for _, d in ipairs(game:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") then
            push(d:GetFullName() .. " [" .. d.ClassName .. "]")
        end
    end

    local text = table.concat(lines, "\n")
    if #text > 12000 then text = text:sub(1, 12000) .. "\n... (truncated)" end
    return text
end

addPluginCard(
    "GAME DUMP",
    "Dump workspace tree, players, remotes, lighting, services → Flint analyzes in CHAT.",
    function()
        local key = keyBox.Text
        if key == "" then addBubble("assistant", "! set API key first"); switchTab("Chat"); return end

        local dump = dumpGame()
        switchTab("Chat")
        addBubble("assistant", "[GAME DUMP]\n" .. dump:sub(1, 350) .. "\n... (" .. #dump .. " chars)")

        local aiLbl = addBubble("assistant", "")
        task.spawn(function()
            for _, w in ipairs({ "h", "he", "hel", "hell", "hello" }) do
                if not aiLbl.Parent then return end
                aiLbl.Text = "ai › " .. w
                task.wait(0.09)
            end
            if aiLbl.Parent then aiLbl.Text = "ai › hello... analyzing dump" end
        end)

        local msgs = {
            { role = "system", content = SYSTEM_PROMPT .. " Analyze the dump, flag exploits, suggest scripts." },
            { role = "user", content = "Analyze this Roblox dump:\n\n" .. dump },
        }
        local content, reasoning, err = callFlint(msgs, key)
        if not content then
            aiLbl.Text = "ai › ✕ " .. tostring(err)
            return
        end
        if reasoning and reasoning ~= "" then setThinking(reasoning) end
        aiLbl.Text = "ai › "
        typewriter(aiLbl, "ai › " .. content, 0.006)
        table.insert(chatLog, { role = "assistant", content = content })
    end
)

addPluginCard(
    "GAME DUMP → EXECUTOR",
    "Dump game, ask Flint to generate a starter script, inject into EXECUTOR tab.",
    function()
        local key = keyBox.Text
        if key == "" then addBubble("assistant", "! set API key first"); switchTab("Chat"); return end

        local dump = dumpGame()
        switchTab("Executor")
        codeBox.Text = "-- generating from game dump..."
        setExecStatus("ai generating...", Color3.fromRGB(140, 200, 140))

        local msgs = {
            { role = "system", content = SYSTEM_PROMPT .. " Generate runnable Luau. No fences, no explanations." },
            { role = "user", content = "Given this dump, write a script to auto-farm all remotes:\n\n" .. dump },
        }
        local content, reasoning, err = callFlint(msgs, key)
        if not content then
            setExecStatus("✕ " .. tostring(err), Color3.fromRGB(220, 100, 100))
            return
        end
        if reasoning and reasoning ~= "" then setThinking(reasoning) end
        content = stripFences(content)
        typewriter(codeBox, content, 0.004)
        setExecStatus("✓ injected from dump", Color3.fromRGB(120, 220, 140))
    end
)

--============================================================
-- CLICK OUTSIDE CLOSES CONFIG
--============================================================
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and cfgPanel.Visible then
        local mp = input.Position
        local ab, sz = cfgPanel.AbsolutePosition, cfgPanel.AbsoluteSize
        local insideCfg = mp.X >= ab.X and mp.X <= ab.X + sz.X and mp.Y >= ab.Y and mp.Y <= ab.Y + sz.Y
        local sb = cfgBtn.AbsolutePosition
        local ss = cfgBtn.AbsoluteSize
        local insideBtn = mp.X >= sb.X and mp.X <= sb.X + ss.X and mp.Y >= sb.Y and mp.Y <= sb.Y + ss.Y
        if not insideCfg and not insideBtn then
            cfgPanel.Visible = false
        end
    end
end)

--============================================================
-- INIT
--============================================================
addBubble("assistant", "ready. open ⚙ config → paste OpenRouter key → chat or use plugins. Flint reasoning appears in THINKING tab.")
setExecStatus("ready", Color3.fromRGB(120, 220, 140))
