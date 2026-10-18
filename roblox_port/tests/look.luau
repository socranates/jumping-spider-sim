-- Look checks: the daughter's pattern is pinned literally, the cuteness knobs stay in range, the idle motion is small and
-- bounded, and the drawn rig stays inside its part budgets at full and low detail. The real SpiderRig, Anatomy, Setae and Idle
-- run under the shim (tests/shim.luau). This says nothing about how Roblox renders them; tools/preview renders the same parts
-- in Godot, and Studio is the only judge of the real look.
local Appearances = require("../src/Shared/Data/Appearances")
local Anatomy = require("../src/Shared/Rig/Anatomy")
local Idle = require("../src/Shared/Rig/Idle")
local Setae = require("../src/Shared/Rig/Setae")
local SupportMath = require("../src/Shared/Movement/SupportMath")
local SpiderRig = require("../src/Shared/Rig/SpiderRig")
local PeacockDance = require("../src/Shared/Rig/PeacockDance")
local AntMimicPose = require("../src/Shared/Rig/AntMimicPose")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL look: " .. what) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end
local function same(a, b): boolean
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end
local function deepcopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in t do out[k] = deepcopy(v) end
	return out
end
local function ellipsoidRadius(c, r, p): number -- 1 on the surface, above 1 outside
	local d = p - c
	return math.sqrt((d.X / r.X) ^ 2 + (d.Y / r.Y) ^ 2 + (d.Z / r.Z) ^ 2)
end

local look = Appearances.profiles[Appearances.default]
check(Appearances.default == "first_spider" and look.id == "first_spider", "the first spider is the default look")

-- ---------------------------------------------------------------- the daughter's design, literally
-- docs/art/first-spider-reference.jpg. These numbers are hers: they change only if she changes her spider.
check(same(look.body, { 0, 0, 0 }) and same(look.legs, { 0, 0, 0 }), "black body and legs")
check(same(look.white, { 0.94, 0.94, 0.92 }), "the white of the markings, bands and cheeks")
check(same(look.eyes, { 0.008, 0.008, 0.008 }) and same(look.fangs, { 0.025, 0.025, 0.025 }), "eye and fang colours")
check(same(look.abdomenRadii, { 0.25, 0.205, 0.285 }), "abdomen size")
check(look.frontLegScale == 1.28 and look.bandFraction == 0.23 and look.speckleCount == 24, "front legs, band share, speckle count")
local SPOTS = {
	{ 0, 0.10, 0.080, 0.074, 0 },
	{ -0.34, -0.46, 0.018, 0.034, -0.35 },
	{ 0.34, -0.46, 0.018, 0.034, 0.35 },
	{ -0.35, 0.67, 0.025, 0.035, 0.4 },
	{ 0.35, 0.67, 0.025, 0.035, -0.4 },
}
local spotsOk = #look.spots == 5
for i, s in SPOTS do
	local g = look.spots[i]
	spotsOk = spotsOk and g ~= nil and g.x == s[1] and g.z == s[2] and g.rx == s[3] and g.rz == s[4] and g.angle == s[5]
end
check(spotsOk, "one large central spot, two small elongated spots in front, two small ovals behind")
local band, speckle = look.band, look.speckle
check(band.count == 9 and band.step == 0.16 and band.z == -0.66 and band.rx == 0.031 and band.rz == 0.018, "the pale band across the front of the abdomen")
check(speckle.from == 0.40 and speckle.step == 0.10 and speckle.rx == 0.0035 and speckle.rz == 0.005, "fine white speckles")

-- ---------------------------------------------------------------- every knob is in the table
local KNOBS = {
	"headCenter", "headRadii", "abdomenCenter", "pedicel.center", "pedicel.radii", "face.center", "face.radii", "neck",
	"cheek.y", "cheek.z", "cheek.radii", "cheek.inset", "chelicerae.x", "chelicerae.radii", "chelicerae.pitch",
	"eye.ame.x", "eye.ame.y", "eye.ame.radii", "eye.ame.out", "eye.ame.reflectance", "eye.ame.socket.scale", "eye.ame.glints", "eye.glintColor",
	"eye.ale.x", "eye.ale.r", "eye.ple.x", "eye.ple.r", "eye.pme.x", "eye.pme.r",
	"palp.x", "palp.drop", "palp.reach", "palp.spread", "palp.stalk", "palp.club", "palp.tipRadii", "palp.fluff.hairs", "palp.fluff.length",
	"palp.drumHz", "palp.drumDeg",
	"limbs.hipX", "limbs.hipZ", "limbs.tipZ", "limbs.diameters", "limbs.thickness", "limbs.stance.x", "limbs.kneeLift", "limbs.pad",
	"fuzz.enabled", "fuzz.locks.abdomen", "fuzz.locks.head", "fuzz.locks.length", "fuzz.locks.width", "fuzz.locks.flat", "fuzz.locks.lift",
	"fuzz.locks.yaw", "fuzz.locks.black", "fuzz.locks.transparency", "fuzz.guard.abdomen", "fuzz.guard.head", "fuzz.guard.length", "fuzz.guard.width",
	"fuzz.guard.lift", "fuzz.guard.transparency", "fuzz.fringe.abdomen", "fuzz.fringe.side", "fuzz.fringe.lift",
	"fuzz.pale.density", "fuzz.pale.length", "fuzz.pale.margin", "fuzz.clear",
	"fuzz.black", "fuzz.dark", "fuzz.grey", "fuzz.frost", "fuzz.shellColor", "fuzz.shells", "fuzz.headShell.zScale",
	"fuzz.tuftHairs", "fuzz.tuftLength", "fuzz.tuft.fan", "fuzz.tuft.width", "fuzz.ruff.hairs", "fuzz.ruff.length",
	"fuzz.legHairs", "fuzz.legLength", "fuzz.legWidth", "fuzz.legTransparency", "fuzz.legBlack",
	"idle.riseSeconds", "idle.fallSeconds", "idle.breathe.period", "idle.breathe.bodyLift", "idle.breathe.lift", "idle.breathe.pitchDeg",
	"idle.tilt.rollDeg", "idle.tilt.yawDeg", "idle.tilt.pitchDeg", "idle.tilt.periods",
	"detail.full.every.lock", "detail.full.shells", "detail.full.idle", "detail.low.every.guard", "detail.low.shells", "detail.low.idle",
	"detail.low.speckleEvery", "detail.low.pads", "detail.low.sockets", "detail.low.highlight",
}
local missing = {}
for _, path in KNOBS do
	local node = look
	for key in string.gmatch(path, "[^.]+") do
		node = if type(node) == "table" then node[key] else nil
	end
	if node == nil then table.insert(missing, path) end
