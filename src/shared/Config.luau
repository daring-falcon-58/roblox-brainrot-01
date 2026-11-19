-- GameConfig: every number the game tunes by, in one place.
-- One job: tuning. No other script hard-codes a price, a timer or a
-- position: they all read it here, so a balance change is one edit.

local Config = {}

-- A new player starts with this much cash.
Config.START_CASH = 100

-- The bazaar has six base plots, three on each side of the conveyor.
-- Plot i is claimed by the i-th player to join, in join order.
Config.PLOT_COUNT = 6
Config.SLOTS_PER_BASE = 8

-- Plot centres: x across the map, z north (-30) or south (+30).
Config.PLOTS = {
	{ x = -58, z = -30 },
	{ x = 0, z = -30 },
	{ x = 58, z = -30 },
	{ x = -58, z = 30 },
	{ x = 0, z = 30 },
	{ x = 58, z = 30 },
}
-- Half-size of one plot pad, for "is this player home" checks.
Config.PLOT_HALF = { x = 13, z = 11 }

-- Slot offsets inside a plot, 2 rows of 4, relative to the plot centre.
Config.SLOT_OFFSETS = {
	{ x = -9, z = -5 },
	{ x = -3, z = -5 },
	{ x = 3, z = -5 },
	{ x = 9, z = -5 },
	{ x = -9, z = 5 },
	{ x = -3, z = 5 },
	{ x = 3, z = 5 },
	{ x = 9, z = 5 },
}

-- The conveyor: brainrots walk from the Snack Dock (west) to the exit
-- (east) along z = 0. A brainrot that reaches the end without being
-- bought walks off and despawns.
Config.CONVEYOR_START = Vector3.new(-80, 1.0, 0)
Config.CONVEYOR_END = Vector3.new(80, 1.0, 0)
Config.CONVEYOR_SPEED = 4 -- studs per second
Config.SPAWN_INTERVAL = 6 -- seconds between spawns
Config.MAX_ON_BELT = 8

-- Selling a brainrot refunds half its price.
Config.SELL_REFUND = 0.5

-- Rebirth: reset cash and brainrots for a permanent income multiplier.
-- The n-th rebirth (n starting at 1) costs this much cash.
Config.rebirthCost = function(rebirths: number): number
	return 10000 * (10 ^ rebirths)
end
-- Income multiplier after n rebirths: x1, x2, x3, ...
Config.incomeMultiplier = function(rebirths: number): number
	return 1 + rebirths
end

-- Base lock: the owner locks their base for this long; stealing from
-- a locked base is refused. The lock then cools down before it can
-- be used again.
Config.LOCK_DURATION = 60
Config.LOCK_COOLDOWN = 120

-- Stealing: hold the prompt this long to lift a brainrot, then carry
-- it home. A slap knocks the thief down and drops the catch.
Config.STEAL_HOLD_SECONDS = 3
Config.SLAP_RANGE = 10
Config.SLAP_COOLDOWN = 5
Config.SLAP_KNOCKBACK = 55 -- studs per second of launch speed

-- The tsunami: first wave this far into the game, then one every
-- interval. The warning runs first; the sweep then crosses the map.
Config.FIRST_WAVE_AT = 150
Config.WAVE_INTERVAL = 180
Config.WAVE_WARNING_SECONDS = 10
Config.WAVE_SWEEP_SECONDS = 8
Config.WAVE_CASH_LOSS = 0.10 -- caught outside your base: lose 10% of cash

-- How often the server saves a player's data, and the DataStore key.
Config.AUTOSAVE_INTERVAL = 90
Config.DATASTORE_NAME = "BrainrotBazaar_v1"
Config.dataKey = function(userId: number): string
	return "player_" .. tostring(userId)
end

-- Money formatting: $1,284 and $47/s, with commas.
function Config.formatMoney(amount: number): string
	local n = math.floor(amount + 0.5)
	local s = tostring(n)
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return "$" .. s .. out
end

return Config
