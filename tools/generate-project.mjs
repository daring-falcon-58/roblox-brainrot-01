// generate-project.mjs — builds the Rojo project for Brainrot Bazaar.
// One job: turn the game's own data into default.project.json.
// It reads the roster out of src/shared/Catalog.luau and the plot
// layout out of src/shared/Config.luau (single source of truth: the
// Luau files the game runs), then lays out the 3D world — island,
// conveyor, six base plots, decor, signs and sample brainrots — and
// writes tools/world-manifest.json beside it, the same world in a
// form the screenshot renderer reads. Run it, then `rojo build`.
//   node tools/generate-project.mjs

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");

const catalogSrc = readFileSync(join(root, "src/shared/Catalog.luau"), "utf8");
const configSrc = readFileSync(join(root, "src/shared/Config.luau"), "utf8");

// --- Parse the roster out of Catalog.luau ---------------------------------
// Each def is one {...} block with id, name, rarity, income, cost,
// color = Color3.fromRGB(r, g, b), shape and accessory lines.
function parseCatalog(src) {
	const defs = [];
	const blockRe = /\{\s*id = "([^"]+)",\s*name = "([^"]+)",\s*rarity = "([^"]+)",\s*income = (\d+),\s*cost = (\d+),\s*color = Color3\.fromRGB\((\d+), (\d+), (\d+)\),\s*shape = "([^"]+)",\s*accessory = "([^"]+)"/g;
	let m;
	while ((m = blockRe.exec(src)) !== null) {
		defs.push({
			id: m[1], name: m[2], rarity: m[3],
			income: Number(m[4]), cost: Number(m[5]),
			color: [Number(m[6]), Number(m[7]), Number(m[8])],
			shape: m[9], accessory: m[10],
		});
	}
	return defs;
}

function parsePlots(src) {
	const plots = [];
	const section = src.split("Config.PLOTS = {")[1].split("\n}")[0];
	const re = /\{\s*x = (-?\d+),\s*z = (-?\d+)\s*\}/g;
	let m;
	while ((m = re.exec(section)) !== null) {
		plots.push({ x: Number(m[1]), z: Number(m[2]) });
	}
	return plots;
}

function parseSlotOffsets(src) {
	const offsets = [];
	const section = src.split("Config.SLOT_OFFSETS = {")[1].split("\n}")[0];
	const re = /\{\s*x = (-?\d+),\s*z = (-?\d+)\s*\}/g;
	let m;
	while ((m = re.exec(section)) !== null) {
		offsets.push({ x: Number(m[1]), z: Number(m[2]) });
	}
	return offsets;
}

const BRAINROTS = parseCatalog(catalogSrc);
const PLOTS = parsePlots(configSrc);
const SLOT_OFFSETS = parseSlotOffsets(configSrc);
if (BRAINROTS.length !== 12) throw new Error(`expected 12 brainrots, parsed ${BRAINROTS.length}`);
if (PLOTS.length !== 6) throw new Error(`expected 6 plots, parsed ${PLOTS.length}`);
if (SLOT_OFFSETS.length !== 8) throw new Error(`expected 8 slots, parsed ${SLOT_OFFSETS.length}`);

const byId = Object.fromEntries(BRAINROTS.map((d) => [d.id, d]));

// Rojo's UDim2 is explicit-only: {"UDim2": [[scaleX, offsetX], [scaleY, offsetY]]}.
const fullSize = { UDim2: [[1, 0], [1, 0]] };
const rgb = (r, g, b) => [r / 255, g / 255, b / 255];
const part = (name, pos, size, color, extra = {}) => ({
	$className: extra.className || "Part",
	$properties: {
		Anchored: true,
		CanCollide: extra.canCollide ?? true,
		CanTouch: false,
		Color: color,
		Material: extra.material || "SmoothPlastic",
		Position: pos,
		Size: size,
		Transparency: extra.transparency ?? 0,
		...(extra.shape ? { Shape: extra.shape } : {}),
		...(extra.locked ? { Locked: true } : {}),
	},
});
const folder = (children) => ({ $className: "Folder", ...children });

