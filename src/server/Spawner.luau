-- BrainrotSpawner: the conveyor belt.
-- One job: roll brainrots, walk them from the Snack Dock to the exit,
-- and sell the one a player buys. A brainrot nobody buys walks off
-- the end and despawns, so the belt is always turning over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("State"))
local Builder = require(script.Parent:WaitForChild("Builder"))
local Bases = require(script.Parent:WaitForChild("Bases"))
local Money = require(script.Parent:WaitForChild("Money"))

local Spawner = {}

-- Every brainrot currently on the belt, keyed by its Model.
-- Each entry is { def, mutation }.
local belt = {} :: { [Model]: { def: Catalog.BrainrotDef, mutation: string } }

-- The remote the server pushes toasts on. Main hands it here.
Spawner.toastRemote = nil :: RemoteEvent?

local function toast(player: Player, message: string)
	if Spawner.toastRemote ~= nil then
		Spawner.toastRemote:FireClient(player, "Toast", { message = message })
	end
end

-- Build one brainrot and put it on the belt at the Snack Dock, with a
-- Buy prompt on it. The prompt is the buy button: hold E to buy.
local function putOnBelt(def: Catalog.BrainrotDef, mutation: string)
	local model = Builder.buildBrainrotModel(def, mutation)
	model:SetPrimaryPartCFrame(
		CFrame.new(Config.CONVEYOR_START) * CFrame.Angles(0, math.pi / 2, 0)
	)
	model.Parent = Workspace:WaitForChild("Belt")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = def.name .. "  " .. Config.formatMoney(def.cost) .. "  $" .. tostring(Catalog.incomePerSecond(def, mutation)) .. "/s"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player: Player)
		Spawner.buyBrainrot(player, model)
	end)

	belt[model] = { def = def, mutation = mutation }
end

-- Roll one brainrot (rarity, then a def of that rarity, then a
-- mutation) and put it on the belt, unless the belt is already full.
function Spawner.spawnBrainrot()
	local count = 0
	for _ in pairs(belt) do
		count += 1
	end
	if count >= Config.MAX_ON_BELT then
		return
	end
	local def = Catalog.rollBrainrot()
	local mutation = Catalog.rollMutation()
	putOnBelt(def, mutation)
end

-- Buy the brainrot off the belt: the player pays its price, it leaves
-- the belt, and it is placed on the first free slot of their base.
-- Every refusal explains itself in the toast it sends back.
function Spawner.buyBrainrot(player: Player, model: Model)
	local entry = belt[model]
	local state = GameState.get(player)
	if entry == nil or state == nil then
		return
	end
	if state.plotIndex == 0 then
		toast(player, "No base yet - wait for a free plot!")
		return
	end
	if GameState.firstFreeSlot(state) == nil then
		toast(player, "Your base is full! Sell a brainrot or rebirth.")
		return
	end
	if not Money.spendCash(state, entry.def.cost) then
		toast(player, "Not enough cash for " .. entry.def.name .. " (" .. Config.formatMoney(entry.def.cost) .. ")")
		return
	end
	belt[model] = nil
	model:Destroy()
	local slot = Bases.placeBrainrotOnBase(player, entry.def.id, entry.mutation)
	if slot == nil then
		Money.addCash(state, entry.def.cost)
		toast(player, "Your base is full - refunded!")
		return
	end
	toast(player, "Bought " .. entry.def.name .. " for " .. Config.formatMoney(entry.def.cost) .. " - earning $" .. tostring(Catalog.incomePerSecond(entry.def, entry.mutation)) .. "/s!")
end

-- Walk every belt brainrot east along the conveyor, a little bob for
-- life, and wash away any that reaches the end unbought.
local function walkBelt(dt: number)
	for model in pairs(belt) do
		if model.Parent == nil then
			belt[model] = nil
			continue
		end
		local primary = model.PrimaryPart
		if primary == nil then
			continue
		end
		local pos = primary.CFrame.Position
		local nextX = pos.X + Config.CONVEYOR_SPEED * dt
		if nextX >= Config.CONVEYOR_END.X then
			belt[model] = nil
			model:Destroy()
			continue
		end
		local bob = math.sin(os.clock() * 4 + pos.X * 0.3) * 0.15
		model:SetPrimaryPartCFrame(
			CFrame.new(nextX, Config.CONVEYOR_START.Y + bob, Config.CONVEYOR_START.Z)
				* CFrame.Angles(0, math.pi / 2, 0)
		)
	end
end

-- Start the belt: one spawn every few seconds, and the walk loop.
function Spawner.start()
	task.spawn(function()
		while true do
			task.wait(Config.SPAWN_INTERVAL)
			Spawner.spawnBrainrot()
		end
	end)
	RunService.Heartbeat:Connect(walkBelt)
end

return Spawner
