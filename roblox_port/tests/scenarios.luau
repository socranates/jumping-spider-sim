-- Recovery scenarios against the box world (tests/shim.luau): the real SpiderMotor, SilkController and JumpInput run tick by
-- tick on the windowsill's own boxes (WindowsillLayout.PIECES), with Workspace queries emulated for axis-aligned boxes.
-- A smoke test of the motor's code paths and decisions, deterministic and runnable anywhere. It is not the Roblox engine:
-- tests/studio/RecoverySpec.luau runs the same scenarios against real raycasts and sphere casts in Studio.
local Motor = require("../src/Shared/Movement/SpiderMotor")
local JumpInput = require("../src/Shared/Movement/JumpInput")
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL boxworld: " .. what) end
end

local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
local sill = BoxWorld.folder("Windowsill", pieces)
local function newMotor()
	return Motor.new({ world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
		heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX })
end
local function input(t)
	local i = Motor.idleInput()
	for k, v in t or {} do i[k] = v end
	return i
end
local function run(m, ticks, inp, stop)
	for n = 1, ticks do
		m:tick(input(inp))
		if stop and stop(m) then return n end
	end
	return ticks
end

do
	local m = newMotor()
	run(m, 60)
	check(m.mode == "attached" and math.abs(m.pos.Y - 0.31) < 1e-6, "the spider stands on the sill at spawn")
	local start = m.pos
	run(m, 60, { wish = Vector3.xAxis })
	check(m.mode == "attached" and m.pos.X > start.X + 1 and math.abs(m.pos.Y - 0.31) < 1e-6, "it walks along the sill")
	local hop = m:hopPlan()
	check(hop.kind == "reachable" and hop.steps > 0, `a hop ahead on the open sill is reachable ({hop.kind} {hop.reason})`)
end

print(`BOXWORLD passed={passed} failed={failed}`)
if failed > 0 then error("box-world scenarios failed") end
