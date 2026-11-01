-- Экран игры: сверху уровень, сердечки, энергия, монеты, здоровье гусеницы; внизу задание; слева кнопки ЛЁД / ЩИТ / РЫВОК
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
local remote = RS:WaitForChild("CatAction")
local shopFn = RS:WaitForChild("ShopAction")
local MPS = game:GetService("MarketplaceService")
local Config = require(RS:WaitForChild("ShopConfig"))

local gui = Instance.new("ScreenGui"); gui.Name = "CatGameUI"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.Parent = plr:WaitForChild("PlayerGui")
local function frame(props) local f = Instance.new("Frame"); f.BorderSizePixel = 0; for k, v in pairs(props) do f[k] = v end; local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = f; return f end
local function lbl(parent, props) local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextColor3 = Color3.new(1, 1, 1); t.TextScaled = true; t.TextStrokeTransparency = 0.6; for k, v in pairs(props) do t[k] = v end; t.Parent = parent; return t end

-- верхняя панель
local top = frame({ Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Color3.fromRGB(20, 24, 48), BackgroundTransparency = 0.15, Parent = gui })
local lvl = lbl(top, { Size = UDim2.new(0.22, 0, 0.6, 0), Position = UDim2.new(0, 220, 0.2, 0), TextXAlignment = Enum.TextXAlignment.Left, Text = "Мир 1 «Двор» · уровень 1" })
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
	local b = Instance.new("TextButton"); b.Size = UDim2.new(0, 120, 0, 62); b.Position = UDim2.new(0, 16, 1, y); b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.GothamBlack; b.TextScaled = true; b.Text = text; b.AutoButtonColor = true; b.Parent = gui; local st = Instance.new("UIStroke"); st.Thickness = 2; st.Color = Color3.new(1, 1, 1); st.Transparency = 0.4; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = b
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = b
	b.Activated:Connect(function() remote:FireServer(action) end)
	return b
end
local bIce = button("ЛЁД", Color3.fromRGB(59, 130, 246), -230, "ice")
local bShield = button("ЩИТ", Color3.fromRGB(46, 204, 113), -160, "shield")
local bDash = button("РЫВОК", Color3.fromRGB(243, 156, 18), -90, "dash")
local hint = lbl(gui, { Size = UDim2.new(0, 260, 0, 18), Position = UDim2.new(0, 146, 1, -86), Text = "E — лёд · Q — щит · R — рывок", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(230, 230, 230) })
if UIS.TouchEnabled and not UIS.KeyboardEnabled then hint.Visible = false end

-- ───────── магазин ─────────
local shopBtn = Instance.new("TextButton"); shopBtn.Size = UDim2.new(0, 120, 0, 40); shopBtn.Position = UDim2.new(0, 16, 0, 64); shopBtn.BackgroundColor3 = Color3.fromRGB(155, 89, 182); shopBtn.TextColor3 = Color3.new(1, 1, 1); shopBtn.Font = Enum.Font.GothamBlack; shopBtn.TextScaled = true; shopBtn.Text = "🛒 МАГАЗИН"; shopBtn.Parent = gui
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = shopBtn end
local shop = frame({ Size = UDim2.new(0.7, 0, 0.74, 0), Position = UDim2.new(0.15, 0, 0.13, 0), BackgroundColor3 = Color3.fromRGB(20, 24, 48), BackgroundTransparency = 0.05, Visible = false, Parent = gui })
lbl(shop, { Size = UDim2.new(0.6, 0, 0, 40), Position = UDim2.new(0.2, 0, 0, 8), Text = "Магазин", TextColor3 = Color3.fromRGB(255, 224, 138) })
local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0, 44, 0, 44); closeBtn.Position = UDim2.new(1, -54, 0, 8); closeBtn.Text = "✕"; closeBtn.TextScaled = true; closeBtn.Font = Enum.Font.GothamBlack; closeBtn.BackgroundColor3 = Color3.fromRGB(85, 85, 85); closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.Parent = shop
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = closeBtn end
local list = Instance.new("ScrollingFrame"); list.Size = UDim2.new(0.96, 0, 1, -64); list.Position = UDim2.new(0.02, 0, 0, 58); list.BackgroundTransparency = 1; list.BorderSizePixel = 0; list.ScrollBarThickness = 8; list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new(); list.Parent = shop
local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, 8); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = list
local order = 0
local function header(text) order += 1; lbl(list, { Size = UDim2.new(1, 0, 0, 30), Text = text, TextColor3 = Color3.fromRGB(255, 224, 138), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order }) end
local rows = {}
local function row(title, desc, color, onClick, refresh)
	order += 1
	local r = frame({ Size = UDim2.new(1, -12, 0, 58), BackgroundColor3 = Color3.fromRGB(40, 46, 80), LayoutOrder = order, Parent = list })
	if color then local sw = frame({ Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 9, 0, 9), BackgroundColor3 = color, Parent = r }) end
	lbl(r, { Size = UDim2.new(0.5, 0, 0, 26), Position = UDim2.new(0, color and 60 or 12, 0, 5), Text = title, TextXAlignment = Enum.TextXAlignment.Left })
	lbl(r, { Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.new(0, color and 60 or 12, 0, 33), Text = desc, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 210), Font = Enum.Font.Gotham })
	local b = Instance.new("TextButton"); b.Size = UDim2.new(0, 170, 0, 42); b.Position = UDim2.new(1, -180, 0, 8); b.Font = Enum.Font.GothamBlack; b.TextScaled = true; b.TextColor3 = Color3.new(1, 1, 1); b.Parent = r
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = b
	b.Activated:Connect(onClick); table.insert(rows, function() refresh(b) end)
