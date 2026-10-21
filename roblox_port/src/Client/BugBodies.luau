--!strict
-- The drawn woodlice (ROBLOX-96, Prey/Woodlouse): a grey segmented body about a centimetre long, made of seven overlapping plates over the back, a small head
-- with two antennae and seven pairs of short legs (woodlice are isopods: seven pairs of walking legs), each louse PARTS parts under the fly's budget, all
-- anchored, never colliding, never seen by a ray and casting no shadow (Habitat/Shapes), placed with one Workspace:BulkMoveTo each frame like the flies. A louse
-- under cover (state "hidden") is drawn a stud and a half under the soil, inside the solid ground, so nothing of it shows; it comes back up where it went under.
-- Display only: the sim decides where each louse is and whether it is hiding; nothing here feeds back.
-- ROBLOX-103 (W3c): pose only, no part added. The fourteen legs step in a metachronal wave (each pair a little behind the one in front, the two sides in
-- opposite phase), a full wave per stride of soil covered, so a louse that stops stops stepping and one that scurries for cover steps fast; the antennae sway.
-- The common garden woodlouse the page names (Porcellio scaber) cannot roll into a ball, so it scurries: no rolling. Far from the camera (FlyLook.far, as the
-- rival's rig) a louse is drawn ten times a second; Reduced Motion keeps the steps and stills the antennae.
-- ROBLOX-105 (W3b part B): the garden's other ambient bugs are drawn here too, each creature by its `kind` (a creature with none is a woodlouse), at their true
-- sizes (1 stud = 1 cm), every part anchored, never solid, never seen by a ray, no shadow, all of them in the same one BulkMoveTo, the same far rule:
--   ladybird ..... a red domed beetle 0.6 long, its seven black spots, a black pronotum with two pale patches, head, antennae and six legs stepping in two
--                  tripods; struck, a drop of yellow fluid shows at each front leg joint (reflex bleeding) while `bleedUntil` lasts; eating, its head works
--   millipede .... a head and twelve rings laid along the head's track (the sim's `trail`), two pairs of legs on each ring (one at the low tier) stepping in a
--                  wave that runs down the body; coiling, the rings wind into a flat spiral round the head; under a stone, under the soil
--   snail ........ a brown shell 3 across with its band, spire and lip, the foot and head, the upper eye stalks (drawn in as the sim's `eyes` falls, sliding
--                  into the head) and the lower feelers; withdrawn into its shell, the soft parts are inside it; and its slime trail, a pale ribbon along the
--                  sim's trail points, fading over Prey/Snail.FADE_S (24 legs at the full tier, 12 at the low)
--   harvestman ... a small oval body with its eye turret and palps, high on eight long legs of two segments each (the second pair longest), stepping;
--                  by day (`hidden`) it is away and drawn nowhere near
-- Reduced Motion keeps the steps and stills the rest (antennae, the ladybird's head, the snail's feelers' sway).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shapes = require(Shared:WaitForChild("Habitat"):WaitForChild("Shapes"))
local FlyLook = require(Shared:WaitForChild("Data"):WaitForChild("FlyLook"))

local BugBodies = {}
BugBodies.__index = BugBodies

-- The most parts a woodlouse may be drawn with (the sheet below makes exactly this many).
BugBodies.PARTS = 24
-- How far under the soil a hidden louse is kept.
BugBodies.UNDER = 1.5
-- (ROBLOX-105) Where a creature that is away is kept: far under the world.
BugBodies.AWAY = -600

-- The sheet: body frame -Z forward, +Y up, the origin the body's centre at Woodlouse.HOVER above the soil, the feet at y = -0.12.
BugBodies.look = {
	colors = { plate = "6b6d6a", plateDark = "5c5e5b", head = "55575a", antenna = "4a4c4f", leg = "7a7c78" },
	plates = 7, plateLength = 0.17, plateWidth = 0.5, plateHeight = 0.26, from = -0.33, pitch = 0.12, -- seven plates from z -0.33 back, every 0.12: a 1.0 long body
	head = { at = { 0, -0.02, -0.44 }, size = { 0.3, 0.2, 0.16 } },
	antenna = { from = { 0.08, 0.02, -0.5 }, to = { 0.22, 0.06, -0.72 }, d = 0.016 },
	leg = { hipX = 0.2, hipY = -0.02, footX = 0.32, footY = -0.12, d = 0.018, from = -0.33, pitch = 0.12 },
	-- (ROBLOX-103) the gait (as Data/FlyLook's `motion`): a wave of `wave` radians from pair to pair, a cycle per `stride` studs; the antennae's sway
	motion = { gait = { stride = 0.4, swing = 0.3, lift = 0.28, settle = 10, jump = 1.0, wave = 0.9 }, antenna = { amp = 0.18, hz = 1.4 } },
}

-- (ROBLOX-105) The ambient bugs' sheets: colours, sizes and their gaits (a cycle per `stride` studs covered; `wave` the lag from one leg or ring to the next).
BugBodies.ambient = {
	ladybird = {
		colors = { elytra = "c8261c", black = "141414", patch = "efe9dc", leg = "1a1a1a", drop = "e8b81e" },
		dome = { at = { 0, 0.02, 0.05 }, size = { 0.5, 0.3, 0.52 } }, -- the wing cases: a dome 0.6 long with the pronotum and head
		spots = { { 0, -0.2 }, { 0.12, -0.06 }, { -0.12, -0.06 }, { 0.17, 0.1 }, { -0.17, 0.1 }, { 0.09, 0.22 }, { -0.09, 0.22 } }, -- (x, z) on the dome: seven
		motion = { gait = { stride = 0.22, swing = 0.35, lift = 0.3, settle = 10, jump = 1.0 }, antenna = { amp = 0.2, hz = 1.6 } },
	},
	millipede = {
		colors = { head = "2b211c", ring = "3d2f27", ringDark = "30251f", leg = "c2ab88", antenna = "4a3b30" },
		ring = { size = { 0.24, 0.22, 0.3 } }, head = { size = { 0.2, 0.17, 0.2 } }, -- (the rings overlap along the body: a cylinder of rings, not beads)
		motion = { gait = { stride = 0.25, swing = 0.4, lift = 0.25, settle = 8, jump = 1.0, wave = 0.55 }, antenna = { amp = 0.25, hz = 1.2 } },
		coil = { inner = 0.12, pitch = 0.25 }, -- the spiral round the head: its first radius and how much it widens a turn (the body's width)
	},
	snail = {
		colors = { foot = "8a7a66", head = "7d6e5c", shell = "9a7a4f", band = "4e3a24", spire = "b08a58", lip = "c9b28a", eye = "1c1814", trail = "cfd8dc" },
		stalk = 0.9, feeler = 0.35, trail = { width = 0.9, thick = 0.025, base = 0.55, full = 24, low = 12, fade = 240 }, -- (fade: Prey/Snail.FADE_S)
	},
	-- (ROBLOX-119) a small brown field ant of the meadow's hill, about 4 mm: head, thorax, the waist's node and the gaster, six legs, elbowed antennae
	ant = {
		colors = { head = "3a2618", thorax = "5a3a22", gaster = "2e1f14", leg = "4a3020", antenna = "3a2618" },
		motion = { gait = { stride = 0.18, swing = 0.4, lift = 0.3, settle = 12, jump = 1.0 } },
	},
	-- (ROBLOX-122) a water strider of the pond, about 1.2 cm: a slim dark body, short front legs held up to grab, the long middle legs (the oars) and hind legs (the
	-- rudders) spread wide on the water, each foot in a dimple of the surface
	skater = {
		colors = { body = "2e2a24", belly = "6a6458", leg = "3a342c", dimple = "c8d4d6" },
		motion = { gait = { stride = 3.0, swing = 0.2, lift = 0.0, settle = 8, jump = 30.0 } },
	},
	harvestman = {
		colors = { body = "6e5034", turret = "3a2a1c", leg = "5a4330", palp = "6a4e36" },
		legs = { { a = 35, l = 1.5 }, { a = 75, l = 2.4 }, { a = 110, l = 1.8 }, { a = 145, l = 2.0 } }, -- degrees from ahead and lengths (studs), each side
		motion = { gait = { stride = 1.1, swing = 0.25, lift = 0.25, settle = 8, jump = 3.0 } },
	},
}

-- `hip`, `side`, `pair` (ROBLOX-103): where a leg turns from and which it is, or an antenna's base (`pair` 0); (ROBLOX-105) `role`: what a part of an ambient
-- bug is to its pose ("leg", "antenna", "drop", "head", "ring", "rleg", "trail", "stalk", "eye", "feeler", "soft", "knee"...), `ring` the ring a millipede's
-- leg hangs from, `a`/`b` a rod's ends in the body frame
type Spec = { name: string, rod: boolean, color: Color3, size: Vector3, frame: CFrame, hip: Vector3?, side: number?, pair: number?, role: string?, ring: number?,
	a: Vector3?, b: Vector3?, material: string? }

local function rodBetween(a: Vector3, b: Vector3, diameter: number): (Vector3, CFrame)
	local dir = (b - a).Unit
	local up = if math.abs(dir.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return Vector3.new((b - a).Magnitude, diameter, diameter), CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0)
end

local function build(): { Spec }
	local L = BugBodies.look
	local specs: { Spec } = {}
	local function color(name: string): Color3
		return Color3.fromHex(L.colors[name])
	end
	for i = 1, L.plates do
		local z = L.from + (i - 1) * L.pitch
		local arch = 1 - 0.18 * math.abs((i - (L.plates + 1) / 2) / ((L.plates - 1) / 2)) -- the back is highest and widest in the middle
		table.insert(specs, { name = "Plate" .. i, rod = false, color = color(if i % 2 == 0 then "plateDark" else "plate"),
			size = Vector3.new(L.plateWidth * arch, L.plateHeight * arch, L.plateLength), frame = CFrame.new(0, 0.01, z) })
	end
	table.insert(specs, { name = "Head", rod = false, color = color("head"), size = Vector3.new(L.head.size[1], L.head.size[2], L.head.size[3]), frame = CFrame.new(L.head.at[1], L.head.at[2], L.head.at[3]) })
	for _, side in { -1, 1 } do
		local word = if side < 0 then "Left" else "Right"
		local a = Vector3.new(L.antenna.from[1] * side, L.antenna.from[2], L.antenna.from[3])
		local b = Vector3.new(L.antenna.to[1] * side, L.antenna.to[2], L.antenna.to[3])
		local size, frame = rodBetween(a, b, L.antenna.d)
		table.insert(specs, { name = word .. "Antenna", rod = true, color = color("antenna"), size = size, frame = frame, hip = a, side = side, pair = 0 })
		for i = 1, 7 do
			local z = L.leg.from + (i - 1) * L.leg.pitch
			local hip, foot = Vector3.new(L.leg.hipX * side, L.leg.hipY, z), Vector3.new(L.leg.footX * side, L.leg.footY, z + 0.02)
			local ls, lf = rodBetween(hip, foot, L.leg.d)
			table.insert(specs, { name = `{word}Leg{i}`, rod = true, color = color("leg"), size = ls, frame = lf, hip = hip, side = side, pair = i })
		end
	end
	return specs
end

-- ---------------------------------------------------------------- (ROBLOX-105) the ambient bugs' sheets
local function hex(s: string): Color3 return Color3.fromHex(s) end
local function v(x: number, y: number, z: number): Vector3 return Vector3.new(x, y, z) end

local function rodSpec(name: string, a: Vector3, b: Vector3, d: number, color: Color3, role: string?, side: number?, pair: number?): Spec
	local size, frame = rodBetween(a, b, d)
	return { name = name, rod = true, color = color, size = size, frame = frame, hip = a, side = side, pair = pair, role = role, a = a, b = b }
end
local function ball(name: string, at: Vector3, size: Vector3, color: Color3, role: string?): Spec
	return { name = name, rod = false, color = color, size = size, frame = CFrame.new(at), role = role }
end

-- The ladybird: the dome of the wing cases, seven spots set into the dome's surface, the pronotum and its two pale patches (full),
-- the head, antennae (full), six legs (hips under the body, feet on the surface at y -0.17) and two drops of fluid (kept inside the body until it bleeds).
local function buildLadybird(tier: string): { Spec }
	local S = BugBodies.ambient.ladybird
	local C = S.colors
	local full = tier ~= "low"
	local out: { Spec } = {}
	local d = S.dome
	local c0 = v(d.at[1], d.at[2], d.at[3])
	local ax, ay, az = d.size[1] / 2, d.size[2] / 2, d.size[3] / 2
	table.insert(out, ball("Elytra", c0, v(d.size[1], d.size[2], d.size[3]), hex(C.elytra)))
	for i, s in S.spots do
		local x, z = s[1], c0.Z + s[2]
		local q = 1 - (x / ax) ^ 2 - ((z - c0.Z) / az) ^ 2
		local y = c0.Y + ay * math.sqrt(math.max(0.02, q))
		local p = v(x, y, z)
		local n = v(x / (ax * ax), (y - c0.Y) / (ay * ay), (z - c0.Z) / (az * az)).Unit
		table.insert(out, { name = "Spot" .. i, rod = false, color = hex(C.black), size = v(0.085, 0.085, 0.03), frame = CFrame.lookAt(p - n * 0.008, p + n) })
	end
	table.insert(out, ball("Pronotum", v(0, 0.0, -0.22), v(0.34, 0.14, 0.16), hex(C.black)))
	if full then
		for _, side in { -1, 1 } do table.insert(out, ball(if side < 0 then "PatchL" else "PatchR", v(0.11 * side, 0.035, -0.235), v(0.08, 0.06, 0.07), hex(C.patch))) end
	end
	table.insert(out, ball("Head", v(0, -0.04, -0.31), v(0.2, 0.1, 0.1), hex(C.black), "head"))
	if full then
		for _, side in { -1, 1 } do
			table.insert(out, rodSpec(if side < 0 then "AntennaL" else "AntennaR", v(0.05 * side, -0.02, -0.35), v(0.11 * side, 0.0, -0.43), 0.012, hex(C.black), "antenna", side, 0))
		end
	end
	local zs = { -0.13, 0.0, 0.13 }
	local reach = { -0.06, 0.0, 0.07 }
	for _, side in { -1, 1 } do
		for i, z in zs do
			table.insert(out, rodSpec(`{if side < 0 then "L" else "R"}Leg{i}`, v(0.1 * side, -0.08, z), v(0.25 * side, -0.17, z + reach[i]), 0.025, hex(C.leg), "leg", side, i))
		end
	end
	for _, side in { -1, 1 } do
		local s = ball(if side < 0 then "DropL" else "DropR", v(0.14 * side, -0.1, -0.14), v(0.06, 0.06, 0.06), hex(C.drop), "drop")
		s.side = side
		table.insert(out, s)
	end
	return out
end

-- The millipede: the head, two antennae, twelve rings, and on each ring two pairs of legs (one pair at the low tier). Ring and leg frames are relative to the
-- ring's own frame (the pose lays the rings along the track).
local function buildMillipede(tier: string): { Spec }
	local S = BugBodies.ambient.millipede
	local C = S.colors
	local out: { Spec } = {}
	table.insert(out, ball("Head", v(0, 0, 0), v(S.head.size[1], S.head.size[2], S.head.size[3]), hex(C.head), "mhead"))
	for _, side in { -1, 1 } do
		table.insert(out, rodSpec(if side < 0 then "AntennaL" else "AntennaR", v(0.05 * side, 0.03, -0.07), v(0.13 * side, 0.06, -0.24), 0.014, hex(C.antenna), "mantenna", side, 0))
	end
	local rings = 12
	for k = 1, rings do
		local s = ball("Ring" .. k, v(0, 0, 0), v(S.ring.size[1], S.ring.size[2], S.ring.size[3]), hex(if k % 2 == 0 then C.ringDark else C.ring), "ring")
		s.ring = k
		table.insert(out, s)
	end
	local offsets: { number } = if tier == "low" then { 0 } else { -0.055, 0.055 }
	for k = 1, rings do
		for _, side in { -1, 1 } do
			for j, dz in offsets do
				local s = rodSpec(`Leg{k}{if side < 0 then "L" else "R"}{j}`, v(0.08 * side, -0.06, dz), v(0.15 * side, -0.12, dz - 0.02), 0.018, hex(C.leg), "rleg", side, k * 2 + j)
				s.ring = k
				table.insert(out, s)
			end
		end
	end
	return out
end

-- The snail, in its frame: the origin on the surface under it, +Y the surface's normal, -Z ahead. The shell's centre is SHELL_AT.
local SHELL_AT = v(0, 1.55, 0.45)
local function buildSnail(tier: string): { Spec }
	local S = BugBodies.ambient.snail
	local C = S.colors
	local out: { Spec } = {}
	local foot = ball("Foot", v(0, 0.25, -0.35), v(1.1, 0.5, 4.0), hex(C.foot), "soft")
	table.insert(out, foot)
	table.insert(out, ball("Head", v(0, 0.42, -2.0), v(0.8, 0.6, 1.0), hex(C.head), "soft"))
	for _, side in { -1, 1 } do
		local base = v(0.2 * side, 0.62, -2.25)
		local tip = base + v(0.25 * side, 0.8, -0.4).Unit * S.stalk
		local s = rodSpec(if side < 0 then "StalkL" else "StalkR", base, tip, 0.09, hex(C.head), "stalk", side, 0)
		table.insert(out, s)
	end
	for _, side in { -1, 1 } do
		local s = ball(if side < 0 then "EyeL" else "EyeR", v(0, 0, 0), v(0.16, 0.16, 0.16), hex(C.eye), "eye")
		s.side = side
		table.insert(out, s)
	end
	for _, side in { -1, 1 } do
		local base = v(0.22 * side, 0.32, -2.45)
		table.insert(out, rodSpec(if side < 0 then "FeelerL" else "FeelerR", base, base + v(0.15 * side, -0.05, -0.32).Unit * S.feeler, 0.07, hex(C.head), "feeler", side, 0))
	end
	table.insert(out, ball("Shell", SHELL_AT, v(2.3, 2.6, 3.0), hex(C.shell)))
	table.insert(out, ball("ShellBand", SHELL_AT + v(0, -0.25, 0.02), v(2.38, 0.55, 2.66), hex(C.band))) -- (a dark band round the shell's girth)
	table.insert(out, ball("Spire", SHELL_AT + v(0.82, 0.12, 0.15), v(0.95, 1.35, 1.35), hex(C.spire))) -- (the last whorls, standing out on its right side)
	table.insert(out, ball("Lip", SHELL_AT + v(-0.25, -1.0, -1.12), v(1.0, 0.45, 0.22), hex(C.lip))) -- (the aperture's lip, over the body)
	local n = if tier == "low" then S.trail.low else S.trail.full
	for i = 1, n do
		local s: Spec = { name = "Trail" .. i, rod = false, color = hex(C.trail), size = v(S.trail.width, S.trail.thick, 0.5), frame = CFrame.new(), role = "trail", pair = i, material = "Glass" }
		table.insert(out, s)
	end
	return out
end

-- The harvestman, in its frame: the origin the body's centre, +Y up, -Z ahead, the feet at y -HOVER (0.9). Each leg two rods: hip up to the knee, knee down to
-- the foot.
local HARVEST_HOVER = 0.9
local function legPoints(i: number, side: number): (Vector3, Vector3, Vector3)
	local L = BugBodies.ambient.harvestman.legs[i]
	local zs = { -0.12, -0.04, 0.04, 0.12 }
	local hip = v(0.15 * side, 0, zs[i])
	local a = math.rad(L.a)
	local d = v(math.sin(a) * side, 0, -math.cos(a))
	local knee = hip + d * (0.32 * L.l) + v(0, 0.55, 0)
	local foot = hip + d * L.l + v(0, -HARVEST_HOVER, 0)
	return hip, knee, foot
end
local function buildHarvestman(_tier: string): { Spec }
	local S = BugBodies.ambient.harvestman
	local C = S.colors
	local out: { Spec } = {}
	table.insert(out, ball("Body", v(0, 0, 0), v(0.42, 0.24, 0.5), hex(C.body)))
	table.insert(out, ball("Turret", v(0, 0.13, -0.1), v(0.1, 0.1, 0.1), hex(C.turret)))
	for _, side in { -1, 1 } do
		table.insert(out, rodSpec(if side < 0 then "PalpL" else "PalpR", v(0.05 * side, -0.04, -0.24), v(0.08 * side, -0.14, -0.34), 0.03, hex(C.palp), nil, side, 0))
	end
	for _, side in { -1, 1 } do
		for i = 1, 4 do
			local hip, knee, foot = legPoints(i, side)
			local word = if side < 0 then "L" else "R"
			local up = rodSpec(`Femur{word}{i}`, hip, knee, 0.022, hex(C.leg), "leg", side, i)
			local down = rodSpec(`Tibia{word}{i}`, knee, foot, 0.018, hex(C.leg), "leg", side, i)
			up.hip = hip; down.hip = hip
			table.insert(out, up)
			table.insert(out, down)
		end
	end
	return out
end

-- (ROBLOX-119) The ant: its head, thorax, the node of its waist and its gaster in a line, six legs from the thorax (a femur up and a tibia down), two elbowed antennae
-- (full tier). Its body's middle rides Prey/Ant.HOVER over the floor.
local ANT_HOVER = 0.12
local function buildAnt(tier: string): { Spec }
	local C = BugBodies.ambient.ant.colors
	local out: { Spec } = {}
	table.insert(out, ball("Head", v(0, 0.02, -0.15), v(0.09, 0.08, 0.1), hex(C.head)))
	table.insert(out, ball("Thorax", v(0, 0.02, -0.04), v(0.07, 0.07, 0.13), hex(C.thorax)))
	table.insert(out, ball("Node", v(0, 0.03, 0.04), v(0.04, 0.05, 0.03), hex(C.thorax)))
	table.insert(out, ball("Gaster", v(0, 0.03, 0.12), v(0.11, 0.1, 0.14), hex(C.gaster)))
	for _, side in { -1, 1 } do
		for i, z in { -0.08, -0.04, 0.0 } do
			local hip = v(0.03 * side, 0, z)
			local a = math.rad(({ 40, 90, 135 })[i])
			local d = v(math.sin(a) * side, 0, -math.cos(a))
			local knee = hip + d * 0.07 + v(0, 0.05, 0)
			local foot = hip + d * 0.17 + v(0, -ANT_HOVER, 0)
			local word = if side < 0 then "L" else "R"
			local up = rodSpec(`Femur{word}{i}`, hip, knee, 0.012, hex(C.leg), "leg", side, i)
			local down = rodSpec(`Tibia{word}{i}`, knee, foot, 0.01, hex(C.leg), "leg", side, i)
			up.hip = hip; down.hip = hip
			table.insert(out, up)
			table.insert(out, down)
		end
		if tier ~= "low" then
			local base = v(0.03 * side, 0.05, -0.19)
			local elbow = base + v(0.05 * side, 0.03, -0.04)
			table.insert(out, rodSpec(`Scape{side}`, base, elbow, 0.01, hex(C.antenna), nil, side, 0))
			table.insert(out, rodSpec(`Flagellum{side}`, elbow, elbow + v(0.04 * side, -0.02, -0.07), 0.01, hex(C.antenna), nil, side, 0))
		end
	end
	return out
end

-- (ROBLOX-122) The water strider: its body, the front legs held up, the middle and hind legs spread out over the water on their thighs and resting on it, a dimple
-- under each of their feet (full tier). Its body's middle rides Prey/Skater.HOVER over the surface.
local SKATER_HOVER = 0.15
local function buildSkater(tier: string): { Spec }
	local C = BugBodies.ambient.skater.colors
	local out: { Spec } = {}
	table.insert(out, ball("Body", v(0, 0, 0.05), v(0.16, 0.1, 0.95), hex(C.body)))
	table.insert(out, ball("Head", v(0, 0.01, -0.5), v(0.1, 0.08, 0.14), hex(C.body)))
	for _, side in { -1, 1 } do
		local word = if side < 0 then "L" else "R"
		-- the front legs, short, up and forward
		table.insert(out, rodSpec(`Front{word}`, v(0.05 * side, 0, -0.32), v(0.14 * side, -0.02, -0.62), 0.02, hex(C.leg), nil, side, 1))
		-- the middle legs: the oars, long, out and back; the hind legs trailing
		for i, leg in { { from = v(0.06 * side, 0, -0.12), knee = v(0.7 * side, 0.05, -0.05), foot = v(1.5 * side, -SKATER_HOVER, 0.35) },
			{ from = v(0.06 * side, 0, 0.0), knee = v(0.5 * side, 0.04, 0.45), foot = v(0.75 * side, -SKATER_HOVER, 1.35) } } do
			table.insert(out, rodSpec(`Femur{word}{i}`, leg.from, leg.knee, 0.022, hex(C.leg), nil, side, i + 1))
			table.insert(out, rodSpec(`Tarsus{word}{i}`, leg.knee, leg.foot, 0.016, hex(C.leg), nil, side, i + 1))
			if tier ~= "low" then
				local d = ball(`Dimple{word}{i}`, leg.foot + v(0, 0.005, 0), v(0.4, 0.01, 0.4), hex(C.dimple))
				d.material = "Glass"
				table.insert(out, d)
			end
		end
	end
	return out
end

local BUILDERS = { ladybird = buildLadybird, millipede = buildMillipede, snail = buildSnail, harvestman = buildHarvestman, ant = buildAnt, skater = buildSkater } :: { [string]: (string) -> { Spec } }

-- (ROBLOX-105) How many parts a creature of `kind` is drawn with at `tier` ("full" or "low"): what World/Garden.AMBIENT's budgets are held against.
function BugBodies.partsOf(kind: string, tier: string?): number
	if kind == "woodlouse" then return BugBodies.PARTS end
	return #BUILDERS[kind](tier or "full")
end

-- `tier` (ROBLOX-105): the client's detail tier, for the ambient bugs' sheets ("full" when not given); the woodlouse is the same at both.
function BugBodies.new(parent: Instance, tier: string?): any
	local folder = Instance.new("Folder")
	folder.Name = "Bugs"
	folder.Parent = parent
	return setmetatable({ folder = folder, rigs = {}, template = build(), templates = {}, tier = tier or "full", parts = {}, frames = {} }, BugBodies)
end

-- The sheet of a kind at this tier.
function BugBodies.templateOf(self: any, kind: string): { Spec }
	if kind == "woodlouse" then return self.template end
	local t = self.templates[kind]
	if t == nil then
		t = BUILDERS[kind](self.tier)
		self.templates[kind] = t
	end
	return t
end

-- One creature's parts (`kind` nil: a woodlouse).
function BugBodies.spawn(self: any, id: string, kind: string?): any
	local k = kind or "woodlouse"
	local folder = Instance.new("Folder")
	folder.Name = id
	folder.Parent = self.folder
	local parts: { Part } = {}
	local template = self:templateOf(k)
	for i, spec in template do
		local part: Part
		if spec.rod then
			part = Shapes.block(folder, spec.name, spec.size, spec.frame, spec.color, spec.material or "SmoothPlastic")
			part.Shape = Enum.PartType.Cylinder
		elseif spec.role == "trail" then
			part = Shapes.block(folder, spec.name, spec.size, spec.frame, spec.color, spec.material or "SmoothPlastic")
			part.Transparency = 1
		else
			part = Shapes.ellipsoid(folder, spec.name, spec.size, spec.frame, spec.color, spec.material or "SmoothPlastic")
		end
		parts[i] = part
	end
	local rig = { kind = k, template = template, folder = folder, parts = parts, stride = 0, gait = 0, t = 0, owed = 0, drawn = false, lastPos = nil :: Vector3?,
		seed = (#id * 1.37) % (2 * math.pi), clear = {} :: { [number]: number } }
	self.rigs[id] = rig
	return rig
end

-- (ROBLOX-103) how a part moves this drawing (a leg about its hip, an antenna about its base), or nil
local function moveOf(spec: Spec, rig: any, reduced: boolean): CFrame?
	local hip = spec.hip
	if hip == nil then return nil end
	local M = BugBodies.look.motion
	local side = spec.side or 1
	if spec.pair == 0 then
		if reduced then return nil end
		local A = M.antenna
		local up = A.amp * math.sin(rig.t * A.hz * 2 * math.pi * (1 + rig.gait) + rig.seed + side)
		local out = A.amp * 0.5 * math.sin(rig.t * A.hz * 1.4 * math.pi + rig.seed * 1.7) * side
		return CFrame.new(hip) * CFrame.fromAxisAngle(Vector3.xAxis, up) * CFrame.fromAxisAngle(Vector3.yAxis, out) * CFrame.new(-hip)
	end
	if rig.gait <= 0 then return nil end
	local G = M.gait
	local phase = rig.stride - (spec.pair or 1) * G.wave + (if side < 0 then math.pi else 0)
	local swing = rig.gait * G.swing * math.sin(phase)
	local lift = rig.gait * G.lift * math.max(0, math.cos(phase))
	return CFrame.new(hip) * CFrame.fromAxisAngle(Vector3.yAxis, side * swing) * CFrame.fromAxisAngle(Vector3.zAxis, side * lift) * CFrame.new(-hip)
end

-- (ROBLOX-105) a leg's step about its hip for a gait `G` at `phase`, or nil standing
local function stepAbout(hip: Vector3, side: number, gait: number, G: any, phase: number): CFrame?
	if gait <= 0 then return nil end
	local swing = gait * G.swing * math.sin(phase)
	local lift = gait * G.lift * math.max(0, math.cos(phase))
	return CFrame.new(hip) * CFrame.fromAxisAngle(Vector3.yAxis, side * swing) * CFrame.fromAxisAngle(Vector3.zAxis, side * lift) * CFrame.new(-hip)
end
-- an antenna's sway about its base, or nil in Reduced Motion
local function sway(spec: Spec, rig: any, A: any, reduced: boolean): CFrame?
	if reduced or spec.hip == nil then return nil end
	local side = spec.side or 1
	local hip = spec.hip :: Vector3
	local up = A.amp * math.sin(rig.t * A.hz * 2 * math.pi * (1 + rig.gait) + rig.seed + side)
	local out = A.amp * 0.5 * math.sin(rig.t * A.hz * 1.4 * math.pi + rig.seed * 1.7) * side
	return CFrame.new(hip) * CFrame.fromAxisAngle(Vector3.xAxis, up) * CFrame.fromAxisAngle(Vector3.yAxis, out) * CFrame.new(-hip)
end

-- A body frame at `pos` facing `heading` laid on the surface whose normal is `normal`.
local function surfaceFrame(pos: Vector3, heading: Vector3, normal: Vector3): CFrame
	local n = if normal.Magnitude > 1e-6 then normal.Unit else Vector3.yAxis
	local h = heading - n * heading:Dot(n)
	if h.Magnitude < 1e-4 then
		h = (if math.abs(n.Y) > 0.9 then -Vector3.zAxis else Vector3.yAxis)
		h = h - n * h:Dot(n)
	end
	return CFrame.lookAt(pos, pos + h.Unit, n)
end

-- The point and the direction toward the head at arc distance `s` back along a millipede's track (its head, then its trail; straight on past the end).
local function along(track: { Vector3 }, s: number): (Vector3, Vector3)
	local left = s
	for i = 1, #track - 1 do
		local a, b = track[i], track[i + 1]
		local d = (b - a).Magnitude
		if d > 1e-6 then
			if left <= d then return a:Lerp(b, left / d), (a - b) / d end
			left -= d
		end
	end
	local last = track[#track]
	local dir = if #track >= 2 and (track[#track - 1] - last).Magnitude > 1e-6 then (track[#track - 1] - last).Unit else Vector3.zAxis
	return last - dir * left, dir
end

-- The ladybird's frames.
local function poseLadybird(rig: any, b: any, reduced: boolean, now: number): { CFrame }
	local S = BugBodies.ambient.ladybird
	local body = surfaceFrame(b.position, b.heading, b.normal)
	local bleeding = (b.bleedUntil or -1) > (now or 0)
	local out = {}
	for i, spec in rig.template do
		local f = spec.frame
		if spec.role == "leg" then
			local phase = rig.stride + (if ((spec.pair or 1) + (if (spec.side or 1) < 0 then 0 else 1)) % 2 == 0 then 0 else math.pi)
			local m = stepAbout(spec.hip :: Vector3, spec.side or 1, rig.gait, S.motion.gait, phase)
			if m ~= nil then f = m * f end
		elseif spec.role == "antenna" then
			local m = sway(spec, rig, S.motion.antenna, reduced)
			if m ~= nil then f = m * f end
		elseif spec.role == "head" and b.state == "eat" and not reduced then
			f = CFrame.new(0, 0.012 * math.sin(rig.t * 9), -0.01 * math.abs(math.sin(rig.t * 4.5))) * f
		elseif spec.role == "drop" and not bleeding then
			f = CFrame.new(0, -0.02, 0.05) -- inside the body
		end
		out[i] = body * f
	end
	return out
end

-- The spiral the coiled millipede winds into: for each ring k (0 the head), its place in the spiral's plane (x, z) and the way it faces, round the head.
local spiralCache: { { x: number, z: number, tx: number, tz: number } }? = nil
local function spiral(): { { x: number, z: number, tx: number, tz: number } }
	if spiralCache ~= nil then return spiralCache end
	local C = BugBodies.ambient.millipede.coil
	local out = {}
	local theta, r = 0, C.inner
	local b = C.pitch / (2 * math.pi)
	local spacing = 0.19
	table.insert(out, { x = 0, z = 0, tx = 0, tz = -1 })
	local s = 0
	local target = spacing
	local px, pz = r, 0
	for k = 1, 12 do
		target = k * spacing
		while s < target do
			local dt = 0.01
			theta += dt
			r = C.inner + b * theta
			local nx, nz = r * math.cos(theta), r * math.sin(theta)
			s += math.sqrt((nx - px) ^ 2 + (nz - pz) ^ 2)
			px, pz = nx, nz
		end
		-- the ring faces back along the spiral toward the head
		local tx, tz = -math.sin(theta) * r - b * math.cos(theta), math.cos(theta) * r - b * math.sin(theta)
		local m = math.sqrt(tx * tx + tz * tz)
		table.insert(out, { x = px, z = pz, tx = -tx / m, tz = -tz / m })
	end
	spiralCache = out
	return out
end

-- The millipede's frames: the rings along the track, wound into the spiral as it coils.
local function poseMillipede(rig: any, b: any, reduced: boolean): { CFrame }
	local S = BugBodies.ambient.millipede
	local G = S.motion.gait
	local spacing = 0.19
	local track: { Vector3 } = { b.position }
	for _, p in b.trail or {} do table.insert(track, p) end
	local c = math.clamp(b.coil or 0, 0, 1)
	c = c * c * (3 - 2 * c)
	local under = if b.hidden then Vector3.new(0, -BugBodies.UNDER, 0) else Vector3.zero
	local head = b.position
	local fwd0 = Vector3.new(b.heading.X, 0, b.heading.Z)
	if fwd0.Magnitude < 1e-4 then fwd0 = -Vector3.zAxis end
	fwd0 = fwd0.Unit
	local right = fwd0:Cross(Vector3.yAxis)
	local sp = spiral()
	local frames: { [number]: CFrame } = {}
	for k = 0, 12 do
		local p, toward = along(track, k * spacing + (if k == 0 then 0 else 0.03))
		if c > 0 then
			local q = sp[k + 1]
			local coilP = head + right * q.x + fwd0 * (-q.z) -- (the spiral's z is laid along the head's back)
			local coilT = (right * q.tx + fwd0 * (-q.tz))
			p = p:Lerp(coilP, c)
			local t = toward:Lerp(coilT, c)
			toward = if t.Magnitude > 1e-4 then t.Unit else toward
		end
		local flatT = Vector3.new(toward.X, 0, toward.Z)
		if flatT.Magnitude < 1e-4 then flatT = fwd0 end
		frames[k] = CFrame.lookAt(p + under, p + under + flatT.Unit, Vector3.yAxis)
	end
	local out = {}
	for i, spec in rig.template do
		if spec.role == "mhead" then
			out[i] = frames[0] * CFrame.new(0, 0, -0.06)
		elseif spec.role == "mantenna" then
			local m = sway(spec, rig, S.motion.antenna, reduced or c > 0.5)
			out[i] = frames[0] * (if m ~= nil then m * spec.frame else spec.frame)
		elseif spec.role == "ring" then
			out[i] = frames[spec.ring :: number]
		elseif spec.role == "rleg" then
			local k = spec.ring :: number
			local f = spec.frame
			if c > 0.05 then
				f = CFrame.new(0, 0.03 * c, 0) * f -- (coiled: the legs are drawn in under the rings)
			else
				local m = stepAbout(spec.hip :: Vector3, spec.side or 1, rig.gait, G, rig.stride - k * G.wave - (if (spec.pair or 0) % 2 == 0 then 0 else G.wave * 0.5))
				if m ~= nil then f = m * f end
			end
			out[i] = frames[k] * f
		else
			out[i] = frames[0] * spec.frame
		end
	end
	return out
end

-- The snail's frames, and its trail's transparencies (set on the parts here when they change).
local function poseSnail(rig: any, b: any, reduced: boolean, now: number): { CFrame }
	local S = BugBodies.ambient.snail
	local body = surfaceFrame(b.position, b.heading, b.normal)
	local inShell = b.state == "shell"
	local eyes = math.clamp(b.eyes or 1, 0, 1)
	local out = {}
	local trailIdx = 0
	for i, spec in rig.template do
		local f = spec.frame
		if inShell and (spec.role == "soft" or spec.role == "stalk" or spec.role == "eye" or spec.role == "feeler") then
			f = CFrame.new(SHELL_AT) -- withdrawn: the soft parts inside the shell
			out[i] = body * f
		elseif spec.role == "stalk" then
			local a, tip = spec.a :: Vector3, spec.b :: Vector3
			local dir = (tip - a).Unit
			if eyes >= 0.5 then
				-- drawing in: the rod slides back into the head along its axis, its tip coming down toward the base
				out[i] = body * CFrame.new(-dir * (S.stalk * (1 - eyes))) * f
			else
				out[i] = body * CFrame.new(0.12 * (spec.side or 1), 0.42, -2.0) * CFrame.Angles(0, math.pi / 2, 0) -- (in: laid along the head, inside it)
			end
		elseif spec.role == "eye" then
			local side = spec.side or 1
			local base = Vector3.new(0.2 * side, 0.62, -2.25)
			local dir = Vector3.new(0.25 * side, 0.8, -0.4).Unit
			local wobble = if reduced then 0 else 0.03 * math.sin(rig.t * 0.9 + rig.seed + side)
			if eyes >= 0.15 then
				out[i] = body * CFrame.new(base + dir * (S.stalk * eyes + 0.04) + Vector3.new(wobble, 0, 0))
			else
				out[i] = body * CFrame.new(0.12 * side, 0.42, -2.1) -- (the eye drawn in with its stalk)
			end
		elseif spec.role == "feeler" then
			local m = if reduced then nil else sway(spec, rig, { amp = 0.12, hz = 0.5 }, false)
			out[i] = body * (if m ~= nil then m * f else f)
		elseif spec.role == "trail" then
			trailIdx += 1
			local pts = b.trail or {}
			local a: any = if trailIdx == 1 then { p = b.position, n = b.normal, t = now } else pts[trailIdx - 1]
			local c: any = pts[trailIdx]
			local part = rig.parts[i]
			local want = 1
			if a ~= nil and c ~= nil and (a.p - c.p).Magnitude > 1e-3 then
				local mid = (a.p + c.p) / 2 + a.n * (S.trail.thick / 2 + 0.005)
				local along = (c.p - a.p)
				local len = along.Magnitude
				out[i] = CFrame.lookAt(mid, mid + along, a.n) -- (the part's length is the sheet's 0.5, the sim's drop spacing)
				local age = math.max(0, (now or 0) - (c.t or 0))
				want = math.clamp(S.trail.base + (1 - S.trail.base) * age / S.trail.fade, S.trail.base, 1)
				if len > 0.75 then want = 1 end
			else
				out[i] = CFrame.new(b.position.X, BugBodies.AWAY, b.position.Z)
			end
			if math.abs((rig.clear[i] or -1) - want) > 0.01 then
				rig.clear[i] = want
				part.Transparency = want
			end
		else
			out[i] = body * f
		end
	end
	return out
end

-- The harvestman's frames (away by day: far under the world); (ROBLOX-119) the ant's the same way (away in its nest by night), `kind` its sheet.
local function poseHarvestman(rig: any, b: any, _reduced: boolean, kind: string?): { CFrame }
	local S = (BugBodies.ambient :: any)[kind or "harvestman"]
	local out = {}
	if b.hidden then
		local away = CFrame.new(b.position.X, BugBodies.AWAY, b.position.Z)
		for i in rig.template do out[i] = away end
		return out
	end
	local body = surfaceFrame(b.position, b.heading, b.normal)
	for i, spec in rig.template do
		local f = spec.frame
		if spec.role == "leg" then
			local side = spec.side or 1
			local phase = rig.stride + (if ((spec.pair or 1) + (if side < 0 then 0 else 1)) % 2 == 0 then 0 else math.pi)
			local m = stepAbout(spec.hip :: Vector3, side, rig.gait, S.motion.gait, phase)
			if m ~= nil then f = m * f end
		end
		out[i] = body * f
	end
	return out
end

-- The stride a kind's legs cycle over, and the move between drawings that is not a step.
local function gaitOf(kind: string): any
	if kind == "woodlouse" then return BugBodies.look.motion.gait end
	local S = (BugBodies.ambient :: any)[kind]
	return if S.motion ~= nil then S.motion.gait else { stride = 1, settle = 8, jump = 1 }
end

-- Places every creature's parts: `lice` are the sims' (id, position, heading, state; ROBLOX-105: `kind` and the kind's own fields). `now` (ROBLOX-103): the
-- prey's clock, for the steps and the sway (nil: no motion); `cameraAt`: the camera's place, for the far rule; `reduced`: Reduced Motion.
function BugBodies.draw(self: any, lice: { any }, now: number?, cameraAt: Vector3?, reduced: boolean?)
	local parts: { BasePart } = self.parts
	local frames: { CFrame } = self.frames
	table.clear(parts)
	table.clear(frames)
	local dtAll = if now ~= nil and self.lastNow ~= nil then math.clamp(now - self.lastNow, 0, 0.25) else 0
	self.lastNow = now
	local present: { [string]: boolean } = {}
	for _, w in lice do
		present[w.id] = true
		local kind = w.kind or "woodlouse"
		local rig = self.rigs[w.id]
		if rig ~= nil and rig.kind ~= kind then rig.folder:Destroy(); self.rigs[w.id] = nil; rig = nil end
		rig = rig or self:spawn(w.id, w.kind)
		rig.owed += dtAll
		if rig.drawn and cameraAt ~= nil and (cameraAt - w.position).Magnitude > FlyLook.far.studs and rig.owed < FlyLook.far.seconds - 1e-6 then continue end
		local dt = rig.owed
		rig.owed, rig.drawn = 0, true
		local G = gaitOf(kind)
		local heading: Vector3 = w.heading
		if heading.Magnitude < 1e-6 then heading = -Vector3.zAxis end
		local position: Vector3 = w.position
		-- the steps: from the ground covered since the last drawing (none under cover or away, none in a jump of more than `jump`, none coiled)
		local moved = if rig.lastPos ~= nil then (if kind == "woodlouse" then Vector3.new(position.X - rig.lastPos.X, 0, position.Z - rig.lastPos.Z).Magnitude else (position - rig.lastPos).Magnitude) else 0
		rig.lastPos = position
		if dt > 0 then
			if moved > G.jump or w.state == "hidden" or w.hidden == true or (w.coil or 0) > 0.05 then moved = 0 end
			if moved > 1e-5 then rig.stride = (rig.stride + moved / G.stride * 2 * math.pi) % (2 * math.pi) end
			local want = if moved > 1e-5 then 1 else 0
			rig.gait += (want - rig.gait) * math.min(1, dt * G.settle)
			if want == 0 and rig.gait < 0.02 then rig.gait = 0 end
			rig.t += dt
		end
		if kind == "woodlouse" then
			if w.state == "hidden" then position -= Vector3.new(0, BugBodies.UNDER, 0) end
			local body = CFrame.lookAt(position, position + heading, Vector3.yAxis)
			for i, part in rig.parts do
				local spec = rig.template[i]
				local move = moveOf(spec, rig, reduced == true)
				table.insert(parts, part)
				table.insert(frames, body * (if move ~= nil then move * spec.frame else spec.frame))
			end
		else
			local list: { CFrame }
			if kind == "ladybird" then list = poseLadybird(rig, w, reduced == true, now or 0)
			elseif kind == "millipede" then list = poseMillipede(rig, w, reduced == true)
			elseif kind == "snail" then list = poseSnail(rig, w, reduced == true, now or 0)
			elseif kind == "ant" then list = poseHarvestman(rig, w, reduced == true, "ant")
			elseif kind == "skater" then list = poseHarvestman(rig, w, reduced == true, "skater")
			else list = poseHarvestman(rig, w, reduced == true) end
			for i, part in rig.parts do
				table.insert(parts, part)
				table.insert(frames, list[i])
			end
		end
	end
	for id, rig in self.rigs do
		if not present[id] then
			rig.folder:Destroy()
			self.rigs[id] = nil
		end
	end
	if #parts > 0 then Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
	self.moved = #parts -- (ROBLOX-111: the parts placed this frame, for the self-test's frame profile)
end

return BugBodies
