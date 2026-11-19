-- BrainrotBuilder: builds a brainrot character out of parts.
-- One job: turn a catalog entry into a Model the world can show.
-- The spawner builds belt brainrots with it, the base manager builds
-- placed ones with it, and the labels it writes are the same ones the
-- screenshots show: name, rarity colour, money-a-second.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

local Builder = {}

-- A small part, anchored, smooth plastic, parented to the model.
local function addPart(model: Model, name: string, class: string, size: Vector3, offset: Vector3, color: Color3): BasePart
	local part = Instance.new(class)
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Parent = model
	return part
end

-- The accessory on top: a crown, a hat, glasses or a cape.
local function addAccessory(model: Model, accessory: string, topY: number)
	if accessory == "crown" then
		addPart(model, "Crown", "Part", Vector3.new(1.6, 0.5, 1.6), Vector3.new(0, topY + 0.25, 0), Color3.fromRGB(255, 215, 0))
		for _, dx in ipairs({ -0.55, 0, 0.55 }) do
			addPart(model, "CrownSpike", "Part", Vector3.new(0.3, 0.5, 0.3), Vector3.new(dx, topY + 0.7, 0), Color3.fromRGB(255, 215, 0))
		end
	elseif accessory == "hat" then
		addPart(model, "HatBrim", "Part", Vector3.new(2.6, 0.25, 2.6), Vector3.new(0, topY + 0.1, 0), Color3.fromRGB(120, 70, 20))
		addPart(model, "HatTop", "Part", Vector3.new(1.4, 1.0, 1.4), Vector3.new(0, topY + 0.7, 0), Color3.fromRGB(120, 70, 20))
	elseif accessory == "glasses" then
		addPart(model, "LensL", "Part", Vector3.new(0.7, 0.7, 0.2), Vector3.new(-0.6, topY - 0.6, 1.15), Color3.fromRGB(20, 20, 20))
		addPart(model, "LensR", "Part", Vector3.new(0.7, 0.7, 0.2), Vector3.new(0.6, topY - 0.6, 1.15), Color3.fromRGB(20, 20, 20))
		addPart(model, "Bridge", "Part", Vector3.new(0.6, 0.15, 0.15), Vector3.new(0, topY - 0.6, 1.15), Color3.fromRGB(20, 20, 20))
	elseif accessory == "cape" then
		addPart(model, "Cape", "Part", Vector3.new(2.2, 2.6, 0.25), Vector3.new(0, topY - 1.6, -1.2), Color3.fromRGB(200, 30, 50))
	end
end

-- Build the Model for one brainrot. The model's PrimaryPart is its
-- body, so callers move it with SetPrimaryPartCFrame. The label above
-- it reads name, rarity and money-a-second, in the rarity's colour.
function Builder.buildBrainrotModel(def: Catalog.BrainrotDef, mutation: string): Model
	local model = Instance.new("Model")
	model.Name = def.name

	local body: BasePart
	local topY = 1.8
	if def.shape == "round" then
		body = addPart(model, "Body", "Part", Vector3.new(3, 3, 3), Vector3.new(0, 1.5, 0), def.color)
		body.Shape = Enum.PartType.Ball
		topY = 3.0
	elseif def.shape == "flat" then
		body = addPart(model, "Body", "Part", Vector3.new(3.6, 1.8, 3), Vector3.new(0, 0.9, 0), def.color)
		topY = 1.8
	elseif def.shape == "cone" then
		body = addPart(model, "Body", "WedgePart", Vector3.new(3, 3.6, 3), Vector3.new(0, 1.8, 0), def.color)
		topY = 3.6
	else -- "tall"
		body = addPart(model, "Body", "Part", Vector3.new(2.4, 3.6, 2.4), Vector3.new(0, 1.8, 0), def.color)
		topY = 3.6
	end
	model.PrimaryPart = body

	-- Two eyes on the front face, so the creature reads as alive.
	local eyeZ = 1.25
	if def.shape == "round" then
		eyeZ = 1.45
	elseif def.shape == "flat" then
		eyeZ = 1.55
	end
	addPart(model, "EyeL", "Part", Vector3.new(0.4, 0.5, 0.2), Vector3.new(-0.55, 1.9, eyeZ), Color3.fromRGB(20, 20, 20)).Shape = Enum.PartType.Ball
	addPart(model, "EyeR", "Part", Vector3.new(0.4, 0.5, 0.2), Vector3.new(0.55, 1.9, eyeZ), Color3.fromRGB(20, 20, 20)).Shape = Enum.PartType.Ball
	-- A grin: a thin dark bar under the eyes.
	addPart(model, "Grin", "Part", Vector3.new(1.1, 0.18, 0.15), Vector3.new(0, 1.25, eyeZ), Color3.fromRGB(20, 20, 20))

	addAccessory(model, def.accessory, topY)

	-- The floating label: name on top, rarity and $/s below it.
	local mutationInfo = Catalog.mutationInfo(mutation)
	local income = Catalog.incomePerSecond(def, mutation)
	local rarityColor = Catalog.rarityInfo(def.rarity).color
	local labelText = def.name
	if mutation ~= "Normal" then
		labelText = mutation .. " " .. def.name
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(140, 52)
	billboard.StudsOffset = Vector3.new(0, topY + 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = labelText
	nameLabel.TextColor3 = mutationInfo.color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Parent = billboard

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Position = UDim2.new(0, 0, 0.55, 0)
	rateLabel.Size = UDim2.new(1, 0, 0.45, 0)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = def.rarity .. "  $" .. tostring(income) .. "/s"
	rateLabel.TextColor3 = rarityColor
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.TextStrokeTransparency = 0.2
	rateLabel.Parent = billboard

	return model
end

return Builder
