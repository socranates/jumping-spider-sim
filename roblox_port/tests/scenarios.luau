-- Recovery scenarios against the box world (tests/shim.luau): tests/studio/RecoveryScenarios.luau run tick by tick on the
-- windowsill's own boxes with Workspace queries emulated for axis-aligned boxes. A deterministic smoke test of the real
-- motor, silk, jump-input and camera code; not the Roblox engine. Studio runs the same module with real queries.
local deps = {
	Motor = require("../src/Shared/Movement/SpiderMotor"),
	JumpInput = require("../src/Shared/Movement/JumpInput"),
	Layout = require("../src/Shared/Habitat/WindowsillLayout"),
	Species = require("../src/Shared/Data/Species"),
	Surfaces = require("../src/Shared/Data/Surfaces"),
	SpiderCamera = require("../src/Client/SpiderCamera"),
	StickCarry = require("../src/Shared/Movement/StickCarry"),
	cameraFixtures = { 1, 7 },
	log = function(line) print("  " .. line) end,
}
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL boxworld: " .. name .. "\n    " .. tostring(err)) end
end
require("./studio/RecoveryScenarios")(check, deps)
-- Cross-check of the emulation itself: Chet's silk spec, which passed in Windows Studio (docs/verification/roblox-silk),
-- runs unchanged on the box world.
check("Chet's Studio silk spec on the box world", function()
	local rows = {}
	require("./studio/SilkSpec")(function(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then table.insert(rows, name .. ": " .. tostring(err)) end
	end)
	assert(#rows == 0, table.concat(rows, "\n"))
end)
-- ROBLOX-99: the game's let-down is half Godot's reel speed, reeling in is Godot's, and a controller never given the rule replays Godot.
check("the let-down on a line runs at half speed under the game's rule, reeling in and Godot's default untouched", function()
	local Silk = require("../src/Shared/Movement/SilkController")
	local world = Instance.new("Folder"); world.Name = "LowerTestWorld"; world.Parent = workspace
	local function part(name, position, size)
		local b = Instance.new("Part"); b.Name = name; b.Position = position; b.Size = size; b.Anchored = true
		b:SetAttribute("ProfileId", "solid"); b.Parent = world; return b
	end
	part("Floor", Vector3.new(200, -0.5, 0), Vector3.new(30, 1, 20))
	part("Leaf", Vector3.new(200, 5, 0), Vector3.new(4, 0.2, 4))
	local surfaces = { solid = { attachable = true, silk_anchor_allowed = true } }
	local tuning = { max_line_length_wu = 20, reel_speed_wu_s = 1.5 }
	assert(Silk.game.lowerScale == 0.5, "the dial is half")
	-- The leaf drop of Chet's silk spec: off the leaf's east edge, a hang that settles, then a second of letting down and half a second of reeling in.
	local function lowered(rules: boolean): (number, number, number)
		local s = Silk.new(world, surfaces, tuning, 35)
		if rules then s:useGameRules() end
		assert(s.speed == 1.5, "Godot's reel speed is the speed")
		assert(s:startDrop(Vector3.new(201.95, 5.41, 0), Vector3.yAxis, Vector3.xAxis))
		local p, v = Vector3.new(202.36, 5.41, 0), Vector3.new(0.6, 0, 0)
		for _ = 1, 120 do local hit; p, v, hit = s:step(p, v, 0, false); assert(not hit, "landed while hanging") end
		assert(s.taut, "the hang settles taut")
		local r0 = s.rest
		for _ = 1, 60 do local hit; p, v, hit = s:step(p, v, -1, false); assert(not hit, "landed while letting down") end
		local down = s.rest - r0
		local r1 = s.rest
		for _ = 1, 30 do local hit; p, v, hit = s:step(p, v, 1, false); assert(not hit, "landed while reeling in") end
		assert(s.block == "" and not s.snagged, `the reel was refused: {s.block}`)
		return down, r1 - s.rest, s.lowerSpeed
	end
	local godotDown, godotUp, godotSpeed = lowered(false)
	local gameDown, gameUp, gameSpeed = lowered(true)
	assert(math.abs(godotDown - 1.5) < 1e-6, `Godot lets down 1.5 studs a second, not {godotDown}`)
	assert(math.abs(gameDown - 0.75) < 1e-6, `the game lets down 0.75 studs a second, not {gameDown}`)
	assert(math.abs(godotUp - 0.75) < 1e-6 and math.abs(gameUp - godotUp) < 1e-9, `reeling in is Godot's either way: {godotUp} {gameUp}`)
	assert(godotSpeed == 1.5 and gameSpeed == 0.75, `lowerSpeed {godotSpeed} {gameSpeed}`)
	-- The motor hands the rule to its line.
	local Motor = deps.Motor
	local motor = Motor.new({ world = world, surfaces = deps.Surfaces, profile = deps.Species.phidippus_audax_prototype, spawn = Vector3.new(200, 0, 0),
		heading = Vector3.xAxis, boundsMin = Vector3.new(150, -5, -50), boundsMax = Vector3.new(250, 40, 50) })
	assert(motor.silk.lowerSpeed == 1.5, "a motor never given the rule lets down at Godot's speed")
	motor:useGameRules()
	assert(motor.silk.lowerSpeed == 0.75 and motor.silk.speed == 1.5, "the motor's line takes the rule")
	world:Destroy()
end)
-- ROBLOX-107: the let-down from the outer sill's front edge past the brick (the Studio self-test's one failure, v35: "left the line 2.0 s into the
-- let-down, at (2.00, -2.70, -24.07)"). The engine let the body sit 0.07 from the brick face, inside its 0.31 skin; the sweep down then met the rounded
-- edge of the wall box's top, which the outer sill's slab covers at y -3, and the landing rule took it: the spider stood on a sliver. Reproduced here on the
-- real regions' boxes from the very place Studio saw, and with the engine's tangent miss emulated (the shim's Spherecast slop) over a whole let-down.
check("a let-down past the wall keeps its skin and never ends on a sliver (ROBLOX-107)", function()
	local WorldMap = require("../src/Shared/World/WorldMap")
	local WorldBuild = require("../src/Shared/World/WorldBuild")
	local Motor = deps.Motor
	local folder = WorldBuild.world(workspace, WorldMap.SEED)
	local EDGE = Vector3.new(2, 0.31, -23.2)
	local function drop(): any
		local motor = Motor.new({ world = folder, surfaces = deps.Surfaces, profile = deps.Species.phidippus_audax_prototype, spawn = EDGE,
			heading = -Vector3.zAxis, boundsMin = Vector3.new(-50, -95, -80), boundsMax = Vector3.new(50, 40, 20) })
		motor:useGameRules()
		motor:place(EDGE, Vector3.yAxis, -Vector3.zAxis)
		assert(motor:requestDrop(), "the drop was refused at the front edge")
		return motor
	end
	local input = Motor.idleInput()
	input.dropHeld = true
	local slop = (BoxWorld :: any).spherecastSlop
	local ok, err = pcall(function()
		-- 1. Studio's place: two seconds into the let-down the body is put 0.07 from the brick (where the engine had it) and lowered on.
		local motor = drop()
		for _ = 1, 150 do motor:tick(input) end
		assert(motor:onLine(), "not on the line after the drop")
		motor.pos = Vector3.new(2, -2.55, -24.07)
		motor.vel = Vector3.zero
		local skin = math.huge
		for t = 1, 360 do
			motor:tick(input)
			assert(motor:onLine(), string.format("left the line %d ticks after Studio's place, at (%.2f, %.2f, %.2f)", t, motor.pos.X, motor.pos.Y, motor.pos.Z))
			skin = math.min(skin, -24 - motor.pos.Z)
		end
		assert(skin >= 0.3, string.format("the body came within %.3f of the brick", skin))
		assert(motor.pos.Y < -6, `lowered only to {motor.pos.Y}`)
		-- 2. The sliver itself: the sweep down beside the face meets the wall box's covered top, and there is no ground under the body there; over the soil there is.
		local silk = motor.silk
		local seam = workspace:Spherecast(Vector3.new(2, -2.68, -24.07), 0.3, Vector3.new(0, -0.05, 0), silk.params)
		assert(seam ~= nil and seam.Instance.Name == "house_wall" and seam.Normal.Y >= 0.707, "the sweep beside the face meets the wall box's covered top, steep enough to land on")
		assert(not silk:groundUnder(Vector3.new(2, -2.69, -24.07), seam), "ground under a body beside the seam")
		local soil = workspace:Raycast(Vector3.new(2, -89.5, -30), Vector3.new(0, -1, 0), silk.params)
		assert(soil ~= nil and silk:groundUnder(Vector3.new(2, -89.69, -30), soil), "no ground under a body over the soil")
		-- 3. The engine's tangent miss emulated over the whole let-down: the skin is kept, the rate is the game's, and the line ends on the bed's soil.
		slop.value = 0.011
		local m2 = drop()
		local y0 = 0
		local closest = math.huge
		local landed, began = nil, nil
		for t = 1, 60 * 140 do
			m2:tick(input)
			if m2:onLine() and began == nil then began = t end
			if began ~= nil and m2.mode == "attached" then landed = t; break end
			assert(m2:onLine() or t < 30, string.format("off the line at tick %d, (%.2f, %.2f, %.2f)", t, m2.pos.X, m2.pos.Y, m2.pos.Z))
			if t == 120 then y0 = m2.pos.Y end
			if t > 60 then closest = math.min(closest, -24 - m2.pos.Z) end
			if t == 480 then
				local rate = (y0 - m2.pos.Y) / 6
				assert(rate > 0.6 and rate < 0.9, `let down at {rate} studs a second`)
			end
		end
		assert(closest >= 0.29, string.format("with the engine's miss the body came within %.3f of the brick", closest))
		assert(landed ~= nil and math.abs(m2.pos.Y - (-89.69)) < 0.05, string.format("the let-down ended at (%.2f, %.2f, %.2f), not on the soil", m2.pos.X, m2.pos.Y, m2.pos.Z))
		print(string.format("  the let-down past the wall: skin %.3f from Studio's place, %.3f with the engine's miss, on the soil after %.1f s", skin, closest, (landed :: number) / 60))
	end)
	slop.value = 0
	folder:Destroy()
	if not ok then error(err, 0) end
end)
-- ROBLOX-111: the let-down in Studio, v36, ran at 0.559 studs a second where the box world's is 0.752. One way the engine's sweep can cost it that the box world's
-- exact sweep never does: a tangent touch, the sphere reported touching a face it is moving along (here the brick face, the body 0.31 off it, the line hanging
-- plumb from the slab's lip). Stopped there, the move loses the tick's motion (it slides once, and the slide meets the same face). The shim's Spherecast reports
-- such a touch when `spherecastGraze` is set (a face within that much of the sphere that the move is not closing on). With the touch on every sweep and the
-- controller's rule taken out the let-down all but stops; with the rule it is the game's rate and every touch is counted as let pass. With exact sweeps the rule
-- lets nothing pass (it changes nothing in the box world), and the counts the self-test prints add up.
check("a tangent touch of the brick does not stop the let-down (ROBLOX-111)", function()
	local WorldMap = require("../src/Shared/World/WorldMap")
	local WorldBuild = require("../src/Shared/World/WorldBuild")
	local Silk = require("../src/Shared/Movement/SilkController")
	local Motor = deps.Motor
	local folder = WorldBuild.world(workspace, WorldMap.SEED)
	local EDGE = Vector3.new(2, 0.31, -23.2)
	local graze = (BoxWorld :: any).spherecastGraze
	local saved = Silk.grazing
	local input = Motor.idleInput()
	input.dropHeld = true
	-- six seconds of letting down measured a second after the line is caught, with the touch emulated from the moment the spider is on the line
	local function letDown(touch: number): (number, any)
		local motor = Motor.new({ world = folder, surfaces = deps.Surfaces, profile = deps.Species.phidippus_audax_prototype, spawn = EDGE,
			heading = -Vector3.zAxis, boundsMin = Vector3.new(-50, -95, -80), boundsMax = Vector3.new(50, 40, 20) })
		motor:useGameRules()
		motor:place(EDGE, Vector3.yAxis, -Vector3.zAxis)
		assert(motor:requestDrop(), "the drop was refused at the front edge")
		local began, y0, before = nil, 0, nil
		for t = 1, 60 * 12 do
			motor:tick(input)
			if began == nil and motor:onLine() then began = t; graze.value = touch end
			if began ~= nil and t == began + 60 then y0 = motor.pos.Y; before = table.clone(motor.silk.stats) end
			if began ~= nil and t == began + 420 then
				local d = {}
				for k, v in motor.silk.stats do d[k] = v - before[k] end
				graze.value = 0
				return (y0 - motor.pos.Y) / 6, d
			end
		end
		graze.value = 0
		error("the let-down never began")
	end
	local ok, err = pcall(function()
		local exact, de = letDown(0)
		assert(exact > 0.74 and exact < 0.76 and de.grazes == 0, `exact sweeps: {exact} studs a second, {de.grazes} touches let pass`)
		assert(de.ticks == 360 and math.abs(de.letOut - 360 * 0.75 / 60) < 1e-6 and math.abs(de.fell - exact * 6) < 1e-6, "the counts: 360 ticks, the line let out at 0.75, the fall the rate's")
		local touched, dt = letDown(0.02)
		assert(touched > 0.74 and touched < 0.76 and dt.grazes >= 300, `with the touch on every sweep: {touched} studs a second, {dt.grazes} touches let pass`)
		Silk.grazing = function() return false end
		local stopped, ds = letDown(0.02)
		Silk.grazing = saved
		assert(stopped < 0.3 and ds.stops >= 300, `without the rule the touch should stop the let-down: {stopped} studs a second, {ds.stops} stops`)
		print(string.format("  the tangent touch: %.3f studs a second exact, %.3f with a touch on every sweep (%d let pass), %.3f without the rule (%d stops, %.3f taken off)",
			exact, touched, dt.grazes, stopped, ds.stops, ds.stopped))
	end)
	Silk.grazing = saved
	graze.value = 0
	folder:Destroy()
	if not ok then error(err, 0) end
end)
print(`BOXWORLD passed={passed} failed={failed}`)
if failed > 0 then error("box-world scenarios failed") end
