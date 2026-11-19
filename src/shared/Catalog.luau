-- BrainrotCatalog: the cast of Brainrot Bazaar.
-- One job: the roster. Every brainrot the game can spawn, its rarity,
-- its money-a-second, its price, its look and its joke. The spawner,
-- the shop HUD and the screenshot renderer all read this one table,
-- so a brainrot on screen is always a brainrot the code knows.
-- Names are the game's own inventions: snack-creatures with titles.

local Catalog = {}

export type RarityName = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type BrainrotDef = {
	id: string,
	name: string,
	rarity: RarityName,
	income: number, -- dollars per second on a base, before mutations and rebirths
	cost: number, -- dollars to buy it off the conveyor
	color: Color3,
	shape: string, -- "round" | "tall" | "flat" | "cone": the body the spawner builds
	accessory: string, -- "crown" | "hat" | "glasses" | "cape" | "none"
	joke: string, -- one line the shop shows under the name
}

-- Rarity ladder, cheapest first. The shop's "next tier" is the first
-- entry here the player cannot afford yet.
Catalog.RARITIES = {
	{ name = "Common", weight = 40, color = Color3.fromRGB(200, 200, 200) },
	{ name = "Rare", weight = 28, color = Color3.fromRGB(80, 160, 255) },
	{ name = "Epic", weight = 16, color = Color3.fromRGB(180, 90, 255) },
	{ name = "Legendary", weight = 9, color = Color3.fromRGB(255, 170, 0) },
	{ name = "Mythic", weight = 5, color = Color3.fromRGB(255, 70, 90) },
	{ name = "Secret", weight = 2, color = Color3.fromRGB(0, 230, 200) },
}

-- Mutations multiply a brainrot's income. Rolled when it spawns.
Catalog.MUTATIONS = {
	{ name = "Normal", weight = 86, multiplier = 1, color = Color3.fromRGB(255, 255, 255) },
	{ name = "Golden", weight = 10, multiplier = 2, color = Color3.fromRGB(255, 215, 0) },
	{ name = "Diamond", weight = 3, multiplier = 5, color = Color3.fromRGB(120, 220, 255) },
	{ name = "Rainbow", weight = 1, multiplier = 10, color = Color3.fromRGB(255, 120, 220) },
}

Catalog.BRAINROTS = {
	{
		id = "picklefoot",
		name = "Sir Picklefoot",
		rarity = "Common",
		income = 1,
		cost = 25,
		color = Color3.fromRGB(110, 190, 60),
		shape = "tall",
		accessory = "hat",
		joke = "A pickle with legs. He walks. That is the whole joke.",
	},
	{
		id = "noodlebeard",
		name = "Captain Noodlebeard",
		rarity = "Common",
		income = 2,
		cost = 60,
		color = Color3.fromRGB(240, 200, 90),
		shape = "tall",
		accessory = "hat",
		joke = "Sailed seven seas of broth. Never found the fork.",
	},
	{
		id = "croissant",
		name = "Madame Croissant",
		rarity = "Rare",
		income = 5,
		cost = 150,
		color = Color3.fromRGB(220, 170, 90),
		shape = "flat",
		accessory = "glasses",
		joke = "Flaky, French, and faintly judging you.",
	},
	{
		id = "wobble",
		name = "Baron Von Wobble",
		rarity = "Rare",
		income = 8,
		cost = 300,
		color = Color3.fromRGB(255, 130, 170),
		shape = "round",
		accessory = "cape",
		joke = "A jelly baron. Wobbles into rooms uninvited.",
	},
	{
		id = "bananas",
		name = "Professor Bananas",
		rarity = "Epic",
		income = 15,
		cost = 650,
		color = Color3.fromRGB(250, 225, 60),
		shape = "tall",
		accessory = "glasses",
		joke = "Holds three peel-HDs in potassium studies.",
	},
	{
		id = "dumpling",
		name = "Duke Dumpling",
		rarity = "Epic",
		income = 22,
		cost = 1100,
		color = Color3.fromRGB(245, 235, 200),
		shape = "round",
		accessory = "cape",
		joke = "Steamed, stuffed, and second in line to the throne.",
	},
	{
		id = "gherkin",
		name = "General Gherkin",
		rarity = "Legendary",
		income = 40,
		cost = 2600,
		color = Color3.fromRGB(60, 160, 60),
		shape = "tall",
		accessory = "hat",
		joke = "Commands the brine brigade. Never blinks. Pickles can't.",
	},
	{
		id = "quokka",
		name = "Queen Quokka",
		rarity = "Legendary",
		income = 65,
		cost = 5200,
		color = Color3.fromRGB(170, 120, 70),
		shape = "round",
		accessory = "crown",
		joke = "The happiest monarch alive. Smiles at tax collectors.",
	},
	{
		id = "lox",
		name = "Lord Lox",
		rarity = "Mythic",
		income = 120,
		cost = 12000,
		color = Color3.fromRGB(255, 140, 90),
		shape = "flat",
		accessory = "crown",
		joke = "A salmon lord. Smoked, cured, and born to brunch.",
	},
	{
		id = "toaster",
		name = "The Grand Toaster",
		rarity = "Mythic",
		income = 200,
		cost = 26000,
		color = Color3.fromRGB(160, 160, 170),
		shape = "tall",
		accessory = "crown",
		joke = "Pops up when least expected. Always slightly burnt.",
	},
	{
		id = "eggroll",
		name = "Emperor Eggroll",
		rarity = "Secret",
		income = 400,
		cost = 65000,
		color = Color3.fromRGB(230, 180, 40),
		shape = "tall",
		accessory = "crown",
		joke = "Ruler of the crispy empire. Crunch is law.",
	},
	{
		id = "samosa",
		name = "Sultan Samosa",
		rarity = "Secret",
		income = 750,
		cost = 160000,
		color = Color3.fromRGB(200, 130, 30),
		shape = "cone",
		accessory = "crown",
		joke = "A triangular titan of spice. Bow before the crunch.",
	},
}

