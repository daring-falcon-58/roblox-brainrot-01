-- StealSystem: stealing brainrots, and slapping thieves.
-- One job: the threat. A player lifts a brainrot off someone else's
-- base, carries it home, and keeps it only if they reach their own
-- base. A slap knocks the thief down and sends the catch home.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("State"))
local Bases = require(script.Parent:WaitForChild("Bases"))

local Steal = {}

-- The remote the server pushes toasts on. Main hands it here.
Steal.toastRemote = nil :: RemoteEvent?

local function toast(player: Player, message: string)
	if Steal.toastRemote ~= nil then
		Steal.toastRemote:FireClient(player, "Toast", { message = message })
	end
end

-- Send a stolen brainrot back to its owner's base: rebuild it on a
-- free slot there (or lose it, when the owner's base filled up).
local function returnToOwner(owner: Player, defId: string, mutation: string)
	local ownerState = GameState.get(owner)
	if ownerState == nil then
		return
	end
	local def = Catalog.getById(defId)
	local slot = Bases.placeBrainrotOnBase(owner, defId, mutation)
	if slot ~= nil and def ~= nil then
		toast(owner, def.name .. " is back on your base!")
	end
end

-- Drop what a player is carrying: the catch goes home to its owner.
-- Called when the thief is slapped, when the wave catches them, and
-- when they leave the game mid-carry.
function Steal.dropStolen(player: Player)
	local state = GameState.get(player)
	if state == nil or state.carrying == nil then
		return
	end
	local carried = state.carrying
	local from = state.carryingFrom
	if carried.model ~= nil then
		carried.model:Destroy()
	end
	state.carrying = nil
	state.carryingFrom = nil
	if from ~= nil then
		returnToOwner(from, carried.defId, carried.mutation)
	end
end

-- Lift a brainrot off someone else's base and carry it home. The
-- prompt's 3-second hold already ran: this is the moment it is taken.
-- Every refusal explains itself, and a locked base cannot be stolen
-- from at all.
function Steal.stealBrainrot(thief: Player, owner: Player, slot: number)
	local thiefState = GameState.get(thief)
	local ownerState = GameState.get(owner)
	if thiefState == nil or ownerState == nil then
		return
	end
	if thief == owner then
		return
	end
	if thiefState.carrying ~= nil then
		toast(thief, "You are already carrying a brainrot!")
		return
	end
	if thiefState.plotIndex == 0 then
		toast(thief, "You have no base to carry it to!")
		return
	end
	if GameState.firstFreeSlot(thiefState) == nil then
		toast(thief, "Your base is full - sell something first!")
		return
	end
	if Bases.isBaseLocked(owner) then
		toast(thief, owner.Name .. "'s base is LOCKED!")
		return
	end
	local placed = ownerState.placed[slot]
	if placed == nil or placed.model == nil then
		return
	end
	-- Take it off the owner's base and carry it above the thief's head.
	ownerState.placed[slot] = nil
	local model = placed.model
	local prompt = model.PrimaryPart:FindFirstChild("StealPrompt")
	if prompt then
		prompt.Enabled = false
	end
	thiefState.carrying = { defId = placed.defId, mutation = placed.mutation, model = model, slot = 0 }
	thiefState.carryingFrom = owner
	local def = Catalog.getById(placed.defId)
	if def ~= nil then
		toast(thief, "You stole " .. def.name .. "! RUN to your base!")
		toast(owner, thief.Name .. " stole your " .. def.name .. "! SLAP them (press F)!")
	end
end

-- Deliver a carried brainrot: the thief reached their own base, so
-- the catch is placed on their first free slot and is theirs now.
local function deliverCarried(player: Player)
	local state = GameState.get(player)
	if state == nil or state.carrying == nil then
		return
	end
	local carried = state.carrying
	if carried.model ~= nil then
		carried.model:Destroy()
	end
	state.carrying = nil
	state.carryingFrom = nil
	local slot = Bases.placeBrainrotOnBase(player, carried.defId, carried.mutation)
	local def = Catalog.getById(carried.defId)
	if slot ~= nil and def ~= nil then
		toast(player, "You kept " .. def.name .. "! It earns $" .. tostring(Catalog.incomePerSecond(def, carried.mutation)) .. "/s now.")
	else
		toast(player, "No free slot - the brainrot got away!")
	end
end

-- Slap the nearest player in range: knock them flying, and if they
-- were carrying a stolen brainrot, the catch goes back to its owner.
-- The owner's own slap is the defence the lock buys time for.
function Steal.slapThief(player: Player)
	local state = GameState.get(player)
	if state == nil then
		return
	end
	local now = os.clock()
	if now - state.lastSlapAt < Config.SLAP_COOLDOWN then
		return
	end
	state.lastSlapAt = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end
	local nearest: Player? = nil
	local nearestDistance = Config.SLAP_RANGE
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherCharacter = other.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if otherRoot ~= nil then
				local distance = (otherRoot.Position - root.Position).Magnitude
				if distance <= nearestDistance then
					nearest = other
					nearestDistance = distance
				end
			end
		end
	end
	if nearest == nil then
		return
	end
	local victim = nearest :: Player
	local victimCharacter = victim.Character
	local victimRoot = victimCharacter and victimCharacter:FindFirstChild("HumanoidRootPart")
	local victimHumanoid = victimCharacter and victimCharacter:FindFirstChildOfClass("Humanoid")
	if victimRoot == nil or victimHumanoid == nil then
		return
	end
	local direction = (victimRoot.Position - root.Position)
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, 1)
	end
	direction = direction.Unit
	victimRoot.AssemblyLinearVelocity = direction * Config.SLAP_KNOCKBACK + Vector3.new(0, 30, 0)
	victimHumanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	local victimState = GameState.get(victim)
	if victimState ~= nil and victimState.carrying ~= nil then
		toast(player, "SLAP! " .. victim.Name .. " dropped the brainrot!")
		Steal.dropStolen(victim)
	else
		toast(player, "SLAP! " .. victim.Name .. " went flying!")
	end
end

-- Every heartbeat: carry the stolen brainrot above its thief's head,
-- and deliver it the moment the thief stands on their own base.
function Steal.start()
	RunService.Heartbeat:Connect(function()
		for player, state in pairs(GameState.players) do
			if state.carrying ~= nil and state.carrying.model ~= nil then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root == nil then
					Steal.dropStolen(player)
					continue
				end
				state.carrying.model:SetPrimaryPartCFrame(
					CFrame.new(root.Position + Vector3.new(0, 5, 0))
				)
				if state.plotIndex ~= 0 and Bases.isInsidePlot(state.plotIndex, root.Position) then
					deliverCarried(player)
				end
			end
		end
	end)
end

return Steal
