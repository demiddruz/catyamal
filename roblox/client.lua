-- Экран игры: сверху уровень, сердечки, энергия, монеты, здоровье гусеницы; внизу задание; слева кнопки ЛЁД / ЩИТ / РЫВОК
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
local remote = RS:WaitForChild("CatAction")

local gui = Instance.new("ScreenGui"); gui.Name = "CatGameUI"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.Parent = plr:WaitForChild("PlayerGui")
local function frame(props) local f = Instance.new("Frame"); f.BorderSizePixel = 0; for k, v in pairs(props) do f[k] = v end; local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = f; return f end
local function lbl(parent, props) local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextColor3 = Color3.new(1, 1, 1); t.TextScaled = true; t.TextStrokeTransparency = 0.6; for k, v in pairs(props) do t[k] = v end; t.Parent = parent; return t end

-- верхняя панель
local top = frame({ Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Color3.fromRGB(20, 24, 48), BackgroundTransparency = 0.15, Parent = gui })
local lvl = lbl(top, { Size = UDim2.new(0.3, 0, 0.6, 0), Position = UDim2.new(0.01, 0, 0.2, 0), TextXAlignment = Enum.TextXAlignment.Left, Text = "Мир 1 «Двор» · уровень 1" })
local hearts = lbl(top, { Size = UDim2.new(0.12, 0, 0.6, 0), Position = UDim2.new(0.62, 0, 0.2, 0), Text = "❤❤❤", TextColor3 = Color3.fromRGB(255, 77, 109) })
local ebg = frame({ Size = UDim2.new(0.12, 0, 0.36, 0), Position = UDim2.new(0.75, 0, 0.32, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.5, Parent = top })
local ebar = frame({ Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(124, 252, 154), Parent = ebg })
local etxt = lbl(ebg, { Size = UDim2.fromScale(1, 1), Text = "⚡ 100", TextColor3 = Color3.fromRGB(10, 40, 20), TextStrokeTransparency = 1 })
local coins = lbl(top, { Size = UDim2.new(0.1, 0, 0.6, 0), Position = UDim2.new(0.89, 0, 0.2, 0), Text = "₽ 0", TextColor3 = Color3.fromRGB(255, 215, 0) })
-- здоровье гусеницы
local mbg = frame({ Size = UDim2.new(0.26, 0, 0, 22), Position = UDim2.new(0.33, 0, 0, 15), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.4, Parent = gui })
local mbar = frame({ Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(230, 57, 70), Parent = mbg })
local mtxt = lbl(mbg, { Size = UDim2.fromScale(1, 1), Text = "Гусеница" })
-- задание внизу
local taskBg = frame({ Size = UDim2.new(0.5, 0, 0, 46), Position = UDim2.new(0.25, 0, 1, -62), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.45, Parent = gui })
local taskTxt = lbl(taskBg, { Size = UDim2.new(0.96, 0, 0.8, 0), Position = UDim2.new(0.02, 0, 0.1, 0), Text = "", TextColor3 = Color3.fromRGB(255, 224, 138) })
-- сообщение по центру
local msg = lbl(gui, { Size = UDim2.new(0.6, 0, 0, 44), Position = UDim2.new(0.2, 0, 0.22, 0), Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeTransparency = 0 })
-- кнопки слева внизу
local function button(text, color, y, action)
	local b = Instance.new("TextButton"); b.Size = UDim2.new(0, 120, 0, 62); b.Position = UDim2.new(0, 16, 1, y); b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.GothamBlack; b.TextScaled = true; b.Text = text; b.AutoButtonColor = true; b.Parent = gui
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = b
	b.Activated:Connect(function() remote:FireServer(action) end)
	return b
end
local bIce = button("ЛЁД", Color3.fromRGB(59, 130, 246), -230, "ice")
local bShield = button("ЩИТ", Color3.fromRGB(46, 204, 113), -160, "shield")
local bDash = button("РЫВОК", Color3.fromRGB(243, 156, 18), -90, "dash")
local hint = lbl(gui, { Size = UDim2.new(0, 260, 0, 18), Position = UDim2.new(0, 146, 1, -86), Text = "E — лёд · Q — щит · R — рывок", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(230, 230, 230) })
if UIS.TouchEnabled and not UIS.KeyboardEnabled then hint.Visible = false end

UIS.InputBegan:Connect(function(inp, processed)
	if processed then return end
	if inp.KeyCode == Enum.KeyCode.E then remote:FireServer("ice")
	elseif inp.KeyCode == Enum.KeyCode.Q then remote:FireServer("shield")
	elseif inp.KeyCode == Enum.KeyCode.R then remote:FireServer("dash") end
end)

local lastMsg, msgT = -1, 0
RunService.RenderStepped:Connect(function(dt)
	local a = function(n, d) local v = plr:GetAttribute(n); if v == nil then return d end; return v end
	lvl.Text = "Мир «" .. a("World", "Двор") .. "» · уровень " .. a("Level", 1)
	local lives = a("Lives", 3); hearts.Text = string.rep("❤", math.max(0, lives)) .. string.rep("♡", math.max(0, 3 - lives))
	local e = math.clamp(a("Energy", 100), 0, 100); ebar.Size = UDim2.new(e / 100, 0, 1, 0); ebar.BackgroundColor3 = e > 50 and Color3.fromRGB(124, 252, 154) or e > 20 and Color3.fromRGB(255, 209, 102) or Color3.fromRGB(255, 82, 82); etxt.Text = "⚡ " .. e
	local ls = plr:FindFirstChild("leaderstats"); if ls and ls:FindFirstChild("Coins") then coins.Text = "₽ " .. ls.Coins.Value end
	local hp, mx = a("MonsterHP", 0), a("MonsterMax", 1); mbar.Size = UDim2.new(math.clamp(hp / math.max(1, mx), 0, 1), 0, 1, 0)
	local fr = a("Frozen", 0); mtxt.Text = (a("Boss", false) and "БОСС " or "Гусеница ") .. hp .. (fr > 0 and ("   ❄ " .. fr) or ""); mbar.BackgroundColor3 = fr > 0 and Color3.fromRGB(154, 214, 255) or Color3.fromRGB(230, 57, 70)
	local tt, td, tn = a("TaskText", ""), a("TaskDone", 0), a("TaskNeed", 0); taskTxt.Text = tn > 0 and ("Задание: " .. tt .. "  " .. td .. "/" .. tn) or tt; taskBg.Visible = tt ~= ""
	local ch = a("Charges", 0); bIce.Text = "ЛЁД ×" .. ch; bShield.Text = "ЩИТ ×" .. ch
	bIce.BackgroundColor3 = ch > 0 and Color3.fromRGB(59, 130, 246) or Color3.fromRGB(85, 85, 85); bShield.BackgroundColor3 = ch > 0 and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(85, 85, 85)
	local dc = a("DashCd", 0); bDash.Text = dc > 0 and string.format("РЫВОК %.1f", dc) or "РЫВОК"; bDash.BackgroundColor3 = dc > 0 and Color3.fromRGB(85, 85, 85) or Color3.fromRGB(243, 156, 18)
	local id = a("MsgId", 0); if id ~= lastMsg then lastMsg = id; msg.Text = a("Msg", ""); msgT = 2.2 end
	msgT -= dt; msg.TextTransparency = math.clamp(1 - msgT, 0, 1); msg.TextStrokeTransparency = math.clamp(1 - msgT, 0, 1)
	-- камера сверху под углом, как в веб-версии
	local char = plr.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if hrp then cam.CameraType = Enum.CameraType.Scriptable; local target = hrp.Position; cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(target + Vector3.new(0, 58, 34), target), math.clamp(dt * 6, 0, 1)) end
end)