-- Look a brainrot up by id. Returns nil for an unknown id.
function Catalog.getById(id: string): BrainrotDef?
	for _, def in ipairs(Catalog.BRAINROTS) do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- The rarity table entry for a rarity name.
function Catalog.rarityInfo(rarity: RarityName)
	for _, entry in ipairs(Catalog.RARITIES) do
		if entry.name == rarity then
			return entry
		end
	end
	return Catalog.RARITIES[1]
end

-- The mutation table entry for a mutation name.
function Catalog.mutationInfo(name: string)
	for _, entry in ipairs(Catalog.MUTATIONS) do
		if entry.name == name then
			return entry
		end
	end
	return Catalog.MUTATIONS[1]
end

-- Roll a rarity by weight. Common is frequent, Secret is a 2-in-100 pull.
function Catalog.rollRarity(): RarityName
	local total = 0
	for _, entry in ipairs(Catalog.RARITIES) do
		total += entry.weight
	end
	local roll = math.random(1, total)
	local running = 0
	for _, entry in ipairs(Catalog.RARITIES) do
		running += entry.weight
		if roll <= running then
			return entry.name
		end
	end
	return "Common"
end

-- Roll a mutation by weight. Rainbow is a 1-in-100 pull.
function Catalog.rollMutation(): string
	local total = 0
	for _, entry in ipairs(Catalog.MUTATIONS) do
		total += entry.weight
	end
	local roll = math.random(1, total)
	local running = 0
	for _, entry in ipairs(Catalog.MUTATIONS) do
		running += entry.weight
		if roll <= running then
			return entry.name
		end
	end
	return "Normal"
end

-- Roll one brainrot to spawn: a random def of a rolled rarity.
function Catalog.rollBrainrot(): BrainrotDef
	local rarity = Catalog.rollRarity()
	local pool = {}
	for _, def in ipairs(Catalog.BRAINROTS) do
		if def.rarity == rarity then
			table.insert(pool, def)
		end
	end
	return pool[math.random(1, #pool)]
end

-- A brainrot's money-a-second after its mutation (before rebirths).
function Catalog.incomePerSecond(def: BrainrotDef, mutation: string): number
	return def.income * Catalog.mutationInfo(mutation).multiplier
end

-- The next tier the player cannot afford yet: the cheapest brainrot
-- whose cost is above the player's cash. Nil when the player can
-- afford the whole cast.
function Catalog.nextTier(cash: number): BrainrotDef?
	local best: BrainrotDef? = nil
	for _, def in ipairs(Catalog.BRAINROTS) do
		if def.cost > cash and (best == nil or def.cost < best.cost) then
			best = def
		end
	end
	return best
end

return Catalog
