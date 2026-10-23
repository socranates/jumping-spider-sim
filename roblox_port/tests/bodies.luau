-- The small lives drawn (ROBLOX-128): the creatures' bodies and their motion under the shim (tests/shim.luau), presentation only. A wingbeat too fast to draw at
-- 60 frames is a trembling blur, never a strobing flap (the hoverfly, the midge, the mosquito, the damselfly), while the moth still beats; the house fly's
-- venation (R4+5 and M1+2 with its bend) on its wings at the full tier, hidden in flight, its part count kept; grooming in seeded bouts by a fly standing calm
-- (the front legs drawn in and rubbed, the hind legs drawn back and rubbed), never while alarmed, walking or in Reduced Motion, the same for the same fly; a fly
-- readying to take off; a singing field cricket's raised forewings; the water strider's rowing; the ant's antennae; the robin's erect stop, level crouch and turning
-- head; the green frog's breathing; and the drawers' kept tables. Says nothing about how any of it looks in Roblox.
local FlyBodies = require("../src/Client/FlyBodies")
local BugBodies = require("../src/Client/BugBodies")
local BirdBody = require("../src/Client/BirdBody")
local PondBodies = require("../src/Client/PondBodies")
local FlyLook = require("../src/Shared/Data/FlyLook")
local Species = require("../src/Shared/Data/Species")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end
local function finite(v: Vector3): boolean return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6 end
local function angle(a: Vector3, b: Vector3): number return math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)) end