// --- Character models (mirrors Builder.buildBrainrotModel) -----------------
// Body per shape, two eyes, a grin, an accessory. Part positions are
// world positions: model origin + the same offsets the builder uses.
function characterParts(def, origin) {
	const [ox, oy, oz] = origin;
	const at = ([x, y, z]) => [ox + x, oy + y, oz + z];
	const c = rgb(...def.color);
	const parts = {};
	let topY = 1.8;
	let eyeZ = 1.25;
	if (def.shape === "round") {
		parts.Body = part("Body", at([0, 1.5, 0]), [3, 3, 3], c, { shape: "Ball", canCollide: false });
		topY = 3.0; eyeZ = 1.45;
	} else if (def.shape === "flat") {
		parts.Body = part("Body", at([0, 0.9, 0]), [3.6, 1.8, 3], c, { canCollide: false });
		topY = 1.8; eyeZ = 1.55;
	} else if (def.shape === "cone") {
		parts.Body = part("Body", at([0, 1.8, 0]), [3, 3.6, 3], c, { className: "WedgePart", canCollide: false });
		topY = 3.6;
	} else {
		parts.Body = part("Body", at([0, 1.8, 0]), [2.4, 3.6, 2.4], c, { canCollide: false });
		topY = 3.6;
	}
	const eye = rgb(20, 20, 20);
	parts.EyeL = part("EyeL", at([-0.55, 1.9, eyeZ]), [0.4, 0.5, 0.2], eye, { shape: "Ball", canCollide: false });
	parts.EyeR = part("EyeR", at([0.55, 1.9, eyeZ]), [0.4, 0.5, 0.2], eye, { shape: "Ball", canCollide: false });
	parts.Grin = part("Grin", at([0, 1.25, eyeZ]), [1.1, 0.18, 0.15], eye, { canCollide: false });
	const gold = rgb(255, 215, 0);
	if (def.accessory === "crown") {
		parts.Crown = part("Crown", at([0, topY + 0.25, 0]), [1.6, 0.5, 1.6], gold, { canCollide: false });
		for (const dx of [-0.55, 0, 0.55]) {
			parts[`CrownSpike${dx}`] = part("CrownSpike", at([dx, topY + 0.7, 0]), [0.3, 0.5, 0.3], gold, { canCollide: false });
		}
	} else if (def.accessory === "hat") {
		const brown = rgb(120, 70, 20);
		parts.HatBrim = part("HatBrim", at([0, topY + 0.1, 0]), [2.6, 0.25, 2.6], brown, { canCollide: false });
		parts.HatTop = part("HatTop", at([0, topY + 0.7, 0]), [1.4, 1.0, 1.4], brown, { canCollide: false });
	} else if (def.accessory === "glasses") {
		parts.LensL = part("LensL", at([-0.6, topY - 0.6, 1.15]), [0.7, 0.7, 0.2], eye, { canCollide: false });
		parts.LensR = part("LensR", at([0.6, topY - 0.6, 1.15]), [0.7, 0.7, 0.2], eye, { canCollide: false });
		parts.Bridge = part("Bridge", at([0, topY - 0.6, 1.15]), [0.6, 0.15, 0.15], eye, { canCollide: false });
	} else if (def.accessory === "cape") {
		parts.Cape = part("Cape", at([0, topY - 1.6, -1.2]), [2.2, 2.6, 0.25], rgb(200, 30, 50), { canCollide: false });
	}
	return parts;
}

function characterModel(def, origin, mutation = "Normal") {
	return { $className: "Model", ...characterParts(def, origin) };
}

// --- The world ---------------------------------------------------------------
const workspace = {};

// Island and sea.
workspace.Island = part("Island", [0, -1, 0], [240, 2, 240], rgb(185, 160, 105), { locked: true });
workspace.Water = part("Water", [0, -3, 0], [700, 2, 700], rgb(40, 120, 220), { transparency: 0.25, locked: true });

// Spawn pad, west end.
workspace.SpawnLocation = {
	$className: "SpawnLocation",
	$properties: {
		Anchored: true, Color: rgb(120, 200, 120), Material: "SmoothPlastic",
		Position: [-95, 0.5, 0], Size: [12, 1, 12], Transparency: 0,
	},
};

