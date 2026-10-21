--!strict
-- The preserve's map (ROBLOX-115, docs/PARK_WORLD_DESIGN.md sections 4 and 10): a nature preserve of 100 by 60 m in an American city, held between a railway
-- embankment (north), the backs of apartment blocks (east), the street with its railings and gate (south) and a canal towpath beyond a hedge (west). Pure data
-- in metres, as the design draws it (x east, z north, the gate at the south), and the one shift that turns it into the game's studs.
--
-- The shift. One stud is a centimetre. The ranger hut stands just inside the gate (x 44..47.5, z 2..5) with its window in its north wall, and the windowsill in
-- that window is the world's origin, exactly where the sill has always been (Habitat/WindowsillLayout, byte for byte): the window's middle (x 45.75 m) is stud
-- x 0, and the hut's north wall's outer face (z 5 m) is stud z -16 (the sill's back frame is at z -13.5..-12.5 and the hut's log wall runs from its cladding at
-- -16 to its lining at 12.5, where the sill's front lip is). North is -z, so the window looks out north into the preserve as the sill's always looked out at -z;
-- east is +x. The ground outside is GROUND_Y (85 cm under the sill), the hut's floor FLOOR_Y (70 cm under it, the hut on a 15 cm sleeper base), its eaves
-- EAVES_Y (2.4 m over the ground).
--
-- Precision (design section 3 and 8): everything drawn stays within LIMIT studs of the origin on every axis, where a float's step is about 0.0005 studs.
-- The preserve's far corners are 5,425 east, 4,575 west, 5,516 north and 484 south; the city beyond is drawn only as far as LIMIT, and its distant towers are
-- impostors at the edge (World/PreserveLook says how).
--
-- What is here: ZONES, the drawn backdrop's pieces of the map, each streamed as one look (World/LookPlan: near at full, far as its cheap masses); HOME_RANGES,
-- the ten home ranges of the design's table (only the hut's sill is walkable in Phase A); CORRIDORS, the ways between them; and the features every look places
-- from (the oak, the pond, the paths, the wall, the hut).
local Preserve = {}

-- The shift: the window's middle and the hut's north face in metres, and the studs they become.
Preserve.ORIGIN_X_M = 45.75
Preserve.NORTH_FACE_M = 5.0
Preserve.NORTH_FACE_Z = -16
Preserve.GROUND_Y = -85
Preserve.FLOOR_Y = -70
Preserve.EAVES_Y = 155
Preserve.LIMIT = 6000

-- The preserve's own extent (metres): 100 by 60.
Preserve.SIZE = table.freeze({ x = 100, z = 60 })

-- Studs from metres: `xm` east, `zm` north, `ym` metres above the ground outside (0 by default).
function Preserve.at(xm: number, zm: number, ym: number?): Vector3
	return Vector3.new((xm - Preserve.ORIGIN_X_M) * 100, Preserve.GROUND_Y + (ym or 0) * 100, Preserve.NORTH_FACE_Z - (zm - Preserve.NORTH_FACE_M) * 100)
end

-- Metres from studs (the inverse of `at`): x east, z north, y over the ground.
function Preserve.metres(p: Vector3): (number, number, number)
	return p.X / 100 + Preserve.ORIGIN_X_M, Preserve.NORTH_FACE_M - (p.Z - Preserve.NORTH_FACE_Z) / 100, (p.Y - Preserve.GROUND_Y) / 100
end

-- A box in studs from a rectangle in metres (x0..x1 east, z0..z1 north) and heights in metres over the ground: `min, max`.
function Preserve.box(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number): (Vector3, Vector3)
	local a, b = Preserve.at(x0, z0, y0), Preserve.at(x1, z1, y1)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)), Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end

