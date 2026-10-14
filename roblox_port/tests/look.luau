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
	"fuzz.enabled", "fuzz.locks.abdomen", "fuzz.locks.head", "fuzz.locks.length", "fuzz.locks.width", "fuzz.locks.flat", "fuzz.locks.lieBack",
	"fuzz.locks.transparency", "fuzz.guard.abdomen", "fuzz.guard.length", "fuzz.guard.width", "fuzz.guard.transparency",
	"fuzz.dark", "fuzz.grey", "fuzz.frost", "fuzz.shellColor", "fuzz.shells", "fuzz.headShell.zScale",
	"fuzz.tuftHairs", "fuzz.tuftLength", "fuzz.tuft.fan", "fuzz.tuft.width", "fuzz.ruff.hairs", "fuzz.ruff.length",
	"fuzz.legHairs", "fuzz.legLength", "fuzz.legWidth", "fuzz.legTransparency",
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
check((kinds.lock or 0) >= 150 and (kinds.guard or 0) >= 150, `the coat has locks ({kinds.lock}) and guard hairs ({kinds.guard})`)
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
check(#Setae.palp(with(function(l) l.palp.fluff.hairs = 0 end)) == 0, "palp.fluff.hairs sets the palps' fluff")
local wide = Anatomy.layout(with(function(l) l.eye.ame.x = 0.14 end))
local wideFront = {}
for _, e in wide.eyes do if e.principal then table.insert(wideFront, e) end end
check(wideFront[2].at.X > front[2].at.X + 0.02, "eye.ame.x spreads the front eyes")
check(Anatomy.layout(with(function(l) l.headRadii = { 0.30, 0.24, 0.30 } end)).headRadii.X == 0.30, "headRadii sets the head")

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
check(full.total <= 720 and full.other <= 160 and full.hair + full.shell >= 300 and full.hair + full.shell <= 720, `full detail part budget ({full.total})`)
check(low.total <= 300 and low.hair >= 100 and low.hair <= 260 and low.shell <= 2, `low detail part budget ({low.total})`)
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
check(moved(b1, b2) < 1e-9, "low detail: no idle motion at all")
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

print(`LOOK passed={passed} failed={failed}`)
if failed > 0 then error("look checks failed") end