// The conveyor: belt, chevrons, rails, and the Snack Dock arch.
workspace.ConveyorBase = part("ConveyorBase", [0, 0.5, 0], [170, 1, 10], rgb(70, 70, 80));
for (let i = 0; i < 17; i++) {
	const x = -80 + i * 10;
	workspace[`Chevron${i}`] = part(`Chevron${i}`, [x, 1.05, 0], [2, 0.15, 6], rgb(255, 210, 0), { canCollide: false });
}
workspace.RailN = part("RailN", [0, 1.2, -5.5], [170, 1, 1], rgb(150, 150, 160));
workspace.RailS = part("RailS", [0, 1.2, 5.5], [170, 1, 1], rgb(150, 150, 160));
workspace.DockPostN = part("DockPostN", [-82, 4, -4], [1, 8, 1], rgb(150, 100, 50));
workspace.DockPostS = part("DockPostS", [-82, 4, 4], [1, 8, 1], rgb(150, 100, 50));
workspace.DockBeam = part("DockBeam", [-82, 8, 0], [1, 1, 10], rgb(150, 100, 50));
workspace.DockSign = {
	$className: "Part",
	$properties: {
		Anchored: true, Color: rgb(60, 60, 80), Material: "SmoothPlastic",
		Position: [-81.4, 6.5, 0], Size: [0.5, 3, 12], Transparency: 0,
	},
	DockSignText: {
		$className: "SurfaceGui",
		$properties: { Face: "Right" },
		Label: {
			$className: "TextLabel",
			$properties: {
				Size: fullSize,
				Text: "SNACK DOCK", TextScaled: true, Font: "GothamBold",
				TextColor3: [1, 1, 1], BackgroundTransparency: 1,
			},
		},
	},
};

// Folders the server fills at runtime: the belt and placed brainrots.
workspace.Belt = folder({});
workspace.Placed = folder({});

// The six base plots.
const plotsNode = {};
const PLOT_COLORS = [
	rgb(255, 120, 120), rgb(120, 180, 255), rgb(120, 230, 140),
	rgb(255, 210, 90), rgb(200, 130, 255), rgb(90, 220, 220),
];
PLOTS.forEach((plot, i) => {
	const n = i + 1;
	const north = plot.z < 0;
	const signZ = plot.z + (north ? -9 : 9);
	const face = north ? "Front" : "Back";
	const node = {};
	node.Pad = part("Pad", [plot.x, 0, plot.z], [26, 1, 22], PLOT_COLORS[i]);
	node.BorderN = part("BorderN", [plot.x, 0.6, plot.z - 11], [26, 0.4, 1], rgb(255, 255, 255), { canCollide: false });
	node.BorderS = part("BorderS", [plot.x, 0.6, plot.z + 11], [26, 0.4, 1], rgb(255, 255, 255), { canCollide: false });
	node.BorderW = part("BorderW", [plot.x - 13, 0.6, plot.z], [1, 0.4, 22], rgb(255, 255, 255), { canCollide: false });
	node.BorderE = part("BorderE", [plot.x + 13, 0.6, plot.z], [1, 0.4, 22], rgb(255, 255, 255), { canCollide: false });
	SLOT_OFFSETS.forEach((off, s) => {
		node[`Slot${s + 1}`] = part(`Slot${s + 1}`, [plot.x + off.x, 0.55, plot.z + off.z], [4, 0.2, 4], rgb(230, 230, 230), { canCollide: false });
	});
	node.SignPost = part("SignPost", [plot.x + 11, 2.5, signZ], [0.8, 5, 0.8], rgb(120, 80, 40));
	node.SignBoard = {
		$className: "Part",
		$properties: {
			Anchored: true, Color: rgb(60, 60, 80), Material: "SmoothPlastic",
			Position: [plot.x + 11, 5.5, signZ], Size: [9, 2.5, 0.5], Transparency: 0,
		},
		OwnerSign: {
			$className: "SurfaceGui",
			$properties: { Face: face },
			Label: {
				$className: "TextLabel",
				$properties: {
					Size: fullSize,
					Text: "EMPTY BASE", TextScaled: true, Font: "GothamBold",
					TextColor3: [1, 1, 1], BackgroundTransparency: 1,
				},
			},
		},
	};
	node.Shield = part("Shield", [plot.x, 7, plot.z], [26, 14, 22], rgb(120, 180, 255), { transparency: 1, canCollide: false });
	plotsNode[`Plot${n}`] = { $className: "Folder", ...node };
});
workspace.Plots = { $className: "Folder", ...plotsNode };

// The big sign over the bazaar, facing the spawn.
workspace.SignPostW = part("SignPostW", [-12, 4.5, -52], [1, 9, 1], rgb(120, 80, 40));
workspace.SignPostE = part("SignPostE", [12, 4.5, -52], [1, 9, 1], rgb(120, 80, 40));
workspace.MainSign = {
	$className: "Part",
	$properties: {
		Anchored: true, Color: rgb(60, 60, 80), Material: "SmoothPlastic",
		Position: [0, 9, -52], Size: [26, 8, 1], Transparency: 0,
	},
	MainSignText: {
		$className: "SurfaceGui",
		$properties: { Face: "Front" },
		Label: {
			$className: "TextLabel",
			$properties: {
				Size: fullSize,
				Text: "BRAINROT BAZAAR", TextScaled: true, Font: "GothamBold",
				TextColor3: [1, 0.82, 0.35], BackgroundTransparency: 1,
			},
		},
	},
};