-- ---------------------------------------------------------------- the zones of the backdrop
-- Each zone is drawn only (Phase A: nothing in it can be walked) and streamed as one look. `x`, `z`: its rectangle in metres; `y`: how high its things stand
-- over the ground, metres. Listed nearest the hut first (a tie in the plan's distance keeps this order).
export type Zone = { id: string, name: string, x: { number }, z: { number }, y: { number } }
local function zone(id: string, name: string, x0: number, x1: number, z0: number, z1: number, y0: number, y1: number): Zone
	return table.freeze({ id = id, name = name, x = table.freeze({ x0, x1 }), z = table.freeze({ z0, z1 }), y = table.freeze({ y0, y1 }) })
end
Preserve.ZONES = table.freeze({
	zone("hut", "The ranger hut", 42, 50, -1, 7, -0.2, 3.6), -- the hut, the bench and water butt under its window, the info board and the bike rack by the gate
	zone("hut_garden", "The hut garden", 38, 52, 6, 14, 0, 2.6), -- herb border, pallet planters, the bird feeder
	zone("bench", "The bench, bin and lamppost", 37, 43, 14, 18.5, 0, 4.6),
	zone("ground", "The ground and the paths", 0, 100, 0, 60, -0.3, 1.9), -- the mown grass, the meadow's and the wood's floors, the paths, the boundary fences
	zone("meadow", "The wildflower meadow", 24, 61, 17, 49, 0, 1.8),
	zone("pond", "The pond and the boardwalk", 60, 80, 28, 45, -0.4, 2.6),
	zone("compost", "The compost bays and the tool shed", 1, 9, 2, 10, 0, 2.9),
	zone("woodland", "The woodland and the veteran oak", 0, 23, 5, 56, 0, 21),
	zone("wall", "The stone retaining wall", 90, 100, 4, 56, 0, 1.7),
	zone("scrub", "The bramble and scrub", 18, 92, 49, 60, 0, 3.4),
	zone("city_south", "The street, the railings and the gate", -12, 105, -14.8, 0, 0, 12),
	zone("city_west", "The hedge and the canal towpath", -14.2, 0, -14, 64, -1.5, 11),
	zone("city_east", "The backs of the apartment blocks", 94, 105.7, -6, 62, 0, 19),
	zone("railway", "The railway embankment", -14.2, 105.7, 60, 64.4, 0, 4.6),
	zone("towers", "The city's towers", -14.2, 105.7, 64.4, 64.8, 0, 32),
}) :: { Zone }

local BY_ID: { [string]: Zone } = {}
for _, z in Preserve.ZONES do BY_ID[z.id] = z end

function Preserve.zone(id: string): Zone?
	return BY_ID[id]
end

-- A zone's box in studs: `min, max`.
function Preserve.zoneBox(z: Zone): (Vector3, Vector3)
	return Preserve.box(z.x[1], z.x[2], z.z[1], z.z[2], z.y[1], z.y[2])
end

-- ---------------------------------------------------------------- the home ranges (design section 4's table; only the first is walkable in Phase A)
-- `n` the design's number, `zone` the backdrop zone it lies in, `at` its middle (metres x, z), `size` its core (metres across).
export type HomeRange = { n: number, id: string, name: string, zone: string, at: { number }, size: number }
local function home(n: number, id: string, name: string, zoneId: string, x: number, z: number, size: number): HomeRange
	return table.freeze({ n = n, id = id, name = name, zone = zoneId, at = table.freeze({ x, z }), size = size })
end
Preserve.HOME_RANGES = table.freeze({
	home(1, "ranger_hut", "Ranger hut", "hut", 45.75, 3.5, 3.5),
	home(2, "hut_garden", "Hut garden", "hut_garden", 45.75, 7, 4), -- (ROBLOX-116: in front of the north window, World/Hut's core: x 43.75..47.75, z 5..9)
	home(3, "meadow", "Meadow", "meadow", 31, 40, 5),
	home(4, "pond_edge", "Pond edge", "pond", 77, 42, 4),
	home(5, "log_pile", "Log pile and woodland floor", "woodland", 10, 29.5, 4),
	home(6, "veteran_oak", "Veteran oak", "woodland", 14, 42, 3),
	home(7, "stone_wall", "Stone retaining wall", "wall", 92, 50, 5),
	home(8, "bench", "The bench, bin and lamppost", "bench", 40, 16, 3),
	home(9, "bramble", "Bramble and railway bank", "scrub", 80, 56, 4),
	home(10, "compost", "Compost and tool shed", "compost", 5, 6, 4),
}) :: { HomeRange }

-- ---------------------------------------------------------------- the corridors (design section 4: the ways between the home ranges)
-- Polylines in metres (x, z); `kind` says what a spider walks there (Phase C onward). The mown paths are the preserve's plan's (docs/preserve_plan.html).
export type Corridor = { id: string, kind: string, points: { { number } }, width: number }
local function corridor(id: string, kind: string, width: number, points: { { number } }): Corridor
	for _, p in points do table.freeze(p) end
	return table.freeze({ id = id, kind = kind, width = width, points = table.freeze(points) })
end
Preserve.CORRIDORS = table.freeze({
	-- the path from the gate past the hut, round the meadow and to the pond, and its cross path (mown grass and fine gravel, 1.4 m wide)
	corridor("path_gate", "gravel", 1.6, { { 45.5, 0 }, { 45.5, 1.4 } }), -- (from the gate to the hut's door, in its south wall)
	corridor("path_loop", "mown", 1.4, { { 45.5, 13 }, { 44.6, 15.4 }, { 40, 16 }, { 22, 16 }, { 20.4, 17.6 }, { 20, 20 }, { 20, 46 }, { 21.2, 48.4 },
		{ 24, 49 }, { 58, 49 }, { 60.4, 47.8 }, { 61, 46 }, { 61, 30 } }),
	corridor("path_cross", "mown", 1.4, { { 45.5, 13 }, { 58, 13 }, { 60.4, 14.2 }, { 61, 16 }, { 61, 29 } }),
	-- (round the hut's east end and in through the hut garden's core, World/Hut's gravel path: west along z 6.71 and north along x 45.15, 0.5 to 0.6 m wide; its points
	-- break at the core's edges, x 47.75 and z 9, ROBLOX-116. ROBLOX-117: walkable round the east end too, World/Hut.WALK: along the south wall's foot at z 1.67 from
	-- the door, north along x 48.4 and in at z 6.55)
	corridor("path_hut", "gravel", 0.6, { { 45.5, 1.67 }, { 48.4, 1.67 }, { 48.4, 6.55 }, { 47.75, 6.55 }, { 45.15, 6.55 }, { 45.15, 9 }, { 45.15, 13 } }),
	corridor("boardwalk", "boardwalk", 1.5, { { 61, 30 }, { 79, 30 } }),
	corridor("path_wall", "mown", 1.2, { { 79, 30 }, { 90, 30 } }),
	corridor("hedge_base", "hedge", 0.8, { { 0.6, 1 }, { 0.6, 59 } }),
	corridor("wall_top", "stone", 0.5, { { 93, 5 }, { 93, 55 } }),
	corridor("fence_rail", "fence", 0.1, { { 0, 60 }, { 100, 60 } }),
	corridor("hut_gutter", "gutter", 0.12, { { 44, 5.2 }, { 47.5, 5.2 } }),
}) :: { Corridor }

-- ---------------------------------------------------------------- features the looks place from (metres)
Preserve.HUT = table.freeze({ x = table.freeze({ 44, 47.5 }), z = table.freeze({ 2, 5 }), wall = 0.285 }) -- a log hut: walls 28.5 cm, the sill's reveal
Preserve.GATE = table.freeze({ x = table.freeze({ 44.3, 46.9 }), z = 0 })
Preserve.OAK = table.freeze({ x = 14, z = 42, trunk = 1.3, height = 19.5, crown = 22 }) -- a bur oak: trunk 1.3 m across, 19.5 m tall, its crown 22 m across
Preserve.POND = table.freeze({ x = 70, z = 37, rx = 8, rz = 7 })
Preserve.MEADOW = table.freeze({ x = table.freeze({ 25, 60 }), z = table.freeze({ 18, 48 }) })
Preserve.WALL = table.freeze({ x = table.freeze({ 92, 94 }), z = table.freeze({ 5, 55 }), height = 1.2 })
Preserve.BENCH = table.freeze({ x = 40, z = 16 })
Preserve.LOG_PILE = table.freeze({ x = table.freeze({ 8, 12 }), z = table.freeze({ 28, 31 }) })
Preserve.COMPOST = table.freeze({ x = table.freeze({ 2, 8 }), z = table.freeze({ 3, 9 }) })
Preserve.HUT_GARDEN = table.freeze({ x = table.freeze({ 38, 52 }), z = table.freeze({ 6, 14 }) })
Preserve.SCRUB = table.freeze({ x = table.freeze({ 18, 92 }), z = table.freeze({ 50, 60 }) })
-- the railway: the embankment's foot at z 60 (the preserve's fence), its crest 3 m up at z 62.6, the track's middle at z 63.4
Preserve.RAILWAY = table.freeze({ foot = 60, crest = 62.6, height = 3.0, track = 63.4, gauge = 1.435, x = table.freeze({ -14.2, 105.7 }) })

return table.freeze(Preserve)
