--!strict
-- The mud dauber wasp's rules: every number of scripts/predator/wasp_director.gd (LIFE round 4, LIFE-14 to LIFE-17), unchanged, in
-- Godot's units (1 WU = 1 stud = 1 cm). They are design choices tuned for fairness, not measurements (LIFE-17): sight range, notice
-- rates, timings and the places it looks. The Godot names are in comments where this file renames them. Predator/WaspDirector reads
-- them; nothing else decides what the wasp does.
--
-- Roblox-only additions are marked "Roblox:". Everything about how it looks is in Data/WaspLook.

local Wasp = {}

export type Point = { id: string, hover: Vector3, land: Vector3? }

-- When it may come: the days and the warm middle of the day (hours of the life clock).
Wasp.firstDay = 2
Wasp.visitChance = 0.6
Wasp.windowFromH = 10.0
Wasp.windowToH = 15.5

-- A visit (game seconds): heard while it arrives, searching, flying away, carrying the spider off.
Wasp.arriveS = 8.0
Wasp.searchS = 45.0
Wasp.leaveS = 5.0
Wasp.carryS = 3.5

-- How it flies: between places at cruising height, in over the window frame from outside.
Wasp.cruiseY = 9.0
Wasp.entry = Vector3.new(38.0, 19.0, 2.0)
Wasp.over = Vector3.new(27.0, 15.0, 2.0)
Wasp.flySpeed = 4.0
Wasp.radius = 0.55 -- WU kept clear of the world on its paths in the air
Wasp.hoverS = { 1.5, 2.5 } -- how long it hovers to look
Wasp.scanDegS = 70.0 -- how fast it turns while it hovers
Wasp.landChance = 0.5
Wasp.landS = 0.6
Wasp.walkS = 2.0
Wasp.walkSpeed = 0.7
Wasp.stepEveryS = 0.5
-- Roblox: the clearance for its steps on a surface. Godot's walk test uses the 0.55 sphere, which the physics engine lets start inside
-- the floor it stands 0.35 above; Roblox's shape casts are not promised to, so a walking wasp is checked with a sphere that fits.
Wasp.walkRadius = 0.3

-- What it sees.
Wasp.sightWu = 7.0
Wasp.noticeStill = 0.25 -- notice per second for a still spider at point-blank range
Wasp.noticeMoving = 1.6 -- added per second at walking speed
Wasp.noticeDecay = 0.2
Wasp.confuseS = 4.0
Wasp.afterLossNotice = 0.35
Wasp.loseUnseenS = 0.8
Wasp.farFromLossWu = 6.0

-- Inspecting and striking.
Wasp.standoffWu = 1.2
Wasp.inspectSpeed = 2.5
Wasp.inspectS = 1.5
Wasp.inspectGiveUpS = 6.0 -- it cannot get to arm's length: it gives up on that spider
Wasp.strikeS = 0.35
Wasp.catchWu = 0.8
Wasp.holdBelow = 0.5

-- The wasp as the spider's senses have it (wasp.gd): its eyes ahead of its centre, the size the senses give it. To the spider it is
-- movement, never prey.
Wasp.eyeAhead = 1.0
Wasp.sensedRadius = 0.9

-- The words and timing of the screen (Godot: caught_panel.gd QUIET_S, LINE_S). Roblox: captionTailS is how long the caption of the wasp
-- leaving stays up and captionFadeS how long it takes to fade.
Wasp.caughtQuietS = 1.5 -- dim and quiet before the line
Wasp.caughtLineS = 1.5 -- the line alone before the summary and the choices
Wasp.caughtDim = 0.82
Wasp.captionTailS = 3.0
Wasp.captionFadeS = 1.0

-- Where it looks for spiders: where it hovers to look and, on open surfaces, where it may land. Every hover point is open straight up
-- to cruising height (tests check them on Godot's boxes; WaspSpec checks them on the real sill).
local points: { Point } = {
	{ id = "floor_middle", hover = Vector3.new(0.0, 1.6, 6.0), land = Vector3.new(0.0, 0.35, 6.0) },
	{ id = "floor_east", hover = Vector3.new(14.0, 1.6, 7.0), land = Vector3.new(14.0, 0.35, 7.0) },
	{ id = "floor_west", hover = Vector3.new(-13.0, 1.6, 7.0), land = Vector3.new(-13.0, 0.35, 7.0) },
	{ id = "floor_back", hover = Vector3.new(-7.0, 1.6, -9.0), land = Vector3.new(-7.0, 0.35, -9.0) },
	{ id = "leaf_west", hover = Vector3.new(-15.0, 5.7, -1.5), land = Vector3.new(-15.0, 4.55, -1.5) },
	{ id = "leaf_middle", hover = Vector3.new(-1.0, 5.7, -1.5), land = Vector3.new(-1.0, 4.55, -1.5) },
	{ id = "leaf_east", hover = Vector3.new(21.5, 6.9, -3.0), land = Vector3.new(21.5, 5.75, -3.0) },
	{ id = "planter", hover = Vector3.new(10.0, 6.1, -4.0), land = Vector3.new(10.0, 4.95, -4.0) },
	{ id = "back_wall_west", hover = Vector3.new(-12.0, 5.0, -11.2) },
	{ id = "back_wall_east", hover = Vector3.new(12.0, 7.0, -11.2) },
	{ id = "right_wall", hover = Vector3.new(28.6, 4.0, 5.0) },
	{ id = "under_leaf_middle", hover = Vector3.new(-1.0, 2.4, 2.3) },
	{ id = "under_leaf_west", hover = Vector3.new(-15.0, 2.4, 2.3) },
	{ id = "planter_front", hover = Vector3.new(10.0, 2.0, 1.5) },
	{ id = "crack_mouth", hover = Vector3.new(-20.8, 1.6, 6.0) },
}
Wasp.points = table.freeze(points)

return Wasp