local HOVER = Species.fly_like_prototype.body.hover_wu
local function bug(id: string, profile: any, state: string, pos: Vector3?): any
	return { id = id, state = state, position = pos or Vector3.new(0, HOVER, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, profile = profile, serial = 1,
		airborne = function(self: any): boolean return self.state ~= "PERCHED" and self.state ~= "ALERT" and self.state ~= "CAPTURED" end,
		alive = function(): boolean return true end }
end
local function find(rig: any, name: string): any
	for _, p in rig.parts do if p.Name == name then return p end end
	error("no part " .. name)
end
local function has(rig: any, name: string): boolean
	for _, p in rig.parts do if p.Name == name then return true end end
	return false
end
-- every part's frame in the frame of the part `base`
local function rel(rig: any, base: string): { [string]: CFrame }
	local b = find(rig, base).CFrame:Inverse()
	local out = {}
	for _, p in rig.parts do out[p.Name] = b * p.CFrame end
	return out
end
local function diff(a: { [string]: CFrame }, b: { [string]: CFrame }, word: string): number
	local most = 0
	for name, f in a do
		if string.find(name, word, 1, true) then most = math.max(most, (f.Position - b[name].Position).Magnitude) end
	end
	return most
end

case("a wingbeat too fast for 60 frames is a trembling blur, never a strobing flap; the moth's slow beat is still drawn as a beat", function()
	check(FlyLook.BLUR_HZ > 0 and FlyLook.BLUR_HZ < 30, `the fastest beat drawn as a beat is under half of 60 frames a second ({FlyLook.BLUR_HZ} Hz)`)
	for _, kind in { "hoverfly", "midge", "mosquito", "damselfly", "moth" } do
		local profile = (Species :: any)[kind .. "_prototype"]
		check(profile ~= nil and profile.body.prey_kind == kind, `{kind}: a profile drawn from its sheet`)
		local sheet = FlyLook.small[kind]
		local blurred = sheet.motion.flap.hz > FlyLook.BLUR_HZ
		check(blurred == (kind ~= "moth"), `{kind}: {sheet.motion.flap.hz} Hz is {if blurred then "a blur" else "a beat"}`)
		local bodies = FlyBodies.new(workspace)
		local f = bug("w", profile, "REPOSITION", Vector3.new(0, 5, 0))
		local t = 0
		bodies:draw({ f }, t)
		local rig = bodies.rigs.w
		local wing = find(rig, if has(rig, "RightWing") then "RightWing" else "RightForewing")
		local first = wing.CFrame.UpVector
		local last = first
		local worst, widest = 0, 0
		for _ = 1, 120 do
			t += 1 / 60
			bodies:draw({ f }, t)
			local up = wing.CFrame.UpVector
			worst = math.max(worst, angle(up, last))
			widest = math.max(widest, angle(up, first))
			last = up
			check(finite(wing.Position), `{kind}: finite`)
		end
		if blurred then
			check(worst > 0 and worst < 0.03 and widest <= 0.1, `{kind}: the blur trembles ({string.format("%.3f", widest)} rad at most) and changes under 0.03 rad a frame ({string.format("%.4f", worst)})`)
		else
			check(worst > 0.05 and worst <= 0.5 and widest > 0.5, `{kind}: a visible smooth beat ({string.format("%.2f", widest)} rad wide, {string.format("%.3f", worst)} a frame)`)
		end
		bodies:draw({}, t)
	end
end)

case("the house fly's wings carry R4+5 and M1+2 with its bend at the full tier, on the wing's upper face, hidden in flight; its parts are still 39 and 29", function()
	local full = FlyBodies.new(workspace, "full")
	local low = FlyBodies.new(workspace, "low")
	local f = bug("hf", Species.fly_like_prototype, "PERCHED")
	full:draw({ f }, 0)
	low:draw({ f }, 0)
	local rig, lrig = full.rigs.hf, low.rigs.hf
	check(#rig.parts == 39 and #lrig.parts == 29, `39 parts at full and 29 at low ({#rig.parts}, {#lrig.parts})`)
	local bristles = 0
	for _, p in rig.parts do if string.sub(p.Name, 1, 7) == "Bristle" then bristles += 1 end end
	check(bristles == 2, "the thorax's pair of bristles kept")
	for _, side in { "Left", "Right" } do
		local wing = find(rig, side .. "Wing")
		for _, name in { "VeinR45", "VeinM1", "VeinM2" } do
			local vein = find(rig, side .. name)
			check(not has(lrig, side .. name), `{side}{name}: not at the low tier`)
			check(vein.Shape == Enum.PartType.Cylinder and vein.Size.Y <= 0.008 and vein.Transparency < 0.5, `{side}{name}: a thin dark rod`)
			for _, e in { 1, -1 } do
				local p = wing.CFrame:PointToObjectSpace(vein.Position + vein.CFrame.RightVector * (e * vein.Size.X / 2))
				local inside = (p.X / (wing.Size.X / 2)) ^ 2 + (p.Z / (wing.Size.Z / 2)) ^ 2
				check(inside < 1 and p.Y > 0 and p.Y < 0.015, `{side}{name}: its end lies on the wing's upper face, inside its outline ({string.format("%.2f", inside)})`)
			end
		end
		-- M1+2 bends up to almost meet R4+5 at the margin
		local m2, r45 = find(rig, side .. "VeinM2"), find(rig, side .. "VeinR45")
		local function tip(p: any): Vector3
			local a, b = p.Position + p.CFrame.RightVector * (p.Size.X / 2), p.Position - p.CFrame.RightVector * (p.Size.X / 2)
			return if a.Z > b.Z then a else b
		end
		local m1 = find(rig, side .. "VeinM1")
		check((tip(m2) - tip(r45)).Magnitude < 0.02 and (tip(m1) - tip(r45)).Magnitude > 0.025 and angle(m1.CFrame.RightVector, m2.CFrame.RightVector) > 0.4,
			`{side}: M1+2 runs down the middle and bends sharply to almost touch R4+5 at the margin`)
	end
	local air = bug("hf", Species.fly_like_prototype, "REPOSITION", Vector3.new(0, 4, 0))
	full:draw({ air }, 0.1)
	check(find(rig, "LeftVeinM2").Transparency == 1 and find(rig, "RightVeinR45").Transparency == 1, "in flight the veins hide in the blur")
	full:draw({ f }, 0.2)
	check(find(rig, "LeftVeinM2").Transparency < 0.5, "and show again on landing")
	full:draw({}, 0.3)
	low:draw({}, 0.3)
end)

case("a fly standing calm grooms in seeded bouts: its front legs rubbed together under its head, its hind legs drawn back and rubbed; never alarmed, walking or in Reduced Motion", function()
	for _, kind in { "fly_like", "fungus_gnat", "hoverfly", "midge", "mosquito" } do
		local profile = (Species :: any)[kind .. "_prototype"]
		local bodies = FlyBodies.new(workspace)
		local f = bug("g1", profile, "PERCHED")
		local t = 0
		bodies:draw({ f }, t)
		local rig = bodies.rigs.g1
		local rest = rel(rig, "Head")
		-- the first seconds still: nothing moves but what always did
		for _ = 1, 120 do t += 1 / 60; bodies:draw({ f }, t) end
		local early = rel(rig, "Head")
		check(diff(early, rest, "Front") < 1e-9 and diff(early, rest, "Hind") < 1e-9, `{kind}: in its first two seconds still its legs stand as they did`)
		local front, hind, lowest = 0, 0, math.huge
		local fronts, hinds = 0, 0
		for _ = 1, 60 * 40 do
			t += 1 / 60
			bodies:draw({ f }, t)
			local now = rel(rig, "Head")
			local df, dh = diff(now, rest, "Front"), diff(now, rest, "Hind")
			if df > 0.01 then fronts += 1 end
			if dh > 0.01 then hinds += 1 end
			front, hind = math.max(front, df), math.max(hind, dh)
			for _, p in rig.parts do
				if p.Name ~= "Shadow" then lowest = math.min(lowest, p.Position.Y - math.min(p.Size.X, p.Size.Y, p.Size.Z) / 2) end
				if not finite(p.Position) then lowest = -math.huge end
			end
		end
		check(fronts > 60 and hinds > 0 and front > 0.02 and hind > 0.02, `{kind}: in 40 s it groomed with its front legs ({fronts} frames) and its hind legs ({hinds} frames)`)
		check(fronts + hinds < 40 * 60 * 0.6, `{kind}: in bouts, with pauses between ({fronts + hinds} of 2400 frames)`)
		check(lowest > -0.06, `{kind}: no part goes far through the surface while it grooms ({string.format("%.3f", lowest)})`)
		-- the same fly grooms the same way: a second drawer, the same frames
		local again = FlyBodies.new(workspace)
		local g = bug("g1", profile, "PERCHED")
		local t2 = 0
		again:draw({ g }, t2)
		for _ = 1, 60 * 12 do t2 += 1 / 60; again:draw({ g }, t2) end
		local bodies3 = FlyBodies.new(workspace)
		local h = bug("g1", profile, "PERCHED")
		local t3 = 0
		bodies3:draw({ h }, t3)
		for _ = 1, 60 * 12 do t3 += 1 / 60; bodies3:draw({ h }, t3) end
		check(diff(rel(again.rigs.g1, "Head"), rel(bodies3.rigs.g1, "Head"), "") < 1e-9, `{kind}: the same fly grooms the same way, every time`)
		-- alarmed, it does not groom; walking ends a bout and starts the count again
		local alarmed = FlyBodies.new(workspace)
		local a = bug("g2", profile, "ALERT")
		local ta = 0
		alarmed:draw({ a }, ta)
		local arest = rel(alarmed.rigs.g2, "Head")
		local moved = 0
		for _ = 1, 60 * 20 do ta += 1 / 60; alarmed:draw({ a }, ta); moved = math.max(moved, diff(rel(alarmed.rigs.g2, "Head"), arest, "Front"), diff(rel(alarmed.rigs.g2, "Head"), arest, "Hind")) end
		check(moved < 1e-9, `{kind}: alarmed, it holds still and never grooms`)
		f.position += Vector3.new(0, 0, -0.01)
		t += 1 / 60
		bodies:draw({ f }, t)
		check(rig.still == 0, `{kind}: a step ends the bout and starts the count again`)
		-- Reduced Motion: no grooming
		local still = FlyBodies.new(workspace)
		local r = bug("g1", profile, "PERCHED")
		local tr = 0
		still:draw({ r }, tr, nil, true)
		local rrest = rel(still.rigs.g1, "Head")
		local rm = 0
		for _ = 1, 60 * 20 do tr += 1 / 60; still:draw({ r }, tr, nil, true); rm = math.max(rm, diff(rel(still.rigs.g1, "Head"), rrest, "Front"), diff(rel(still.rigs.g1, "Head"), rrest, "Hind")) end
		check(rm < 1e-9, `{kind}: in Reduced Motion it does not groom`)
		check(#rig.parts == #still.rigs.g1.parts, `{kind}: no part added`)
		for _, d in { bodies, again, bodies3, alarmed, still } do d:draw({}, t + 100) end
	end
end)

case("a fly about to take off readies itself: raised on its legs, nose up, its middle legs forward; not in Reduced Motion", function()
	local bodies = FlyBodies.new(workspace)
	local f = bug("r1", Species.fly_like_prototype, "ALERT")
	local t = 0
	bodies:draw({ f }, t)
	local rig = bodies.rigs.r1
	local thorax, head = find(rig, "Thorax"), find(rig, "Head")
	local y0, hy0, mid0 = thorax.Position.Y, head.Position.Y, find(rig, "RightMiddleTibia").Position.Z
	f.pending = 5
	for _ = 1, 12 do t += 1 / 60; bodies:draw({ f }, t) end
	check(thorax.Position.Y > y0 + 0.01 and head.Position.Y - hy0 > thorax.Position.Y - y0, `raised and nose up (thorax +{string.format("%.3f", thorax.Position.Y - y0)})`)
	check(find(rig, "RightMiddleTibia").Position.Z < mid0 - 0.01, "its middle legs swung forward")
	f.pending = nil
	for _ = 1, 60 do t += 1 / 60; bodies:draw({ f }, t) end
	check(math.abs(thorax.Position.Y - y0) < 1e-3, "the moment past, it settles")
	local still = FlyBodies.new(workspace)
	local g = bug("r2", Species.fly_like_prototype, "ALERT")
	g.pending = 5
	still:draw({ g }, 0, nil, true)
	local gy = find(still.rigs.r2, "Thorax").Position.Y
	for k = 1, 12 do still:draw({ g }, k / 60, nil, true) end
	check(math.abs(find(still.rigs.r2, "Thorax").Position.Y - gy) < 1e-9, "in Reduced Motion it does not")
	bodies:draw({}, t)
	still:draw({}, 1)
end)

case("a singing field cricket holds its forewings raised and dips them through each chirp; a female, a hushed male and a quiet one do not", function()
	local function sing(serial: number, hushed: boolean, reduced: boolean): (number, number)
		local bodies = FlyBodies.new(workspace)
		local f = bug("c" .. serial, Species.cricket_night_prototype, "PERCHED")
		f.serial, f.hushed = serial, hushed
		local t = 0
		bodies:draw({ f }, t, nil, reduced)
		local rig = bodies.rigs["c" .. serial]
		local wings, abdomen = find(rig, "Forewings"), find(rig, "Abdomen")
		local rest = angle(wings.CFrame.LookVector, abdomen.CFrame.LookVector)
		local most, least = 0, math.huge
		for _ = 1, 90 do t += 1 / 60; bodies:draw({ f }, t, nil, reduced) end
		for _ = 1, 60 do
			t += 1 / 60
			bodies:draw({ f }, t, nil, reduced)
			local a = angle(wings.CFrame.LookVector, abdomen.CFrame.LookVector) - rest
			most, least = math.max(most, a), math.min(least, a)
		end
		bodies:draw({}, t)
		return most, least
	end
	local most, least = sing(1, false, false)
	check(least > 0.5 and most < 0.9 and most - least > 0.05, `a singing male raises his forewings ({string.format("%.2f", least)} to {string.format("%.2f", most)} rad) and they dip in each chirp`)
	local f1 = sing(2, false, false)
	local f2 = sing(3, true, false)
	local f3 = sing(5, false, true)
	check(f1 < 1e-6 and f2 < 1e-6 and f3 < 1e-6, "a female, a hushed male, and a male in Reduced Motion: the forewings lie flat")
	check(Species.cricket_prototype.body.chirp ~= true and FlyLook.small.cricket.motion.sing ~= nil, "only the night's profile sings")
end)

case("the water strider rows: the middle legs sweep back together and reach forward again as it glides, the dimples with them; the hind legs trail", function()
	local bodies = BugBodies.new(workspace, "full")
	local s = { id = "s1", kind = "skater", position = Vector3.new(0, 0.15, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, state = "skate" }
	bodies:draw({ s }, 0)
	local rig = bodies.rigs.s1
	local function local_(name: string): Vector3 return find(rig, "Body").CFrame:PointToObjectSpace(find(rig, name).Position) end
	local hind0, dimple0 = local_("TarsusR2"), local_("DimpleR1")
	local minZ, maxZ, symmetric = math.huge, -math.huge, 0
	local t = 0
	for _ = 1, 120 do
		t += 1 / 60
		s.position += Vector3.new(0, 0, -0.04)
		bodies:draw({ s }, t)
		local d = local_("DimpleR1")
		minZ, maxZ = math.min(minZ, d.Z), math.max(maxZ, d.Z)
		local l = local_("DimpleL1")
		symmetric = math.max(symmetric, math.abs(l.Z - d.Z) + math.abs(l.X + d.X))
		local tars = find(rig, "TarsusR1")
		local tip = tars.Position - tars.CFrame.RightVector * (tars.Size.X / 2)
		local tip2 = tars.Position + tars.CFrame.RightVector * (tars.Size.X / 2)
		local gap = math.min((tip - find(rig, "DimpleR1").Position).Magnitude, (tip2 - find(rig, "DimpleR1").Position).Magnitude)
		check(gap < 0.03, `the dimple stays under the oar's foot ({string.format("%.3f", gap)})`)
	end
	check(maxZ - minZ > 0.3, `the oars sweep {string.format("%.2f", maxZ - minZ)} studs fore and aft`)
	check(symmetric < 1e-6, "both oars together, a mirror of each other")
	check((local_("TarsusR2") - hind0).Magnitude < 1e-6, "the hind legs trail as they were")
	for _ = 1, 60 do t += 1 / 60; bodies:draw({ s }, t) end
	check((local_("DimpleR1") - dimple0).Magnitude < 1e-6, "gliding to a stop, the oars rest where they were")
	check(#rig.parts == BugBodies.partsOf("skater", "full"), "no part added")
	bodies:draw({}, t)
end)

case("the ant's elbowed antennae sweep as it goes, the two each in their own time, the joint kept", function()
	local bodies = BugBodies.new(workspace, "full")
	local a = { id = "a1", kind = "ant", position = Vector3.new(0, 0.12, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, state = "walk", hidden = false }
	bodies:draw({ a }, 0)
	local rig = bodies.rigs.a1
	local function at(name: string): CFrame return find(rig, "Head").CFrame:Inverse() * find(rig, name).CFrame end
	local f0 = at("Flagellum1")
	local moved, joint, apart = 0, 0, 0
	local t = 0
	for _ = 1, 90 do
		t += 1 / 60
		a.position += Vector3.new(0, 0, -0.005)
		bodies:draw({ a }, t)
		moved = math.max(moved, (at("Flagellum1").Position - f0.Position).Magnitude)
		local sc, fl = find(rig, "Scape1"), find(rig, "Flagellum1")
		local scEnds = { sc.Position + sc.CFrame.RightVector * sc.Size.X / 2, sc.Position - sc.CFrame.RightVector * sc.Size.X / 2 }
		local flEnds = { fl.Position + fl.CFrame.RightVector * fl.Size.X / 2, fl.Position - fl.CFrame.RightVector * fl.Size.X / 2 }
		local best = math.huge
		for _, p in scEnds do for _, q in flEnds do best = math.min(best, (p - q).Magnitude) end end
		joint = math.max(joint, best)
		local l, r = at("Flagellum-1").Position, at("Flagellum1").Position
		apart = math.max(apart, math.abs(l.Y - r.Y))
	end
	check(moved > 0.005, `the antenna sweeps ({string.format("%.3f", moved)} studs)`)
	check(joint < 1e-6, "scape and flagellum stay joined at the elbow")
	check(apart > 1e-3, "the two are not in step")
	bodies:draw({}, t)
end)

case("the robin stops erect, looking about; seeing something it crouches level and cocks its head; its parts' transparency written only when it changes", function()
	local function headY(pose: string, t: number): number
		for _, p in BirdBody.parts(pose, t, 1, 0) do if p.name == "Head" then return p.frame.Position.Y end end
		return 0
	end
	local function headFrame(pose: string, t: number): CFrame
		for _, p in BirdBody.parts(pose, t, 1, 0) do if p.name == "Head" then return p.frame end end
		return CFrame.identity
	end
	check(headY("stand", 0) > headY("watch", 0) + 1, "standing it holds its head high; watching it crouches low")
	local turned = 0
	for k = 1, 40 do turned = math.max(turned, angle(headFrame("stand", k * 0.25).LookVector, headFrame("stand", 0).LookVector)) end
	check(turned > 0.25, `stopped, its head turns about ({string.format("%.2f", turned)} rad)`)
	local w1, w2 = headFrame("watch", 0), headFrame("watch", 7)
	check((w1.Position - w2.Position).Magnitude < 1e-9 and angle(w1.LookVector, w2.LookVector) < 1e-9, "watching, its head is still: the tell")
	for _, pose in { "stand", "hop", "watch" } do
		local lo, hi = math.huge, -math.huge
		for _, p in BirdBody.parts(pose, 0.3, 1, 0) do
			local c = p.frame.Position
			lo = math.min(lo, c.Z - p.size.Z / 2); hi = math.max(hi, c.Z + p.size.Z / 2)
			check(finite(c), `{pose}: {p.name} finite`)
		end
		check(hi - lo > 20 and hi - lo < 30, `{pose}: {string.format("%.1f", hi - lo)} cm from bill to tail`)
	end
	-- the drawer keeps its lists and writes transparency only on a change
	local body = BirdBody.new(workspace, "full")
	local bird = { here = true, pos = Vector3.new(0, 0, 0), heading = -Vector3.zAxis, pose = "stand", cock = 1, flying = false }
	body:draw(bird, 1 / 60, 0)
	local moved = body.moved
	local head = body.parts.Head
	body:draw(bird, 1 / 60, 0)
	check(body.moved == moved and #moved > 20, "the frame's list is kept from one frame to the next")
	check(head.Transparency == 0 and body.parts.WingL.Transparency == 0, "its parts shown")
	bird.pose = "fly"
	bird.flying = true
	body:draw(bird, 1 / 60, 0)
	check(body.parts.ToeL.Transparency == 1, "in the air its toes hide")
	body.folder:Destroy()
end)

case("the green frog breathes: its throat flutters between breaths, and every few seconds a lung breath pumps deep and swells its flanks", function()
	local stub = { here = true, pos = Vector3.new(0, 0, 0), heading = -Vector3.zAxis, tongue = function() return nil end, mouth = function() return Vector3.zero end }
	local bodies = PondBodies.new(workspace, "full")
	-- drawn through a whole breath: the body part's width follows it
	local widest, narrowest = 0, math.huge
	for k = 0, 360 do
		bodies:draw(stub, nil, nil, nil, k / 60)
		local body = bodies.frog.model:FindFirstChild("Body")
		widest, narrowest = math.max(widest, body.Size.X), math.min(narrowest, body.Size.X)
	end
	check(widest > narrowest * 1.03, `drawn, its flanks swell and settle ({string.format("%.2f", narrowest)} to {string.format("%.2f", widest)})`)
	-- the pure parts: a lung breath swells the body and the throat pumps deeper than its flutter
	local function size(name: string, throat: number, swell: number): Vector3
		for _, s in PondBodies.frogParts(throat, 0, swell) do if s.name == name then return s.size end end
		return Vector3.zero
	end
	check(size("Body", 0.5, 1).X > size("Body", 0.5, 0).X * 1.03 and size("Body", 0.5, 0).X == size("Body", 0.5, nil :: any).X, "a lung breath swells its flanks; without one the body is as it was")
	check(#PondBodies.frogParts(0.5, 0, 1) == #PondBodies.frogParts(0.5, 0), "no part added")
	check(PondBodies.BREATH > 2 and 60 / PondBodies.BREATH < 30, `a lung breath every {PondBodies.BREATH} s, under the paper's ceiling of about 30 a minute`)
	bodies.folder:Destroy()
end)

case("the drawers keep their working tables from frame to frame", function()
	local flies = FlyBodies.new(workspace)
	local f = bug("k1", Species.fly_like_prototype, "PERCHED")
	flies:draw({ f }, 0)
	local p1 = flies.present
	flies:draw({ f }, 1 / 60)
	check(flies.present == p1 and p1.k1 == true, "the flies' list of who is here is kept")
	flies:draw({}, 2 / 60)
	check(flies.rigs.k1 == nil and next(flies.present) == nil, "and a fly gone is gone")
	local bugs = BugBodies.new(workspace, "full")
	local w = { id = "w1", position = Vector3.new(0, 0.12, 0), heading = -Vector3.zAxis, normal = Vector3.yAxis, state = "walk" }
	bugs:draw({ w }, 0)
	local b1 = bugs.present
	bugs:draw({ w }, 1 / 60)
	check(bugs.present == b1 and b1.w1 == true, "the bugs' too")
	bugs:draw({}, 2 / 60)
end)

case("pond reuse preserves the frozen geometry and owns its buffers", function()
local Reference=require("./studio/LegacyPondBodies")
local Candidate=PondBodies
local function equalVector(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
local function equalFrame(a,b)
 return equalVector(a.Position,b.Position) and equalVector(a.RightVector,b.RightVector)
  and equalVector(a.UpVector,b.UpVector) and equalVector(a.LookVector,b.LookVector)
end
local function same(a,b)
 for _,name in {"frog","darner"} do
  local x,y=a[name],b[name]
  if (x==nil)~=(y==nil) then return false,name.." presence" end
  if x then
   if x.count~=y.count then return false,name.." count" end
   for i=1,x.count do
    local p,q=x.parts[i],y.parts[i]
    if (p==nil)~=(q==nil) then return false,name.." tier hole" end
    if p then
     if p.Name~=q.Name or not equalVector(p.Size,q.Size) or not equalFrame(p.CFrame,q.CFrame)
      or p.Color.R~=q.Color.R or p.Color.G~=q.Color.G or p.Color.B~=q.Color.B
      or p.Material~=q.Material or p.Transparency~=q.Transparency or p.Reflectance~=q.Reflectance
      or p.CanCollide~=q.CanCollide or p.CanQuery~=q.CanQuery or p.Anchored~=q.Anchored then
      return false,name.." part "..i.." "..p.Name
     end
    end
   end
  end
 end
 return true,""
end
local totalCalls,totalFrogCalls=0,0
for _,tier in {"full","low"} do
 local a,b=Reference.new(workspace,tier),Candidate.new(workspace,tier)
 local other=Candidate.new(workspace,tier)
 local frog={here=true,pos=Vector3.zero,heading=Vector3.zAxis,length=0}
 function frog:mouth() return self.pos+Vector3.new(0,.9,-4.4) end
 function frog:tongue(target) return if self.length>0 then self:mouth()-Vector3.zAxis*self.length else nil end
 a:draw(nil,nil,nil,nil,0);b:draw(nil,nil,nil,nil,0)
 check(a.frog==nil and b.frog==nil and a.darner==nil and b.darner==nil,"empty draw built models")
 local buffers=nil;local recipe=nil;local frogRecipe=nil
 local original=Candidate.darnerParts;local calls=0
 local originalFrog=Candidate.frogParts;local frogCalls=0
 Candidate.darnerParts=function(...) calls+=1;return original(...) end
 Candidate.frogParts=function(...) frogCalls+=1;return originalFrog(...) end
 for i=1,420 do
  local t=(i-1)/60
  frog.here=(i%79)<60
  frog.pos=Vector3.new(math.sin(t)*8,math.cos(t)*2,t*3)
  frog.heading=Vector3.new(math.sin(t),0,math.cos(t))
  frog.length=if i%31<10 then (i%31)*1.7 else 0
  local at=if i%67<53 then Vector3.new(t*9,10+math.sin(t),-t*7) else nil
  local heading=if i%7==0 then nil else Vector3.new(math.cos(t),0,math.sin(t))
  local shownFrog=if i%101<95 then frog else nil
  a:draw(shownFrog,nil,at,heading,t);b:draw(shownFrog,nil,at,heading,t)
  local ok,why=same(a,b);check(ok,tier.." frame "..i.." "..why)
  if b.frog and b.darner then
   if not buffers then
    buffers={b.frog.moved,b.frog.frames,b.darner.moved,b.darner.frames};recipe=b.darner.recipe;frogRecipe=b.frog.recipe
    check(buffers[1]~=buffers[3] and buffers[2]~=buffers[4],"frog and darner share mutable buffers")
   end
   check(b.frog.moved==buffers[1] and b.frog.frames==buffers[2] and b.darner.moved==buffers[3]
    and b.darner.frames==buffers[4] and b.darner.recipe==recipe and b.frog.recipe==frogRecipe
    and b.frog.bodySpec.name=="Body" and b.frog.throatSpec.name=="Throat","buffer or recipe identity changed")
   check(#b.frog.moved==#b.frog.frames and #b.darner.moved==#b.darner.frames,"stale parallel entries")
  end
 end
 check(calls==1,tier.." invariant darner recipe rebuilt "..calls.." times")
 check(frogCalls==1,tier.." invariant frog recipe rebuilt "..frogCalls.." times")
 totalCalls+=calls
 totalFrogCalls+=frogCalls
 other:draw(frog,nil,Vector3.zero,nil,0)
 check(other.frog.moved~=b.frog.moved and other.darner.moved~=b.darner.moved
  and other.darner.recipe~=b.darner.recipe and other.frog.recipe~=b.frog.recipe
  and other.frog.bodySpec~=b.frog.bodySpec and other.frog.throatSpec~=b.frog.throatSpec,"presentation instances share mutable ownership")
 Candidate.darnerParts=original
 Candidate.frogParts=originalFrog
 -- Hidden parts must all leave and then reappear with the new transforms/sizes.
 a:draw(nil,nil,nil,nil,9);b:draw(nil,nil,nil,nil,9)
 local ok,why=same(a,b);check(ok,"hidden transition "..why)
 frog.here=true;frog.length=12
 a:draw(frog,nil,Vector3.one,Vector3.xAxis,10);b:draw(frog,nil,Vector3.one,Vector3.xAxis,10)
 ok,why=same(a,b);check(ok,"reappearance "..why)
 a.folder:Destroy();b.folder:Destroy();other.folder:Destroy()
end
for _,throat in {-.2,0,.1,.999,1,1.4} do
 for _,tongue in {0,.049,.05,.050001,.1,1,20} do
  for _,swell in {"default",0,.2,1} do
   local value=if swell=="default" then nil else swell
   local a,b=Reference.frogParts(throat,tongue,value),Candidate.frogParts(throat,tongue,value)
   local same=#a==#b
   for i,x in a do
    local y=b[i]
    same=same and y~=nil and x.name==y.name and equalVector(x.size,y.size) and equalFrame(x.frame,y.frame)
     and x.color==y.color and x.ball==y.ball and x.full==y.full and x.material==y.material
     and x.transparency==y.transparency and x.reflectance==y.reflectance
   end
   check(same,"public factory changed at "..throat.."/"..tongue.."/"..tostring(swell))
  end
 end
end
end)

print(`BODIES passed={passed} failed={failed}`)
if failed > 0 then error("body checks failed") end
