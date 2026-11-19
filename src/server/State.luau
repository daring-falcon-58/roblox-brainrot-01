-- GameState: the game's one source of truth, server-side only.
-- One job: hold every player's state in a single table. The client
-- never requires this module and never sees it: the server reads and
-- writes it, and only pushes summaries to the client through remotes.
-- A placed brainrot is { defId, mutation, model, slot }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GameState = {}

export type PlacedBrainrot = {
	defId: string,
	mutation: string,
	model: Model?,
	slot: number,
}

export type PlayerState = {
	cash: number,
	rebirths: number,
	plotIndex: number,
	placed: { [number]: PlacedBrainrot },
	lockedUntil: number,
	lockReadyAt: number,
	lastSlapAt: number,
	carrying: PlacedBrainrot?,
	carryingFrom: Player?,
	leaderstats: Folder?,
}

-- Every connected player's state, keyed by the Player instance.
GameState.players = {} :: { [Player]: PlayerState }

-- A fresh player: starting cash, no rebirths, no plot yet, empty base.
function GameState.newPlayer(): PlayerState
	return {
		cash = 0,
		rebirths = 0,
		plotIndex = 0,
		placed = {},
		lockedUntil = 0,
		lockReadyAt = 0,
		lastSlapAt = 0,
		carrying = nil,
		carryingFrom = nil,
		leaderstats = nil,
	}
end

-- The state for a player, or nil when they have none (left already).
function GameState.get(player: Player): PlayerState?
	return GameState.players[player]
end

-- How many brainrots sit on this player's base right now.
function GameState.placedCount(state: PlayerState): number
	local n = 0
	for _ in pairs(state.placed) do
		n += 1
	end
	return n
end

-- The first free slot number on this player's base, or nil when full.
function GameState.firstFreeSlot(state: PlayerState): number?
	for slot = 1, Config.SLOTS_PER_BASE do
		if state.placed[slot] == nil then
			return slot
		end
	end
	return nil
end

return GameState
