--!strict
-- Deterministic recovery scenarios (HANDOFF-roblox-silk.md, Chet's acceptance list): missed jumps caught by the line,
-- lowering from a leaf, a wall and the planter, reeling, a snag, early and pre-held let-go presses, focus-loss
-- cancellation and a ten-miss recovery sequence, plus the catch camera (no roll, never inside the sill, the 45-degree
-- framing cap, the player's look winning), the landing patch's states and the body turning to Focus, the eye view and an
-- aim. The real SpiderMotor, SilkController, JumpInput and SpiderCamera run tick by tick
-- at 1/60 s on the windowsill's own boxes (WindowsillLayout.PIECES) in a separate folder; nothing waits on the frame rate.
-- Studio runs this with the engine's raycasts and sphere casts (tests/studio/Runner.server.luau). The plain Luau CLI runs the
-- same code against the box-world emulation in tests/shim.luau (tests/scenarios.luau): a smoke test, not engine evidence.
-- A miss is made the way a player makes one (Godot M03): a jump is planned and committed to a perch that then drops away.
return function(check: (string, () -> ()) -> (), deps: any)
	local Motor, JumpInput, Layout, Species, Surfaces, SpiderCamera = deps.Motor, deps.JumpInput, deps.Layout, deps.Species, deps.Surfaces, deps.SpiderCamera
	local DT = Motor.DT
	local HEIGHT = Motor.HEIGHT
	local folders: { Instance } = {}

	local function part(folder: Instance, name: string, lo: Vector3, hi: Vector3, profile: string): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = hi - lo
		p.Position = (hi + lo) / 2
		p:SetAttribute("ProfileId", profile)
		if deps.transparent then p.Transparency = 1 end
		p.Parent = folder
		return p
	end

	local function windowsill(name: string): Instance
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
		for _, piece in Layout.PIECES do part(folder, piece.id, piece.lo, piece.hi, piece.profile) end
		table.insert(folders, folder)
		return folder
	end

	local sill = windowsill("RecoverySill")
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { sill }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { sill }

	local function newMotor(world: Instance?): any
		return Motor.new({ world = world or sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
			heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX, probeParent = world or sill })
	end
	local function input(t: any?): any
		local i: any = Motor.idleInput()
		for k, v in t or {} do i[k] = v end
		return i
	end
	local function finite(v: Vector3): boolean
		return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e5
	end
	local function insideSill(p: Vector3, r: number): boolean
		return #workspace:GetPartBoundsInRadius(p, r, overlap) > 0
	end
	local function has(events: { string }, kind: string): boolean
		return table.find(events, kind) ~= nil
	end

	-- A run: ticks the motor (and, when given, the camera) with an input function until `done` or the tick limit, and
	-- watches every tick: finite, the body never inside the sill, the line never longer than its rest length, the camera
	-- never rolled and never inside the sill.
	type Run = { m: any, cam: any?, events: { string }, ticks: number, problems: { string }, maxTurn: number }
	local function watch(m: any, cam: any?): Run
		return { m = m, cam = cam, events = {}, ticks = 0, problems = {}, maxTurn = 0 }
	end
	local function problem(r: Run, text: string)
		if #r.problems < 6 then table.insert(r.problems, `tick {r.ticks}: {text}`) end
	end
	local function step(r: Run, inp: any)
		local m = r.m
		m:tick(inp)
		r.ticks += 1
		for _, e in m:drainEvents() do table.insert(r.events, e.kind) end
		if not finite(m.pos) or not finite(m.vel) then problem(r, "non-finite position or velocity") end
		if insideSill(m.pos, 0.25) then problem(r, `body inside the sill at {m.pos}`) end
		local silk = m.silk
		if silk.mode == "locked" then
			-- As Godot's M03: the line may pass through geometry only on ticks flagged as snagged, where its straight
			-- segments are not its length.
			if not silk.snagged and silk:path(m.pos) > silk.rest + 0.02 then problem(r, "line longer than its rest length") end
			if silk.rest > silk.maximum + 1e-6 or silk.paid < 0 then problem(r, "line length out of range") end
		end
		local cam: any = r.cam
		if cam then
			cam:tick(DT)
			cam:render(DT, 0, 0)
			local cf = cam.camera.CFrame
			if not cam.eyeView and math.abs(cf.RightVector.Y) > 1e-5 then problem(r, "the camera rolled") end
			if insideSill(cf.Position, 0.05) then problem(r, `camera inside the sill at {cf.Position}`) end
			r.maxTurn = math.max(r.maxTurn, math.abs(cam.framing.assist))
		end
	end
	-- Studio would stop a script that runs too long without yielding; the engine run yields now and then (the CLI does not).
	local function breathe(r: Run)
		if deps.yield and r.ticks % 600 == 0 then deps.yield() end
	end
	local function runUntil(r: Run, limit: number, inp: any, done: ((any) -> boolean)?): boolean
		for _ = 1, limit do
			step(r, inp)
			breathe(r)
			if done and done(r.m) then return true end
		end
		return false
	end
	local function newCamera(m: any): any
		local camera = Instance.new("Camera")
		camera.Parent = sill
		local drawnUp = Vector3.yAxis
		local cam = SpiderCamera.new(camera, params, function()
			drawnUp = drawnUp:Lerp(m.up, 0.33).Unit
			return { pos = m.pos, drawnUp = drawnUp, heading = m.heading, onLine = m:onLine(), rest = m:lineRestPoint(), lip = m:lineLip() }
		end, function(_on: boolean) end)
		cam.mouse = false
		return cam
	end

	-- A miss: from a spot on a surface, a leap planned to a perch that drops away once the spider has left.
	local function miss(m: any, at: Vector3, heading: Vector3, perchTop: Vector3): (boolean, string)
		m:place(at, Vector3.yAxis, heading)
		local lo = perchTop + Vector3.new(-0.5, -0.4, -0.5)
		local hi = perchTop + Vector3.new(0.5, 0, 0.5)
		local perch = part(sill, "PracticePerch", lo, hi, "leaf_dry_prototype")
		local plan = m:planJump(perchTop, Vector3.yAxis, perch)
		local ok = plan.kind == "reachable" and m:commit(plan)
		perch:Destroy()
		return ok, `{plan.kind} {plan.reason}`
	end
	local hanging = function(mm: any) return mm.silk.mode == "locked" and mm.silk.taut end
	local settled = function(mm: any) return (mm.silk.mode == "locked" and mm.silk.taut and mm.vel.Magnitude < 0.3) or mm.mode == "attached" end
	local attached = function(mm: any) return mm.mode == "attached" end

	local ok, err = pcall(function()
		-- ------------------------------------------------------------------ missed jumps and reeling
		check("a missed leap off the east leaf is caught by the line, settles, and reeling takes hold of the leaf", function()
			local m = newMotor()
			local cam = newCamera(m)
			local r = watch(m, cam)
			cam:snap()
			local launched, why = miss(m, Vector3.new(21.5, 5.4 + HEIGHT, -0.6), Vector3.zAxis, Vector3.new(21.5, 5.3, 2.9))
			assert(launched, "the practice leap was not reachable: " .. why)
			assert(runUntil(r, 240, input(), hanging), "no catch")
			assert(has(r.events, "anchored") and has(r.events, "locked") and has(r.events, "caught"), "line events: " .. table.concat(r.events, ","))
			assert(m.pos.Y > 1 and m.pos.Y < 5.4, `hangs below the leaf, not on the floor: {m.pos}`)
			assert(runUntil(r, 600, input(), settled), "the swing did not settle within 10 s")
			assert(runUntil(r, 1800, input({ reel = 1 }), attached), "reeling did not take hold again")
			assert(has(r.events, "completed") and m.supportPart and m.supportPart.Name == "leaf_east", `took hold of {m.supportPart} at {m.pos}`)
			assert(#r.problems == 0, table.concat(r.problems, "; "))
			assert(r.maxTurn <= math.rad(45) + 1e-9, "framing turn over the cap")
		end)

		-- ------------------------------------------------------------------ letting down: a leaf, a wall, the planter
		check("F on the middle leaf walks to the nearest edge, lets down, and a held F lowers to the sill floor", function()
			local m = newMotor()
			local r = watch(m)
			m:place(Vector3.new(0.5, 4.2 + HEIGHT, -3.0), Vector3.yAxis, Vector3.xAxis)
			assert(m:requestDrop() and m.silk.walk ~= nil, "no walk to the edge")
			assert(runUntil(r, 240, input(), hanging), "no hang after the walk to the edge")
			assert(has(r.events, "drop_walk") and has(r.events, "dropped"), table.concat(r.events, ","))
			assert(runUntil(r, 900, input({ dropHeld = true }), attached), "lowering never reached a surface")
			assert(m.pos.Y < 0.5, `landed at {m.pos}`)
			assert(#r.problems == 0, table.concat(r.problems, "; "))
		end)
		check("F on the back wall lets down at once and lowering reaches the floor", function()
			local m = newMotor()
			local r = watch(m)
			m:place(Vector3.new(-8, 6, -12.5 + HEIGHT), Vector3.zAxis, Vector3.yAxis)
			assert(m:requestDrop() and m.mode == "air" and m.silk.walk == nil, "a wall should let down at once")
			assert(runUntil(r, 1200, input({ dropHeld = true }), attached), "lowering never reached a surface")
			assert(m.pos.Y < 0.5, `landed at {m.pos}`)
			assert(#r.problems == 0, table.concat(r.problems, "; "))
		end)
		check("F on the planter rim walks to its front edge, lets down clear of the planter and lowers to the floor", function()
			local m = newMotor()
			local r = watch(m)
			m:place(Vector3.new(10, 4.6 + HEIGHT, 0.0), Vector3.yAxis, Vector3.zAxis)
			assert(m:requestDrop(), "planter rim refused")
			assert(runUntil(r, 240, input(), hanging), "no hang")
			assert(runUntil(r, 900, input({ dropHeld = true }), attached), "lowering never reached a surface")
			assert(m.pos.Y < 0.5 and m.pos.Z > 0.2, `landed at {m.pos}`)
			assert(#r.problems == 0, table.concat(r.problems, "; "))
		end)
		check("after letting down from the leaf, reeling climbs back and takes hold of the leaf", function()
			local m = newMotor()
			local r = watch(m)
			m:place(Vector3.new(0.5, 4.2 + HEIGHT, -3.0), Vector3.yAxis, Vector3.xAxis)
			m:requestDrop()
			assert(runUntil(r, 240, input(), hanging), "no hang")
			runUntil(r, 90, input())
			assert(runUntil(r, 900, input({ reel = 1 }), attached), "reeling did not take hold")
			assert(m.supportPart and m.supportPart.Name == "leaf_middle", `took hold of {m.supportPart} at {m.pos}`)
			assert(#r.problems == 0, table.concat(r.problems, "; "))
		end)

		-- ------------------------------------------------------------------ a snag
		check("a second obstruction snags the line: reeling is refused, lowering and letting go still work", function()
			local m = newMotor()
			local r = watch(m)
			m:place(Vector3.new(0.5, 4.2 + HEIGHT, -3.0), Vector3.yAxis, Vector3.xAxis)
			m:requestDrop()
			assert(runUntil(r, 240, input(), hanging), "no hang")
			runUntil(r, 120, input())
			local bend = m.silk.bend
			assert(bend ~= nil, "the leaf's edge should hold one bend")
			local obstacle = part(sill, "SecondEdge", (bend + m.pos) / 2 - Vector3.one * 0.06, (bend + m.pos) / 2 + Vector3.one * 0.06, "bare_wood_rough")
			runUntil(r, 2, input())
			assert(m.silk.snagged and has(r.events, "snagged"), "no snag reported")
			local rest = m.silk.rest
			runUntil(r, 60, input({ reel = 1 }))
			assert(math.abs(m.silk.rest - rest) < 1e-9, "reeling shortened a snagged line")
			runUntil(r, 30, input({ reel = -1 }))
			assert(m.silk.rest > rest + 0.5, "lowering did not pay out")
			runUntil(r, 2, input())
			assert(runUntil(r, 40, input({ releaseHeld = true }), function(mm) return mm.silk.mode == "none" end), "a deliberate hold did not let go")
			assert(has(r.events, "released"), table.concat(r.events, ","))
			obstacle:Destroy()
			assert(runUntil(r, 240, input(), attached) and m.pos.Y < 0.5, "did not fall to the floor")
			assert(#r.problems == 0, table.concat(r.problems, "; "))
		end)

		-- ------------------------------------------------------------------ early and pre-held let-go presses
		check("a press in the 0.4 s grace never lets go, however long it is held; a fresh 0.6 s hold does", function()
			local m = newMotor()
			local r = watch(m)
			local launched = miss(m, Vector3.new(21.5, 5.4 + HEIGHT, -0.6), Vector3.zAxis, Vector3.new(21.5, 5.3, 2.9))
			assert(launched, "no practice leap")
			assert(runUntil(r, 240, input(), function(mm) return mm.silk.mode == "locked" end), "no lock")
			runUntil(r, 5, input())
			runUntil(r, 180, input({ releaseHeld = true }))
			assert(m:onLine(), "a press inside the grace let go")
			runUntil(r, 1, input())
			runUntil(r, 35, input({ releaseHeld = true }))
			assert(m:onLine() and m.silk.release.progress > 0.9, "a 35-tick hold let go, or showed no progress")
			runUntil(r, 1, input({ releaseHeld = true }))
			assert(m.silk.mode == "none" and has(r.events, "released"), "the 36th tick of a fresh hold did not let go")
			assert(#r.problems == 0, table.concat(r.problems, "; "))
		end)
		check("Q held from before the leap through the catch never lets go; a fresh hold does", function()
			local m = newMotor()
			local r = watch(m)
			local launched = miss(m, Vector3.new(21.5, 5.4 + HEIGHT, -0.6), Vector3.zAxis, Vector3.new(21.5, 5.3, 2.9))
			assert(launched, "no practice leap")
			assert(runUntil(r, 240, input({ releaseHeld = true }), function(mm) return mm.silk.mode == "locked" end), "no lock")
			runUntil(r, 300, input({ releaseHeld = true }))
			assert(m:onLine(), "a held-over press let go")
			runUntil(r, 1, input())
			assert(runUntil(r, 36, input({ releaseHeld = true }), function(mm) return mm.silk.mode == "none" end), "a fresh hold did not let go")
			assert(#r.problems == 0, table.concat(r.problems, "; "))
		end)

		-- ------------------------------------------------------------------ focus loss
		check("focus loss cancels: an aim never leaps afterwards, a let-go hold starts over, a walk to the edge stops", function()
			local m = newMotor()
			local j = JumpInput.new()
			m:place(Vector3.new(-22, HEIGHT, 6), Vector3.yAxis, Vector3.xAxis)
			m:setAimRay(Vector3.new(-25, 3, 6), Vector3.new(1, -0.45, 0).Unit)
			j:press()
			for _ = 1, 12 do j:step(m); m:tick(input()) end
			assert(j:isAiming() and m:isPreparing(), "no aim")
			j:drop(m)
			j:release()
			for _ = 1, 3 do j:step(m); m:tick(input()) end
			assert(m.mode == "attached" and not m:isPreparing() and j.last == nil, "a release after focus loss leaped")
			local r = watch(m)
			local launched = miss(m, Vector3.new(21.5, 5.4 + HEIGHT, -0.6), Vector3.zAxis, Vector3.new(21.5, 5.3, 2.9))
			assert(launched, "no practice leap")
			assert(runUntil(r, 240, input(), function(mm) return mm.silk.mode == "locked" end), "no lock")
			runUntil(r, 40, input())
			runUntil(r, 18, input({ releaseHeld = true }))
			assert(m.silk.release.progress > 0.4, "no let-go progress")
			local release = m.silk.release -- what the client does on focus loss (SpiderClient dropAll)
			release.down, release.counts, release.held, release.progress = true, false, 0, 0
			runUntil(r, 60, input())
			assert(m:onLine() and m.silk.release.progress == 0, "the hold survived focus loss")
			runUntil(r, 35, input({ releaseHeld = true }))
			assert(m:onLine(), "the hold resumed where it was")
			m:place(Vector3.new(0.5, 4.2 + HEIGHT, -3.0), Vector3.yAxis, Vector3.xAxis)
			m:requestDrop()
			runUntil(r, 10, input())
			assert(m:cancelWalk() and m.silk.walk == nil, "no walk to cancel")
			runUntil(r, 120, input())
			assert(m.mode == "attached" and m.silk.mode == "none" and m.pos.Y > 4, "the walk went on after focus loss")
		end)

		-- ------------------------------------------------------------------ the catch camera
		check("catch camera: a squeezed view turns by the smallest working 15-degree step, never past 45, and the player's look wins", function()
			local cliffWorld = Instance.new("Folder")
			cliffWorld.Name = "CliffWorld"
			cliffWorld.Parent = workspace
			table.insert(folders, cliffWorld)
			part(cliffWorld, "Floor", Vector3.new(-20, -1, -20), Vector3.new(20, 0, 20), "painted_wood_dry")
			-- A roofed canyon running along Z, one stud wide: only views along it have room (a quarter turn from across it).
			part(cliffWorld, "WestWall", Vector3.new(0, 0, -10), Vector3.new(4, 7, 10), "bare_wood_rough")
			part(cliffWorld, "EastWall", Vector3.new(5, 0, -10), Vector3.new(9, 7, 10), "bare_wood_rough")
			part(cliffWorld, "Roof", Vector3.new(0, 7, -10), Vector3.new(9, 8, 10), "bare_wood_rough")
			local cparams = RaycastParams.new()
			cparams.FilterType = Enum.RaycastFilterType.Include
			cparams.FilterDescendantsInstances = { cliffWorld }
			local cover = OverlapParams.new()
			cover.FilterType = Enum.RaycastFilterType.Include
			cover.FilterDescendantsInstances = { cliffWorld }
			local onLine = true
			local spot = Vector3.new(4.5, 5, 0)
			local lip = Vector3.new(4.5, 6.9, 0)
			local function cameraAt(yaw: number): any
				local camera = Instance.new("Camera")
				camera.Parent = cliffWorld
				local c = SpiderCamera.new(camera, cparams, function()
					return { pos = spot, drawnUp = Vector3.yAxis, heading = Vector3.xAxis, onLine = onLine, rest = spot, lip = lip }
				end, function(_on: boolean) end)
				c.mouse = false
				c.yaw = yaw
				return c
			end
			-- Looking across the canyon (yaw -90): the boom is in the wall at every pitch and only a quarter turn clears it.
			local squeezed = cameraAt(math.rad(-90))
			for _ = 1, 90 do squeezed:tick(DT); squeezed:render(DT, 0, 0) end
			assert(squeezed.framing.assist == 0, "a quarter turn is beyond the 45-degree cap: nothing turns")
			assert(squeezed.boom < 2.5, `as squeezed as without framing ({squeezed.boom})`)
			-- 45 degrees off: the framing turns by the smallest working step (here exactly the cap) and holds it.
			local framed = cameraAt(math.rad(-45))
			for _ = 1, 90 do framed:tick(DT); framed:render(DT, 0, 0) end
			local turn = framed.framing.assist
			local steps = turn / math.rad(15)
			assert(turn ~= 0 and math.abs(steps - math.floor(steps + 0.5)) < 1e-6 and math.abs(turn) <= math.rad(45) + 1e-9, `turn {math.deg(turn)} is not a 15-degree step within the cap`)
			local from = spot + Vector3.yAxis * framed.pivot
			for k = 0, math.floor(math.abs(steps + 0.5)) - 1 do
				for _, side in { 1, -1 } do
					local smaller = k * math.rad(15) * side
					if math.abs(smaller) < math.abs(turn) - 1e-9 then assert(not framed:_goodView(from, framed.yaw + smaller, spot, lip), `a smaller turn {math.deg(smaller)} also worked`) end
				end
			end
			assert(framed.boom >= 2.5, `the turned view is comfortable ({framed.boom})`)
			local cf = framed.camera.CFrame
			assert(math.abs(cf.RightVector.Y) < 1e-5 and #workspace:GetPartBoundsInRadius(cf.Position, 0.05, cover) == 0, "the framed camera rolled or sits in the cliff")
			local view0 = framed:viewYaw()
			for _ = 1, 150 do framed:tick(DT); framed:render(DT, 0, 0) end
			assert(math.abs(framed:viewYaw() - view0) < 1e-6, "the turn drifted while the spider hung still")
			local yaw0 = framed.yaw
			framed:look(1, 0)
			assert(framed.framing.assist == 0 and math.abs(framed:viewYaw() - (view0 - math.rad(1))) < 1e-9, "a one-degree look did not take the turn over without a jump")
			assert(math.abs(framed.yaw - (yaw0 + turn - math.rad(1))) < 1e-9, "the turn did not become the player's yaw")
			for _ = 1, 120 do framed:tick(DT); framed:render(DT, 0, 0) end
			assert(framed.framing.assist == 0, "the framing came back while the line was out")
			-- Aiming and a recenter win over a held turn as well.
			local aimed = cameraAt(math.rad(-45))
			for _ = 1, 90 do aimed:tick(DT); aimed:render(DT, 0, 0) end
			local v1 = aimed:viewYaw()
			aimed:setAiming(true)
			assert(aimed.framing.assist == 0 and math.abs(aimed:viewYaw() - v1) < 1e-9, "aiming moved the view")
			aimed:setAiming(false)
			local recentred = cameraAt(math.rad(-45))
			for _ = 1, 90 do recentred:tick(DT); recentred:render(DT, 0, 0) end
			local v2 = recentred:viewYaw()
			recentred:startRecenter()
			assert(recentred.framing.assist == 0 and math.abs(recentred:viewYaw() - v2) < 1e-9 and recentred.recenterT == 0, "a recenter jumped")
			-- The line ends: the view stays where the framing left it.
			local ending = cameraAt(math.rad(-45))
			for _ = 1, 90 do ending:tick(DT); ending:render(DT, 0, 0) end
			local v3 = ending:viewYaw()
			onLine = false
			ending:tick(DT)
			onLine = true
			assert(ending.framing.assist == 0 and math.abs(ending:viewYaw() - v3) < 1e-9, "the view moved when the line ended")
		end)

		-- ------------------------------------------------------------------ the landing patch and the body's turns
		check("the landing patch says Reachable, Blocked, Out of reach and Can't land there, as Godot's planner", function()
			local m = newMotor()
			m:place(Vector3.new(-22, HEIGHT, 6), Vector3.yAxis, Vector3.xAxis)
			local floor = sill:FindFirstChild("sill_floor")
			local reach = m:planJump(Vector3.new(-19, 0, 6), Vector3.yAxis, floor)
			assert(reach.kind == "reachable" and reach.steps > 0 and (reach.path[#reach.path] - reach.seat).Magnitude < 1e-6, `open sill: {reach.kind} {reach.reason}`)
			local far = m:planJump(Vector3.new(25, 0, 6), Vector3.yAxis, floor)
			assert(far.kind == "unreachable" and far.reason ~= "", `47 studs: {far.kind} {far.reason}`)
			local plate = part(sill, "CoatedPlate", Vector3.new(-18, 0, 2), Vector3.new(-17.8, 3, 4), "ptfe_coated")
			local coated = m:planJump(Vector3.new(-18, 1.5, 3), -Vector3.xAxis, plate)
			plate:Destroy()
			assert(coated.kind == "ineligible" and coated.reason == "ineligible_surface", `coated wall: {coated.kind} {coated.reason}`)
			local tight = m:planJump(Vector3.new(-29.9, 0, 6), Vector3.yAxis, floor)
			assert(tight.kind == "obstructed" and tight.reason == "no_room", `against the frame: {tight.kind} {tight.reason}`)
			assert(not m:commit(far) and not m:commit(tight) and m.mode == "attached", "a plan that is not reachable launched")
			m:place(Vector3.new(-29.5, HEIGHT, 6), Vector3.yAxis, -Vector3.xAxis)
			local hop = m:hopPlan()
			assert(hop.kind == "obstructed" and hop.reason == "hop_blocked", `hop into the frame: {hop.kind} {hop.reason}`)
			m:place(Vector3.new(-22, HEIGHT, 6), Vector3.yAxis, Vector3.xAxis)
			local open = m:hopPlan()
			assert(open.kind == "reachable" and m:commit(open) and m.mode == "air", "a hop on the open sill")
		end)
		check("Focus, the eye view and an aim turn the body toward where the view points", function()
			local m = newMotor()
			m:place(Vector3.new(-22, HEIGHT, 6), Vector3.yAxis, Vector3.xAxis)
			for _ = 1, 40 do m:tick(input({ focusPoint = Vector3.new(-22, 0.3, 12) })) end
			assert(m.heading:Dot(Vector3.zAxis) > 0.999, `Focus turned to {m.heading}`)
			m:place(Vector3.new(-22, HEIGHT, 6), Vector3.yAxis, Vector3.xAxis)
			local gaze = Vector3.new(math.cos(math.rad(60)), 0, math.sin(math.rad(60)))
			for _ = 1, 60 do m:tick(input({ gaze = gaze })) end
			assert(math.deg(math.acos(math.clamp(m.heading:Dot(gaze), -1, 1))) < 4.5, "the eye view did not turn the body to the gaze")
			m:place(Vector3.new(-22, HEIGHT, 6), Vector3.yAxis, Vector3.xAxis)
			for _ = 1, 20 do m:tick(input({ gaze = Vector3.new(math.cos(math.rad(20)), 0, math.sin(math.rad(20))) })) end
			assert(m.heading:Dot(Vector3.xAxis) > 0.9999, "a gaze inside 30 degrees turned the body")
			m:place(Vector3.new(-22, HEIGHT, 6), Vector3.yAxis, Vector3.xAxis)
			m:setAimRay(Vector3.new(-22, 3, 2), Vector3.new(0, -0.6, 1).Unit)
			assert(m:beginPrepare(), "no preparation")
			m:aimPlan()
			local before = m.pos
			for _ = 1, 30 do m:tick(input({ wish = Vector3.xAxis })) end
			assert((m.pos - before).Magnitude < 1e-9 and m.heading:Dot(Vector3.zAxis) > 0.99, `preparing: held still and turned to the aim ({m.heading})`)
		end)

		-- ------------------------------------------------------------------ ten misses
		check("ten misses from leaves and the planter are caught and recovered by reeling, lowering or letting go", function()
			local fixtures: { { any } } = {
				{ "east leaf, front", Vector3.new(21.5, 5.4, -0.6), Vector3.zAxis, Vector3.new(21.5, 5.3, 2.9), "reel" },
				{ "east leaf, back", Vector3.new(21.5, 5.4, -5.4), -Vector3.zAxis, Vector3.new(21.5, 5.3, -8.9), "reel" },
				{ "middle leaf, front", Vector3.new(0.5, 4.2, 0.4), Vector3.zAxis, Vector3.new(0.5, 4.1, 2.9), "reel" },
				{ "middle leaf, back", Vector3.new(0.5, 4.2, -3.4), -Vector3.zAxis, Vector3.new(0.5, 4.1, -5.9), "reel" },
				{ "west leaf, front", Vector3.new(-15, 4.2, 0.4), Vector3.zAxis, Vector3.new(-15, 4.1, 2.9), "reel" },
				{ "west leaf, west side", Vector3.new(-17.4, 4.2, -1.5), -Vector3.xAxis, Vector3.new(-19.9, 4.1, -1.5), "reel" },
				{ "planter rim, front", Vector3.new(10, 4.6, 0.2), Vector3.zAxis, Vector3.new(10, 4.5, 3.2), "reel" },
				{ "middle leaf, front, then lower", Vector3.new(-3, 4.2, 0.4), Vector3.zAxis, Vector3.new(-3, 4.1, 2.9), "lower" },
				{ "east leaf, front, then lower", Vector3.new(24, 5.4, -0.6), Vector3.zAxis, Vector3.new(24, 5.3, 2.9), "lower" },
				{ "west leaf, front, then let go", Vector3.new(-13, 4.2, 0.4), Vector3.zAxis, Vector3.new(-13, 4.1, 2.9), "letgo" },
			}
			local results = {}
			local recovered = 0
			for i, f in fixtures do
				local m = newMotor()
				local withCamera = deps.cameraFixtures == "all" or (type(deps.cameraFixtures) == "table" and table.find(deps.cameraFixtures, i) ~= nil)
				local r = watch(m, if withCamera then newCamera(m) else nil)
				local name, at, heading, perch, after = f[1], f[2], f[3], f[4], f[5]
				local launched, why = miss(m, at + Vector3.new(0, HEIGHT, 0), heading, perch)
				if r.cam then r.cam:snap() end
				local outcome = "not launched: " .. why
				if launched then
					local caught = runUntil(r, 300, input(), hanging)
					local calm = caught and runUntil(r, 600, input(), settled)
					local done = false
					if caught and after == "reel" then
						done = runUntil(r, 2400, input({ reel = 1 }), attached) and has(r.events, "completed")
					elseif caught and after == "lower" then
						done = runUntil(r, 2400, input({ reel = -1 }), attached) and m.pos.Y < 0.5
					elseif caught then
						runUntil(r, 1, input())
						done = runUntil(r, 40, input({ releaseHeld = true }), function(mm) return mm.silk.mode == "none" end)
							and runUntil(r, 300, input(), attached) and m.pos.Y < 0.5
					end
					outcome = `caught {caught}, settled {calm}, {after} {done}, {r.ticks} ticks, max turn {math.floor(math.deg(r.maxTurn) + 0.5)}`
					if caught and done and #r.problems == 0 then recovered += 1 else outcome ..= " " .. table.concat(r.problems, "; ") end
				end
				table.insert(results, `{i} {name}: {outcome}`)
			end
			if deps.log then for _, line in results do deps.log(line) end end
			assert(recovered == #fixtures, `{recovered}/{#fixtures} recovered:\n` .. table.concat(results, "\n"))
		end)
	end)
	for _, folder in folders do folder:Destroy() end
	if not ok then error(err) end
end