// Tsunami warning sign at the east exit.
workspace.TsunamiSign = {
	$className: "Part",
	$properties: {
		Anchored: true, Color: rgb(60, 60, 80), Material: "SmoothPlastic",
		Position: [88, 4, -15], Size: [0.5, 3, 10], Transparency: 0,
	},
	TsunamiSignText: {
		$className: "SurfaceGui",
		$properties: { Face: "Left" },
		Label: {
			$className: "TextLabel",
			$properties: {
				Size: fullSize,
				Text: "TSUNAMI ZONE", TextScaled: true, Font: "GothamBold",
				TextColor3: [1, 0.4, 0.4], BackgroundTransparency: 1,
			},
		},
	},
};

// Decor: palms, rocks, clouds, crates, umbrellas, lighthouse.
const PALMS = [[-40, -48], [40, -48], [-70, 48], [70, 48], [-105, -25], [-105, 25], [105, -40], [105, 40]];
PALMS.forEach(([x, z], i) => {
	workspace[`PalmTrunk${i}`] = part(`PalmTrunk${i}`, [x, 3.5, z], [1.2, 7, 1.2], rgb(140, 100, 50));
	for (let l = 0; l < 5; l++) {
		const a = (l / 5) * Math.PI * 2;
		workspace[`PalmLeaf${i}_${l}`] = part(`PalmLeaf${i}_${l}`, [x + Math.cos(a) * 2.2, 7.4, z + Math.sin(a) * 2.2], [4, 0.8, 1.6], rgb(60, 180, 80), { canCollide: false });
	}
});
const ROCKS = [[-30, 55, 4], [25, -55, 5], [60, 55, 3], [-60, -55, 4], [95, 10, 5], [-95, -45, 3], [30, 48, 4], [-20, -48, 3], [80, 55, 4], [-75, 15, 3]];
ROCKS.forEach(([x, z, s], i) => {
	workspace[`Rock${i}`] = part(`Rock${i}`, [x, 0.5, z], [s, s * 0.7, s], rgb(140, 140, 145), { shape: "Ball" });
});
const CLOUDS = [[-50, 50, -40], [20, 58, -60], [70, 48, 30], [-80, 55, 50], [0, 60, 60], [50, 52, -10]];
CLOUDS.forEach(([x, y, z], i) => {
	for (let b = 0; b < 3; b++) {
		workspace[`Cloud${i}_${b}`] = part(`Cloud${i}_${b}`, [x + (b - 1) * 5, y, z + (b % 2) * 2], [8, 3, 5], [1, 1, 1], { canCollide: false, transparency: 0.1 });
	}
});
const CRATES = [[-70, -12], [-70, -8], [-70, -10], [-66, -10], [90, 12], [90, 16]];
CRATES.forEach(([x, z], i) => {
	workspace[`Crate${i}`] = part(`Crate${i}`, [x, 1.5 + (i === 2 ? 3 : 0), z], [3, 3, 3], rgb(170, 120, 60));
});
const UMBRELLAS = [[-58, -16, 0], [58, 16, 1], [0, -16, 2], [0, 44, 3]];
// umbrella: [plotX, plotZ, colour index] — pole + canopy beside the plot.
const UMBRELLA_COLORS = [rgb(255, 80, 80), rgb(80, 160, 255), rgb(255, 210, 60), rgb(120, 220, 120)];
UMBRELLAS.forEach(([x, z, ci], i) => {
	workspace[`UmbrellaPole${i}`] = part(`UmbrellaPole${i}`, [x, 2.5, z], [0.5, 5, 0.5], rgb(200, 200, 200), { canCollide: false });
	workspace[`UmbrellaTop${i}`] = part(`UmbrellaTop${i}`, [x, 5.2, z], [7, 1.2, 7], UMBRELLA_COLORS[ci], { shape: "Ball", canCollide: false });
});
// Lighthouse at the east end.
workspace.LightBase = part("LightBase", [100, 1, -70], [8, 2, 8], rgb(200, 200, 200));
workspace.LightTower1 = part("LightTower1", [100, 6, -70], [5, 8, 5], rgb(220, 60, 60));
workspace.LightTower2 = part("LightTower2", [100, 14, -70], [5, 8, 5], rgb(240, 240, 240));
workspace.LightTower3 = part("LightTower3", [100, 22, -70], [5, 8, 5], rgb(220, 60, 60));
workspace.LightTop = part("LightTop", [100, 27, -70], [6, 2, 6], rgb(60, 60, 80));
workspace.LightBulb = part("LightBulb", [100, 29.5, -70], [3, 3, 3], rgb(255, 240, 150), { shape: "Ball", canCollide: false });

