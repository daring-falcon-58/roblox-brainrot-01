-- WaveEvent: the tsunami that sweeps the bazaar.
-- One job: the hazard. Every few minutes a wave crosses the map:
-- a warning first, then the wall of water. Anyone caught outside
-- their own base is flung back to spawn and loses 10% of their cash,
-- and every brainrot on the conveyor is washed away. The dash home
-- with a catch is the game's tensest moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("State"))
local Bases = require(script.Parent:WaitForChild("Bases"))
local Money = require(script.Parent:WaitForChild("Money"))
local Steal = require(script.Parent:WaitForChild("Steal"))

local Wave = {}

-- The remote the server pushes wave warnings on. Main hands it here.
Wave.eventRemote = nil :: RemoteEvent?

local function broadcast(kind: string, data: any)
	if Wave.eventRemote ~= nil then
		Wave.eventRemote:FireAllClients(kind, data)
	end
end

-- The spawn point, where caught players are flung back to.
local SPAWN_POINT = Vector3.new(-95, 3, 0)

-- Catch one player in the wave: drop what they carry, fling them to
-- spawn, and take 10% of their cash. Once per wave per player.
local function catchPlayer(player: Player, hit: { [Player]: boolean })
	if hit[player] then
		return
	end
	hit[player] = true
	local state = GameState.get(player)
	if state == nil then
		return
	end
	Steal.dropStolen(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root ~= nil then
		root.AssemblyLinearVelocity = Vector3.new(-60, 40, 0)
		character:SetPrimaryPartCFrame(CFrame.new(SPAWN_POINT))
	end
	local loss = math.floor(state.cash * Config.WAVE_CASH_LOSS)
	if loss > 0 then
		Money.addCash(state, -loss)
	end
	if Wave.eventRemote ~= nil then
		Wave.eventRemote:FireClient(player, "Toast", {
			message = "The wave caught you! Lost " .. Config.formatMoney(loss) .. " - run home next time!",
		})
	end
end

-- One wave: warn, sweep the wall across the map, catch stragglers,
-- and wash the conveyor clean. The wall is a part the world shows;
-- the catches are positional, so no one is hit by luck alone.
local function runWave()
	broadcast("WaveWarning", { seconds = Config.WAVE_WARNING_SECONDS })
	task.wait(Config.WAVE_WARNING_SECONDS)
	broadcast("WaveStart", {})

	local wall = Instance.new("Part")
	wall.Name = "TsunamiWall"
	wall.Size = Vector3.new(10, 50, 260)
	wall.Position = Vector3.new(-130, 25, 0)
	wall.Color = Color3.fromRGB(40, 120, 220)
	wall.Material = Enum.Material.Glass
	wall.Transparency = 0.35
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanTouch = false
	wall.Parent = Workspace

	-- Wash the conveyor: every brainrot on the belt is swept away.
	local beltFolder = Workspace:FindFirstChild("Belt")
	if beltFolder then
		for _, model in ipairs(beltFolder:GetChildren()) do
			model:Destroy()
		end
	end

	local hit = {} :: { [Player]: boolean }
	local steps = 40
	for i = 1, steps do
		local t = i / steps
		wall.Position = Vector3.new(-130 + 260 * t, 25, 0)
		for _, player in ipairs(Players:GetPlayers()) do
			local state = GameState.get(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if state ~= nil and root ~= nil then
				local home = state.plotIndex ~= 0 and Bases.isInsidePlot(state.plotIndex, root.Position)
				-- Caught when the wall has passed the player and they
				-- are not standing on their own base.
				if not home and root.Position.X < wall.Position.X + 5 then
					catchPlayer(player, hit)
				end
			end
		end
		task.wait(Config.WAVE_SWEEP_SECONDS / steps)
	end

	wall:Destroy()
	broadcast("WaveEnd", {})
end

-- Start the wave timer: the first wave a couple of minutes in, then
-- one every few minutes for the rest of the game.
function Wave.start()
	task.spawn(function()
		task.wait(Config.FIRST_WAVE_AT)
		while true do
			runWave()
			task.wait(Config.WAVE_INTERVAL)
		end
	end)
end

return Wave