end
check(#missing == 0, "knobs in the appearance table (missing: " .. table.concat(missing, ", ") .. ")")

-- ---------------------------------------------------------------- cuter proportions
local A = Anatomy.layout(look)
local function volume(r): number return r.X * r.Y * r.Z end
local headToAbdomen = volume(A.headRadii) / volume(A.abdomenRadii)
check(headToAbdomen >= 1.0 and headToAbdomen <= 1.3, `the head is slightly bigger than the abdomen ({string.format("%.2f", headToAbdomen)} x its volume)`)
check(A.headRadii.Y / A.headRadii.X >= 0.78, "a rounder, less flat head")
local ame = look.eye.ame
local eyeShare = ame.radii[1] / A.headRadii.X
check(eyeShare >= 0.33 and eyeShare <= 0.5, `big front eyes ({string.format("%.2f", eyeShare)} of the head's half width)`)
check(#ame.glints >= 1 and #ame.glints <= 2 and #A.glints == 2 * #ame.glints, "one or two catchlights on each front eye")
local glintsOk = true
for _, g in ame.glints do
	glintsOk = glintsOk and g.r <= ame.radii[1] * 0.3 and math.sqrt(g.dx * g.dx + g.dy * g.dy) + g.r < ame.radii[1]
end
check(glintsOk, "catchlights are small and inside the eye")
local front, others = {}, 0
for _, e in A.eyes do
	if e.principal then table.insert(front, e) else others += 1 end
end
check(#front == 2 and others == 6, "two front eyes and six smaller ones")
check(near(front[1].at.X, -front[2].at.X, 1e-9) and front[1].at.Y == front[2].at.Y and front[1].at.Z == front[2].at.Z, "the face is symmetric")
check((front[1].at - front[2].at).Magnitude > 2 * ame.radii[1], "the front eyes do not overlap")
local eyesOnHead = true
for _, e in A.eyes do
	local s = ellipsoidRadius(A.headCenter, A.headRadii, e.at)
	eyesOnHead = eyesOnHead and s >= 0.97 and s <= 1.45 and e.at.Z < A.headCenter.Z + A.headRadii.Z * 0.3
end
check(eyesOnHead, "every eye sits on the head's surface")
local lowest = math.huge
for _, e in A.eyes do lowest = math.min(lowest, e.at.Y) end
check(front[1].at.Y > A.headCenter.Y and front[1].at.Z < A.headCenter.Z - A.headRadii.Z * 0.6, "the front eyes are on the front of the head, above its middle")
check(#A.palps == 2 and A.palps[1].tip.Y < A.palps[1].base.Y and A.palps[1].tip.Z < A.palps[1].base.Z and A.palps[1].base.X == -A.palps[2].base.X, "two palps hang forward and down from the face, mirrored")

-- No human features on the face (SPEC: no eyebrows, no human smile). Part names and tuft placement.
local function rigParts(detail: string)
	local folder = Instance.new("Folder")
	local rig = SpiderRig.new(folder, folder, nil, detail)
	return rig, rig.model:GetChildren()
end
local FORBIDDEN = { "Brow", "Mouth", "Lip", "Nose", "Smile", "Teeth", "Tongue", "Ear", "Cheek" }
local fullRig, fullParts = rigParts("full")
local namesOk = true
for _, p in fullParts do
	for _, bad in FORBIDDEN do
		if bad ~= "Cheek" and string.find(p.Name, bad) then namesOk = false end
	end
end
check(namesOk, "no part is named like a human feature")
local hairs = Setae.body(look)
local kinds = {}
for _, h in hairs do kinds[h.kind] = (kinds[h.kind] or 0) + 1 end
local tuftsOk, nearEye = true, math.huge
for _, h in hairs do
	if h.kind == "tuft" then
		tuftsOk = tuftsOk and h.at.Z > front[1].at.Z + 0.08 and h.at.Y > A.headCenter.Y -- behind the eye row, on the upper head
		for _, e in front do nearEye = math.min(nearEye, (h.at - e.at).Magnitude) end
	end
end
check(kinds.tuft == 2 * look.fuzz.tuftHairs and tuftsOk, "bold-jumper tufts: a fan on each side, behind and above the eyes, not brows")
check(nearEye > ame.radii[1], "tufts do not cover the front eyes")
-- ---------------------------------------------------------------- the coat (ROBLOX-13, second pass)
-- Short and thin hairs that lie nearly flat and are combed toward the rear; only a few short guard hairs stand up. Every hair has
-- the colour of the pattern it grows from: black on the black areas, white only inside the white spots and the band.
local COAT = { lock = true, guard = true, fringe = true, pale = true }
local function liftOf(h): number return math.deg(math.asin(math.clamp(h.dir:Dot(h.normal), -1, 1))) end
local coat, upright, longest, widest, lengthSum = 0, {}, 0, 0, 0
for _, h in hairs do
	if COAT[h.kind] then
		coat += 1
		longest, widest, lengthSum = math.max(longest, h.length), math.max(widest, h.width), lengthSum + h.length
		if liftOf(h) > 40 then table.insert(upright, h) end
	end
end
check((kinds.lock or 0) >= 150 and (kinds.fringe or 0) >= 20 and (kinds.pale or 0) >= 15,
	`the coat has locks ({kinds.lock}), a fringe ({kinds.fringe}) and white hairs ({kinds.pale})`)
check(longest <= 0.05 and lengthSum / coat <= 0.04 and widest <= 0.02,
	`coat hairs are short and thin (longest {string.format("%.3f", longest)}, mean {string.format("%.3f", lengthSum / coat)}, widest {string.format("%.3f", widest)} studs)`)
local standingAreGuards = true
for _, h in upright do standingAreGuards = standingAreGuards and h.kind == "guard" end
check(standingAreGuards and #upright == (kinds.guard or 0) and #upright >= 10 and #upright * 8 <= coat, `only a few short guard hairs stand up ({#upright} of {coat})`)
local flatOk, combed, locks = true, 0, 0
for _, h in hairs do
	local lift = liftOf(h)
	if h.kind == "lock" or h.kind == "pale" then flatOk = flatOk and lift <= 15 end
	if h.kind == "fringe" then flatOk = flatOk and lift <= 35 end
	if h.kind == "lock" then
		locks += 1
		if h.dir.Z > 0.3 then combed += 1 end
	end
end
check(flatOk, "locks and white hairs lie within 15 degrees of the surface, the fringe within 35")
check(combed >= locks * 0.9, `locks are combed toward the rear ({combed} of {locks})`)

-- The white as the rig draws it: the AbdomenSpot, FrontBand and PaleCheek parts, read back from the rig (offset in the body frame, size).
local drawn, cheeks = {}, {}
for _, f in fullRig._fixed do
	if f.part.Name == "AbdomenSpot" or f.part.Name == "FrontBand" then table.insert(drawn, f) end
	if f.part.Name == "PaleCheek" then table.insert(cheeks, f) end
end
check(#drawn == #look.spots + look.band.count and #cheeks == 2, "the rig draws the five spots, the band's dabs and the two pale cheeks")
-- The smallest ellipse radius at p over the drawn markings seen from above (below 1: inside one), and the gap to the nearest edge
-- in studs, at least (radius - 1) times the smaller half-axis.
local function overWhite(p: Vector3): (number, number)
	local best, gap = math.huge, math.huge
	for _, f in drawn do
		local q = f.offset:PointToObjectSpace(p)
		local a, b = f.part.Size.X / 2, f.part.Size.Z / 2
		local r = math.sqrt((q.X / a) ^ 2 + (q.Z / b) ^ 2)
		best = math.min(best, r)
		gap = math.min(gap, (r - 1) * math.min(a, b))
	end
	return best, gap
end
local ac = A.abdomenCenter
local paleIn, paleCount, blackClear, blackCount, toneOk, whiteOnlyOnWhite = true, 0, true, 0, true, true
local worstGap = math.huge
for _, h in hairs do
	local points = { h.at, h.at + h.dir * (h.length * 0.5), h.at + h.dir * h.length }
	if h.kind == "pale" then
		paleCount += 1
		toneOk = toneOk and h.tone == "white"
		for _, p in points do paleIn = paleIn and (overWhite(p)) < 1 end -- the whole hair stays inside a marking
	elseif COAT[h.kind] then
		toneOk = toneOk and (h.tone == "black" or h.tone == "dark") -- nothing grey or frosted in the body coat
		if h.group == "abdomen" and h.at.Y >= ac.Y + 0.02 then
			blackCount += 1
			for _, p in points do
				local _, gap = overWhite(p)
				worstGap = math.min(worstGap, gap)
			end
		end
	end
	if h.white and h.kind ~= "pale" and h.kind ~= "ruff" then whiteOnlyOnWhite = false end
end
blackClear = worstGap >= 0.002
check(paleCount >= 15 and paleIn, `white coat hairs stay inside the white spots and the band ({paleCount} hairs)`)
check(blackCount >= 100 and blackClear, `black coat hairs keep off every white marking ({blackCount} hairs, at least {string.format("%.4f", worstGap)} studs clear)`)
check(toneOk and whiteOnlyOnWhite, "white hairs are only on the white (and the face's ruff), every other coat hair is black or dark")
local offCheek, cheekHairs = true, 0
for _, h in hairs do
	if COAT[h.kind] and h.group == "head" then
		cheekHairs += 1
		for _, along in { 0, 0.5, 1 } do
			local p = h.at + h.dir * (h.length * along)
			for _, c in cheeks do
				local q = c.offset:PointToObjectSpace(p)
				offCheek = offCheek and math.sqrt((q.X / (c.part.Size.X / 2)) ^ 2 + (q.Y / (c.part.Size.Y / 2)) ^ 2 + (q.Z / (c.part.Size.Z / 2)) ^ 2) > 1.1
			end
		end
	end
end
check(cheekHairs >= 20 and offCheek, `no black hair lies on the pale cheeks ({cheekHairs} head coat hairs)`)

-- The softness comes from the fur shells: several, dark, faint (together they tint the body by less than a third).
local tint, shellMax = 1, 0
for _, shell in look.fuzz.shells do tint *= shell.transparency end
for _, v in look.fuzz.shellColor do shellMax = math.max(shellMax, v) end
check(#look.fuzz.shells >= 3 and 1 - tint <= 0.3 and shellMax <= 0.15, `fur shells: {#look.fuzz.shells} dark and faint ones (body tint {string.format("%.2f", 1 - tint)})`)
check(look.fuzz.shells[#look.fuzz.shells].scale >= 1.12, "the outer fur shell stands far enough off the body to make a soft halo")
check(look.detail.low.every.guard == 0 and look.detail.low.shells == 1, "low detail has no standing guard hairs and one fur shell")
local fringeOk, lean, fringeN = true, 0, 0
for _, h in hairs do
	if h.kind == "fringe" then
		local out = if h.at.X >= 0 then 1 else -1
		fringeOk = fringeOk and math.abs(h.at.X) >= 0.15 and liftOf(h) >= 10 -- at the sides, lifted a little
		lean += h.dir.X * out
		fringeN += 1
	end
end
check(fringeOk and fringeN > 0 and lean / fringeN > 0.15, "the fringe grows at the sides, lifted a little and leaning out, so the outline is soft")
local covered = false
for _, h in hairs do
	for _, e in A.eyes do
		if (h.at - e.at).Magnitude < e.radii.X * 0.85 then covered = true end
	end
end
check(not covered, "no hair sits inside an eye")
check(#Setae.palp(look) == 2 * look.palp.fluff.hairs, "fluffy palps: hairs on each club")

-- Knobs have effects (copies of the table, so the real one is untouched).
local function with(edit: (any) -> ()): any
	local copy = deepcopy(look)
	edit(copy)
	return copy
end
check(#Setae.body(with(function(l) l.fuzz.enabled = false end)) == 0, "fuzz.enabled turns the coat off")
check(#Setae.body(with(function(l) l.fuzz.locks.abdomen = 0 end)) < #hairs - 40, "fuzz.locks.abdomen sets the number of locks")
local function countKind(list: { any }, kind: string): number
	local n = 0
	for _, h in list do if h.kind == kind then n += 1 end end
	return n
end
check(countKind(Setae.body(with(function(l) l.fuzz.guard.abdomen = 0; l.fuzz.guard.head = 0 end)), "guard") == 0, "fuzz.guard sets the standing hairs")
check(countKind(Setae.body(with(function(l) l.fuzz.pale.density = 0 end)), "pale") == 0, "fuzz.pale.density sets the white hairs on the markings")
check(countKind(Setae.body(with(function(l) l.fuzz.clear = 0.05 end)), "lock") < (kinds.lock or 0), "fuzz.clear keeps the black hairs further off the white")
local function meanLift(list: { any }, kind: string): number
	local sum, n = 0, 0
	for _, h in list do
		if h.kind == kind then sum += liftOf(h); n += 1 end
	end
	return sum / math.max(1, n)
end
check(meanLift(Setae.body(with(function(l) l.fuzz.locks.lift = { 50, 70 } end)), "lock") > meanLift(hairs, "lock") + 30, "fuzz.locks.lift sets how flat the locks lie")
check(#Setae.palp(with(function(l) l.palp.fluff.hairs = 0 end)) == 0, "palp.fluff.hairs sets the palps' fluff")
local wide = Anatomy.layout(with(function(l) l.eye.ame.x = 0.14 end))
local wideFront = {}
for _, e in wide.eyes do if e.principal then table.insert(wideFront, e) end end
check(wideFront[2].at.X > front[2].at.X + 0.02, "eye.ame.x spreads the front eyes")
check(Anatomy.layout(with(function(l) l.headRadii = { 0.30, 0.24, 0.30 } end)).headRadii.X == 0.30, "headRadii sets the head")

-- Snap accents have quiet intervals, deterministic bounded peaks, and no camera/root motion.
local peakSnap, quiet = 0, 0
for i=0,600 do
 local yaw,lift=Idle.snap(i/60,false)
 check(math.abs(yaw)<=math.rad(5)+1e-9 and lift>=0 and lift<=.022+1e-9,"snap stays bounded")
 peakSnap=math.max(peakSnap,math.abs(yaw));if yaw==0 and lift==0 then quiet+=1 end
end
check(peakSnap>math.rad(4) and quiet>300,"snaps are distinct bursts with still pauses")
-- ---------------------------------------------------------------- idle motion
local cfg = look.idle
local lim = Idle.limits(cfg)
local zeroOk = true
for t = 0, 60, 0.7 do
	local p = Idle.pose(t, 0, cfg)
	zeroOk = zeroOk and p.bodyLift == 0 and p.abdomenLift == 0 and p.abdomenPitch == 0 and p.headRoll == 0 and p.headYaw == 0 and p.headPitch == 0
end
check(zeroOk, "no idle motion while not calm")
local peak = { 0, 0, 0, 0, 0, 0 }
local boundOk = true
for t = 0, 600, 0.37 do
	local p = Idle.pose(t, 1, cfg)
	local v = { p.bodyLift, p.abdomenLift, p.abdomenPitch, p.headRoll, p.headYaw, p.headPitch }
	local l = { lim.bodyLift, lim.abdomenLift, lim.abdomenPitch, lim.headRoll, lim.headYaw, lim.headPitch }
	for i = 1, 6 do
		boundOk = boundOk and math.abs(v[i]) <= l[i] + 1e-12
		peak[i] = math.max(peak[i], math.abs(v[i]) / l[i])
	end
end
check(boundOk, "idle motion stays inside its limits")
check(peak[1] > 0.8 and peak[4] > 0.5 and peak[5] > 0.5 and peak[6] > 0.5, "idle motion actually moves")
check(lim.bodyLift <= 0.012 and lim.abdomenLift <= 0.03 and lim.abdomenPitch <= math.rad(5) and lim.headRoll <= math.rad(10)
	and lim.headYaw <= math.rad(10) and lim.headPitch <= math.rad(6), "idle motion is gentle (small bob, small tilt)")
check(Idle.pose(12.3, 0.6, cfg).headRoll == Idle.pose(12.3, 0.6, cfg).headRoll, "idle motion is deterministic")
local drumZero, drumMax = true, 0
for t = 0, 120, 0.05 do
	local d0, d1 = Idle.palps(t, 0, look.palp), Idle.palps(t, 1, look.palp)
	drumZero = drumZero and d0[1] == 0 and d0[2] == 0
	drumMax = math.max(drumMax, math.abs(d1[1]), math.abs(d1[2]))
end
check(drumZero and drumMax > 0.5 * math.rad(look.palp.drumDeg) and drumMax <= math.rad(look.palp.drumDeg) + 1e-12, "palp drumming is bounded and stops when not standing")
check(look.palp.drumDeg <= 25 and look.palp.drumHz <= 5, "palp drumming is a flick, not a flail")

-- ---------------------------------------------------------------- the rig: budgets and motion
local floor = BoxWorld.folder("LookFloor", { { name = "floor", lo = Vector3.new(-5, -1, -5), hi = Vector3.new(5, 0, 5), profile = "painted_wood_dry" } })
local function census(parts)
	local c = { total = 0, hair = 0, shell = 0, other = 0, bad = 0 }
	for _, p in parts do
		if p:IsA("BasePart") then
			c.total += 1
			if p.Name == "Seta" then c.hair += 1 elseif p.Name == "FuzzShell" then c.shell += 1 else c.other += 1 end
			if not (p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch) then c.bad += 1 end
			if p.Size.X < 0.001 or p.Size.Y < 0.001 or p.Size.Z < 0.001 or p.Size.X ~= p.Size.X then c.bad += 1 end
		end
	end
	return c
end
local lowRig, lowParts = rigParts("low")
local full, low = census(fullParts), census(lowParts)
print(`look: full {full.total} parts ({full.hair} hairs, {full.shell} shells, {full.other} other), low {low.total} ({low.hair} hairs, {low.shell} shells, {low.other} other)`)
-- Budgets are the ones the first coat had (705 parts at full detail, 272 at low): the second coat is lighter, not heavier.
check(full.total <= 705 and full.other <= 160 and full.hair + full.shell >= 300 and full.hair + full.shell <= 720, `full detail part budget ({full.total})`)
check(low.total <= 272 and low.hair >= 100 and low.hair <= 260 and low.shell <= 2, `low detail part budget ({low.total})`)
-- Each tier keeps exactly the hairs its table says: one in `every` of each class, none of a class whose `every` is 0.
local function kept(count: number, every: number): number return if every <= 0 then 0 else math.floor(count / every) end
local function expectedHairs(every: { [string]: number }): number
	local n = 0
	for kind, count in kinds do n += kept(count, every[kind] or 1) end
	n += kept(#Setae.palp(look), every.palp)
	for i = 1, 8 do n += kept(#Setae.leg(look, i), every.leg) end
	return n
end
check(full.hair == expectedHairs(look.detail.full.every), `full detail keeps the hairs its table says ({full.hair} of {expectedHairs(look.detail.full.every)})`)
check(low.hair == expectedHairs(look.detail.low.every), `low detail keeps the hairs its table says ({low.hair} of {expectedHairs(look.detail.low.every)}), no guard hairs`)
check(low.total < full.total * 0.45 and low.other < full.other, "low detail is under half the parts of full")
check(full.bad == 0 and low.bad == 0, "every drawn part is anchored, non-colliding, not queryable and has a real size")
check(fullRig.model:GetAttribute("Detail") == "full" and lowRig.model:GetAttribute("Detail") == "low", "the model says which detail it was built at")
check(fullRig.model:FindFirstChild("PrincipalEye") ~= nil and lowRig.model:FindFirstChild("PrincipalEye") ~= nil, "both tiers keep the front eyes")
local lowCatch = 0
for _, p in lowParts do if p.Name == "Catchlight" then lowCatch += 1 end end
check(lowCatch == 2 * #ame.glints, "both tiers keep the catchlights")

local function snapshot(rig): { [string]: any }
	local out = {}
	for _, p in rig.model:GetChildren() do
		if p:IsA("BasePart") then table.insert(out, p.CFrame.Position) end
	end
	return out
end
local function moved(a, b): number
	local most = 0
	for i, v in a do most = math.max(most, (v - b[i]).Magnitude) end
	return most
end
local body = SupportMath.bodyCFrame(Vector3.new(0, 0.31, 0), Vector3.yAxis, Vector3.new(0, 0, -1))
local function settle(rig, seconds: number, grounded: boolean?, moving: boolean?)
	for _ = 1, math.floor(seconds * 60) do rig:update(body, 1 / 60, if grounded == nil then true else grounded, moving or false) end
end
local fullFloor = SpiderRig.new(floor, floor, nil, "full")
local lowFloor = SpiderRig.new(floor, floor, nil, "low")
settle(fullFloor, 0.5); settle(lowFloor, 0.5)
local feet = {}
for i, leg in fullFloor._legs do feet[i] = leg.planted end
local a1, b1 = snapshot(fullFloor), snapshot(lowFloor)
settle(fullFloor, 4); settle(lowFloor, 4)
local a2, b2 = snapshot(fullFloor), snapshot(lowFloor)
check(moved(a1, a2) > 0.004, `full detail: the standing spider breathes, tilts its head and drums its palps ({string.format("%.4f", moved(a1, a2))} studs)`)
check(moved(b1, b2) < 0.12, "low detail: bounded snap accents without elaborate idle detail")
check(moved(a1, a2) < 0.12, "idle motion stays small")
local feetStill = true
for i, leg in fullFloor._legs do feetStill = feetStill and feet[i] ~= nil and leg.planted ~= nil and (leg.planted - feet[i]).Magnitude < 1e-9 end
check(feetStill, "idle motion leaves the planted feet where they are")
check((fullFloor.root.CFrame.Position - body.Position).Magnitude < 1e-9, "the root part (what the camera and tests read) is not moved by the idle motion")
fullFloor.reducedMotion = true
settle(fullFloor, 3)
local a3 = snapshot(fullFloor)
settle(fullFloor, 2)
check(moved(a3, snapshot(fullFloor)) < 1e-9, "reduced motion turns the idle motion off")
local walking = SpiderRig.new(floor, floor, nil, "full")
settle(walking, 3)
local w1 = snapshot(walking)
settle(walking, 0.3, true, true)
settle(walking, 3, true, true)
local w2 = snapshot(walking)
settle(walking, 2, true, true)
check(moved(w2, snapshot(walking)) < 0.12, "walking has no idle motion on top (head and palps still)")
for _, r in { fullRig, lowRig, fullFloor, lowFloor, walking } do r:destroy() end

-- ---------------------------------------------------------------- the peacock spider (ROBLOX-30)
-- A second appearance drawn by the same rig: small, low, with a fan of flat discs and legs III of its own. The daughter's spider is
-- checked above and stays the default; nothing below changes it.
local volans = Appearances.profiles.maratus_volans_male
check(volans ~= nil and volans.id == "maratus_volans_male" and Appearances.default == "first_spider", "the peacock spider is a second profile and the default is still the first spider")
local PA = Anatomy.layout(volans)
local pLength = (PA.abdomenCenter.Z + PA.abdomenRadii.Z) - (PA.faceCenter.Z - PA.faceRadii.Z)
check(pLength >= 0.40 and pLength <= 0.50, `the peacock spider's body is about 0.45 studs long ({string.format("%.3f", pLength)}; a male is 4 to 5 mm at 1 stud = 1 cm)`)
check(pLength < 0.55 * ((A.abdomenCenter.Z + A.abdomenRadii.Z) - (A.faceCenter.Z - A.faceRadii.Z)), "it is about half the default spider's length")
check(volans.fuzz == nil and volans.scale == 0.47 and volans.bodyDrop > 0.15 and volans.bodyDrop < 0.30, "no fuzz at this size; it stands low (the body drops under the collider's centre)")
local pFront = {}
for _, e in PA.eyes do if e.principal then table.insert(pFront, e) end end
check(#pFront == 2 and #PA.eyes == 8 and #PA.palps == 2, "still a jumping spider: two big front eyes, six smaller ones, two palps")
check(#volans.stripes == 3 and volans.stripes.color[1] > 0.7 and volans.stripes.color[3] < 0.2, "three red-orange carapace stripes")
check(volans.pairs[3] ~= nil and volans.pairs[3].bands == false and volans.limbs.pairReach[3] > 1, "legs III are longer, darker, unbanded")

local function pRig(detail: string, parent: Instance?)
	local folder = parent or Instance.new("Folder")
	return SpiderRig.new(folder, folder, "maratus_volans_male", detail)
end
local pFull, pLow = pRig("full"), pRig("low")
local function names(rig): { [string]: number }
	local out: { [string]: number } = {}
	for _, p in rig.model:GetChildren() do
		if p:IsA("BasePart") then out[p.Name] = (out[p.Name] or 0) + 1 end
	end
	return out
end
local cf, cl = census(pFull.model:GetChildren()), census(pLow.model:GetChildren())
print(`look: peacock spider full {cf.total} parts, low {cl.total}`)
check(cf.total <= 130 and cf.hair == 0 and cf.shell == 0, `peacock full detail part budget ({cf.total})`)
check(cl.total <= 80 and cl.total < cf.total * 0.75, `peacock low detail part budget ({cl.total})`)
check(cf.bad == 0 and cl.bad == 0, "every drawn peacock part is anchored, non-colliding, not queryable and has a real size")
local nf, nl = names(pFull), names(pLow)
check((nf.FanFringe or 0) == 2 and (nf.FanFigure or 0) == 3 and (nf.FanFlap or 0) == 2 and (nf.FanField or 0) == 3 and (nf.FanArch or 0) == 3, "the full fan: fringe and rim on both faces, two arches and two fields in front, the figure, the flaps")
check((nl.FanFringe or 0) == 1 and (nl.FanField or 0) == 1 and (nl.FanFigure or 0) == 3, "the low fan is front only and plainer")
check((nf.CarapaceStripe or 0) == 3 and (nf.PaleCheek or 0) == 2 and (nf.PrincipalEye or 0) == 2 and (nf.Catchlight or 0) == 4, "stripes, the pale margin, the two front eyes with their catchlights")
local pBad = false
for name in nf do
	for _, bad in FORBIDDEN do if bad ~= "Cheek" and string.find(name, bad) then pBad = true end end
end
check(not pBad, "no peacock part is named like a human feature")

local pFloor = SpiderRig.new(floor, floor, "maratus_volans_male", "full")
local dFloor = SpiderRig.new(floor, floor, nil, "full")
settle(pFloor, 1); settle(dFloor, 1)
check(pFloor.model:GetAttribute("AppearanceId") == "maratus_volans_male" and dFloor.model:GetAttribute("AppearanceId") == "first_spider", "the model says which spider it is")
check((pFloor.root.CFrame.Position - body.Position).Magnitude < 1e-9, "the root part stays at the collider's frame")
local abdomenY, lowest, highest = 0, math.huge, -math.huge
for _, p in pFloor.model:GetChildren() do
	if p:IsA("BasePart") and p.Name == "Abdomen" then abdomenY = p.CFrame.Position.Y end
	if p:IsA("BasePart") and (string.find(p.Name, "Femur") or string.find(p.Name, "Tarsus") or p.Name == "Cephalothorax") then
		lowest = math.min(lowest, p.CFrame.Position.Y - p.Size.Y / 2)
	end
end
check(abdomenY > 0.05 and abdomenY < 0.17, `the drawn body stands low (abdomen centre {string.format("%.3f", abdomenY)} up with the collider at 0.31)`)
local feetDown = true
for _, leg in pFloor._legs do feetDown = feetDown and leg.planted ~= nil and math.abs(leg.planted.Y) < 1e-6 end
check(feetDown, "all eight feet find the floor")
local footReach = 0
for _, leg in pFloor._legs do footReach = math.max(footReach, (leg.planted :: Vector3 - Vector3.new(0, 0, 0)).Magnitude) end
check(footReach < 0.55, `the legs are not much longer than the body (farthest foot {string.format("%.2f", footReach)} studs from the body)`)

-- The fan, folded and open: the dance pose is the only thing that moves it.
local function fanParts(rig, name: string)
	local out = {}
	for _, p in rig.model:GetChildren() do
		if p:IsA("BasePart") and p.Name == name then table.insert(out, p) end
	end
	return out
end
local foldedField = fanParts(pFloor, "FanField")[1]
local foldedWidth = foldedField.Size.X
local foldedAbdomen = fanParts(pFloor, "Abdomen")[1].CFrame
local pose = PeacockDance.rawPose(5.2, false)
check(pose.fanOpen > 0.99 and pose.legsRaise > 0.99, "(the dance pose at 5.2 s has the fan open and legs III up)")
pFloor.dance = pose
settle(pFloor, 0.1)
local openField = fanParts(pFloor, "FanField")[1]
check(openField.Size.X > foldedWidth * 1.6, `the fan widens as it opens ({string.format("%.3f", foldedWidth)} to {string.format("%.3f", openField.Size.X)} studs)`)
local fringe = fanParts(pFloor, "FanFringe")
local roundness = 0
for _, f in fringe do roundness = math.max(roundness, f.Size.X / f.Size.Z) end
check(roundness >= 1.0 and roundness <= 1.3, `the open fan is a near-round disc, a little wider than long (width to length {string.format("%.2f", roundness)})`)
check(openField.CFrame.UpVector.Z < -0.9, "raised, the fan's face looks forward")
local abdomenNow = fanParts(pFloor, "Abdomen")[1].CFrame
check(abdomenNow.Position.Y > foldedAbdomen.Position.Y + 0.05, `the abdomen rises with the fan ({string.format("%.3f", abdomenNow.Position.Y - foldedAbdomen.Position.Y)} studs)`)
local tarsusIII = fanParts(pFloor, "Tarsus3")[1].CFrame.Position.Y
check(tarsusIII > 0.2, `legs III go up (the left foot {string.format("%.2f", tarsusIII)} studs up)`)
check((pFloor.root.CFrame.Position - body.Position).Magnitude < 1e-9, "the dance does not move the root part")
local planted = true
for i, leg in pFloor._legs do planted = planted and leg.planted ~= nil and (leg.pair == 3 or (leg.planted - pFloor._legs[i].planted).Magnitude < 1e-9) end
check(planted, "the other legs stay planted while legs III are up")
pFloor.dance = nil
settle(pFloor, 0.1)
check(fanParts(pFloor, "FanField")[1].Size.X < foldedWidth * 1.05, "with no pose the fan folds again")
-- The pose says nothing to an appearance without a fan, and slow dance steps never reach the collider.
dFloor.dance = pose
local before = snapshot(dFloor)
dFloor:update(body, 0, true, false)
check(dFloor._fan == nil and moved(before, snapshot(dFloor)) < 0.05, "the default spider has no fan and ignores a dance pose")
-- The spider-eye view hides the fan with the body.
pFloor:setEyeView(true)
local hidden = true
for _, f in fanParts(pFloor, "FanFringe") do hidden = hidden and f.LocalTransparencyModifier == 1 end
check(hidden, "the eye view hides the fan")
dFloor.dance=nil
dFloor.reducedMotion=false
dFloor.jumpLoad=1
local anchors={};for i,leg in dFloor._legs do anchors[i]=leg.foot end
settle(dFloor,.25)
check(dFloor._shownLoad>.99,"held jump builds the drawn preparation")
local feetStill=true;for i,leg in dFloor._legs do feetStill=feetStill and (leg.foot-anchors[i]).Magnitude<1e-8 end
check(feetStill and (dFloor.root.Position-body.Position).Magnitude<1e-9,"preparation keeps planted feet and physics root unchanged")
dFloor.reducedMotion=true
dFloor:update(body,.2,true,false)
check(dFloor._shownLoad==0,"reduced motion clears preparation")
dFloor.jumpLoad=0;dFloor.jumpPush=1;dFloor.reducedMotion=false
dFloor:update(body,0,false,false)
local extended=dFloor._legs[3].tarsus.Position
dFloor.jumpPush=0;dFloor:update(body,0,false,false)
check((dFloor._legs[3].tarsus.Position-extended).Magnitude>.03,"rear legs visibly extend at takeoff")
for _,r in {pFull,pLow,dFloor} do
 r.dance=nil;r.jumpLoad=0;r.jumpPush=0;r.hangDirection=Vector3.yAxis;r.reducedMotion=true
 for _=1,30 do r:update(body,1/60,false,false) end
 local head=r.model:FindFirstChild("Cephalothorax")
 check(r:spinneretPoint(body).Y>head.Position.Y+.2*r._k,"hanging head sits beneath spinneret")
 check((r.root.Position-body.Position).Magnitude<1e-9,"hanging leaves camera/physics root alone")
 local feet={};for i,leg in r._legs do feet[i]=leg.foot end
 r:update(body,1,false,false)
 local calm=true;for i,leg in r._legs do calm=calm and (leg.foot-feet[i]).Magnitude<1e-8 and leg.planted==nil end
 check(calm,"reduced-motion hanging legs are still and unplanted")
 r.hangDirection=nil;r:update(body,1/60,true,false)
 check(r._hang==0,"landing restores surface frame immediately")
end


-- ---------------------------------------------------------------- the ant-mimicking spider (ROBLOX-64)
-- A third appearance drawn by the same rig: an ant's three segments and waist, long thin legs, a jumping spider's eyes. Legs I go up as
-- antennae and the body turns a little as it walks, both only from the pose. The first spider and the peacock spider are checked above and
-- below and nothing here changes them.
local function antMimicChecks() -- a function of its own: this file is close to Luau's limit of 200 locals
local ant = Appearances.profiles.myrmarachne_formicaria_female
check(ant ~= nil and ant.id == "myrmarachne_formicaria_female" and Appearances.default == "first_spider" and Appearances.profiles.maratus_volans_male ~= nil, "the ant-mimicking spider is a third profile and the default is still the first spider")
local NA = Anatomy.layout(ant)
local aLength = (NA.abdomenCenter.Z + NA.abdomenRadii.Z) - (NA.faceCenter.Z - NA.faceRadii.Z)
check(aLength >= 0.46 and aLength <= 0.54, `the ant-mimicking spider's body is about 0.5 studs long ({string.format("%.3f", aLength)}; the playbacks' body length was 5 mm at 1 stud = 1 cm)`)
check(ant.fuzz == nil and ant.fan == nil and ant.scale == 0.5 and ant.bodyDrop > 0.15 and ant.bodyDrop < 0.25 and ant.antennae ~= nil and ant.antennae.pair == 1, "no fuzz, no fan, stands on long legs; legs I are its antennae")
local aFront = {}
for _, e in NA.eyes do if e.principal then table.insert(aFront, e) end end
check(#aFront == 2 and #NA.eyes == 8 and #NA.palps == 2 and #NA.cheeks == 0, "still a jumping spider: two big front eyes, six smaller ones, two palps")
-- An ant's silhouette: a head wider than the thorax, a waist narrower than any of the three, an oval gaster behind it, in a row.
local thorax, node
for _, ex in ant.extras do
	if ex.name == "Thorax" then thorax = ex elseif ex.name == "PetioleNode" then node = ex end
end
check(thorax ~= nil and node ~= nil, "a thorax and a node on the waist are drawn")
local waistX = ant.pedicel.radii[1]
check(NA.headRadii.X > thorax.radii[1] and waistX < thorax.radii[1] * 0.5 and waistX < NA.abdomenRadii.X * 0.5, "the head is wider than the thorax and the waist is a narrow petiole (under half either side)")
check(NA.headCenter.Z < thorax.center[3] and thorax.center[3] < ant.pedicel.center[2 + 1] and ant.pedicel.center[3] < NA.abdomenCenter.Z, "head, thorax, waist and gaster in a row, front to back")
local pinchHead = ellipsoidRadius(NA.headCenter, NA.headRadii, Vector3.new(0, 0, (NA.headCenter.Z + NA.headRadii.Z + (thorax.center[3] - thorax.radii[3])) / 2))
check(pinchHead < 1.0 and NA.abdomenRadii.Z * 2 > NA.headRadii.Z * 2 * 1.2, "the head and the thorax overlap only at a pinch, and the gaster is the longest segment")
check(ant.legs[1] < 0.3 and ant.gloss ~= nil and ant.gloss > 0 and ant.gloss <= 0.3, "dark, glossy cuticle (the body is nearly black)")
check(ant.limbs.diameters[1][1] <= 0.025 and ant.limbs.stance.reach >= 1.0, "long, thin legs")

local function aRig(detail: string, parent: Instance?)
	local folder = parent or Instance.new("Folder")
	return SpiderRig.new(folder, folder, "myrmarachne_formicaria_female", detail)
end
local aFull, aLow = aRig("full"), aRig("low")
local ac, al = census(aFull.model:GetChildren()), census(aLow.model:GetChildren())
print(`look: ant-mimicking spider full {ac.total} parts, low {al.total}`)
check(ac.total <= 100 and ac.hair == 0 and ac.shell == 0, `ant mimic full detail part budget ({ac.total})`)
check(al.total <= 70 and al.total < ac.total * 0.9, `ant mimic low detail part budget ({al.total})`)
check(ac.bad == 0 and al.bad == 0, "every drawn ant mimic part is anchored, non-colliding, not queryable and has a real size")
local an, anl = names(aFull), names(aLow)
check((an.Thorax or 0) == 1 and (an.PetioleNode or 0) == 1 and (an.Pedicel or 0) == 1 and (an.Abdomen or 0) == 1 and (an.Cephalothorax or 0) == 1, "the full set of segments: head, thorax, node, waist, gaster")
check((an.PrincipalEye or 0) == 2 and (an.Catchlight or 0) == 4 and (an.PaleCheek or 0) == 0 and (an.CarapaceStripe or 0) == 0 and (an.FanField or 0) == 0, "the big front eyes with their catchlights; no cheeks, stripes or fan")
check((an.Femur1 or 0) == 1 and (an.Femur8 or 0) == 1 and (an.FemurBand1 or 0) == 0 and (anl.Foot1 or 0) == 0 and (an.Foot1 or 0) == 1, "eight legs; no bands; foot balls only at full detail")
local aBad = false
for name in an do
	for _, bad in FORBIDDEN do if bad ~= "Cheek" and string.find(name, bad) then aBad = true end end
end
check(not aBad, "no ant mimic part is named like a human feature")
local glossy = true
for _, p in aFull.model:GetChildren() do
	if p:IsA("BasePart") and (p.Name == "Abdomen" or p.Name == "Thorax" or p.Name == "Cephalothorax") then glossy = glossy and p.Reflectance == ant.gloss end
end
check(glossy, "the body segments are glossy")

local aFloor = SpiderRig.new(floor, floor, "myrmarachne_formicaria_female", "full")
settle(aFloor, 1)
check(aFloor.model:GetAttribute("AppearanceId") == "myrmarachne_formicaria_female" and (aFloor.root.CFrame.Position - body.Position).Magnitude < 1e-9, "the model says which spider it is; the root stays at the collider's frame")
local feetDown = true
for _, leg in aFloor._legs do feetDown = feetDown and leg.planted ~= nil and math.abs(leg.planted.Y) < 1e-6 end
check(feetDown, "all eight feet find the floor")
local aReach = 0
for _, leg in aFloor._legs do aReach = math.max(aReach, (leg.planted :: Vector3).Magnitude) end
check(aReach < 0.62, `the legs reach about a body length from the body (farthest foot {string.format("%.2f", aReach)} studs)`)
local lowestBody, headTop = math.huge, 0
for _, p in aFloor.model:GetChildren() do
	if p:IsA("BasePart") and (p.Name == "Abdomen" or p.Name == "Cephalothorax" or p.Name == "Thorax") then lowestBody = math.min(lowestBody, p.CFrame.Position.Y - p.Size.Y / 2) end
	if p:IsA("BasePart") and p.Name == "Cephalothorax" then headTop = p.CFrame.Position.Y + p.Size.Y / 2 end
end
check(lowestBody > 0.04 and lowestBody < 0.12, `the body stands clear of the floor on its legs ({string.format("%.3f", lowestBody)} studs under the belly)`)

-- The antennae: legs I go up above the head, both the same (in phase), and nothing else changes; no pose, no antennae.
local function legPart(rig, name: string): BasePart return fanParts(rig, name)[1] end
local plantedBefore = {}
for i, leg in aFloor._legs do plantedBefore[i] = leg.planted end
local tarsusBefore = legPart(aFloor, "Tarsus1").CFrame.Position
local stand = AntMimicPose.new()
local pose
for _ = 1, 90 do pose = stand:step(1 / 60, true, false, 0) end
check(pose.antennae > 0.999, "(the pose has the antennae up)")
aFloor.reducedMotion = true -- the twitch (ROBLOX-57) yaws the whole body for a moment; mirror and phase are compared with it off
aFloor.ant = pose
settle(aFloor, 0.1)
local l1, r1 = legPart(aFloor, "Tarsus1").CFrame.Position, legPart(aFloor, "Tarsus5").CFrame.Position
check(l1.Y > headTop + 0.05 and r1.Y > headTop + 0.05 and l1.Y > tarsusBefore.Y + 0.15, `legs I go up above head height (feet {string.format("%.3f", l1.Y)} and {string.format("%.3f", r1.Y)} up, the head's top {string.format("%.3f", headTop)})`)
check(near(l1.Y, r1.Y, 1e-6) and near(l1.Z, r1.Z, 1e-6) and near(l1.X, -r1.X, 1e-6), "both legs I are mirror images: they move in phase")
check(l1.Z < -0.2, "the antennae point forward")
local others = true
for i, leg in aFloor._legs do
	if leg.pair ~= 1 then others = others and leg.planted ~= nil and (leg.planted :: Vector3 - plantedBefore[i]).Magnitude < 1e-9 end
end
check(others, "the other six legs stay planted while legs I are up")
local feetAfter = true
for _, leg in aFloor._legs do feetAfter = feetAfter and leg.planted ~= nil and (leg.pair ~= 1 or math.abs(leg.planted.Y) < 1e-6) end
check(feetAfter and (aFloor.root.CFrame.Position - body.Position).Magnitude < 1e-9, "legs I keep their planted feet below the raised pose; the root does not move")
-- Waving moves both together; the display key lifts them higher.
local upY, upZ = l1.Y, l1.Z
local waved = AntMimicPose.new()
local wp
local lowest, highest = math.huge, -math.huge
for _ = 1, 240 do
	wp = waved:step(1 / 60, true, false, 0)
	aFloor.ant = wp
	aFloor:update(body, 1 / 60, true, false)
	local a1, a2 = legPart(aFloor, "Tarsus1").CFrame.Position, legPart(aFloor, "Tarsus5").CFrame.Position
	if wp.antennae > 0.999 then
		lowest, highest = math.min(lowest, a1.Y), math.max(highest, a1.Y)
		if not (near(a1.Y, a2.Y, 1e-6) and near(a1.Z, a2.Z, 1e-6)) then feetAfter = false end
	end
end
check(feetAfter and highest - lowest > 0.02, `waving moves the antennae together ({string.format("%.3f", highest - lowest)} studs of travel)`)
local shown = AntMimicPose.new()
shown:start(true, false)
for _ = 1, 40 do aFloor.ant = shown:step(1 / 60, true, false, 0); aFloor:update(body, 1 / 60, true, false) end
check(legPart(aFloor, "Tarsus1").CFrame.Position.Y > highest - 0.02, "the display pose lifts legs I at least as high as the calm wave reaches")
aFloor.ant = nil
aFloor.reducedMotion = false
settle(aFloor, 0.2)
check(legPart(aFloor, "Tarsus1").CFrame.Position.Y < tarsusBefore.Y + 0.02, "with no pose legs I are legs again")
-- The drawn walk: the body turns about its up axis, the root and the planted feet do not.
local walkPose = { antennae = 0, high = 0, wave = 0, yaw = math.rad(10), lateral = 0.03, walking = true, shownSeconds = 0 }
local abdomenBefore = fanParts(aFloor, "Abdomen")[1].CFrame
local rootBefore = aFloor.root.CFrame
aFloor.ant = walkPose
aFloor:update(body, 1 / 60, true, true)
local abdomenAfter = fanParts(aFloor, "Abdomen")[1].CFrame
local turned = math.acos(math.clamp(abdomenAfter.LookVector:Dot(abdomenBefore.LookVector), -1, 1))
check(near(turned, math.rad(10), 0.01), `the drawn body turns {string.format("%.1f", math.deg(turned))} degrees with the yaw`)
aFloor.ant = { antennae = 0, high = 0, wave = 0, yaw = 0, lateral = 0.03, walking = true, shownSeconds = 0 }
aFloor:update(body, 1 / 60, true, true)
check(near(fanParts(aFloor, "Abdomen")[1].CFrame.Position.X - abdomenBefore.Position.X, 0.03, 1e-6), "and sways to the side by the lateral")
check((aFloor.root.CFrame.Position - rootBefore.Position).Magnitude < 1e-9 and aFloor.root.CFrame.LookVector.X == rootBefore.LookVector.X, "the root part (the collider's frame) does not turn or sway")
aFloor.ant = nil
-- The other appearances ignore the pose.
dFloor.ant = pose
local beforeD = snapshot(dFloor)
settle(dFloor, 0.1)
pFloor.ant = pose
local beforeP = snapshot(pFloor)
settle(pFloor, 0.1)
check(moved(beforeD, snapshot(dFloor)) < 0.05 and moved(beforeP, snapshot(pFloor)) < 0.05, "the first spider and the peacock spider ignore an ant pose")
aFloor:setEyeView(true)
local aHidden = true
for _, p in aFloor.model:GetChildren() do
	if p:IsA("BasePart") and p.Name == "Thorax" then aHidden = aHidden and p.LocalTransparencyModifier == 1 end
end
check(aHidden, "the eye view hides the thorax with the body")
for _, r in { pFull, pLow, pFloor, dFloor, aFull, aLow, aFloor } do r:destroy() end
end
antMimicChecks()

-- ---------------------------------------------------------------- the tarantula pack (ROBLOX-81)
-- Two more appearances drawn by the same rig: the Mexican redknee and the Greenbottle blue. A costume on the first spider's body: its size, its
-- stance and its eight legs; what makes them tarantulas is the carapace, the tubercle's eight tiny eyes, the fangs, the palps, the abdomen and
-- the leg colours. Nothing below changes the three spiders checked above.
local function tarantulaChecks() -- a function of its own: this file is close to Luau's limit of 200 locals
local RED, BLUE = "brachypelma_hamorii", "chromatopelma_cyaneopubescens"
local red, blue = Appearances.profiles[RED], Appearances.profiles[BLUE]
check(red ~= nil and blue ~= nil and red.id == RED and blue.id == BLUE and Appearances.default == "first_spider", "the two tarantulas are profiles and the default is still the first spider")
check(red.pack == "tarantula_pack" and blue.pack == "tarantula_pack" and look.pack == nil and volans.pack == nil and Appearances.profiles.myrmarachne_formicaria_female.pack == nil, "both belong to the tarantula pack; the first three spiders belong to none")
local function hexOf(c: { number }): string return string.format("%02X%02X%02X", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
-- Perplexity's colours, exactly (design adapted by Nathan; the shapes are ART).
check(hexOf(red.body) == "1A1614" and hexOf(red.extras[1].color) == "D67638" and red.extras[1].name == "CarapaceRim", "the redknee's carapace: a dark centre #1A1614 with a copper-orange rim #D67638")
check(hexOf(red.abdomenColor) == "161312" and red.marks[1].name == "UrticatingPatch" and hexOf(red.marks[1].color) == "BA5028" and red.marks[1].z > 0.2, "plump velvet-black abdomen #161312 with a ginger-rust patch #BA5028 at the dorsal rear")
check(hexOf(red.legColors.knee) == "EE5E22" and hexOf(red.legBands.tibia) == "E08642" and hexOf(red.legColors.tarsus) == "181413" and hexOf(red.legColors.femur) == "0E0C0B", "flame-orange patellae #EE5E22, a warm pale-orange tibia band #E08642, dark velvety feet #181413, near-black femurs")
check(hexOf(red.white) == "EE5E22", "the pedipalps' patellae are the same flame orange")
check(hexOf(blue.body) == "24767C" and hexOf(blue.extras[1].color) == "308E94" and hexOf(blue.fangs) == "308E94" and blue.gloss == 0.08, "the greenbottle's carapace is metallic blue-green #24767C (Reflectance 0.08) with a lighter turquoise rim and chelicerae #308E94")
check(hexOf(blue.legColors.femur) == "204AA8" and hexOf(blue.legColors.tarsus) == "204AA8" and hexOf(blue.legColors.knee) == "2E62C4" and hexOf(blue.legColors.ankle) == "2E62C4" and blue.legGloss == 0.06, "cobalt legs #204AA8 (Reflectance 0.06) with brighter azure joint rings #2E62C4")
check(hexOf(blue.fuzz.frost) == "DAA86C" and blue.fuzz.legsOnly == true and blue.fuzz.legTone == "frost", "pale golden-tan leg bristles #DAA86C")
check(hexOf(blue.abdomenColor) == "E46226" and #blue.marks == 7 and hexOf(blue.marks[1].color) == "2A1C18", "a vivid tiger-orange abdomen #E46226 with markings in #2A1C18")
local TA, TB = Anatomy.layout(red), Anatomy.layout(blue)
-- A tarantula against the first spider: a broader, lower carapace, thick parallel fangs, longer leg-like palps, stockier legs.
for _, t in { { red, TA }, { blue, TB } } do
	local lk, ly = t[1], t[2]
	check(ly.headRadii.X > A.headRadii.X and ly.headRadii.Y < A.headRadii.Y * 0.7 and ly.headRadii.X / ly.headRadii.Y > 1.5 * (A.headRadii.X / A.headRadii.Y), `{lk.id}: a broad, low carapace`)
	check(lk.fuzz == nil or lk.fuzz.legsOnly == true, `{lk.id}: no coat of fuzz on the body`)
	check(lk.cheek == nil and lk.fan == nil and lk.stripes == nil and lk.antennae == nil and lk.scale == nil, `{lk.id}: no cheeks, fan, stripes or antennae, and the first spider's size`)
end
local function len3(pl: any): number return Vector3.new(pl.drop, pl.reach, pl.spread).Magnitude end
local cheli = look.chelicerae.radii
check(near(red.chelicerae.radii[2] / cheli[2], 1.3, 0.05) and near(red.chelicerae.radii[1] / cheli[1], 1.3, 0.05) and red.chelicerae.splay == 0 and red.chelicerae.pitch > 0, "thick (about 1.3 times) parallel chelicerae that point forward and down")
check(near(len3(red.palp) / len3(look.palp), 1.45, 0.05) and near(len3(blue.palp) / len3(look.palp), 1.45, 0.05), "pedipalps about 1.45 times the first spider's in length")
local function femur(lk: any, pair: number): number return lk.limbs.diameters[pair][1] * lk.limbs.thickness * (if pair == 1 then lk.frontLegScale else 1) end
check(near(femur(red, 2) / femur(look, 2), 1.35, 0.02) and femur(blue, 2) > femur(look, 2) * 1.1 and femur(blue, 2) < femur(red, 2), "the redknee's legs are about 1.35 times the first spider's thickness, the greenbottle's a little less")
check(red.limbs.tipZ[1] > look.limbs.tipZ[1] and red.bodyDrop > 0 and red.bodyDrop < 0.15 and TA.abdomenRadii.Y * 2 > TB.abdomenRadii.Y * 2 * 1.1, "the legs are no longer than the first spider's, it stands low, and the redknee's abdomen is the plumper")
-- The ocular tubercle: a small mound that stands out of the carapace, eight eyes on it, none of the salticid's big front pair.
for _, t in { { red, TA }, { blue, TB } } do
	local lk, ly = t[1], t[2]
	local tub = ly.tubercle :: any
	check(tub ~= nil and tub.radii.X < ly.headRadii.X * 0.4 and tub.center.Y + tub.radii.Y > ly.headCenter.Y + ly.headRadii.Y, `{lk.id}: a small tubercle that stands up out of the carapace`)
	local principal, onMound, inCluster = 0, 0, 0
	for _, e in ly.eyes do
		if e.principal then principal += 1 end
		local k = ellipsoidRadius(tub.center, tub.radii, e.at)
		if k > 0.95 and k < 1.55 then onMound += 1 end
		if (e.at - tub.center).Magnitude < 0.12 and e.radii.X < 0.03 then inCluster += 1 end
	end
	check(#ly.eyes == 8 and principal == 0 and onMound == 8 and inCluster == 8, `{lk.id}: eight tiny eyes clustered on the mound, no big front pair ({onMound} on the mound)`)
	check(#ly.glints == 2 and ly.glints[1].side ~= ly.glints[2].side, `{lk.id}: two catchlights, one a side`)
end
check(TA.tubercle.center.Y == TA.tubercle.center.Y and ellipsoidRadius(TA.headCenter, TA.headRadii, TA.eyes[1].at) > 1.0, "the eyes are above the carapace")
-- The parts, at both tiers: budgets (128 at full detail, 80 at low), one tubercle, eight eyes, two catchlights, the spinnerets, the markings.
local function rigOf(id: string, detail: string, parent: Instance?)
	local folder = parent or Instance.new("Folder")
	return SpiderRig.new(folder, folder, id, detail)
end
local function counts(id: string)
	local f, l = rigOf(id, "full"), rigOf(id, "low")
	local out = { full = census(f.model:GetChildren()), low = census(l.model:GetChildren()), nf = names(f), nl = names(l), f = f, l = l }
	return out
end
local rc, bc = counts(RED), counts(BLUE)
print(`look: Mexican redknee full {rc.full.total} parts, low {rc.low.total}; Greenbottle blue full {bc.full.total} parts ({bc.full.hair} bristles), low {bc.low.total}`)
check(rc.full.total <= 128 and bc.full.total <= 128, `tarantula full detail part budget ({rc.full.total} and {bc.full.total}, at most 128)`)
check(rc.low.total <= 80 and bc.low.total <= 80 and rc.low.total < rc.full.total and bc.low.total < bc.full.total, `tarantula low detail (phone and mate) part budget ({rc.low.total} and {bc.low.total}, at most 80)`)
check(rc.full.bad == 0 and rc.low.bad == 0 and bc.full.bad == 0 and bc.low.bad == 0 and rc.full.shell == 0 and bc.full.shell == 0, "every drawn tarantula part is anchored, non-colliding, not queryable and has a real size")
check(rc.full.hair == 0 and rc.low.hair == 0 and bc.low.hair == 0 and bc.full.hair >= 24 and bc.full.hair <= 40, `the redknee has no bristles; the greenbottle has {bc.full.hair} on its legs at full detail and none at low`)
for _, c in { rc, bc } do
	local nf, nl = c.nf, c.nl
	check((nf.OcularTubercle or 0) == 1 and (nl.OcularTubercle or 0) == 1 and (nf.Eye or 0) == 8 and (nl.Eye or 0) == 8 and (nf.Catchlight or 0) == 2 and (nl.Catchlight or 0) == 2, "one tubercle, eight tiny eyes and two catchlights at both tiers")
	check((nf.PrincipalEye or 0) == 0 and (nf.EyeSocket or 0) == 0 and (nf.PaleCheek or 0) == 0 and (nf.FanField or 0) == 0 and (nf.CarapaceRim or 0) == 1 and (nl.CarapaceRim or 0) == 1, "no big front eyes, sockets, cheeks or fan; the carapace has its rim")
	check((nf.Spinneret or 0) == 2 and (nf.SpinneretTip or 0) == 2 and (nl.Spinneret or 0) == 2 and (nl.SpinneretTip or 0) == 0, "two spinnerets of two segments at full detail, of one at low")
	check((nf.Chelicera or 0) == 2 and (nf.PalpStalk or 0) == 2 and (nf.PalpBand or 0) == 2 and (nf.Femur1 or 0) == 1 and (nf.Femur8 or 0) == 1 and (nf.Foot1 or 0) == 1 and (nl.Foot1 or 0) == 0, "two fangs, two palps, eight legs; foot balls at full detail only")
end
check((rc.nf.UrticatingPatch or 0) == 1 and (rc.nl.UrticatingPatch or 0) == 1 and (rc.nf.TibiaBand1 or 0) == 1 and (rc.nf.TibiaBand8 or 0) == 1 and (rc.nf.FemurBand1 or 0) == 0 and (rc.nf.TarsusBand1 or 0) == 0 and (rc.nl.TibiaBand8 or 0) == 1, "the redknee: the rust patch and one band on each tibia, on both tiers")
check((bc.nf.AbdomenBar or 0) == 8 and (bc.nl.AbdomenBar or 0) == 8 and (bc.nf.AbdomenMidline or 0) == 3 and (bc.nl.AbdomenMidline or 0) == 1 and (bc.nf.TibiaBand1 or 0) == 0, "the greenbottle: four pairs of bars on both tiers, the dark midline whole at full detail and a dab at low, no leg bands")
local tarBad = false
for _, c in { rc, bc } do
	for name in c.nf do
		for _, bad in FORBIDDEN do if string.find(name, bad) then tarBad = true end end
	end
end
check(not tarBad, "no tarantula part is named like a human feature")
-- Colours and gloss as drawn.
local function partColor(rig, name: string): string return hexOf({ rig.model:FindFirstChild(name).Color.R, rig.model:FindFirstChild(name).Color.G, rig.model:FindFirstChild(name).Color.B }) end
check(partColor(rc.f, "Cephalothorax") == "1A1614" and partColor(rc.f, "CarapaceRim") == "D67638" and partColor(rc.f, "Abdomen") == "161312" and partColor(rc.f, "UrticatingPatch") == "BA5028" and partColor(rc.f, "Knee1") == "EE5E22" and partColor(rc.f, "TibiaBand1") == "E08642" and partColor(rc.f, "Tarsus1") == "181413" and partColor(rc.f, "Femur1") == "0E0C0B", "the redknee is drawn in Perplexity's colours")
check(partColor(bc.f, "Cephalothorax") == "24767C" and partColor(bc.f, "CarapaceRim") == "308E94" and partColor(bc.f, "Chelicera") == "308E94" and partColor(bc.f, "Abdomen") == "E46226" and partColor(bc.f, "AbdomenBar") == "2A1C18" and partColor(bc.f, "Femur1") == "204AA8" and partColor(bc.f, "Knee1") == "2E62C4" and partColor(bc.f, "Ankle1") == "2E62C4" and partColor(bc.f, "Seta") == "DAA86C", "the greenbottle is drawn in Perplexity's colours, bristles included")
check(bc.f.model:FindFirstChild("Cephalothorax").Reflectance == 0.08 and bc.f.model:FindFirstChild("Femur1").Reflectance == 0.06 and bc.f.model:FindFirstChild("Tarsus3").Reflectance == 0.06 and (rc.f.model:FindFirstChild("Cephalothorax").Reflectance or 0) == 0, "slight gloss on the greenbottle's carapace (0.08) and legs (0.06); none on the redknee")
-- The bars soften at the last growth stage only; the first spider's rig has none of that.
local barT = {}
for stage = 0, 3 do
	bc.f:setGrowthStage(stage)
	barT[stage] = bc.f.model:FindFirstChild("AbdomenBar").Transparency
end
check(barT[0] == 0 and barT[1] == 0 and barT[2] == 0 and barT[3] > 0.4 and barT[3] <= 0.7, `the greenbottle's bars soften at the last stage ({barT[3]} transparent) and are full before it`)
bc.f:setGrowthStage(3)
local barMid = bc.f.model:FindFirstChild("AbdomenMidline")
check(barMid.Transparency == 0, "(the dark midline stays)")
rc.f:setGrowthStage(3)
check(rc.f.model:FindFirstChild("UrticatingPatch").Transparency == 0, "the redknee's patch does not fade")
-- Growth and the mate's scale: the same scaling as the first spider's, any size.
local ratio = {}
for _, id in { "first_spider", RED, BLUE } do
	local r = rigOf(id, "low")
	r:setGrowthStage(0)
	local before = r.model:FindFirstChild("Cephalothorax").Size
	r:setGrowthStage(3)
	local adult = r.model:FindFirstChild("Cephalothorax").Size
	r:setScale(1.7)
	ratio[id] = { adult.X / before.X, r.model:FindFirstChild("Cephalothorax").Size.X / before.X }
	r:destroy()
end
for _, id in { RED, BLUE } do
	check(near(ratio[id][1], 1.5, 1e-9) and near(ratio[id][2], 1.7, 1e-9) and near(ratio[id][1], ratio.first_spider[1], 1e-9), `{id}: the adult stage scales the body 1.5 times, setScale to any size`)
end
-- Standing on the floor: eight feet down, the belly clear, the root at the collider, the eye view hiding the tubercle and the rim.
for _, id in { RED, BLUE } do
	local rig = rigOf(id, "full", floor)
	settle(rig, 1)
	local down = true
	for _, leg in rig._legs do down = down and leg.planted ~= nil and math.abs((leg.planted :: Vector3).Y) < 1e-6 end
	check(down, `{id}: all eight feet find the floor`)
	local belly = math.huge
	for _, p in rig.model:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Abdomen" or p.Name == "Cephalothorax" or p.Name == "CarapaceRim") then belly = math.min(belly, p.CFrame.Position.Y - p.Size.Y / 2) end
	end
	check(belly > 0.0 and belly < 0.12, `{id}: the body stands low and clear of the floor ({string.format("%.3f", belly)} studs under the belly)`)
	check(rig.model:GetAttribute("AppearanceId") == id and (rig.root.CFrame.Position - body.Position).Magnitude < 1e-9, `{id}: the model says which spider it is; the root stays at the collider's frame`)
	local reach = 0
	for _, leg in rig._legs do reach = math.max(reach, (leg.planted :: Vector3 - Vector3.new(0, 0, 0)).Magnitude) end
	local firstReach = 0
	for _, leg in fullFloor._legs do firstReach = math.max(firstReach, (leg.planted :: Vector3 - Vector3.new(0, 0, 0)).Magnitude) end
	check(reach <= firstReach * 1.02, `{id}: the legs reach no further than the first spider's (farthest foot {string.format("%.2f", reach)} studs against {string.format("%.2f", firstReach)})`)
	rig:setEyeView(true)
	local hidden = true
	for _, p in rig.model:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "OcularTubercle" or p.Name == "CarapaceRim" or p.Name == "Spinneret" or p.Name == "AbdomenBar" or p.Name == "UrticatingPatch") then hidden = hidden and p.LocalTransparencyModifier == 1 end
	end
	check(hidden, `{id}: the eye view hides the tubercle, the rim and the markings with the body`)
	rig:destroy()
end
-- The threat display and silk mat (ROBLOX-82): the pose rears the drawn prosoma, lifts legs I and the palps, turns the drawn body about and swings
-- the spinnerets. Display only: the root, the planted feet and the other spiders do not change. reducedMotion is on for the comparisons so the idle
-- twitch does not move the baseline.
local TarantulaPose = require("../src/Shared/Rig/TarantulaPose")
local TarantulaData = require("../src/Shared/Data/Tarantula")
local function part(rig: any, name: string): BasePart return rig.model:FindFirstChild(name) :: BasePart end
local function pair(rig: any, name: string): { BasePart } return fanParts(rig, name) end
for _, id in { RED, BLUE } do
	local rig = rigOf(id, "full", floor)
	rig.reducedMotion = true
	settle(rig, 0.5)
	local planted = {}
	for i, leg in rig._legs do planted[i] = leg.planted end
	local head0, tub0, tars0 = part(rig, "Cephalothorax").CFrame.Position, part(rig, "OcularTubercle").CFrame.Position, part(rig, "Tarsus1").CFrame.Position
	local palp0 = pair(rig, "PalpStalk")[1].CFrame.Position
	local rear0 = part(rig, "Tarsus4").CFrame.Position
	local abdomen0 = part(rig, "Abdomen").CFrame
	local root0 = rig.root.CFrame
	-- The rear-up, held: the head and tubercle go up and back, legs I and the palps go up above the head, the legs behind stay put.
	local hold = TarantulaPose.rawPose(1.5, false)
	check(hold.phase == "threat" and near(hold.rear, math.rad(TarantulaData.rearDeg), 1e-9) and hold.legs == 1, "(the pose at 1.5 s is the held threat)")
	rig.threat = hold
	settle(rig, 0.1)
	local head1, tub1, tars1 = part(rig, "Cephalothorax").CFrame.Position, part(rig, "OcularTubercle").CFrame.Position, part(rig, "Tarsus1").CFrame.Position
	check(head1.Y > head0.Y + 0.05 and tub1.Y > tub0.Y + 0.05, `{id}: the prosoma rears (head {string.format("%.3f", head1.Y - head0.Y)} and tubercle {string.format("%.3f", tub1.Y - tub0.Y)} studs up)`)
	check(tars1.Y > tars0.Y + 0.15 and tars1.Y > tub1.Y, `{id}: legs I lift above the tubercle ({string.format("%.3f", tars1.Y)} against {string.format("%.3f", tub1.Y)})`)
	local lt, rt = part(rig, "Tarsus1").CFrame.Position, part(rig, "Tarsus5").CFrame.Position
	check(near(lt.Y, rt.Y, 1e-4) and near(lt.X, -rt.X, 1e-4), `{id}: both raised legs are mirror images`)
	check(pair(rig, "PalpStalk")[1].CFrame.Position.Y > palp0.Y + 0.02, `{id}: the palps lift`)
	check(math.abs(part(rig, "Tarsus4").CFrame.Position.Y - rear0.Y) < 0.03 and (part(rig, "Tarsus4").CFrame.Position - rear0).Magnitude < 0.05, `{id}: the legs behind hardly change ({string.format("%.4f", (part(rig, "Tarsus4").CFrame.Position - rear0).Magnitude)} studs)`)
	local plantedOk = true
	for i, leg in rig._legs do plantedOk = plantedOk and leg.planted ~= nil and (leg.planted :: Vector3 - planted[i]).Magnitude < 1e-9 end
	check(plantedOk and (rig.root.CFrame.Position - root0.Position).Magnitude < 1e-9, `{id}: every foot keeps its planted spot and the root does not move`)
	check(part(rig, "Abdomen").CFrame.Position.Y < head1.Y and (part(rig, "Abdomen").CFrame.Position - abdomen0.Position).Magnitude < 0.02, `{id}: the abdomen stays on the floor behind the reared prosoma`)
	-- The tremble moves the raised feet a little and nothing else.
	rig.threat = { phase = "threat", presence = 1, rear = hold.rear, legs = 1, palps = hold.palps, yaw = 0, sweep = 0, tremor = 0 }
	settle(rig, 0.1)
	local still = part(rig, "Tarsus1").CFrame.Position.Y
	rig.threat = { phase = "threat", presence = 1, rear = hold.rear, legs = 1, palps = hold.palps, yaw = 0, sweep = 0, tremor = 1 }
	settle(rig, 0.1)
	local shaken = part(rig, "Tarsus1").CFrame.Position.Y - still
	check(shaken > 0.003 and shaken < 0.05, `{id}: the tremble moves a raised foot only a little ({string.format("%.4f", shaken)} studs)`)
	-- With no pose (presence 0) the motor has the head and legs again.
	rig.threat = TarantulaPose.NONE
	settle(rig, 0.1)
	check(near(part(rig, "Cephalothorax").CFrame.Position.Y, head0.Y, 1e-6) and near(part(rig, "Tarsus1").CFrame.Position.Y, tars0.Y, 1e-6), `{id}: no pose, no rear: the head and legs I are back where the motor has them`)
	rig.threat = nil
	-- The turn about: the drawn body pivots about its up axis to 180 degrees; the root and the feet do not turn.
	local mat = TarantulaPose.rawPose(3.2 + 1.2 + 0.1, false)
	check(mat.phase == "mat" and near(mat.yaw, math.rad(180), 1e-9), "(the pose in the mat phase has turned the body 180 degrees)")
	rig.threat = { phase = "mat", presence = 1, rear = 0, legs = 0, palps = 0, yaw = mat.yaw, sweep = 0, tremor = 0 }
	settle(rig, 0.1)
	local turned = math.acos(math.clamp(part(rig, "Abdomen").CFrame.LookVector:Dot(abdomen0.LookVector), -1, 1))
	check(near(turned, math.pi, 0.01), `{id}: the drawn body turns {string.format("%.1f", math.deg(turned))} degrees about its up axis`)
	check(part(rig, "Abdomen").CFrame.Position.Z < abdomen0.Position.Z - 0.1, `{id}: the abdomen has swung round to the front`)
	check(rig.root.CFrame.LookVector.Z == root0.LookVector.Z and (rig.root.CFrame.Position - root0.Position).Magnitude < 1e-9, `{id}: the root (the collider's frame) does not turn`)
	-- The spinnerets sweep side to side; the second segment farther; a sweep of nothing is straight back.
	rig.threat = nil
	settle(rig, 0.1)
	local s0, t0 = pair(rig, "Spinneret")[1].CFrame.Position, pair(rig, "SpinneretTip")[1].CFrame.Position
	local right = { phase = "turn", presence = 1, rear = 0, legs = 0, palps = 0, yaw = 0, sweep = math.rad(TarantulaData.sweepDeg), tremor = 0 }
	rig.threat = right
	settle(rig, 0.1)
	local s1, t1 = pair(rig, "Spinneret")[1].CFrame.Position, pair(rig, "SpinneretTip")[1].CFrame.Position
	rig.threat = { phase = "turn", presence = 1, rear = 0, legs = 0, palps = 0, yaw = 0, sweep = -right.sweep, tremor = 0 }
	settle(rig, 0.1)
	local s2 = pair(rig, "Spinneret")[1].CFrame.Position
	check(math.abs(s1.X - s0.X) > 0.005 and math.abs(s2.X - s0.X) > 0.005 and (s1.X - s0.X) * (s2.X - s0.X) < 0, `{id}: the spinnerets swing to one side and the other ({string.format("%.3f", s1.X - s0.X)} and {string.format("%.3f", s2.X - s0.X)} studs)`)
	check(math.abs(t1.X - t0.X) > math.abs(s1.X - s0.X), `{id}: the tip segment swings farther than the base`)
	check(near(s1.Y, s0.Y, 1e-6) and near(part(rig, "Tarsus1").CFrame.Position.Y, tars0.Y, 1e-6), `{id}: the sweep moves nothing else`)
	rig.threat = nil
	rig:destroy()
end
-- Another appearance ignores the pose entirely; so do the rigs that have no threat configuration.
local ignorer = rigOf("first_spider", "full", floor)
ignorer.reducedMotion = true
settle(ignorer, 0.3)
local ignoreBefore = snapshot(ignorer)
ignorer.threat = TarantulaPose.rawPose(1.5, false)
settle(ignorer, 0.1)
check(moved(ignoreBefore, snapshot(ignorer)) < 0.05, "the first spider ignores a threat pose")
ignorer:destroy()
for _, c in { rc, bc } do
	c.f:destroy()
	c.l:destroy()
end
end
tarantulaChecks()

print(`LOOK passed={passed} failed={failed}`)
if failed > 0 then error("look checks failed") end
