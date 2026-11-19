-- BazaarHud: everything the player sees.
-- One job: the interface over the 3D world. The top bar shows cash
-- ticking up at its rate, the shop shows the next tier to buy, the
-- base panel lists what is placed (with a Sell button each), and the
-- start screen, wave banner and rebirth banner mark the game's beats.
-- The client only draws: every number it shows came from the server,
-- and every button asks the server through a remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameEvent = remotes:WaitForChild("GameEvent") :: RemoteEvent
local playerAction = remotes:WaitForChild("PlayerAction") :: RemoteEvent
local sellBrainrotFn = remotes:WaitForChild("SellBrainrot") :: RemoteFunction
local rebirthFn = remotes:WaitForChild("Rebirth") :: RemoteFunction
local lockBaseFn = remotes:WaitForChild("LockBase") :: RemoteFunction

local cash = Config.START_CASH
local income = 0
local rebirths = 0

local gui = Instance.new("ScreenGui")
gui.Name = "BazaarGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- A dark translucent panel, the HUD's one look.
local function makePanel(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	return panel
end

-- A text label, the HUD's one look.
local function makeLabel(parent: Instance, name: string, text: string, size: number, color: Color3, position: UDim2, labelSize: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = labelSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- A button, the HUD's one look.
local function makeButton(parent: Instance, name: string, text: string, size: number, color: Color3, position: UDim2, buttonSize: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.TextSize = size
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.BackgroundColor3 = color
	button.Position = position
	button.Size = buttonSize
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

-- The top bar: cash, money-a-second, rebirths. Centred, clear of the
-- top-left corner where Roblox puts its own menu buttons.
local topBar = makePanel(gui, "TopBar", UDim2.new(0.5, -260, 0, 10), UDim2.new(0, 520, 0, 64))
local cashLabel = makeLabel(topBar, "Cash", "$100", 36, Color3.fromRGB(255, 255, 255), UDim2.new(0, 16, 0, 6), UDim2.new(0, 220, 0, 52))
local incomeLabel = makeLabel(topBar, "Income", "+$0/s", 24, Color3.fromRGB(90, 230, 130), UDim2.new(0, 240, 0, 14), UDim2.new(0, 140, 0, 36))
local rebirthLabel = makeLabel(topBar, "Rebirths", "REBIRTH x1", 24, Color3.fromRGB(255, 210, 90), UDim2.new(0, 390, 0, 14), UDim2.new(0, 120, 0, 36))

-- Lock and rebirth: the two buttons that guard and grow a base.
local lockButton = makeButton(gui, "LockButton", "LOCK BASE (60s)", 20, Color3.fromRGB(60, 120, 230), UDim2.new(1, -220, 0, 10), UDim2.new(0, 200, 0, 48))
local rebirthButton = makeButton(gui, "RebirthButton", "REBIRTH $10,000", 20, Color3.fromRGB(200, 130, 30), UDim2.new(1, -220, 0, 66), UDim2.new(0, 200, 0, 48))

-- The shop: the next tier to buy, then the four tiers after it, so
-- the climb ahead is always on screen.
local shopPanel = makePanel(gui, "ShopPanel", UDim2.new(0, 12, 0, 90), UDim2.new(0, 300, 0, 250))
makeLabel(shopPanel, "ShopTitle", "NEXT TIERS", 22, Color3.fromRGB(255, 210, 90), UDim2.new(0, 14, 0, 8), UDim2.new(0, 200, 0, 28))
local shopRows = {}
for i = 1, 5 do
	local row = makeLabel(shopPanel, "ShopRow" .. tostring(i), "", 17, Color3.fromRGB(230, 230, 230), UDim2.new(0, 14, 0, 40 + (i - 1) * 40), UDim2.new(0, 272, 0, 36))
	shopRows[i] = row
end

-- Your base: every brainrot placed on it, each with its money rate
-- and a Sell button that refunds half its price.
local basePanel = makePanel(gui, "BasePanel", UDim2.new(1, -312, 0, 130), UDim2.new(0, 300, 0, 300))
makeLabel(basePanel, "BaseTitle", "YOUR BASE", 22, Color3.fromRGB(120, 220, 255), UDim2.new(0, 14, 0, 8), UDim2.new(0, 200, 0, 28))
local baseRows = {}
for i = 1, 8 do
	local row = Instance.new("Frame")
	row.Name = "BaseRow" .. tostring(i)
	row.Position = UDim2.new(0, 10, 0, 40 + (i - 1) * 32)
	row.Size = UDim2.new(0, 280, 0, 28)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = basePanel
	local nameLabel = makeLabel(row, "Name", "", 16, Color3.fromRGB(230, 230, 230), UDim2.new(0, 4, 0, 0), UDim2.new(0, 190, 0, 28))
	local sellButton = makeButton(row, "Sell", "SELL", 15, Color3.fromRGB(180, 60, 60), UDim2.new(0, 200, 0, 0), UDim2.new(0, 70, 0, 28))
	baseRows[i] = { frame = row, name = nameLabel, sell = sellButton, slot = 0 }
end

-- The hint bar: what to do next, along the bottom.
local hintLabel = makeLabel(gui, "Hint", "Walk to the conveyor - press E on a brainrot to buy it!", 20, Color3.fromRGB(255, 255, 255), UDim2.new(0.5, -320, 1, -52), UDim2.new(0, 640, 0, 36))
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
hintLabel.BackgroundTransparency = 0.2

-- The SLAP button, bottom-right, for thieves at arm's length.
local slapButton = makeButton(gui, "SlapButton", "SLAP  (F)", 22, Color3.fromRGB(200, 50, 70), UDim2.new(1, -150, 1, -120), UDim2.new(0, 130, 0, 56))

-- The wave banner: hidden until the tsunami is coming.
local waveBanner = makePanel(gui, "WaveBanner", UDim2.new(0.5, -300, 0, 84), UDim2.new(0, 600, 0, 56))
waveBanner.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
waveBanner.Visible = false
local waveLabel = makeLabel(waveBanner, "WaveText", "TSUNAMI INCOMING - RUN TO YOUR BASE!", 26, Color3.fromRGB(255, 255, 255), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0))
waveLabel.TextXAlignment = Enum.TextXAlignment.Center

-- The rebirth banner: shown for a few seconds after a rebirth.
local rebirthBanner = makePanel(gui, "RebirthBanner", UDim2.new(0.5, -250, 0.35, 0), UDim2.new(0, 500, 0, 80))
rebirthBanner.BackgroundColor3 = Color3.fromRGB(200, 130, 30)
rebirthBanner.Visible = false
local rebirthBannerLabel = makeLabel(rebirthBanner, "RebirthText", "REBIRTH! Income x2 forever", 30, Color3.fromRGB(255, 255, 255), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0))
rebirthBannerLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Toasts: short messages stacked at the bottom-left, fading out.
local toastPanel = Instance.new("Frame")
toastPanel.Name = "Toasts"
toastPanel.Position = UDim2.new(0, 12, 1, -200)
toastPanel.Size = UDim2.new(0, 420, 0, 140)
toastPanel.BackgroundTransparency = 1
toastPanel.Parent = gui

local function showToast(message: string)
	local toast = makeLabel(toastPanel, "Toast", message, 18, Color3.fromRGB(255, 255, 255), UDim2.new(0, 0, 0, 0), UDim2.new(0, 420, 0, 34))
	toast.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
	toast.BackgroundTransparency = 0.2
	toast.TextXAlignment = Enum.TextXAlignment.Left
	for _, other in ipairs(toastPanel:GetChildren()) do
		if other ~= toast and other:IsA("TextLabel") then
			other.Position += UDim2.new(0, 0, 0, -38)
		end
	end
	task.delay(4, function()
		toast:Destroy()
	end)
end

-- The start screen: the game's title, how it plays, and PLAY.
local startScreen = Instance.new("Frame")
startScreen.Name = "StartScreen"
startScreen.Size = UDim2.fromScale(1, 1)
startScreen.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
startScreen.BackgroundTransparency = 0.25
startScreen.BorderSizePixel = 0
startScreen.Parent = gui
local startTitle = makeLabel(startScreen, "Title", "BRAINROT BAZAAR", 64, Color3.fromRGB(255, 210, 90), UDim2.new(0.5, -400, 0.22, 0), UDim2.new(0, 800, 0, 80))
startTitle.TextXAlignment = Enum.TextXAlignment.Center
local startSub = makeLabel(startScreen, "Subtitle", "Collect the snack-creatures. Guard your base. Outrun the wave.", 24, Color3.fromRGB(255, 255, 255), UDim2.new(0.5, -400, 0.32, 0), UDim2.new(0, 800, 0, 36))
startSub.TextXAlignment = Enum.TextXAlignment.Center
local startHow = makeLabel(startScreen, "HowTo", "1. Buy brainrots off the conveyor (press E)\n2. They earn money every second on your base\n3. Steal from rivals - and SLAP thieves with F\n4. When the TSUNAMI comes, run home!", 22, Color3.fromRGB(230, 230, 230), UDim2.new(0.5, -400, 0.42, 0), UDim2.new(0, 800, 0, 130))
startHow.TextXAlignment = Enum.TextXAlignment.Center
local playButton = makeButton(startScreen, "PlayButton", "PLAY", 32, Color3.fromRGB(60, 180, 80), UDim2.new(0.5, -110, 0.62, 0), UDim2.new(0, 220, 0, 64))
playButton.MouseButton1Click:Connect(function()
	startScreen.Visible = false
	showToast("Welcome to the Bazaar! Buy your first brainrot on the conveyor.")
end)

-- Refresh the money display and the shop from the latest numbers.
local function updateMoneyDisplay()
	cashLabel.Text = Config.formatMoney(cash)
	incomeLabel.Text = "+$" .. tostring(income) .. "/s"
	rebirthLabel.Text = "REBIRTH x" .. tostring(1 + rebirths)
	rebirthButton.Text = "REBIRTH " .. Config.formatMoney(Config.rebirthCost(rebirths))
	-- The five cheapest brainrots above the player's cash: the climb.
	local ahead = {}
	for _, def in ipairs(Catalog.BRAINROTS) do
		if def.cost > cash then
			table.insert(ahead, def)
		end
	end
	table.sort(ahead, function(a, b)
		return a.cost < b.cost
	end)
	for i = 1, 5 do
		local def = ahead[i]
		if def == nil then
			shopRows[i].Text = ""
		else
			shopRows[i].Text = def.name .. "  $" .. tostring(def.income) .. "/s  " .. Config.formatMoney(def.cost)
			shopRows[i].TextColor3 = Catalog.rarityInfo(def.rarity).color
		end
	end
end

-- Refresh the base panel from the placed models in the world: the
-- world is the source of truth, so a stolen brainrot leaves the list
-- the moment its model leaves the base.
local function refreshBasePanel()
	local placedFolder = Workspace:FindFirstChild("Placed")
	local mine = {}
	if placedFolder then
		for _, model in ipairs(placedFolder:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("OwnerId") == player.UserId then
				table.insert(mine, model)
			end
		end
	end
	table.sort(mine, function(a, b)
		return (a:GetAttribute("Slot") or 0) < (b:GetAttribute("Slot") or 0)
	end)
	for i = 1, 8 do
		local row = baseRows[i]
		local model = mine[i]
		if model == nil then
			row.frame.Visible = false
			continue
		end
		row.frame.Visible = true
		row.slot = model:GetAttribute("Slot") or 0
		row.name.Text = model.Name
	end
end

-- Sell buttons: one handler each, reading the row's current slot, so
-- a refresh never stacks duplicate connections on a button.
for _, row in ipairs(baseRows) do
	row.sell.MouseButton1Click:Connect(function()
		if row.slot == 0 then
			return
		end
		local ok, message = sellBrainrotFn:InvokeServer(row.slot)
		showToast(message)
	end)
end

-- Lock and rebirth ask the server and show what it answers.
lockButton.MouseButton1Click:Connect(function()
	local ok, message = lockBaseFn:InvokeServer()
	showToast(message)
end)
rebirthButton.MouseButton1Click:Connect(function()
	local ok, message = rebirthFn:InvokeServer()
	showToast(message)
end)

-- Slap: the button and the F key do the same thing.
local function doSlap()
	playerAction:FireServer("Slap")
end
slapButton.MouseButton1Click:Connect(doSlap)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		doSlap()
	end
end)

-- The wave countdown: the banner counts down the warning, then says
-- the wave is here, then hides when it passes.
local waveCountdown = 0
task.spawn(function()
	while true do
		task.wait(1)
		if waveCountdown > 0 then
			waveCountdown -= 1
			if waveCountdown > 0 then
				waveLabel.Text = "TSUNAMI INCOMING - RUN TO YOUR BASE!  " .. tostring(waveCountdown) .. "s"
			else
				waveLabel.Text = "THE WAVE IS HERE!"
			end
		end
	end
end)

-- Everything the server pushes arrives on this one remote.
gameEvent.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "Income" then
		cash = data.cash
		income = data.income
		rebirths = data.rebirths
		updateMoneyDisplay()
	elseif kind == "Toast" then
		showToast(data.message)
	elseif kind == "Rebirth" then
		rebirthBannerLabel.Text = "REBIRTH! Income x" .. tostring(data.multiplier) .. " forever"
		rebirthBanner.Visible = true
		task.delay(5, function()
			rebirthBanner.Visible = false
		end)
	elseif kind == "WaveWarning" then
		waveCountdown = data.seconds
		waveLabel.Text = "TSUNAMI INCOMING - RUN TO YOUR BASE!  " .. tostring(data.seconds) .. "s"
		waveBanner.Visible = true
	elseif kind == "WaveStart" then
		waveCountdown = 0
		waveLabel.Text = "THE WAVE IS HERE!"
	elseif kind == "WaveEnd" then
		waveBanner.Visible = false
	end
end)

-- The base panel follows the world: refresh when a brainrot is
-- placed on, or taken off, any base.
local placedFolder = Workspace:WaitForChild("Placed")
placedFolder.ChildAdded:Connect(refreshBasePanel)
placedFolder.ChildRemoved:Connect(refreshBasePanel)

updateMoneyDisplay()
refreshBasePanel()
