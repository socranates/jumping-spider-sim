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
-- ---------------------------------------------------------------- the coat (ROBLOX-13, second pass; ROBLOX-85, third)
-- Short, fine hairs that lie along the body at 15 to 25 degrees off the surface, pointing backward and a little outward; only a few short guard hairs
-- stand up. Every hair has the colour of the pattern it grows from: black on the black areas, white only inside the white spots and the band
-- (a few with a greyer cast).
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
	if h.kind == "lock" then flatOk = flatOk and lift >= 14.9 and lift <= 25.1 end
	if h.kind == "pale" then flatOk = flatOk and lift >= 13.9 and lift <= 22.1 end
	if h.kind == "fringe" then flatOk = flatOk and lift >= 19.9 and lift <= 30.1 end
	if h.kind == "lock" then
		locks += 1
		if h.dir.Z > 0.3 then combed += 1 end
	end
end
check(flatOk, "locks lie at 15 to 25 degrees off the surface, the white hairs at 14 to 22 and the fringe at 20 to 30: lying along the body, not flat chips and not spikes")
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
local greyTips = 0
for _, h in hairs do
	local points = { h.at, h.at + h.dir * (h.length * 0.5), h.at + h.dir * h.length }
	if h.kind == "pale" then
		paleCount += 1
		toneOk = toneOk and h.tone == "white"
		for _, p in points do paleIn = paleIn and (overWhite(p)) < 1 end -- the whole hair stays inside a marking
	elseif COAT[h.kind] then
		toneOk = toneOk and (h.tone == "black" or h.tone == "dark" or h.tone == "grey") -- nothing frosted in the body coat; a few have a greyer cast
		if h.tone == "grey" then greyTips += 1 end
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
check(toneOk and whiteOnlyOnWhite, "white hairs are only on the white (and the face's ruff), every other coat hair is black, dark or (a few) grey")
check(greyTips >= 8 and greyTips <= coat * 0.12, `a few coat hairs have a paler, greyer cast ({greyTips} of {coat}), nothing frosted or white off the pattern`)
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
-- Budgets: the first coat had 705 parts at full detail and 272 at low. ROBLOX-84 gives the legs, feet and fangs their segments (53 parts more at full
-- detail, 10 at low) and sets the ceiling at 700 and 290; `other` (everything that is not a hair or a shell) was 141 and is 193.
check(full.total <= 700 and full.other <= 200 and full.hair + full.shell >= 300 and full.hair + full.shell <= 720, `full detail part budget ({full.total})`)
check(low.total <= 290 and low.hair >= 100 and low.hair <= 260 and low.shell <= 2, `low detail part budget ({low.total})`)
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
-- The greenbottle's palette is ROBLOX-85's (ROBLOX-81's first palette was a carapace #24767C at Reflectance 0.08, cobalt legs #204AA8 at 0.06, pale golden-tan
-- bristles #DAA86C and a tiger-orange abdomen #E46226 with bars #2A1C18, which read as pure plastic): teal-green with a sheen, deep metallic cobalt, pale
-- blue-white bristles, a burnt-orange abdomen and softer brown bars; the azure joint rings (#2E62C4), the turquoise chelicerae (#308E94) and the dark midline (#2A1C18) are as they were.
check(hexOf(blue.body) == "1E8062" and hexOf(blue.extras[1].color) == "2A9A7E" and hexOf(blue.fangs) == "308E94" and blue.gloss == 0.14, "the greenbottle's carapace is teal-green #1E8062 with a sheen (Reflectance 0.14), a lighter rim #2A9A7E and turquoise chelicerae #308E94")
check(hexOf(blue.legColors.femur) == "1E3F8F" and hexOf(blue.legColors.tarsus) == "1E3F8F" and hexOf(blue.legColors.knee) == "2E62C4" and hexOf(blue.legColors.ankle) == "2E62C4" and blue.legGloss == 0.10, "deep metallic cobalt legs #1E3F8F (Reflectance 0.10) with brighter azure joint rings #2E62C4")
check(hexOf(blue.fuzz.frost) == "C9DCF2" and blue.fuzz.legsOnly == true and blue.fuzz.legTone == "frost", "pale blue-white leg bristles #C9DCF2")
check(hexOf(blue.abdomenColor) == "C4551C" and #blue.marks == 7 and hexOf(blue.marks[1].color) == "2A1C18" and hexOf(blue.marks[4].color) == "5A2A14", "a burnt-orange abdomen #C4551C with a dark midline #2A1C18 and softer brown bars #5A2A14")
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
-- The parts, at both tiers: budgets (150 at full detail, 90 at low since ROBLOX-84; 128 and 80 before), one tubercle, eight eyes, two catchlights, the spinnerets, the markings.
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
check(rc.full.total <= 150 and bc.full.total <= 150, `tarantula full detail part budget ({rc.full.total} and {bc.full.total}, at most 150)`)
check(rc.low.total <= 90 and bc.low.total <= 90 and rc.low.total < rc.full.total and bc.low.total < bc.full.total, `tarantula low detail (phone and mate) part budget ({rc.low.total} and {bc.low.total}, at most 90)`)
check(rc.full.bad == 0 and rc.low.bad == 0 and bc.full.bad == 0 and bc.low.bad == 0, "every drawn tarantula part is anchored, non-colliding, not queryable and has a real size")
check(rc.full.shell == 2 and rc.low.shell == 2 and bc.full.shell == 2 and bc.low.shell == 2, "a fur shell on the carapace and one on the abdomen, at both tiers (ROBLOX-85)")
check(rc.low.hair == 0 and bc.low.hair == 0 and rc.full.hair >= 30 and rc.full.hair <= 40 and bc.full.hair >= 30 and bc.full.hair <= 40, `leg bristles (and the redknee's patch tuft) at full detail only: {rc.full.hair} and {bc.full.hair} hairs at full, none at low`)
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
check(partColor(bc.f, "Cephalothorax") == "1E8062" and partColor(bc.f, "CarapaceRim") == "2A9A7E" and partColor(bc.f, "Chelicera") == "308E94" and partColor(bc.f, "Abdomen") == "C4551C" and partColor(bc.f, "AbdomenBar") == "5A2A14" and partColor(bc.f, "AbdomenMidline") == "2A1C18" and partColor(bc.f, "Femur1") == "1E3F8F" and partColor(bc.f, "Knee1") == "2E62C4" and partColor(bc.f, "Ankle1") == "2E62C4" and partColor(bc.f, "Seta") == "C9DCF2", "the greenbottle is drawn in its ROBLOX-85 colours, bristles included")
check(bc.f.model:FindFirstChild("Cephalothorax").Reflectance == 0.14 and bc.f.model:FindFirstChild("Femur1").Reflectance == 0.10 and bc.f.model:FindFirstChild("Tarsus3").Reflectance == 0.10 and bc.f.model:FindFirstChild("FemurTip3").Reflectance == 0.10 and (rc.f.model:FindFirstChild("Cephalothorax").Reflectance or 0) == 0, "a sheen on the greenbottle's carapace (0.14) and metallic legs (0.10, tips too); none on the redknee")
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

-- ---------------------------------------------------------------- the segments of a leg, the feet and the fangs (ROBLOX-84)
-- The first spider and the two tarantulas draw each leg link as the segments a spider has: a tapered femur (two rods), a patella for a knee, a
-- tapered tibia (the first spider), a break in the tarsus, a flattened pad and its claws (the first spider), and fangs under the
-- chelicerae. The solver, the targets and the gait are untouched: the joints are where they were. The rival (a clone of the first spider's
-- look, ROBLOX-72) and the peacock and ant spiders are drawn as before.
local function shapeChecks()
local RED, BLUE = "brachypelma_hamorii", "chromatopelma_cyaneopubescens"
local function build(id: string?, detail: string, parent: Instance?): any
	local folder = parent or Instance.new("Folder")
	return SpiderRig.new(folder, folder, id, detail)
end
local function endOf(p: BasePart, sign: number): Vector3 return p.CFrame * Vector3.new(sign * p.Size.X / 2, 0, 0) end -- a rod's end (-1 start, 1 end)
local function pick(rig: any, name: string): BasePart return rig.model:FindFirstChild(name) :: BasePart end
local first, firstLow = build(nil, "full", floor), build(nil, "low", floor)
local rival = build("rival_spider", "full", floor)
for _, r in { first, firstLow, rival } do settle(r, 1) end
local nf, nl, nr = names(first), names(firstLow), names(rival)
check((nf.FemurTip1 or 0) == 1 and (nf.FemurTip8 or 0) == 1 and (nf.TibiaTip1 or 0) == 1 and (nf.TarsusTip8 or 0) == 1 and (nf.TarsalJoint1 or 0) == 1 and (nf.TarsalJoint8 or 0) == 1, "the first spider's legs: a tapered femur and tibia and a break in the tarsus, on all eight")
check((nf.Claw or 0) == 16 and (nf.Fang or 0) == 4 and (nf.Foot1 or 0) == 1 and (nf.Foot8 or 0) == 1, "two claws on every foot (16), and two fangs of two segments (4)")
check((nl.FemurTip1 or 0) == 1 and (nl.TibiaTip1 or 0) == 0 and (nl.TarsalJoint1 or 0) == 0 and (nl.TarsusTip1 or 0) == 0 and (nl.Claw or 0) == 0 and (nl.Foot1 or 0) == 0 and (nl.Fang or 0) == 2, "at low detail: the femur still tapers and the fangs are one segment; no tibia taper, tarsus break, pad or claws")
check(next(nr) ~= nil and (nr.FemurTip1 or 0) == 0 and (nr.TarsalJoint1 or 0) == 0 and (nr.Claw or 0) == 0 and (nr.Fang or 0) == 0, "the rival, a clone of the first spider's look, keeps the plain legs and no fangs")
check(Appearances.profiles.rival_spider.legForm == nil and Appearances.profiles.rival_spider.fang == nil and Appearances.profiles.maratus_volans_male.legForm == nil and Appearances.profiles.myrmarachne_formicaria_female.legForm == nil, "the rival, the peacock spider and the ant mimic have no legForm and no fang")
-- The shaped legs share the plain legs' joints exactly: the same feet, the same knees and ankles (the solver was not touched).
local same3 = true
for i, leg in first._legs do
	local o = rival._legs[i]
	same3 = same3 and leg.planted ~= nil and o.planted ~= nil and (leg.planted - o.planted).Magnitude < 1e-9
	same3 = same3 and (pick(first, "Knee" .. i).CFrame.Position - pick(rival, "Knee" .. i).CFrame.Position).Magnitude < 1e-9
	same3 = same3 and (pick(first, "Ankle" .. i).CFrame.Position - pick(rival, "Ankle" .. i).CFrame.Position).Magnitude < 1e-9
end
check(same3, "the feet, knees and ankles of the shaped legs are exactly where the plain legs have them")
-- Each link is a chain of rods that meet end to end: femur, its thinner tip, the patella at the knee; tibia and its tip; the tarsus, the break, the tip, the foot.
local joined, taper, bigKnee = true, true, true
for i, leg in first._legs do
	local fe, ft, ti, tt, ta, tp, jt, ko = pick(first, "Femur" .. i), pick(first, "FemurTip" .. i), pick(first, "Tibia" .. i), pick(first, "TibiaTip" .. i), pick(first, "Tarsus" .. i), pick(first, "TarsusTip" .. i), pick(first, "TarsalJoint" .. i), pick(first, "Knee" .. i)
	local gaps = { (endOf(fe, 1) - endOf(ft, -1)).Magnitude, (endOf(ft, 1) - ko.CFrame.Position).Magnitude, (endOf(ti, 1) - endOf(tt, -1)).Magnitude, (endOf(ta, 1) - jt.CFrame.Position).Magnitude,
		(endOf(ta, 1) - endOf(tp, -1)).Magnitude, (endOf(tp, 1) - leg.foot).Magnitude, (endOf(ta, -1) - pick(first, "Ankle" .. i).CFrame.Position).Magnitude }
	for n, gap in gaps do
		joined = joined and gap < 1.5e-3 -- (the rig keeps a rod's length until it differs by a millimetre)
	end
	taper = taper and ft.Size.Y < fe.Size.Y * 0.8 and tt.Size.Y < ti.Size.Y * 0.9 and tp.Size.Y < ta.Size.Y * 0.85 and ft.Size.X < fe.Size.X
	bigKnee = bigKnee and ko.Size.X > fe.Size.Y * 1.2 and ko.Size.Y > fe.Size.Y * 1.05
end
check(joined, "the rods meet end to end (to a millimetre): the femur and its tip run into the patella at the knee, the tarsus into its break and on to the foot")
check(taper, "the femur and tibia taper (the tip rods are thinner) and so does the tarsus past its break")
check(bigKnee, "the patella is longer than the femur is thick and a little stouter than it")
local straight = pick(first, "Ankle1").CFrame.Position:Lerp(first._legs[1].foot, 0.55)
check(near(pick(first, "TarsalJoint1").CFrame.Position.Y - straight.Y, 0.012, 1e-6) and near(pick(first, "TarsalJoint1").CFrame.Position.X, straight.X, 1e-6), "the tarsus' break, 55% of the way to the foot, is lifted 0.012 studs: a bend, not a straight rod")
-- The foot: a flattened pad lying on the floor, claws leaving its front, none of it under the floor.
local flat, lowest, claws = true, math.huge, 0
for i = 1, 8 do
	local pad = pick(first, "Foot" .. i)
	flat = flat and pad.Size.Y < pad.Size.X * 0.7 and pad.Size.Y < pad.Size.Z * 0.8
	lowest = math.min(lowest, pad.CFrame.Position.Y - pad.Size.Y / 2)
end
for _, p in first.model:GetChildren() do
	if p:IsA("BasePart") and p.Name == "Claw" then claws += 1; lowest = math.min(lowest, endOf(p, 1).Y, endOf(p, -1).Y) end
end
check(flat and claws == 16 and lowest > -0.012, `the pads are flattened and the claws and pads do not sink into the floor (lowest {string.format("%.4f", lowest)} studs)`)
-- Fangs: under the chelicerae, tucked and curved at the first spider, and bigger and pointing forward at the tarantulas.
local FA = Anatomy.layout(look)
local TA, TB = Anatomy.layout(Appearances.profiles[RED]), Anatomy.layout(Appearances.profiles[BLUE])
local fangsOk = #FA.fangs == 4
for _, f in FA.fangs do
	local jaw = if f.side < 0 then FA.jaws[1] else FA.jaws[2]
	fangsOk = fangsOk and f.at.Y < jaw.at.Y - jaw.radii.Y * 0.5 and f.side * f.at.X > 0 and f.at.Z < jaw.at.Z + jaw.radii.Z
end
check(fangsOk and FA.fangs[2].dir.Y < -0.7 and FA.fangs[2].side * FA.fangs[2].dir.X < 0, "the first spider's four fang segments hang below the chelicerae, curving in toward the middle")
check(#TA.fangs == 2 and #TB.fangs == 2 and TA.fangs[1].dir.Z < -0.85 and TA.fangs[1].radii.Z > FA.fangs[1].radii.Z * 1.6, "the tarantulas' fangs are larger, one segment each, and point forward")
check(#Anatomy.layout(Appearances.profiles.maratus_volans_male).fangs == 0 and #Anatomy.layout(Appearances.profiles.myrmarachne_formicaria_female).fangs == 0, "the peacock spider and the ant mimic have no fangs")
-- The tarantulas: the same, with a taper in the palps; budgets are above.
for _, id in { RED, BLUE } do
	local f, l = build(id, "full"), build(id, "low")
	local a, b = names(f), names(l)
	check((a.FemurTip1 or 0) == 1 and (a.FemurTip8 or 0) == 1 and (a.TarsalJoint1 or 0) == 1 and (a.TarsalJoint8 or 0) == 1 and (a.FootBristle or 0) == 0 and (a.Claw or 0) == 0 and (a.Fang or 0) == 2 and (a.PalpStalkTip or 0) == 2, `{id}: full detail: a tapered femur, a break in the tarsus, two fangs and a tapered palp (the scopula's bristles are the legs' own since ROBLOX-85)`)
	check((b.FemurTip1 or 0) == 0 and (b.TarsalJoint1 or 0) == 0 and (b.Fang or 0) == 2 and (b.PalpStalkTip or 0) == 2 and (b.Foot1 or 0) == 0, `{id}: low detail: the fangs and the palps' taper, no leg taper, break or scopula`)
	local wide = pick(f, "Foot1")
	local legD = pick(f, "Tarsus1").Size.Y
	check(wide.Size.Z > legD * 1.5 and wide.Size.Y < wide.Size.Z, `{id}: each foot is a pad wider than the tarsus is thick (the scopula)`)
	f:destroy(); l:destroy()
end
-- Any size: the rods, the pad and the toes scale with setScale as the rest does; the eye view keeps only legs I's lower segments.
local scaled = build(nil, "full", floor)
local c0 = pick(scaled, "Claw").Size.X
local fd0, pd0 = pick(scaled, "FemurTip1").Size.Y, pick(scaled, "Foot1").Size.Z
scaled:setScale(1.7)
check(near(pick(scaled, "Claw").Size.X / c0, 1.7, 1e-9) and near(pick(scaled, "FemurTip1").Size.Y / fd0, 1.7, 1e-9) and near(pick(scaled, "Foot1").Size.Z / pd0, 1.7, 1e-9), "setScale scales the tips, the pad and the claws like the rest of the spider")
first:setEyeView(true)
local shown = 0
for _, p in first.model:GetChildren() do
	if p:IsA("BasePart") and p.Name == "Claw" and p.LocalTransparencyModifier == 0 then shown += 1 end
end
check(shown == 4 and pick(first, "FemurTip1").LocalTransparencyModifier == 1 and pick(first, "TibiaTip1").LocalTransparencyModifier == 0 and pick(first, "TarsalJoint1").LocalTransparencyModifier == 0 and pick(first, "TarsalJoint2").LocalTransparencyModifier == 1 and pick(first, "Fang").LocalTransparencyModifier == 1, "the eye view keeps legs I's lower segments, joint and claws, and hides the femurs, the other legs and the fangs")
for _, r in { first, firstLow, rival, scaled } do r:destroy() end
end
shapeChecks()

-- ---------------------------------------------------------------- fur, sheen and palette (ROBLOX-85)
-- The first spider's hairs lie along the body and flow outward, its base has a faint sheen; the tarantulas are velvet: a Fabric fur shell per body mass,
-- bristles that lean down the leg (more on the front pairs), the redknee's urticating cluster and raised copper rim, the greenbottle's raised midline.
local function furChecks()
local RED, BLUE = "brachypelma_hamorii", "chromatopelma_cyaneopubescens"
local function build(id: string?, detail: string, parent: Instance?): any
	local folder = parent or Instance.new("Folder")
	return SpiderRig.new(folder, folder, id, detail)
end
local function pick(rig: any, name: string): BasePart return rig.model:FindFirstChild(name) :: BasePart end
local function lum(c: { number }): number return 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3] end
-- The first spider: the flow of the locks and the legs' hairs, and the sheen on the carapace and abdomen.
local ac = Vector3.new(look.abdomenCenter[1], look.abdomenCenter[2], look.abdomenCenter[3])
local outward, locks, rear = 0, 0, 0
for _, h in Setae.body(look) do
	if h.kind == "lock" and h.group == "abdomen" and math.abs(h.at.X - ac.X) > 0.06 then
		locks += 1
		outward += if h.dir.X * (h.at.X - ac.X) > 0 then 1 else 0
		rear += if h.dir.Z > 0 then 1 else 0
	end
end
check(locks > 20 and outward / locks > 0.7 and rear / locks > 0.9, `the abdomen's locks flow backward and outward ({outward} of {locks} lean out, {rear} lean back)`)
local legOk, legN = true, 0
for i = 1, 8 do
	for _, h in Setae.leg(look, i) do
		legN += 1
		legOk = legOk and h.lift ~= nil and math.deg(h.lift :: number) >= 14.99 and math.deg(h.lift :: number) <= 26.01
	end
end
check(legOk and legN > 40, `the first spider's leg hairs lie at 15 to 26 degrees off the leg, pointing down it ({legN} hairs)`)
local fx, fl = build(nil, "full"), build(nil, "low")
local fa, fb = pick(fx, "Cephalothorax"), pick(fx, "Abdomen")
check(fa.Reflectance == 0.04 and fb.Reflectance == 0.04 and fa.Material == Enum.Material.SmoothPlastic and fb.Material == Enum.Material.SmoothPlastic and pick(fl, "Abdomen").Reflectance == 0.04, "the first spider's carapace and abdomen have a faint sheen (Reflectance 0.04, SmoothPlastic), at both tiers")
local eyesSame = true
for _, p in fx.model:GetChildren() do
	if p:IsA("BasePart") and p.Name == "PrincipalEye" then eyesSame = eyesSame and p.Reflectance == look.eye.ame.reflectance end
end
check(eyesSame and look.gloss == 0.04, "the eyes keep their own Reflectance")
local cnt = { full = 0, low = 0 }
for _, p in fx.model:GetChildren() do if p.Name == "Seta" then cnt.full += 1 end end
for _, p in fl.model:GetChildren() do if p.Name == "Seta" then cnt.low += 1 end end
check(cnt.low > 0 and cnt.low < cnt.full * 0.4, `low detail keeps fewer lying hairs ({cnt.low} against {cnt.full})`)
fx:destroy(); fl:destroy()
-- The tarantulas' velvet.
local rd, bl = Appearances.profiles[RED], Appearances.profiles[BLUE]
for _, id in { RED, BLUE } do
	local lk = Appearances.profiles[id]
	local f, l = build(id, "full", floor), build(id, "low", floor)
	settle(f, 1)
	local shells = {}
	for _, p in f.model:GetChildren() do if p.Name == "FuzzShell" then table.insert(shells, p) end end
	local A = Anatomy.layout(lk)
	local fine = #shells == 2
	for _, sh in shells do
		fine = fine and sh.Material == Enum.Material.Fabric and sh.Transparency >= 0.3 and sh.Transparency <= 0.7 and sh.CastShadow == false
		local under = if sh.Size.Y > 0.4 then pick(f, "Abdomen") else pick(f, "Cephalothorax")
		fine = fine and sh.Size.X / under.Size.X > 1.065 and sh.Size.X / under.Size.X < 1.08 and sh.Size.Z / under.Size.Z > 1.065 and sh.Size.Z / under.Size.Z < 1.08
	end
	check(fine, `{id}: two Fabric fur shells, partly transparent, 7 percent larger than the carapace and the abdomen they cover`)
	local headShell = if shells[1].Size.Y < shells[2].Size.Y then shells[1] else shells[2]
	local buried = 0
	for _, e in A.eyes do
		local dx, dz = e.at.X - A.headCenter.X, e.at.Z - A.headCenter.Z
		if Anatomy.topY(A.headCenter, headShell.Size / 2, dx, dz) > e.at.Y + e.radii.Y * 0.3 then buried += 1 end
	end
	check(buried == 0, `{id}: the carapace's shell does not bury the eyes' beads ({buried} of {#A.eyes} covered)`)
	-- Bristles: more on the front pairs, leaning 32 to 48 degrees off the leg, from the sides of the leg.
	local byPair, leanOk, edgeOk = {}, true, true
	for i = 1, 8 do
		local n = 0
		for _, h in Setae.leg(lk, i) do
			n += 1
			leanOk = leanOk and h.lift ~= nil and math.deg(h.lift :: number) >= 31.99 and math.deg(h.lift :: number) <= 48.01
			edgeOk = edgeOk and math.abs(math.deg(h.theta)) >= 49.99 and math.abs(math.deg(h.theta)) <= 115.01
		end
		byPair[(i - 1) % 4 + 1] = (byPair[(i - 1) % 4 + 1] or 0) + n
	end
	check(byPair[1] > byPair[2] and byPair[2] > byPair[3] and byPair[3] >= byPair[4] and byPair[1] >= 3 * byPair[4], `{id}: bristle counts fall from the front pair to the back ({byPair[1]}, {byPair[2]}, {byPair[3]}, {byPair[4]})`)
	check(leanOk and edgeOk, `{id}: bristles lean 32 to 48 degrees down the leg and grow from its sides (50 to 115 degrees from the top)`)
	local lowShell = 0
	for _, p in l.model:GetChildren() do if p.Name == "FuzzShell" then lowShell += 1 end end
	check(lowShell == 2, `{id}: the shells stay at low detail`)
	f:destroy(); l:destroy()
end
-- The redknee's urticating patch: a denser cluster inside the patch, combed toward the rear, full tier only; the rim stands proud of the carapace.
local cl = Setae.cluster(rd)
local patch = rd.marks[1]
local aR, aC = Anatomy.v3(rd.abdomenRadii), Anatomy.v3(rd.abdomenCenter)
local inside, backward = 0, 0
for _, h in cl do
	local dx, dz = (h.at.X - aC.X - patch.x * aR.X) / patch.rx, (h.at.Z - aC.Z - patch.z * aR.Z) / patch.rz
	inside += if dx * dx + dz * dz <= 1 then 1 else 0
	backward += if h.dir.Z > 0 then 1 else 0
end
check(#cl == 8 and inside == 8 and backward == 8 and #Setae.cluster(bl) == 0, "the redknee's patch carries 8 hairs, all inside the patch and combed toward the rear; the greenbottle has none")
local rf, rl = build(RED, "full", floor), build(RED, "low", floor)
settle(rf, 1); settle(rl, 1)
local function seta(r: any): number local n = 0 for _, p in r.model:GetChildren() do if p.Name == "Seta" then n += 1 end end return n end
check(seta(rf) - seta(rl) >= 8 and seta(rl) == 0, "the cluster is drawn at full detail and not at low")
local rim, car = pick(rf, "CarapaceRim"), pick(rf, "Cephalothorax")
local dx = car.Size.X / 2 * 0.95
local rimTop = Anatomy.topY(rim.Position, rim.Size / 2, dx, 0)
local carTop = Anatomy.topY(car.Position, car.Size / 2, dx, 0)
check(rimTop - carTop >= 0.010, `the redknee's copper rim stands up round the carapace's edge ({string.format("%.3f", rimTop - carTop)} studs proud)`)
rf:destroy(); rl:destroy()
-- The greenbottle: the midline's ridges stand above the fur shell, the bars are softer than the first palette's.
local bf = build(BLUE, "full", floor)
settle(bf, 1)
local shellTop = 0
for _, p in bf.model:GetChildren() do
	if p.Name == "FuzzShell" and p.Size.X > 2 * Anatomy.v3(bl.abdomenRadii).X * 0.9 then shellTop = p.Position.Y + p.Size.Y / 2 end
end
local ridgeOk, ridges = true, 0
for _, p in bf.model:GetChildren() do
	if p.Name == "AbdomenMidline" then
		ridges += 1
		local shellAt = Anatomy.topY(Anatomy.v3(bl.abdomenCenter), Anatomy.v3(bl.abdomenRadii) * 1.075, p.Position.X - bl.abdomenCenter[1], p.Position.Z - bl.abdomenCenter[3])
		ridgeOk = ridgeOk and p.Position.Y + p.Size.Y / 2 > shellAt
	end
end
check(ridges == 3 and ridgeOk and shellTop > 0, "the greenbottle's dark midline stands above its fur shell (three ridges)")
bf:destroy()
local abd, bar, ridge = lum(bl.abdomenColor), lum(bl.marks[4].color), lum(bl.marks[1].color)
check(abd - bar < 0.30 and bar > ridge, `the bars are softer than the first palette's: a burnt-orange ground, brown bars (contrast {string.format("%.2f", abd - bar)}), the midline darker still`)
end
furChecks()

-- ---------------------------------------------------------------- hanging on the dragline (ROBLOX-86)
-- The drawn body hangs with its long axis along the line (within 10 degrees, the sway and lean included), head down, no foot below the head or out of the
-- body's reach, legs I and II up toward the line; a damped 2.5 second swing and a slow damped turn that the drop starts; Reduced Motion is a still pose;
-- the head turns up on the way up the line; the low tier draws the same parts. Judged by eye in tools/preview (--hang); Studio has not seen it.
local function hangChecks()
local function part(r: any, name: string): BasePart return r.model:FindFirstChild(name) :: BasePart end
local line = Vector3.new(0.10, 1, 0.05).Unit
local function frameOf(at: Vector3): CFrame return SupportMath.bodyCFrame(at, Vector3.yAxis, Vector3.new(0, 0, -1)) end
local home = Vector3.new(0, 2, 0)
local function axisOf(r: any): Vector3 return (r:spinneretPoint(frameOf(home)) - part(r, "EyeFace").Position).Unit end -- the face to the spinneret tip
local function angleTo(a: Vector3, b: Vector3): number return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1))) end
local function drop(r: any, seconds: number, reduced: boolean)
	r.reducedMotion = reduced
	r.hangDirection = line
	for _ = 1, math.floor(seconds * 60 + 0.5) do r:update(frameOf(home), 1 / 60, false, false) end
end
local ids = { "first_spider", "maratus_volans_male", "myrmarachne_formicaria_female", "rival_spider", "brachypelma_hamorii", "chromatopelma_cyaneopubescens" }
for _, id in ids do
	for _, detail in { "full", "low" } do
		local r = SpiderRig.new(floor, floor, id, detail)
		local total = r:count().total
		local worst, lowest = 0, 0
		local g = r._growth
		local head = part(r, "EyeFace")
		for frame = 1, 600 do -- ten seconds of the drop
			r.hangDirection = line
			r:update(frameOf(home), 1 / 60, false, false)
			if frame >= 30 then
				worst = math.max(worst, angleTo(axisOf(r), line))
			end
		end
		check(worst <= 10, `{id} {detail}: the hung body's long axis stays within 10 degrees of the line ({string.format("%.1f", worst)})`)
		check(worst >= 2, `{id} {detail}: and it is not a plumb bob ({string.format("%.1f", worst)} degrees at most)`)
		check(r:count().total == total, `{id} {detail}: hanging adds and removes no part`)
		-- feet: none below the head, none off the ground's reach, all unplanted; the head is the lowest of the body
		local spin = r:spinneretPoint(frameOf(home))
		local depthOfHead = (spin - head.Position):Dot(line) + head.Size.Z * 0.5
		local bodyLength = (spin - head.Position).Magnitude + head.Size.Z * 0.5
		local belowHead, wide, planted = 0, 0, 0
		for _, leg in r._legs do
			local foot = leg.foot
			belowHead = math.max(belowHead, (spin - foot):Dot(line) - depthOfHead)
			local off = (foot - spin) - line * (foot - spin):Dot(line)
			wide = math.max(wide, off.Magnitude / bodyLength)
			if leg.planted ~= nil then planted += 1 end
		end
		check(belowHead <= 0.01 * bodyLength and planted == 0, `{id} {detail}: no foot reaches below the head, none is planted ({string.format("%.3f", belowHead)} studs below)`)
		check(wide < 0.62, `{id} {detail}: the feet stay within the body's reach sideways ({string.format("%.2f", wide)} of its length)`)
		check((r.root.Position - home).Magnitude < 1e-9, `{id} {detail}: the root part (camera and collider) is where the motor left it`)
		-- head down: the head is under the tail
		check((part(r, "Abdomen").Position - head.Position):Dot(line) > 0.3 * bodyLength, `{id} {detail}: the head hangs under the abdomen`)
		-- the tail is on the line: the spinneret is within 4 degrees' worth of it from the body's middle
		local off = (spin - home) - line * (spin - home):Dot(line)
		check(off.Magnitude < 0.15 * bodyLength, `{id} {detail}: the silk leaves the spinneret on the line through the body ({string.format("%.3f", off.Magnitude)} studs off)`)
		r:destroy()
	end
end
-- the sway and the turn, on the first spider
local function swing(r: any, seconds: number): ({ number }, { number })
	local fore, turn = {}, {}
	for frame = 1, math.floor(seconds * 60 + 0.5) do
		r.hangDirection = line
		r:update(frameOf(home), 1 / 60, false, false)
		local side = part(r, "Abdomen").CFrame.RightVector
		local u = line
		local f = u:Cross(side).Unit
		local axis = axisOf(r)
		fore[frame] = math.deg(math.atan2(axis:Dot(f), axis:Dot(u)))
		local e1 = u:Cross(Vector3.zAxis).Unit
		local e2 = u:Cross(e1)
		turn[frame] = math.deg(math.atan2(side:Dot(e2), side:Dot(e1)))
	end
	return fore, turn
end
local moving, still = SpiderRig.new(floor, floor, nil, "full"), SpiderRig.new(floor, floor, nil, "full")
still.reducedMotion = true
local H = moving._appearance.hang
local foreM, turnM = swing(moving, 14)
local foreS, turnS = swing(still, 14)
check(H.sway.period == 2.5 and H.sway.deg <= 6 and H.sway.deg >= 3 and H.leanDeg <= 4 and H.spin.degPerS <= 10, "the hang's numbers: a 2.5 s swing of a few degrees, a lean under 4, a turn of at most 10 degrees a second")
local lean = foreS[60]
check(near(foreS[600], lean, 1e-6) and near(foreS[840], lean, 1e-6) and math.abs(lean) > 1 and math.abs(lean) <= H.leanDeg + 0.5, `Reduced Motion: the hanging pose is still and keeps a small lean ({string.format("%.2f", lean)} degrees)`)
check(near(turnS[840], turnS[60], 1e-6), "Reduced Motion: no turn about the line")
local sign = if lean >= 0 then 1 else -1
local a1 = sign * (foreM[math.floor(0.625 * 60)] - lean) -- the first quarter swing (0.625 s)
local a2 = sign * (foreM[math.floor(0.625 * 60 + 2.5 * 60)] - lean) -- one period later
check(a1 > H.sway.deg * math.exp(-0.625 / H.sway.decay) * 0.85 and a1 < H.sway.deg * 1.05, `the swing starts at about its amplitude ({string.format("%.2f", a1)} degrees)`)
check(near(a2 / a1, math.exp(-2.5 / H.sway.decay), 0.07), `and decays by exp(-t/{H.sway.decay}) a period on ({string.format("%.2f", a2 / a1)})`)
local late = 0
for frame = 600, 840 do late = math.max(late, math.abs(foreM[frame] - lean)) end
check(late < 0.6, `by ten seconds the swing has died away ({string.format("%.2f", late)} degrees)`)
-- the period: the swing crosses its mean upward once every 2.5 seconds
local crossings = {}
for frame = 40, 400 do
	if foreM[frame - 1] - lean < 0 and foreM[frame] - lean >= 0 then table.insert(crossings, frame / 60) end
end
check(#crossings >= 2 and near(crossings[2] - crossings[1], 2.5, 0.12), `the swing's period is 2.5 seconds ({if #crossings >= 2 then string.format("%.2f", crossings[2] - crossings[1]) else "no crossing"})`)
local fastest, early, later = 0, 0, 0
for frame = 31, 840 do fastest = math.max(fastest, math.abs(turnM[frame] - turnM[frame - 1]) * 60) end
early = math.abs(turnM[120] - turnM[60]) / 1.0
later = math.abs(turnM[840] - turnM[780]) / 1.0
check(fastest <= 10 and fastest > 2, `the turn about the line is slow and at most 10 degrees a second ({string.format("%.1f", fastest)})`)
check(later < early * 0.5 and math.abs(turnM[840] - turnM[60]) < 60, `and it dies away ({string.format("%.1f", early)} then {string.format("%.1f", later)} degrees a second)`)
-- the second drop turns the other way
moving.hangDirection = nil
for _ = 1, 30 do moving:update(frameOf(home), 1 / 60, true, false) end
local _, turnB = swing(moving, 3)
check((turnB[120] - turnB[60]) * (turnM[120] - turnM[60]) < 0, "a second drop turns the other way")
moving:destroy(); still:destroy()
-- legs: I and II curl up toward the line (their feet are above their hips along it), III and IV fold along the body
local r = SpiderRig.new(floor, floor, nil, "full")
drop(r, 1.5, true)
local spin = r:spinneretPoint(frameOf(home))
local depth: { number } = {}
for i, leg in r._legs do depth[i] = (spin - leg.foot):Dot(line) end
local hipsDepth = (spin - part(r, "EyeFace").Position):Dot(line)
check(depth[1] < hipsDepth and depth[2] < hipsDepth and depth[3] < hipsDepth and depth[4] < hipsDepth and depth[5] < hipsDepth, "the feet are above the head along the line (nothing reaches for the ground)")
local diff = 0
for pair = 1, 4 do diff = math.max(diff, math.abs(depth[pair] - depth[pair + 4])) end
check(diff > 0.01, `the left and right legs are not mirrors ({string.format("%.3f", diff)} studs apart at most)`)
r:destroy()
-- going up the line: head up, blended over 0.5 s; back to head down when it stops
local c = SpiderRig.new(floor, floor, nil, "full")
local headDown = true
c.hangDirection = line
local at = home
for _ = 1, 60 do c:update(frameOf(at), 1 / 60, false, false) end
check((part(c, "Abdomen").Position - part(c, "EyeFace").Position):Dot(line) > 0.3 and c._climb == 0, "hanging still: head down")
local early, upSeen
for frame = 1, 120 do -- two seconds up the line at 0.9 studs a second
	at = at + line * (0.9 / 60)
	c:update(frameOf(at), 1 / 60, false, false)
	if frame == 24 then early = c._climb end
end
local headUp = (part(c, "EyeFace").Position - part(c, "Abdomen").Position):Dot(line)
check(c._climb > 0.99 and headUp > 0.3, `climbing the line the head turns up (head {string.format("%.2f", headUp)} studs above the abdomen)`)
check(early ~= nil and early < 0.9, `the head turns over a half second, not at once ({string.format("%.2f", early or -1)} of the way after 0.4 s)`)
for _ = 1, 120 do c:update(frameOf(at), 1 / 60, false, false) end
check(c._climb < 0.01 and (part(c, "Abdomen").Position - part(c, "EyeFace").Position):Dot(line) > 0.3, "stopped: head down again")
c:destroy()
local d = SpiderRig.new(floor, floor, nil, "full") -- going down the line is not a climb
d.hangDirection = line
local lower = home
for _ = 1, 120 do lower = lower - line * (0.9 / 60); d:update(frameOf(lower), 1 / 60, false, false) end
check(d._climb == 0, "lowering on the line stays head down")
d.hangDirection = nil
d:update(frameOf(lower), 1 / 60, true, false)
check(d._hang == 0 and d._climb == 0 and not d._climbing, "landing clears the hang at once")
d:destroy()
end
hangChecks()

print(`LOOK passed={passed} failed={failed}`)
if failed > 0 then error("look checks failed") end