// --- Sample brainrots: the ones the screenshots show -----------------------
// Five on the belt (the parade), three placed on the south-centre
// plot (the player's base in the screenshots). The runtime spawner
// builds the same shapes from the same catalog.
const manifest = { characters: [], signs: [], plots: PLOTS, slotOffsets: SLOT_OFFSETS };
const BELT_SAMPLES = [
	["picklefoot", -60], ["noodlebeard", -30], ["croissant", 0], ["wobble", 30], ["bananas", 60],
];
BELT_SAMPLES.forEach(([id, x]) => {
	const def = byId[id];
	workspace[`Sample_${id}`] = characterModel(def, [x, 1.0, 0]);
	manifest.characters.push({ id, name: def.name, rarity: def.rarity, income: def.income, mutation: "Normal", x, y: 1.0, z: 0, onBelt: true });
});
const BASE_SAMPLES = [["picklefoot", 1], ["croissant", 2], ["bananas", 3]];
BASE_SAMPLES.forEach(([id, slot]) => {
	const def = byId[id];
	const plot = PLOTS[3]; // south-centre plot (x=0, z=30)
	const off = SLOT_OFFSETS[slot - 1];
	const x = plot.x + off.x;
	const z = plot.z + off.z;
	workspace[`Placed_${id}`] = characterModel(def, [x, 0.6, z]);
	manifest.characters.push({ id, name: def.name, rarity: def.rarity, income: def.income, mutation: "Normal", x, y: 0.6, z, onBelt: false, plot: 4, slot });
});
manifest.signs = [
	{ text: "BRAINROT BAZAAR", pos: [0, 9, -52], size: [26, 8], face: "Front" },
	{ text: "SNACK DOCK", pos: [-81.4, 6.5, 0], size: [12, 3], face: "Right" },
	{ text: "TSUNAMI ZONE", pos: [88, 4, -15], size: [10, 3], face: "Left" },
];

// --- The Rojo project ---------------------------------------------------------
const project = {
	name: "brainrot-bazaar",
	tree: {
		$className: "DataModel",
		Players: { $properties: { CharacterAutoLoads: true } },
		ReplicatedStorage: {
			Shared: { $path: "src/shared" },
			Remotes: {
				$className: "Folder",
				GameEvent: { $className: "RemoteEvent" },
				PlayerAction: { $className: "RemoteEvent" },
				SellBrainrot: { $className: "RemoteFunction" },
				Rebirth: { $className: "RemoteFunction" },
				LockBase: { $className: "RemoteFunction" },
			},
		},
		ServerScriptService: { Server: { $path: "src/server" } },
		StarterPlayer: { StarterPlayerScripts: { Client: { $path: "src/client" } } },
		Workspace: { $properties: { FilteringEnabled: true }, ...workspace },
		Lighting: {
			$properties: {
				Ambient: [0.5, 0.5, 0.5],
				Brightness: 2,
				ClockTime: 10.5,
				GlobalShadows: true,
				Outlines: false,
				Technology: "Future",
			},
		},
		SoundService: { $properties: { RespectFilteringEnabled: true } },
	},
};

writeFileSync(join(root, "default.project.json"), JSON.stringify(project, null, 2) + "\n");
writeFileSync(join(here, "world-manifest.json"), JSON.stringify(manifest, null, 2) + "\n");

// Count the instances the place will hold.
let instances = 0;
(function count(node) {
	if (node && typeof node === "object") {
		if (node.$className) instances++;
		for (const v of Object.values(node)) count(v);
	}
})(project.tree);
console.log(`wrote default.project.json (${instances} instances) and tools/world-manifest.json`);
console.log(`roster: ${BRAINROTS.length} brainrots, plots: ${PLOTS.length}, slots: ${SLOT_OFFSETS.length}`);
