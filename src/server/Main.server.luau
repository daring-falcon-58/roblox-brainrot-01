-- GameServer: the game's wiring, and its only Script.
-- One job: start the game. It requires every module once, hands the
-- remotes to the modules that push on them, answers the client's
-- RemoteFunctions, loads and saves each player's data, and starts the
-- belt, the steal loop, the wave timer and the income tick. No game
-- rule lives here: the rules live in the modules it wires.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("State"))
local Bases = require(script.Parent:WaitForChild("Bases"))
local Money = require(script.Parent:WaitForChild("Money"))
local Spawner = require(script.Parent:WaitForChild("Spawner"))
local Steal = require(script.Parent:WaitForChild("Steal"))
local Wave = require(script.Parent:WaitForChild("Wave"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameEvent = remotes:WaitForChild("GameEvent") :: RemoteEvent
local playerAction = remotes:WaitForChild("PlayerAction") :: RemoteEvent
local sellBrainrotFn = remotes:WaitForChild("SellBrainrot") :: RemoteFunction
local rebirthFn = remotes:WaitForChild("Rebirth") :: RemoteFunction
local lockBaseFn = remotes:WaitForChild("LockBase") :: RemoteFunction

-- The one remote every module pushes on: income, toasts, rebirths,
-- wave warnings. The client switches on the first argument.
Money.incomeRemote = gameEvent
Spawner.toastRemote = gameEvent
Steal.toastRemote = gameEvent
Wave.eventRemote = gameEvent

-- Stealing is wired here, not in Bases: Steal requires Bases, so the
-- wire runs one way only, through this script.
Bases.stealRequested = Steal.stealBrainrot

-- The client's RemoteFunctions: sell, rebirth, lock. Each returns
-- (ok, message) and the client shows the message as a toast.
sellBrainrotFn.OnServerInvoke = function(player: Player, slot: number)
	return Money.sellBrainrot(player, slot)
end
rebirthFn.OnServerInvoke = function(player: Player)
	return Money.rebirthPlayer(player)
end
lockBaseFn.OnServerInvoke = function(player: Player)
	local ok = Bases.lockBase(player)
	if ok then
		return true, "Base LOCKED for " .. tostring(Config.LOCK_DURATION) .. "s - no one can steal from you!"
	end
	return false, "Lock is cooling down (" .. tostring(math.floor(Bases.lockCooldownLeft(player))) .. "s left)"
end

-- The client's one RemoteEvent: F (or the SLAP button) slaps.
playerAction.OnServerEvent:Connect(function(player: Player, action: string)
	if action == "Slap" then
		Steal.slapThief(player)
	end
end)

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	end
end

-- Save one player's progress: cash, rebirths, and every brainrot on
-- their base. Silent on failure: Studio without API access, or a
-- throttled store, must never break the game.
local function savePlayer(player: Player)
	if store == nil then
		return
	end
	local state = GameState.get(player)
	if state == nil then
		return
	end
	local brainrots = {}
	for _, placed in pairs(state.placed) do
		table.insert(brainrots, { defId = placed.defId, mutation = placed.mutation })
	end
	local data = { cash = math.floor(state.cash), rebirths = state.rebirths, brainrots = brainrots }
	pcall(function()
		store:SetAsync(Config.dataKey(player.UserId), data)
	end)
end

-- Load a player's save, or start fresh. A corrupt save starts fresh
-- too: the game never refuses a player over saved data.
local function loadPlayer(player: Player): { cash: number, rebirths: number, brainrots: { { defId: string, mutation: string } } }
	local fresh = { cash = Config.START_CASH, rebirths = 0, brainrots = {} }
	if store == nil then
		return fresh
	end
	local ok, data = pcall(function()
		return store:GetAsync(Config.dataKey(player.UserId))
	end)
	if not ok or type(data) ~= "table" then
		return fresh
	end
	if type(data.cash) == "number" then
		fresh.cash = data.cash
	end
	if type(data.rebirths) == "number" then
		fresh.rebirths = data.rebirths
	end
	if type(data.brainrots) == "table" then
		fresh.brainrots = data.brainrots
	end
	return fresh
end

-- A player joins: state, save, plot, leaderstats, and their saved
-- brainrots back on the base.
local function onPlayerAdded(player: Player)
	local state = GameState.newPlayer()
	GameState.players[player] = state
	local save = loadPlayer(player)
	state.cash = save.cash
	state.rebirths = save.rebirths
	Money.createLeaderstats(player, state)
	Money.syncLeaderstats(state)
	local gotPlot = Bases.assignPlot(player)
	if gotPlot then
		for _, saved in ipairs(save.brainrots) do
			if Catalog.getById(saved.defId) ~= nil then
				Bases.placeBrainrotOnBase(player, saved.defId, saved.mutation or "Normal")
			end
		end
	else
		gameEvent:FireClient(player, "Toast", { message = "All 6 bases are taken - you are spectating until one frees up!" })
	end
end

-- A player leaves: drop what they carry, save, free the plot.
local function onPlayerRemoving(player: Player)
	Steal.dropStolen(player)
	savePlayer(player)
	local state = GameState.get(player)
	if state ~= nil then
		if state.plotIndex ~= 0 then
			Bases.clearBase(player)
			Bases.releasePlot(state.plotIndex)
		end
		GameState.players[player] = nil
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- The game's loops: income ticks every second, autosave every 90.
task.spawn(function()
	while true do
		task.wait(1)
		Money.tickIncome()
	end
end)
task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayer(player)
		end
	end
end)

-- Start the belt, the steal loop and the wave timer.
Spawner.start()
Steal.start()
Wave.start()
