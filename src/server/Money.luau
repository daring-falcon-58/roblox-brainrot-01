-- Money: cash, income and rebirths.
-- One job: the economy. It owns leaderstats, adds the money a base
-- earns every second, sells brainrots back, and rebirths a player.
-- It never places or removes brainrots itself: Bases does that.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("State"))
local Bases = require(script.Parent:WaitForChild("Bases"))

local Money = {}

-- The remote the server pushes income updates on. Main creates it
-- and hands it here; Money never creates remotes of its own.
Money.incomeRemote = nil :: RemoteEvent?

-- Build a player's leaderstats: Cash, income per second, rebirths.
function Money.createLeaderstats(player: Player, state: GameState.PlayerState)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = state.cash
	cash.Parent = folder
	local income = Instance.new("IntValue")
	income.Name = "Income"
	income.Value = 0
	income.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = state.rebirths
	rebirths.Parent = folder
	folder.Parent = player
	state.leaderstats = folder
end

-- Push the leaderstats values after any change, so the board and the
-- HUD always read the same numbers the server holds.
function Money.syncLeaderstats(state: GameState.PlayerState)
	if state.leaderstats == nil then
		return
	end
	local cash = state.leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		cash.Value = math.floor(state.cash)
	end
	local income = state.leaderstats:FindFirstChild("Income")
	if income and income:IsA("IntValue") then
		income.Value = math.floor(Money.incomePerSecond(state))
	end
	local rebirths = state.leaderstats:FindFirstChild("Rebirths")
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = state.rebirths
	end
end

-- Add cash. Amount may be fractional; the board shows whole dollars.
function Money.addCash(state: GameState.PlayerState, amount: number)
	state.cash += amount
	Money.syncLeaderstats(state)
end

-- Spend cash when the player can afford it. Returns false without
-- spending anything when the player is short.
function Money.spendCash(state: GameState.PlayerState, amount: number): boolean
	if state.cash < amount then
		return false
	end
	state.cash -= amount
	Money.syncLeaderstats(state)
	return true
end

-- What this player's base earns a second: every placed brainrot's
-- rate, after its mutation, times the rebirth multiplier.
function Money.incomePerSecond(state: GameState.PlayerState): number
	local total = 0
	for _, placed in pairs(state.placed) do
		local def = Catalog.getById(placed.defId)
		if def ~= nil then
			total += Catalog.incomePerSecond(def, placed.mutation)
		end
	end
	return total * Config.incomeMultiplier(state.rebirths)
end

-- Tick the whole economy one second: every player's base pays out,
-- and each player hears their new cash and income on the remote.
-- Main calls this once a second; it is the money ticking at its rate.
function Money.tickIncome()
	for player, state in pairs(GameState.players) do
		local income = Money.incomePerSecond(state)
		if income > 0 then
			state.cash += income
			Money.syncLeaderstats(state)
		end
		if Money.incomeRemote ~= nil then
			Money.incomeRemote:FireClient(player, "Income", {
				cash = math.floor(state.cash),
				income = math.floor(income),
				rebirths = state.rebirths,
			})
		end
	end
end

-- Sell a placed brainrot back for half its price. The brainrot leaves
-- the base and the player keeps the refund.
function Money.sellBrainrot(player: Player, slot: number): (boolean, string)
	local state = GameState.get(player)
	if state == nil then
		return false, "No state"
	end
	local placed = state.placed[slot]
	if placed == nil then
		return false, "That slot is empty"
	end
	local def = Catalog.getById(placed.defId)
	if def == nil then
		return false, "Unknown brainrot"
	end
	local refund = math.floor(def.cost * Config.SELL_REFUND)
	Bases.removeBrainrotFromBase(player, slot)
	Money.addCash(state, refund)
	return true, "Sold " .. def.name .. " for " .. Config.formatMoney(refund)
end

-- Rebirth a player: pay the rebirth cost, lose all cash and every
-- brainrot on the base, and gain a permanent +1 income multiplier.
-- The cost grows tenfold each rebirth, so the next tier is always a
-- climb, never a gift.
function Money.rebirthPlayer(player: Player): (boolean, string)
	local state = GameState.get(player)
	if state == nil then
		return false, "No state"
	end
	local cost = Config.rebirthCost(state.rebirths)
	if state.cash < cost then
		return false, "Rebirth costs " .. Config.formatMoney(cost)
	end
	state.cash = Config.START_CASH
	state.rebirths += 1
	Bases.clearBase(player)
	Money.syncLeaderstats(state)
	if Money.incomeRemote ~= nil then
		Money.incomeRemote:FireClient(player, "Rebirth", {
			rebirths = state.rebirths,
			multiplier = Config.incomeMultiplier(state.rebirths),
		})
	end
	return true, "REBIRTH! Income is now x" .. tostring(Config.incomeMultiplier(state.rebirths)) .. " forever"
end

return Money
