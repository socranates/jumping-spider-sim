-- Port check: the Luau JumpMath and SupportMath against values produced by the Godot game's own jump_math.gd.
-- Run from roblox_port/:  luau tests/run.luau
local shim = require("./shim")
_G.Vector3 = shim.Vector3
_G.CFrame = shim.CFrame
local JumpMath = require("../src/Shared/Movement/JumpMath")
local SupportMath = require("../src/Shared/Movement/SupportMath")
local ref = require("./jump_reference")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end
local function near(a: number, b: number, eps: number): boolean
	return math.abs(a - b) <= eps
end
local function v(t) return Vector3.new(t[1], t[2], t[3]) end

-- Godot's Vector3 is single precision, so values agree to float32 rounding (about 1e-7 relative), not bit for bit.
local F32 = 2e-5
local g = Vector3.new(0, ref.gravity, 0)
for i, c in ref.cases do
	local r = JumpMath.solve(v(c.p0), v(c.seat), v(c.ln), v(c.tn), g, ref.dt, ref.t_min, ref.t_max, ref.max_speed)
	check(r.reason == c.reason, `case {i}: reason {r.reason} == {c.reason}`)
	check(#r.valid == c.count, `case {i}: {#r.valid} solutions == {c.count}`)
	if c.minSpeed >= 0 then
		check(near(r.minSpeed, c.minSpeed, F32 * c.minSpeed), `case {i}: min speed {r.minSpeed} == {c.minSpeed}`)
	end
	if c.steps > 0 then
		local s = r.valid[1]
		check(s.steps == c.steps, `case {i}: steps {s.steps} == {c.steps}`)
		check(near(s.speed, c.speed, F32 * c.speed), `case {i}: speed {s.speed} == {c.speed}`)
		check((s.velocity - v(c.v)).Magnitude < F32 * c.speed, `case {i}: launch velocity matches`)
		-- Flying the discrete tick loop lands exactly on the seat.
		local path = JumpMath.path(v(c.p0), s.velocity, g, ref.dt, s.steps)
		check((path[#path] - v(c.seat)).Magnitude < 1e-9, `case {i}: tick loop lands on the seat`)
	end
end

local up = Vector3.new(0, 1, 0)
check(JumpMath.isStanding(up) and not JumpMath.isStanding(Vector3.new(1, 0, 0)), "floor stands, wall does not")
check(JumpMath.minApproach(Vector3.new(1, 0, 0)) == 0.3, "walls need 0.3 approach")
local t = SupportMath.tangentDir(Vector3.new(1, 1, 0), up)
check((t - Vector3.new(1, 0, 0)).Magnitude < 1e-12, "tangentDir drops the normal part")
local r = SupportMath.rotateToward(Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), math.rad(30))
check(near(SupportMath.angleTo(Vector3.new(1, 0, 0), r), math.rad(30), 1e-9), "rotateToward caps the turn")
check(SupportMath.filterNormal(up, Vector3.new(0.01, 1, 0).Unit, 2) == up, "filterNormal ignores tiny changes")

local Appearance = require("../src/Shared/Data/Appearances")
local InputState = require("../src/Shared/Movement/InputState")
local look = Appearance.profiles[Appearance.default]
check(look.body[1] == 0 and look.body[2] == 0 and look.body[3] == 0, "first spider is black")
check(#look.spots == 5 and look.spots[1].rx > look.spots[2].rx * 3, "five spots with large centre")
check(look.spots[2].z < 0 and look.spots[3].z < 0 and look.spots[4].z > 0 and look.spots[5].z > 0, "two front and two rear spots")
check(look.frontLegScale > 1 and look.speckleCount <= 24, "stout front legs and bounded speckles")
local input = InputState.new()
input:set("Forward", true); input:set("Right", true)
local x,y = input:axes()
check(near(x*x+y*y,1,1e-9), "diagonal input normalized")
input:clear(); input:stick(0.1,0)
x,y = input:axes(); check(x == 0 and y == 0, "stick deadzone")
input:stick(0,1); x,y=input:axes(); check(x == 0 and y == 1, "stick full forward")
input:set("Creep", true); input:clear(); x,y=input:axes()
check(x == 0 and y == 0 and not input.held.Creep, "focus loss clears movement and creep")

print(`SUMMARY passed={passed} failed={failed}`)
if failed > 0 then error("port check failed") end
