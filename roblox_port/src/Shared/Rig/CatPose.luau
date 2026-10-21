--!strict
-- The ranger's cat drawn (ROBLOX-118; its sim is Predator/Cat): a domestic cat at true size, a brown mackerel tabby, posed from what the cat is doing. Pure: a list
-- of parts (each an ellipsoid, a ball or a cylinder with its size, its frame in the cat's own frame, its colour and whether the low tier keeps it), so
-- Client/CatBody draws it, tools/preview/scene.py renders it and tests/preserve.luau measures it, all from these same numbers.
--
-- The cat's frame: its origin on the surface it stands on, under the middle of its body; forward -Z (CFrame.lookAt's), up +Y, right +X. Studs are centimetres.
-- True size (a domestic cat, Felis catus): about 46 cm from the nose to the root of the tail, a tail about 28 cm, 23 to 25 cm at the shoulder, the head about
-- 9.5 cm across, the ears 4.5 cm tall, the eyes about 2 cm across (the shoulder here 24, the body 46 from the nose's tip to the hips' back).
--
-- Poses: walk (a lateral-sequence walk, each foot 62% of its stride on the ground, the tail up), jump (stretched out), sit (on its haunches, the tail round its
-- feet), rest (lying as a loaf, its eyes half shut: it purrs as it settles), sleep (curled round itself, its eyes shut, its tail over its nose), eat (head down
-- to the bowl), groom (sitting, licking a raised forepaw), watch (still, its head following what moved, its tail's tip twitching), stalk (low, slow), crouch (low
-- at the front, the hindquarters' wiggle), swat (a forepaw out at the thing and back). It breathes always (about 25 breaths a minute awake and 20 asleep), and
-- now and then, sitting or lying awake, it gives a slow blink.
local CatPose = {}

export type Part = { name: string, kind: string, size: Vector3, cf: CFrame, color: string, full: boolean }
export type State = {
	pose: string, t: number, -- the pose and the seconds the cat has lived (the breath, the gait, the blink, the twitch)
	speed: number?, -- studs a second over the ground (the gait)
	look: Vector3?, -- the point its head follows, in its own frame
	paw: Vector3?, -- where its pat is aimed, in its own frame
	swat: number?, -- how far through the pat (0..1)
	seated: boolean?, -- (watch) sitting rather than standing
}

local v = Vector3.new
local TAU = 2 * math.pi
CatPose.COLORS = table.freeze({
	fur = "8a7a66", stripe = "4b4036", light = "c9bba5", white = "e8e0d2", nose = "c98a85", inner = "d6a49a", iris = "b9a33a", pupil = "141210",
	collar = "a8322c", bell = "c9a33a", whisker = "f2eee6",
})
local C = CatPose.COLORS

-- An ellipsoid of `size` (x across, y up, z along) whose long axis runs from a to b.
local function along(a: Vector3, b: Vector3): CFrame
	local d = b - a
	if d.Magnitude < 1e-4 then return CFrame.new(a) end
	local up = if math.abs(d.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt((a + b) * 0.5, b, up)
end

-- The skeleton of a pose: where the body's three masses are and how they are pitched, the neck, the head's place and turn, each leg's joints, the tail's points,
-- how far the eyes are shut and how much the breath swells.
type Leg = { a: Vector3, b: Vector3, c: Vector3, d: Vector3? } -- front: shoulder, elbow, paw; hind: hip, stifle, hock, paw
type Skeleton = {
	chest: Vector3, chestPitch: number, belly: Vector3, bellyPitch: number, hips: Vector3, hipsPitch: number, yawBody: { number }?,
	neckA: Vector3, neckB: Vector3, head: Vector3, headYaw: number, headPitch: number, headRoll: number,
	fl: Leg, fr: Leg, hl: Leg, hr: Leg, tail: { Vector3 }, shut: number, breath: number, low: boolean?,
}

local function frontLeg(shoulder: Vector3, paw: Vector3): Leg
	local wrist = paw + v(0, 2.2, 0.4)
	local elbow = (shoulder + wrist) * 0.5 + v(0, 0, 1.8)
	return { a = shoulder, b = elbow, c = wrist, d = paw }
end
local function hindLeg(hip: Vector3, paw: Vector3, heel: Vector3?): Leg
	local hock = heel or (paw + v(0, 5, 3.4))
	local stifle = (hip + hock) * 0.5 + v(0, 0, -3.6)
	return { a = hip, b = stifle, c = hock, d = paw }
end

-- The tail's eleven points from its root along a curve: `dirs` gives its direction at the root and at the tip; `sway` swings it sideways.
local function tailCurve(root: Vector3, d0: Vector3, d1: Vector3, length: number, sway: number): { Vector3 }
	local pts = { root }
	local p = root
	for i = 1, 10 do
		local s = i / 10
		local d = d0:Lerp(d1, s * s)
		d = (d + v(sway * s, 0, 0))
		p = p + d.Unit * (length / 10)
		table.insert(pts, p)
	end
	return pts
end
-- The tail lying round the feet: an arc on the ground about `centre`, from `a0` to `a1` radians (0 behind, +pi/2 to its right), radius `r`.
local function tailRound(root: Vector3, centre: Vector3, r: number, a0: number, a1: number, y: number): { Vector3 }
	local pts = { root }
	for i = 1, 10 do
		local a = a0 + (a1 - a0) * (i / 10)
		table.insert(pts, v(centre.X + r * math.sin(a), y, centre.Z + r * math.cos(a)))
	end
	return pts
end

-- The slow blink: shut over 0.35 s, held 0.4 s, opened over 0.6 s, once every 7 to 11 s (from the clock alone, so it is the same on every client).
local function blink(t: number): number
	local period = 9.0
	local k = t % period
	local start = 6.5 + 1.5 * math.sin(math.floor(t / period) * 1.7)
	local x = k - start
	if x < 0 or x > 1.35 then return 0 end
	if x < 0.35 then return x / 0.35 end
	if x < 0.75 then return 1 end
	return 1 - (x - 0.75) / 0.6
end

local function standing(t: number, speed: number, low: number): Skeleton
	-- the walk: a lateral sequence (left hind, left fore, right hind, right fore a quarter apart), each foot on the ground 62% of the time
	local moving = speed > 1
	local period = if speed > 30 then 0.5 else 0.9
	local reach = if moving then speed * period * 0.62 / 2 else 0
	local function foot(neutral: Vector3, phase: number): Vector3
		if not moving then return neutral end
		local p = ((t / period) + phase) % 1
		if p < 0.62 then return neutral + v(0, 0, reach * (2 * p / 0.62 - 1)) end
		local s = (p - 0.62) / 0.38
		return neutral + v(0, 3.5 * math.sin(s * math.pi), reach * (1 - 2 * s))
	end
	local bob = if moving then 0.4 * math.sin(TAU * t / period * 2) else 0
	local y = -low
	local sk: Skeleton = {
		chest = v(0, 16 + y + bob, -11), chestPitch = 0, belly = v(0, 15.5 + y + bob, 1), bellyPitch = 0, hips = v(0, 16.5 + y * 0.8 + bob, 11.5), hipsPitch = 0,
		neckA = v(0, 19 + y + bob, -15.5), neckB = v(0, 24 + y * 1.2 + bob, -20.5), head = v(0, 25.5 + y * 1.3 + bob, -24), headYaw = 0, headPitch = 0, headRoll = 0,
		fl = frontLeg(v(-3.8, 16 + y, -12.5), foot(v(-3.8, 1, -13.5), 0.25)), fr = frontLeg(v(3.8, 16 + y, -12.5), foot(v(3.8, 1, -13.5), 0.75)),
		hl = hindLeg(v(-4.2, 16 + y * 0.8, 12), foot(v(-4.2, 1, 12.5), 0)), hr = hindLeg(v(4.2, 16 + y * 0.8, 12), foot(v(4.2, 1, 12.5), 0.5)),
		tail = {}, shut = 0, breath = 0,
	}
	-- the tail held up in a loose question mark, swinging a little as it walks
	sk.tail = tailCurve(v(0, 18.5 + y * 0.8 + bob, 18), v(0, 0.6, 0.8), v(0, 0.7, -0.6), 28, 0.25 * math.sin(TAU * t * 0.7))
	return sk
end

local function sitting(t: number): Skeleton
	local sk: Skeleton = {
		chest = v(0, 17, -6), chestPitch = -55, belly = v(0, 11.5, 1), bellyPitch = -40, hips = v(0, 7, 7), hipsPitch = -10,
		neckA = v(0, 21, -8), neckB = v(0, 26, -10), head = v(0, 29, -12.5), headYaw = 0, headPitch = 0, headRoll = 0,
		fl = frontLeg(v(-3.6, 15, -7), v(-3.4, 1, -10.5)), fr = frontLeg(v(3.6, 15, -7), v(3.4, 1, -10.5)),
		hl = hindLeg(v(-4.8, 8, 8), v(-4.6, 1, -3), v(-4.9, 1.6, 7)), hr = hindLeg(v(4.8, 8, 8), v(4.6, 1, -3), v(4.9, 1.6, 7)),
		tail = tailRound(v(0, 3, 13.5), v(0, 1.5, 3), 11, 0.15, 2.7, 1.5), shut = 0, breath = 0,
	}
	return sk
end

local function lying(t: number): Skeleton
	local sk: Skeleton = {
		chest = v(0, 8, -8), chestPitch = 0, belly = v(0, 8.5, 1), bellyPitch = 0, hips = v(0, 8, 10), hipsPitch = 0,
		neckA = v(0, 11, -12), neckB = v(0, 14, -15.5), head = v(0, 15, -18.5), headYaw = 0, headPitch = -8, headRoll = 0,
		fl = frontLeg(v(-3.4, 7, -9), v(-3, 1.1, -13.5)), fr = frontLeg(v(3.4, 7, -9), v(3, 1.1, -13.5)),
		hl = hindLeg(v(-4.6, 7, 10), v(-4.8, 1.1, 3), v(-5, 1.6, 12)), hr = hindLeg(v(4.6, 7, 10), v(4.8, 1.1, 3), v(5, 1.6, 12)),
		tail = tailRound(v(0, 3, 16), v(0, 1.5, 0), 12.5, 0.2, 2.5, 1.6), shut = 0.5, breath = 0,
	}
	return sk
end

-- Curled asleep: the body round an arc, the head tucked against the hindquarters, the tail over the nose.
local function curled(): Skeleton
	local R = 5.5
	local function onArc(deg: number, y: number, r: number?): Vector3
		local a = math.rad(deg)
		return v((r or R) * math.sin(a), y, -(r or R) * math.cos(a))
	end
	local sk: Skeleton = {
		chest = onArc(-35, 7), chestPitch = 0, belly = onArc(45, 7.5), bellyPitch = 0, hips = onArc(125, 7), hipsPitch = 0,
		yawBody = { 125, 45, -35 }, -- (each mass turned along the arc, its front toward the head: 90 degrees less its place on the arc)
		neckA = onArc(-60, 7.5, 6), neckB = onArc(-80, 8, 8), head = onArc(-95, 8, 10.5), headYaw = 35, headPitch = -18, headRoll = 28, -- (its head laid on its paws, its face turned out)
		fl = frontLeg(onArc(-30, 5, 6), onArc(-75, 1.2, 5)), fr = frontLeg(onArc(-20, 5, 10), onArc(-60, 1.2, 8)),
		hl = hindLeg(onArc(130, 5, 6), onArc(80, 1.2, 4), onArc(150, 1.6, 4)), hr = hindLeg(onArc(140, 5, 11), onArc(95, 1.2, 9), onArc(165, 1.6, 9)),
		tail = {}, shut = 1, breath = 0,
	}
	local pts = { onArc(140, 4.5, 8) }
	for i = 1, 10 do table.insert(pts, onArc(140 + i * 22, 2.6, 11.5)) end
	sk.tail = pts
	return sk
end

local function jumping(t: number): Skeleton
	local sk = standing(t, 0, 0)
	sk.chest, sk.belly, sk.hips = v(0, 17, -13), v(0, 16, 1), v(0, 15, 13)
	sk.chestPitch, sk.hipsPitch = 8, -8
	sk.fl = frontLeg(v(-3.6, 16, -14), v(-3.4, 8, -27))
	sk.fr = frontLeg(v(3.6, 16, -14), v(3.4, 8, -27))
	sk.hl = hindLeg(v(-4.2, 15, 13), v(-4, 7, 30), v(-4.1, 9, 24))
	sk.hr = hindLeg(v(4.2, 15, 13), v(4, 7, 30), v(4.1, 9, 24))
	sk.tail = tailCurve(v(0, 17, 19), v(0, 0.1, 1), v(0, 0.2, 1), 28, 0)
	return sk
end

-- Turns the head toward a point in the cat's frame (clamped as a cat's neck allows), from where its neck meets it.
local function lookAt(sk: Skeleton, target: Vector3)
	local d = target - sk.neckB
	local yaw = math.deg(math.atan2(-d.X, -d.Z))
	local pitch = math.deg(math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z)))
	sk.headYaw = math.clamp(yaw, -75, 75)
	sk.headPitch = math.clamp(pitch, -45, 55)
