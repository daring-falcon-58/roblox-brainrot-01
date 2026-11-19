-- BaseManager: every player's home base.
-- One job: plots, slots and locks. It hands out a plot when a player
-- joins, places a bought brainrot on a free slot, takes one off when
-- it is sold or stolen, and locks the base against thieves. It never
-- touches cash: money lives in the Money module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("State"))
local Builder = require(script.Parent:WaitForChild("Builder"))

local Bases = {}

-- Set by Main after both modules load: called when a player holds a
-- placed brainrot's Steal prompt. (Bases cannot require Steal: Steal
-- requires Bases, so the wire runs one way, through Main.)
Bases.stealRequested = nil :: ((Player, Player, number) -> ())?

-- Plot pad colours, one per plot, so each base reads as its own.
local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(120, 230, 140),
	Color3.fromRGB(255, 210, 90),
	Color3.fromRGB(200, 130, 255),
	Color3.fromRGB(90, 220, 220),
}

-- The centre of a plot in the world, from the config's plot table.
function Bases.plotCenter(plotIndex: number): Vector3
	local plot = Config.PLOTS[plotIndex]
	return Vector3.new(plot.x, 0.6, plot.z)
end

-- Is this world position inside this plot's pad? The wave uses it to
-- tell whether a player made it home in time.
function Bases.isInsidePlot(plotIndex: number, position: Vector3): boolean
	local plot = Config.PLOTS[plotIndex]
	return math.abs(position.X - plot.x) <= Config.PLOT_HALF.x
		and math.abs(position.Z - plot.z) <= Config.PLOT_HALF.z
end

-- The plot's folder in the place: Workspace/Plots/Plot1 .. Plot6.
local function plotFolder(plotIndex: number): Folder
	return Workspace:WaitForChild("Plots"):WaitForChild("Plot" .. tostring(plotIndex))
end

-- Hand a player the next free plot: colour its pad, write their name
-- on its sign, and remember the plot in their state. Returns false
-- when all six plots are taken (the seventh player waits).
function Bases.assignPlot(player: Player): boolean
	local state = GameState.get(player)
	if state == nil or state.plotIndex ~= 0 then
		return false
	end
	for i = 1, Config.PLOT_COUNT do
		local taken = false
		for _, other in pairs(GameState.players) do
			if other.plotIndex == i then
				taken = true
				break
			end
		end
		if not taken then
			state.plotIndex = i
			local folder = plotFolder(i)
			local pad = folder:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") then
				pad.Color = PLOT_COLORS[i]
			end
			local board = folder:FindFirstChild("SignBoard")
			local sign = board and board:FindFirstChild("OwnerSign")
			if sign and sign:IsA("SurfaceGui") then
				local label = sign:FindFirstChildOfClass("TextLabel")
				if label then
					label.Text = player.Name .. "'s BASE"
				end
			end
			return true
		end
	end
	return false
end

-- Give a plot back when its player leaves: reset the pad and sign.
function Bases.releasePlot(plotIndex: number)
	if plotIndex < 1 or plotIndex > Config.PLOT_COUNT then
		return
	end
	local folder = plotFolder(plotIndex)
	local pad = folder:FindFirstChild("Pad")
	if pad and pad:IsA("BasePart") then
		pad.Color = PLOT_COLORS[plotIndex]
	end
	local board = folder:FindFirstChild("SignBoard")
	local sign = board and board:FindFirstChild("OwnerSign")
	if sign and sign:IsA("SurfaceGui") then
		local label = sign:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = "EMPTY BASE"
		end
	end
	local shield = folder:FindFirstChild("Shield")
	if shield and shield:IsA("BasePart") then
		shield.Transparency = 1
	end
end

-- Where a slot sits in the world, for placing a brainrot on it.
local function slotPosition(plotIndex: number, slot: number): Vector3
	local plot = Config.PLOTS[plotIndex]
	local offset = Config.SLOT_OFFSETS[slot]
	return Vector3.new(plot.x + offset.x, 0.6, plot.z + offset.z)
end

-- Place a brainrot on a player's base: build its model, stand it on
-- the first free slot, hang a Steal prompt on it, and record it in
-- the player's state. Returns the slot, or nil when the base is full.
function Bases.placeBrainrotOnBase(player: Player, defId: string, mutation: string): number?
	local state = GameState.get(player)
	local def = Catalog.getById(defId)
	if state == nil or def == nil or state.plotIndex == 0 then
		return nil
	end
	local slot = GameState.firstFreeSlot(state)
	if slot == nil then
		return nil
	end
	local model = Builder.buildBrainrotModel(def, mutation)
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Slot", slot)
	model:SetPrimaryPartCFrame(CFrame.new(slotPosition(state.plotIndex, slot)))
	model.Parent = Workspace:WaitForChild("Placed")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = def.name .. "  $" .. tostring(Catalog.incomePerSecond(def, mutation)) .. "/s"
	prompt.HoldDuration = Config.STEAL_HOLD_SECONDS
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(thief: Player)
		if Bases.stealRequested ~= nil then
			(Bases.stealRequested :: any)(thief, player, slot)
		end
	end)

	state.placed[slot] = { defId = defId, mutation = mutation, model = model, slot = slot }
	return slot
end

-- Take a brainrot off a base and destroy its model. Returns the
-- removed record, or nil when the slot was already empty.
function Bases.removeBrainrotFromBase(player: Player, slot: number): GameState.PlacedBrainrot?
	local state = GameState.get(player)
	if state == nil then
		return nil
	end
	local placed = state.placed[slot]
	if placed == nil then
		return nil
	end
	if placed.model ~= nil then
		placed.model:Destroy()
	end
	state.placed[slot] = nil
	return placed
end

-- Clear a whole base: every placed brainrot is destroyed and forgotten.
-- Rebirth calls this; the player keeps nothing but the multiplier.
function Bases.clearBase(player: Player)
	local state = GameState.get(player)
	if state == nil then
		return
	end
	for slot in pairs(state.placed) do
		Bases.removeBrainrotFromBase(player, slot)
	end
end

-- Lock a base for Config.LOCK_DURATION seconds. Returns false when
-- the lock is still cooling down.
function Bases.lockBase(player: Player): boolean
	local state = GameState.get(player)
	if state == nil then
		return false
	end
	local now = os.clock()
	if now < state.lockReadyAt then
		return false
	end
	state.lockedUntil = now + Config.LOCK_DURATION
	state.lockReadyAt = now + Config.LOCK_DURATION + Config.LOCK_COOLDOWN
	local folder = plotFolder(state.plotIndex)
	local shield = folder:FindFirstChild("Shield")
	if shield and shield:IsA("BasePart") then
		shield.Transparency = 0.35
	end
	task.delay(Config.LOCK_DURATION, function()
		if shield and shield.Parent ~= nil then
			shield.Transparency = 1
		end
	end)
	return true
end

-- Is this player's base locked right now? A locked base cannot be
-- stolen from: the Steal module asks this before every steal.
function Bases.isBaseLocked(player: Player): boolean
	local state = GameState.get(player)
	if state == nil then
		return false
	end
	return os.clock() < state.lockedUntil
end

-- Seconds until the lock can be used again, for the HUD button.
function Bases.lockCooldownLeft(player: Player): number
	local state = GameState.get(player)
	if state == nil then
		return 0
	end
	return math.max(0, state.lockReadyAt - os.clock())
end

return Bases