end
local function hasPass(key) return table.find(string.split(plr:GetAttribute("Passes") or "", ","), key) ~= nil end
local function ownsKit(K) if (K.coins or 0) == 0 and not K.pass then return true end; if K.pass then return hasPass(K.pass) end; return table.find(string.split(plr:GetAttribute("OwnedKits") or "", ","), K.key) ~= nil end
local function toast(t) plr:SetAttribute("Msg", t); plr:SetAttribute("MsgId", (plr:GetAttribute("MsgId") or 0) + 0.5) end

header("Пропуски — покупаются один раз")
for _, key in ipairs(Config.PassOrder) do local ps = Config.Passes[key]
	row(ps.name, ps.desc, nil, function() if hasPass(key) then return end; if ps.id > 0 then MPS:PromptGamePassPurchase(plr, ps.id) else toast("Пропуск скоро появится") end end,
		function(b) if hasPass(key) then b.Text = "✓ ЕСТЬ"; b.BackgroundColor3 = Color3.fromRGB(46, 204, 113) elseif ps.id > 0 then b.Text = "R$ " .. ps.price; b.BackgroundColor3 = Color3.fromRGB(0, 162, 255) else b.Text = "скоро"; b.BackgroundColor3 = Color3.fromRGB(85, 85, 85) end end)
end
header("Монеты и энергия")
for _, key in ipairs(Config.ProductOrder) do local pr = Config.Products[key]
	row(pr.name, pr.coins and "монеты сразу на счёт" or "энергия до 100 прямо сейчас", nil, function() if pr.id > 0 then MPS:PromptProductPurchase(plr, pr.id) else toast("Скоро появится") end end,
		function(b) if pr.id > 0 then b.Text = "R$ " .. pr.price; b.BackgroundColor3 = Color3.fromRGB(0, 162, 255) else b.Text = "скоро"; b.BackgroundColor3 = Color3.fromRGB(85, 85, 85) end end)
end
header("Форма Леона")
for _, K in ipairs(Config.Kits) do
	row(K.name, K.pass and ("по пропуску «" .. Config.Passes[K.pass].name .. "»") or (K.coins > 0 and (K.coins .. " монет") or "бесплатно"), Color3.fromRGB(K.torso[1], K.torso[2], K.torso[3]),
		function() local action = ownsKit(K) and "equipKit" or "buyKit"; if K.pass and not ownsKit(K) then local ps = Config.Passes[K.pass]; if ps.id > 0 then MPS:PromptGamePassPurchase(plr, ps.id) else toast("Пропуск скоро появится") end; return end; local ok, m = shopFn:InvokeServer(action, K.key); toast(m) end,
		function(b) if plr:GetAttribute("Kit") == K.key then b.Text = "НАДЕТА"; b.BackgroundColor3 = Color3.fromRGB(46, 204, 113) elseif ownsKit(K) then b.Text = "НАДЕТЬ"; b.BackgroundColor3 = Color3.fromRGB(59, 130, 246) elseif K.pass then b.Text = "ПРОПУСК"; b.BackgroundColor3 = Color3.fromRGB(85, 85, 85) else b.Text = "₽ " .. K.coins; b.BackgroundColor3 = Color3.fromRGB(243, 156, 18) end end)