end

-- The skeleton for a state.
function CatPose.skeleton(state: State): Skeleton
	local t = state.t
	local pose = state.pose
	local sk: Skeleton
	if pose == "walk" then
		sk = standing(t, state.speed or 60, 0)
	elseif pose == "jump" then
		sk = jumping(t)
	elseif pose == "sit" then
		sk = sitting(t)
		sk.headYaw = 25 * math.sin(t * 0.21) -- (it looks about, slowly)
		sk.shut = 0
	elseif pose == "rest" then
		sk = lying(t)
	elseif pose == "sleep" then
		sk = curled()
	elseif pose == "eat" then
		sk = standing(t, 0, 0)
		sk.neckA, sk.neckB, sk.head = v(0, 17, -16), v(0, 12, -22), v(0, 8.5, -25)
		sk.headPitch = -55 + 4 * math.sin(t * 6)
	elseif pose == "groom" then
		sk = sitting(t)
		sk.fr = frontLeg(v(3.6, 15, -7), v(2.4, 21, -14.5))
		sk.head = v(1.2, 26.5, -12.5)
		sk.headYaw, sk.headPitch = -20, -35 + 6 * math.sin(t * 7)
	elseif pose == "stalk" then
		sk = standing(t, state.speed or 20, 6)
		sk.head = sk.head + v(0, -2, -2)
		sk.tail = tailCurve(sk.hips + v(0, 2, 6), v(0, -0.1, 1), v(0, 0.15, 1), 28, 0.3 * math.sin(t * 9))
	elseif pose == "crouch" or pose == "swat" then
		sk = standing(t, 0, 7)
		sk.hips = sk.hips + v(1.2 * math.sin(TAU * 3 * t), 2.5, 0) -- (the wiggle before the pat)
		sk.hl, sk.hr = hindLeg(v(-4.2, 11.5, 12), v(-4.2, 1, 13)), hindLeg(v(4.2, 11.5, 12), v(4.2, 1, 13))
		sk.tail = tailCurve(sk.hips + v(0, 2, 6), v(0, 0, 1), v(0, 0.3, 1), 28, 0.5 * math.sin(t * 11))
		if pose == "swat" then
			local k = math.clamp(state.swat or 0, 0, 1)
			local out = math.sin(k * math.pi) -- (out to the far end of its reach halfway through, and back)
			local target = state.paw or v(3.5, 2, -34)
			local shoulder = v(3.8, 10, -12.5)
			local d = target - shoulder
			if d.Magnitude > 26 then d = d.Unit * 26 end
			sk.fr = frontLeg(shoulder, shoulder:Lerp(shoulder + d, out) + v(0, 3 * out, 0))
		end
	else -- "watch"
		sk = if state.seated then sitting(t) else standing(t, 0, 2)
		sk.tail[#sk.tail] = sk.tail[#sk.tail] + v(0.8 * math.sin(t * 10), 0, 0) -- (its tail's tip twitches)
	end
	if state.look ~= nil and pose ~= "sleep" and pose ~= "eat" and pose ~= "groom" then lookAt(sk, state.look) end
	-- the breath, and the eyes: shut asleep, half shut lying awake, a slow blink now and then sitting or lying awake, wide open watching
	sk.breath = 0.025 * math.sin(TAU * t / (if pose == "sleep" then 3.0 else 2.4))
	if pose == "sit" or pose == "rest" or pose == "groom" then sk.shut = math.max(sk.shut, blink(t)) end
	if pose == "watch" or pose == "stalk" or pose == "crouch" or pose == "swat" then sk.shut = 0 end
	return sk
end

-- The parts of a state, in a fixed order (the same names and count for every pose).
function CatPose.parts(state: State): { Part }
	local sk = CatPose.skeleton(state)
	local out: { Part } = {}
	local function add(name: string, kind: string, size: Vector3, cf: CFrame, color: string, full: boolean)
		table.insert(out, { name = name, kind = kind, size = size, cf = cf, color = color, full = full })
	end
	local b = 1 + sk.breath
	local function mass(c: Vector3, pitch: number, yaw: number?): CFrame
		return CFrame.new(c) * CFrame.Angles(0, math.rad(yaw or 0), 0) * CFrame.Angles(math.rad(pitch), 0, 0)
	end
	local yaws = sk.yawBody or { 0, 0, 0 }
	local chestCF, bellyCF, hipsCF = mass(sk.chest, -sk.chestPitch, yaws[1]), mass(sk.belly, -sk.bellyPitch, yaws[2]), mass(sk.hips, -sk.hipsPitch, yaws[3])
	add("Chest", "ellipsoid", v(12 * b, 14 * b, 16), chestCF, C.fur, false)
	add("Belly", "ellipsoid", v(12.5 * b, 12 * b, 22), bellyCF, C.fur, false)
	add("Hips", "ellipsoid", v(12, 13, 12), hipsCF, C.fur, false)
	add("BellyFur", "ellipsoid", v(9.5, 7, 18), bellyCF * CFrame.new(0, -3.2, 0), C.light, true)
	add("Bib", "ellipsoid", v(8, 10, 6), chestCF * CFrame.new(0, -1.5, -5.6), C.light, true)
	-- the tabby's stripes: bands round each of the body's masses, a little proud of it (so they follow it however it lies)
	-- (each band is the mass's own cross-section where it lies, a millimetre proud: an ellipsoid's section at z is its x and y scaled by sqrt(1 - (z / half its length)^2))
	local bands: { { any } } = { { chestCF, -2.5, v(12 * b, 14 * b, 16) }, { chestCF, 3.5, v(12 * b, 14 * b, 16) }, { bellyCF, -5.5, v(12.5 * b, 12 * b, 22) },
		{ bellyCF, 4.5, v(12.5 * b, 12 * b, 22) }, { hipsCF, -2.5, v(12, 13, 12) }, { hipsCF, 3, v(12, 13, 12) } }
	for i, band in bands do
		local size: Vector3 = band[3]
		local k = math.sqrt(math.max(0.05, 1 - ((band[2] :: number) / (size.Z / 2)) ^ 2))
		add(`Stripe{i}`, "ellipsoid", v(size.X * k + 0.08, size.Y * k + 0.08, 1.2), (band[1] :: CFrame) * CFrame.new(0, 0, band[2]), C.stripe, true)
	end
	-- the neck, the collar round it and its bell
	local neckCF = along(sk.neckA, sk.neckB)
	add("Neck", "ellipsoid", v(7.6, 8.6, (sk.neckB - sk.neckA).Magnitude + 5), neckCF, C.fur, false)
	local collarAt = sk.neckA:Lerp(sk.neckB, 0.45)
	local collarCF = along(collarAt - (sk.neckB - sk.neckA).Unit * 0.6, collarAt + (sk.neckB - sk.neckA).Unit * 0.6) * CFrame.Angles(0, math.pi / 2, 0)
	add("Collar", "cylinder", v(1.2, 8.8, 8.8), collarCF, C.collar, false)
	add("Bell", "ball", v(1.4, 1.4, 1.4), CFrame.new(collarAt + (neckCF.UpVector * -4.6)), C.bell, false)
	-- the head and its face
	local headCF = CFrame.new(sk.head) * CFrame.Angles(0, math.rad(sk.headYaw), 0) * CFrame.Angles(math.rad(sk.headPitch), 0, 0) * CFrame.Angles(0, 0, math.rad(sk.headRoll))
	add("Head", "ellipsoid", v(9.5, 8.5, 8.5), headCF, C.fur, false)
	add("CheekL", "ellipsoid", v(4.2, 4.4, 4), headCF * CFrame.new(-3.2, -1.4, -2), C.fur, true)
	add("CheekR", "ellipsoid", v(4.2, 4.4, 4), headCF * CFrame.new(3.2, -1.4, -2), C.fur, true)
	add("Muzzle", "ellipsoid", v(4.6, 3.4, 3.2), headCF * CFrame.new(0, -2, -4.2), C.white, false)
	add("Nose", "ellipsoid", v(1.3, 0.8, 0.7), headCF * CFrame.new(0, -0.9, -5.75), C.nose, false)
	add("Chin", "ellipsoid", v(3, 1.6, 2.5), headCF * CFrame.new(0, -3.4, -3), C.white, true)
	for i, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local ear = headCF * CFrame.new(side * 3, 4.3, 0.6) * CFrame.Angles(math.rad(-10), 0, math.rad(-side * 16))
		add("Ear" .. tag, "ellipsoid", v(3.6, 4.8, 0.9), ear, C.fur, false)
		add("EarIn" .. tag, "ellipsoid", v(2.4, 3.3, 0.3), ear * CFrame.new(0, -0.3, -0.45), C.inner, true)
		local _ = i
	end
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local eye = headCF * CFrame.new(side * 2.2, 1, -3.35)
		add("Eye" .. tag, "ball", v(1.95, 1.95, 1.95), eye, C.iris, false)
		add("Pupil" .. tag, "ellipsoid", v(0.45, 1.5, 0.3), eye * CFrame.new(0, 0, -0.92), C.pupil, false)
		local shut = math.clamp(sk.shut, 0, 1)
		add("Lid" .. tag, "ellipsoid", v(2.15, 0.25 + shut * 1.9, 2.1), eye * CFrame.new(0, 0.98 * (1 - shut), 0.02), C.fur, false)
	end
	for _, side in { -1, 1 } do
		for k = 1, 3 do
			local a = (headCF * CFrame.new(side * 2.1, -2.1, -5)).Position
			local bb = (headCF * CFrame.new(side * 8.5, -2.6 + k * 0.8, -5.6 + k * 0.5)).Position
			add(`Whisker{if side < 0 then "L" else "R"}{k}`, "cylinder", v((bb - a).Magnitude, 0.09, 0.09), along(a, bb) * CFrame.Angles(0, math.pi / 2, 0), C.whisker, true)
		end
	end
	-- the legs: bones as ellipsoids along them, and the paws
	local function bone(name: string, a: Vector3, bb: Vector3, d: number, color: string)
		add(name, "ellipsoid", v(d, d, (bb - a).Magnitude + d * 0.7), along(a, bb), color, false)
	end
	for _, item in { { "FL", sk.fl }, { "FR", sk.fr } } :: { { any } } do
		local leg: Leg = item[2]
		bone(item[1] .. "Upper", leg.a, leg.b, 3.4, C.fur)
		bone(item[1] .. "Lower", leg.b, leg.c, 2.5, C.fur)
		add(item[1] .. "Paw", "ellipsoid", v(2.8, 1.8, 3.6), CFrame.new(leg.d :: Vector3), C.light, false)
	end
	for _, item in { { "HL", sk.hl }, { "HR", sk.hr } } :: { { any } } do
		local leg: Leg = item[2]
		bone(item[1] .. "Thigh", leg.a, leg.b, 4.2, C.fur)
		bone(item[1] .. "Shank", leg.b, leg.c, 2.7, C.fur)
		bone(item[1] .. "Foot", leg.c, leg.d :: Vector3, 2.1, C.fur)
		add(item[1] .. "Paw", "ellipsoid", v(2.8, 1.8, 3.4), CFrame.new(leg.d :: Vector3), C.light, false)
	end
	-- the tail, ringed dark and light, thinning to its tip
	for i = 1, 10 do
		local d = 2.9 - 1.2 * (i - 1) / 9
		bone(`Tail{i}`, sk.tail[i], sk.tail[i + 1], d, if i % 2 == 0 then C.stripe else C.fur)
	end
	-- the forehead's dark marks (the tabby's "M")
	add("Brow1", "ellipsoid", v(0.8, 0.4, 3), headCF * CFrame.new(-1.1, 3.9, -1.2), C.stripe, true)
	add("Brow2", "ellipsoid", v(0.8, 0.4, 3), headCF * CFrame.new(1.1, 3.9, -1.2), C.stripe, true)
	return out
end

-- The cat's frame in the world: on its surface at `pos`, facing `heading` (flat).
function CatPose.frame(pos: Vector3, heading: Vector3): CFrame
	local f = v(heading.X, 0, heading.Z)
	if f.Magnitude < 1e-4 then f = v(0, 0, -1) end
	return CFrame.lookAt(pos, pos + f.Unit, Vector3.yAxis)
end

return table.freeze(CatPose)
