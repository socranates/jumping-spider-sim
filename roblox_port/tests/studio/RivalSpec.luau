--!strict
-- The roaming rival on the engine (ROBLOX-69). The CLI (tests/rivalnav.luau) walks the rival's own SpiderMotor over the sill's boxes on an emulated
-- box world; here the same route graph and drive run on the engine's real raycasts against a private copy of the sill: every place it patrols to
-- is a real face with room for a body, and it walks to the floor, a leaf, the planter's rim and the back wall without entering the retreat.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared.Habitat.WindowsillLayout)
local Species = require(Shared.Data.Species)
local Surfaces = require(Shared.Data.Surfaces)
local Motor = require(Shared.Movement.SpiderMotor)
local Route = require(Shared.Predator.RivalRoute)
local Drive = require(Shared.Predator.RivalDrive)
local Rival = require(Shared.Predator.RivalSpider)

local DT = 1 / 60

return function(check: (string, () -> ()) -> ())
	local world = Instance.new("Folder")
	world.Name = "RivalTestWorld"
	world.Parent = workspace
	for _, b in Layout.PIECES do
		local part = Instance.new("Part")
		part.Name = b.id
		part.Anchored = true
		part.Size = b.hi - b.lo
		part.CFrame = CFrame.new((b.hi + b.lo) * 0.5)
		part.Parent = world
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world }
	local function newMotor(): any
		return Motor.new({ world = world, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Vector3.new(25, 0.31, 8),
			heading = Vector3.new(-1, 0, 0), boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX, probeParent = world })
	end
	local function snapshot(): any
		return { position = Vector3.new(-25, 0.31, 6), previous = Vector3.new(-25, 0.31, 6), up = Vector3.yAxis, grounded = true, heading = Vector3.xAxis,
			day = 3, hour = 12, meals = 2, resting = false, safe = false, wasp = false, gentle = false, moving = false, airborne = false,
			onLine = false, holding = false, striking = false }
	end

	check("RIVAL: every place it patrols to is a real face under a body that fits (real casts)", function()
		local drive = Drive.new(newMotor(), function() return true end)
		assert(#drive.waypoints >= 80, `only {#drive.waypoints} places to patrol to`)
		for i, w in drive.waypoints do
			local centre = w.pos + w.up * Route.SEAT
			local hit = workspace:Raycast(centre, -w.up * 0.8, params)
			assert(hit ~= nil and (hit.Position - w.pos).Magnitude < 0.05, `place {i}: no face under it`)
			assert(not Layout.inRetreat(centre), `place {i} is in the retreat`)
		end
		drive:destroy()
	end)

	check("RIVAL: it walks to the floor, a leaf, the planter's rim and the back wall on real casts and never enters the retreat", function()
		local m = newMotor()
		local d = Drive.new(m, function() return true end)
		local r = Rival.new()
		r.state = "patrol"
		m:place(Vector3.new(25, 0.31, 8), Vector3.yAxis, Vector3.new(-1, 0, 0))
		r.position, r.previous, r.up, r.heading, r.origin = m.pos, m.pos, m.up, m.heading, m.pos
		d.prevState = "patrol"
		local s = snapshot()
		local targets: { any } = {
			{ "sill_floor", function(w: any): boolean return w.pos.X < 0 and w.pos.Z < -2 end },
			{ "leaf_west", function(w: any): boolean return w.up.Y > 0.9 end },
			{ "planter_rim", function(w: any): boolean return w.up.Y > 0.9 end },
			{ "back_frame_west", function(w: any): boolean return w.up.Z > 0.9 end },
		}
		for _, t in targets do
			local goal: any = nil
			for _, w in d.waypoints do
				if Route.faces()[w.face].piece == t[1] and t[2](w) then goal = w break end
			end
			assert(goal ~= nil, `no place on {t[1]}`)
			local before = d.stats.arrivals
			d:_setGoal(goal, "patrol")
			local arrived = false
			for _ = 1, math.floor(200 / DT) do
				Drive.update(d, r, DT, s)
				assert(not Layout.inRetreat(m.pos), `entered the retreat on the way to {t[1]}`)
				if d.stats.arrivals > before then arrived = true break end
				if d.goal == nil then break end
			end
			assert(arrived, `did not reach {t[1]}`)
		end
		d:destroy()
	end)

	world:Destroy()
end
