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
print(`BOXWORLD passed={passed} failed={failed}`)
if failed > 0 then error("box-world scenarios failed") end
