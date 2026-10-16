--!strict
-- The mud dauber wasp on the engine (ROBLOX-26). The CLI (tests/wasp.luau) replays Godot's director against its goldens on an analytic
-- world and checks the places on the sill's boxes; here the same director and the same places run on real raycasts and real sphere
-- casts against a private copy of the sill, and the drawn wasp is built from real Parts.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WaspDirector = require(Shared.Predator.WaspDirector)
local Data = require(Shared.Data.Wasp)
local Layout = require(Shared.Habitat.WindowsillLayout)
local Species = require(Shared.Data.Species)

local DT = 1 / 60
local OPEN = Vector3.new(2, 0.31, 6)
local CRACK = Vector3.new(-25, 0.31, 6)

return function(check: (string, () -> ()) -> ())
	local world = Instance.new("Folder")
	world.Name = "WaspTestWorld"
	world.Parent = workspace
	for _, b in Layout.PIECES do
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = b.hi - b.lo
		part.CFrame = CFrame.new((b.hi + b.lo) * 0.5)
		part.Parent = world
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world }
	local walk = Species.phidippus_audax_prototype.locomotion.walk_speed_wu_s
	local function clear(a: Vector3, b: Vector3, r: number): boolean
		return (a - b).Magnitude < 1e-5 or workspace:Spherecast(a, r, b - a, params) == nil
	end
	local function inside(p: Vector3): boolean
		for _, b in Layout.PIECES do
			if p.X > b.lo.X and p.X < b.hi.X and p.Y > b.lo.Y and p.Y < b.hi.Y and p.Z > b.lo.Z and p.Z < b.hi.Z then return true end
		end
		return false
	end
	local function newDirector(): any
		return WaspDirector.new({
			seed = 914, enabled = true,
			world = {
				ray = function(a: Vector3, b: Vector3): boolean return workspace:Raycast(a, b - a, params) ~= nil end,
				clear = clear,
				inRetreat = function(p: Vector3): boolean return Layout.inRetreat(p) end,
			},
		})
	end
	local block = { day = 2, hour = 12.0, resting = false, moulting = false, meals = 1 }

	check("WASP: every place has room to hover, a way in, a way up and ground to land on (real casts)", function()
		local up = Vector3.new(0, 1, 0)
		for _, p in Data.points do
			local hover: Vector3 = p.hover
			local top = Vector3.new(hover.X, Data.cruiseY, hover.Z)
			assert(clear(hover + up * 0.01, hover, Data.radius), `{p.id}: no room to hover`)
			assert(clear(hover, top, Data.radius), `{p.id}: not open straight up`)
			assert(clear(Data.over, top, Data.radius), `{p.id}: not reached from over the frame`)
			if p.land then
				local land: Vector3 = p.land
				assert(clear(hover, land + up * 0.25, Data.radius), `{p.id}: no clear way down to land`)
				assert(workspace:Raycast(land, Vector3.new(0, -0.5, 0), params) ~= nil, `{p.id}: no ground under the landing`)
				assert(clear(land, land + up * 1.2, Data.walkRadius), `{p.id}: no room to take off`)
			end
		end
		assert(clear(Data.entry, Data.over, Data.radius), "the way in over the frame is blocked")
	end)

	check("WASP: it searches a sill it cannot find the spider on, never inside a piece, and gives up (real casts)", function()
		local d = newDirector()
		local spider = { position = CRACK, velocity = Vector3.zero, walkSpeed = walk, airborne = false, falling = false }
		assert(d:force(2, "crack_mouth"), "the visit does not begin")
		local seen: { [string]: boolean } = {}
		local left = false
		for n = 1, 60 * 90 do
			spider.velocity = Vector3.new(0, 0, if (n // 30) % 2 == 0 then walk else -walk)
			spider.position += spider.velocity * DT
			d:step(DT, spider, block)
			seen[d.phase] = true
			assert(not inside(d.wasp.position), `the wasp is inside a piece at tick {n}: {d.wasp.position}`)
			for _, s in d:drainSignals() do
				if s.kind == "left" then left = true end
			end
			if d.phase == "away" then break end
		end
		assert(seen.arriving and seen.searching and seen.leaving, "it arrives, searches and leaves")
		assert(left and d.phase == "away", "it gives up and goes")
		assert(d.escapes == 0, "it never saw the spider in the crack")
	end)

	check("WASP: a spider moving in the open is found and carried off, over the frame (real casts)", function()
		local d = newDirector()
		local spider = { position = OPEN, velocity = Vector3.zero, walkSpeed = walk, airborne = false, falling = false }
		d:force(2, "floor_middle")
		local caught, carried = false, false
		for n = 1, 60 * 60 do
			if d.phase == "searching" or d.phase == "arriving" then
				spider.velocity = Vector3.new(if (n // 30) % 2 == 0 then walk else -walk, 0, 0)
			else
				spider.velocity = Vector3.zero
			end
			spider.position += spider.velocity * DT
			d:step(DT, spider, block)
			if d.holding and d.heldAt then spider.position = d.heldAt end
			assert(not inside(d.wasp.position), `the wasp is inside a piece: {d.wasp.position}`)
			for _, s in d:drainSignals() do
				if s.kind == "caught" then caught = true elseif s.kind == "carried_off" then carried = true end
			end
			if carried then break end
		end
		assert(caught and carried, "caught and carried off")
		assert(spider.position.Y > 10, `up and away: {spider.position}`)
	end)

	check("WASP: a lunge from a spider that dropped on its line is missed (real casts)", function()
		local d = newDirector()
		local spider = { position = OPEN, velocity = Vector3.zero, walkSpeed = walk, airborne = false, falling = false }
		d:force(2, "floor_middle")
		local noticed = false
		for n = 1, 60 * 100 do
			if d.phase == "searching" then spider.velocity = Vector3.new(if (n // 30) % 2 == 0 then walk else -walk, 0, 0) else spider.velocity = Vector3.zero end
			spider.position += spider.velocity * DT
			if noticed then spider.falling = true end
			d:step(DT, spider, block)
			assert(not d.holding, "a dropped spider was caught")
			for _, s in d:drainSignals() do
				if s.kind == "noticed" then noticed = true end
			end
			if d.phase == "away" then break end
		end
		assert(noticed and d.phase == "away", "found, then lost")
	end)

	check("WASP: the drawn wasp builds from real Parts and is not touched by anything", function()
		local clientFolder = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
		local WaspBody = require(clientFolder:WaitForChild("WaspBody") :: ModuleScript) :: any
		local body = WaspBody.new(world)
		local d = newDirector()
		d:force(2, "floor_middle")
		local spider = { position = OPEN, velocity = Vector3.zero, walkSpeed = walk, airborne = false, falling = false }
		for _ = 1, 600 do d:step(DT, spider, block) end
		body:draw(d.wasp, 5.0)
		local parts = 0
		for _, o in body.folder:GetDescendants() do
			if o:IsA("BasePart") then
				parts += 1
				local p = o :: BasePart
				assert(not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow and p.Anchored, `{p.Name} is not inert`)
			end
		end
		assert(parts >= 40 and parts <= 80, `{parts} parts`)
		body:destroy()
	end)

	world:Destroy()
end