end
shopBtn.Activated:Connect(function() shop.Visible = not shop.Visible end)
closeBtn.Activated:Connect(function() shop.Visible = false end)
-- воскрешение после проигрыша
local revive = Instance.new("TextButton"); revive.Size = UDim2.new(0, 300, 0, 64); revive.Position = UDim2.new(0.5, -150, 0.5, -32); revive.BackgroundColor3 = Color3.fromRGB(46, 204, 113); revive.TextColor3 = Color3.new(1, 1, 1); revive.Font = Enum.Font.GothamBlack; revive.TextScaled = true; revive.Text = "ВОСКРЕСНУТЬ · R$ " .. Config.Products.Revive.price; revive.Visible = false; revive.Parent = gui
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = revive end
revive.Activated:Connect(function() if Config.Products.Revive.id > 0 then MPS:PromptProductPurchase(plr, Config.Products.Revive.id) end end)

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
	local lives, maxL = a("Lives", 3), a("MaxLives", 3); hearts.Text = string.rep("❤", math.max(0, lives)) .. string.rep("♡", math.max(0, maxL - lives))
	local e = math.clamp(a("Energy", 100), 0, 100); ebar.Size = UDim2.new(e / 100, 0, 1, 0); ebar.BackgroundColor3 = e > 50 and Color3.fromRGB(124, 252, 154) or e > 20 and Color3.fromRGB(255, 209, 102) or Color3.fromRGB(255, 82, 82); etxt.Text = "⚡ " .. e
	local ls = plr:FindFirstChild("leaderstats"); if ls and ls:FindFirstChild("Coins") then coins.Text = "₽ " .. ls.Coins.Value end
	local hp, mx = a("MonsterHP", 0), a("MonsterMax", 1); mbar.Size = UDim2.new(math.clamp(hp / math.max(1, mx), 0, 1), 0, 1, 0)
	local fr = a("Frozen", 0); mtxt.Text = (a("Boss", false) and "БОСС " or "Гусеница ") .. hp .. (fr > 0 and ("   ❄ " .. fr) or ""); mbar.BackgroundColor3 = fr > 0 and Color3.fromRGB(154, 214, 255) or Color3.fromRGB(230, 57, 70)
	local tt, td, tn = a("TaskText", ""), a("TaskDone", 0), a("TaskNeed", 0); taskTxt.Text = tn > 0 and ("Задание: " .. tt .. "  " .. td .. "/" .. tn) or tt; taskBg.Visible = tt ~= ""
	local ch = a("Charges", 0); bIce.Text = "ЛЁД ×" .. ch; bShield.Text = "ЩИТ ×" .. ch
	bIce.BackgroundColor3 = ch > 0 and Color3.fromRGB(59, 130, 246) or Color3.fromRGB(70, 74, 90); bShield.BackgroundColor3 = ch > 0 and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(70, 74, 90)
	local dc = a("DashCd", 0); bDash.Text = dc > 0 and string.format("РЫВОК %.1f", dc) or "РЫВОК"; bDash.BackgroundColor3 = dc > 0 and Color3.fromRGB(85, 85, 85) or Color3.fromRGB(243, 156, 18)
	revive.Visible = a("CanRevive", false) == true
	if shop.Visible then for _, f in ipairs(rows) do f() end end
	local id = a("MsgId", 0); if id ~= lastMsg then lastMsg = id; msg.Text = a("Msg", ""); msgT = 2.2 end
	msgT -= dt; msg.TextTransparency = math.clamp(1 - msgT, 0, 1); msg.TextStrokeTransparency = math.clamp(1 - msgT, 0, 1)
	-- камера сверху под углом, как в веб-версии
	local char = plr.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if hrp then cam.CameraType = Enum.CameraType.Scriptable; local target = hrp.Position; cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(target + Vector3.new(0, 58, 34), target), math.clamp(dt * 6, 0, 1)) end
end)
