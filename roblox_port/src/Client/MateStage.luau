--!strict
-- What the mating cycle looks like (ROBLOX-80). Display only: the cycle itself is Life/Mating and Predator/Mate (what is true), and nothing here feeds back.
--   the mate ..... a SpiderRig of the played spider's own look at the adult size times the mate's factor (male 0.9, female 1.15, each +-5%), drawn with the
--                  rival's path (a "low"-detail rig, put on the mate's pose each frame) and destroyed when the mate is off the sill;
--   the egg sac .. a small silk sphere in the crack, held by three threads (Data/MatingRules.sacAt), from the morning it is made until the family carries on;
--   the hatching . a seeded handful of spiderlings (parts: a body, a head and, when ballooning, a thread) that come out of the sac, wander a little on the
--                  crack's floor and balloon away one by one on a silk thread with a gentle lift, in about 26 s. The count is the brood, up to 12 on the full
--                  detail tier and 4 on the low one. The plan and the pose of each are pure functions of the seed and the scene's clock (MateStage.plan, MateStage.pose),
--                  so a spiderling is always where it was: nothing is rolled while it plays, and a scene seen again is the same scene.
-- Every part is anchored, never collides, is never seen by a ray, never touched and casts no shadow, as the dew and the draglines are: the sac and the
-- spiderlings are in the crack, and a sight cast or a jump probe must pass through them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(Shared:WaitForChild("Data"):WaitForChild("MatingRules"))
local WorldMap = require(Shared:WaitForChild("World"):WaitForChild("WorldMap"))
local SupportMath = require(Shared:WaitForChild("Movement"):WaitForChild("SupportMath"))
local PreyRandom = require(Shared:WaitForChild("Prey"):WaitForChild("PreyRandom"))
local SpiderRig = require(Shared:WaitForChild("Rig"):WaitForChild("SpiderRig"))
local Growth = require(Shared:WaitForChild("Life"):WaitForChild("Growth"))
local Appearances = require(Shared:WaitForChild("Data"):WaitForChild("Appearances"))

local MateStage = {}
MateStage.__index = MateStage

-- The hatching scene, in seconds. The first spiderling is out at about 1 s, the last balloons at 20.5 s at the latest, a lift takes LIFT_SECONDS after
-- the TIPTOE_SECONDS of standing with the thread out; the scene is over (and the card comes) at SCENE_SECONDS.
MateStage.SCENE_SECONDS = 26.0
MateStage.TIPTOE_SECONDS = 1.2
MateStage.LIFT_SECONDS = 4.0
MateStage.LIFT_HEIGHT = 2.4 -- how far a spiderling rises while it is seen
MateStage.MAX_FULL = 12
MateStage.MAX_LOW = 4
MateStage.BODY = 0.14 -- the abdomen's diameter in studs (one stud is a centimetre: a spiderling a millimetre or two is shown larger so it can be seen)
-- Where a spiderling's two balls sit, in BODY, along its heading from its middle, and the head's diameter: the head overlaps the abdomen (centres 0.77 apart, the radii
-- 0.5 and 0.35 add to 0.85, so they are 0.08 into each other); at 0.55 and 0.6 across there was a gap of 0.1 BODY (0.014 studs) between them, a head floating in front.
MateStage.BODY_AT, MateStage.HEAD_AT, MateStage.HEAD = -0.35, 0.42, 0.7
-- The crack's floor, where the spiderlings walk: inside the retreat's box (the map's: ROBLOX-94), clear of its walls.
local FLOOR_Y = 0.05
local CRACK = WorldMap.retreat("sill_crevice") :: WorldMap.Retreat
local LO = Vector3.new(CRACK.min.X + 0.4, FLOOR_Y, CRACK.min.Z + 0.4)
local HI = Vector3.new(CRACK.max.X - 0.4, FLOOR_Y, CRACK.max.Z - 0.4)

local SILK = Color3.fromRGB(236, 232, 214)

export type Spiderling = { emerge: number, balloon: number, angle: number, reach: number, speed: number, phase: number, wx: number, wz: number }
export type Pose = { state: string, position: Vector3, heading: Vector3, alpha: number, thread: Vector3? }

-- ---------------------------------------------------------------- the plan: pure

-- The spiderlings of a brood: a seeded draw for each from the world's seed, the family's number, the day the eggs hatched and the spiderling's own number.
-- `count` is how many are drawn (the tier's cap on the brood). They come out one after another, wander for a few seconds and balloon in the same order.
function MateStage.plan(seed: number, generation: number, day: number, count: number): { Spiderling }
	local plan: { Spiderling } = {}
	local n = math.max(count, 1)
	local span = MateStage.SCENE_SECONDS - 5.5 - 8.0 -- the balloons begin at 8 s and the last starts by 20.5 s
	for i = 0, count - 1 do
		local g = PreyRandom.new((seed * 83492791 + generation * 19349663 + day * 73856093 + (i + 1) * 2654435 + 6101) % 2147483647)
		g:next()
		local emerge = 0.6 + i * 0.3 + g:next() * 0.3
		local balloon = 8.0 + (i + g:next() * 0.8) * span / n
		table.insert(plan, {
			emerge = emerge, balloon = balloon,
			angle = g:next() * math.pi * 2, -- the way it first heads from the sac
			reach = 0.6 + g:next() * 1.4, -- how far from the sac it goes
			speed = 0.18 + g:next() * 0.2, -- studs a second
			phase = g:next() * math.pi * 2,
			wx = (g:next() - 0.5) * 0.9, wz = (g:next() - 0.5) * 0.9, -- the drift of the air while it rises
		})
	end
	return plan
end

local function clampFloor(p: Vector3): Vector3
	return Vector3.new(math.clamp(p.X, LO.X, HI.X), FLOOR_Y, math.clamp(p.Z, LO.Z, HI.Z))
end

-- Where a spiderling walks `u` seconds after it came out: out from the sac along a gently bending path, never farther than its reach.
local function walkAt(p: Spiderling, u: number, reduced: boolean): Vector3
	local sac = Rules.sacAt
	local out = math.min(0.35 + u * p.speed, p.reach)
	local bend = if reduced then 0 else math.sin(p.phase + u * 0.6) * 0.8
	local a = p.angle + bend
	return clampFloor(Vector3.new(sac.X + math.cos(a) * out, FLOOR_Y, sac.Z + math.sin(a) * out))
end

-- The pose of a spiderling at scene time t: state "sac" (not out yet, not drawn), "walk", "tiptoe" (standing with the thread out), "lift" (rising on the
-- thread, fading) or "gone". `alpha` is how visible it is (0 hidden, 1 seen). The thread's top end is given while it is out.
function MateStage.pose(p: Spiderling, t: number, reduced: boolean): Pose
	local sac = Rules.sacAt
	if t < p.emerge then
		return { state = "sac", position = sac, heading = Vector3.xAxis, alpha = 0, thread = nil }
	end
	if t < p.balloon then
		local here = walkAt(p, t - p.emerge, reduced)
		local ahead = walkAt(p, t - p.emerge + 0.1, reduced)
		local d = ahead - here
		local h = if d.Magnitude > 1e-4 then d.Unit else Vector3.new(math.cos(p.angle), 0, math.sin(p.angle))
		return { state = "walk", position = here, heading = h, alpha = math.min(1, (t - p.emerge) / 0.5), thread = nil }
	end
	local here = walkAt(p, p.balloon - p.emerge, reduced)
	local h = Vector3.new(math.cos(p.angle), 0, math.sin(p.angle))
	local s = t - p.balloon
	if s < MateStage.TIPTOE_SECONDS then
		local len = 0.1 + 0.9 * (s / MateStage.TIPTOE_SECONDS)
		return { state = "tiptoe", position = here, heading = h, alpha = 1, thread = here + Vector3.new(p.wx * 0.3, 1, p.wz * 0.3).Unit * len }
	end
	local u = (s - MateStage.TIPTOE_SECONDS) / MateStage.LIFT_SECONDS
	if u >= 1 then return { state = "gone", position = here, heading = h, alpha = 0, thread = nil } end
	local e = u * u * (3 - 2 * u) -- slow at first, a gentle lift
	local rise = e * MateStage.LIFT_HEIGHT
	local at = here + Vector3.new(p.wx * e * 1.6, rise, p.wz * e * 1.6)
	local alpha = if u < 0.6 then 1 else math.max(0, 1 - (u - 0.6) / 0.4)
	return { state = "lift", position = at, heading = h, alpha = alpha, thread = at + Vector3.new(p.wx * 0.3, 1, p.wz * 0.3).Unit * 1.0 }
end

-- How many spiderlings the tier shows of a brood.
function MateStage.countFor(brood: number, detail: string): number
	return math.min(brood, if detail == "low" then MateStage.MAX_LOW else MateStage.MAX_FULL)
end

-- ---------------------------------------------------------------- drawing

local function display(p: BasePart, parent: Instance)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
end

local function ball(name: string, diameter: number, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * diameter
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	display(p, parent)
	return p
end

local function strand(name: string, a: Vector3, b: Vector3, parent: Instance, thickness: number): Part
	local p = Instance.new("Part")
	p.Name = name
	local len = math.max((b - a).Magnitude, 0.01)
	p.Size = Vector3.new(thickness, thickness, len)
	p.CFrame = CFrame.lookAt((a + b) * 0.5, b)
	p.Color = SILK
	p.Material = Enum.Material.Neon
	p.Transparency = 0.35
	display(p, parent)
	return p
end

-- `parent`: where the stage's folder goes (the Workspace); `world`: the sill (the rig's contact casts read it).
function MateStage.new(parent: Instance, world: Instance, detail: string): any
	local folder = Instance.new("Folder")
	folder.Name = "Family"
	folder.Parent = parent
	return setmetatable({
		folder = folder, world = world, detail = detail, parent = parent,
		rig = nil :: any, rigFor = "", scaleFor = 0, sac = nil :: Part?, sacThreads = {} :: { Part },
		plan = {} :: { Spiderling }, bodies = {} :: { { body: Part, head: Part, thread: Part } },
		t = 0.0, running = false, finished = false, rider = nil :: any,
	}, MateStage)
end

-- ---- the mate

-- Draws the mate where `mate` (the record) stands, or takes its rig away when it is not on the sill. `appearance`: the played spider's look. `focus` (ROBLOX-89): the point
-- the mate looks at (the player's spider during the mating scene; its drawn body turns a little toward it), and `turn` (radians, 0 for none): how far the drawn body is
-- turned about its up axis from where the simulation faces it (a female mate turning away in the scene's last beat; the simulation's heading is untouched).
-- `cameraAt` (ROBLOX-93): where the camera is; a mate farther than SpiderRig's FAR_STUDS from it is drawn ten times a second (the simulation steps it every tick), unless it is in
-- the mating scene or about to be. The mate's scale is set when the rig is made and when the mate's factor changes (clamped to 0.5..2, as Mate.valid allows), not every frame.
function MateStage.drawMate(self: any, mate: any, appearance: string, dt: number, reduced: boolean, focus: Vector3?, turn: number?, cameraAt: Vector3?)
	if mate == nil or mate.state == "away" then
		if self.rig ~= nil then
			self.rig:destroy()
			self.rig, self.rigFor = nil, ""
		end
		return
	end
	appearance = Appearances.mateLook(appearance, mate.sex) -- (ROBLOX-127: the first spider's male mate has a male's build)
	if self.rig == nil or self.rigFor ~= appearance then
		if self.rig ~= nil then self.rig:destroy() end
		self.rig = SpiderRig.new(self.parent, self.world, appearance, "low", true) -- (living: it breathes and takes the mating scene's cues, for the same parts)
		self.rig.model.Name = "MateSpider"
		self.rigFor, self.scaleFor = appearance, 0
	end
	local rig = self.rig
	rig.reducedMotion = reduced
	local factor = mate.scale
	factor = if type(factor) == "number" and factor == factor then math.clamp(factor, 0.5, 2) else 1
	if self.scaleFor ~= factor then
		self.scaleFor = factor
		rig:setGrowthStage(Growth.ADULT)
		rig:setScale(rig:growthScale(Growth.ADULT) * factor) -- (ROBLOX-114: the look's own adult, which is Growth's for the first spider and the tarantulas)
	end
	local moving = (mate.position - (mate.previous or mate.position)).Magnitude > 0.001
	local up = mate.up or Vector3.yAxis
	local heading = mate.heading
	if turn ~= nil and turn ~= 0 then heading = CFrame.fromAxisAngle(up, turn):VectorToWorldSpace(heading) end
	rig.focusPoint = focus
	local near = cameraAt == nil or focus ~= nil or mate.state == "attend" or mate.state == "pair"
	rig:drawStep(SupportMath.bodyCFrame(mate.position, up, heading), dt, true, moving, if near then 0 else (cameraAt :: Vector3 - mate.position).Magnitude)
end

-- ---- the egg sac

-- Shows the sac or takes it away. It is a silk sphere resting in the crack's corner on three threads.
function MateStage.drawSac(self: any, show: boolean)
	if not show then
		if self.sac ~= nil then
			self.sac:Destroy()
			for _, t in self.sacThreads do t:Destroy() end
			self.sac, self.sacThreads = nil, {}
		end
		return
	end
	if self.sac ~= nil then return end
	local at = Rules.sacAt
	local sac = ball("EggSac", Rules.sacRadius * 2, SILK, self.folder)
	sac.Position = at
	sac.Transparency = 0.12
	self.sac = sac
	local pins = { Vector3.new(at.X - 0.7, at.Y, at.Z), Vector3.new(at.X, at.Y, at.Z + 0.6), Vector3.new(at.X + 0.3, 0.0, at.Z - 0.5) }
	for i, pin in pins do table.insert(self.sacThreads, strand("SacThread" .. i, at, pin, self.folder, 0.012)) end
end

-- ---- the hatching

-- Begins the scene for a brood. Nothing is drawn for the spiderlings until the plan says one is out.
function MateStage.begin(self: any, seed: number, generation: number, day: number, brood: number)
	self:clearScene()
	local count = MateStage.countFor(brood, self.detail)
	self.plan = MateStage.plan(seed, generation, day, count)
	for i = 1, count do
		local body = ball("Spiderling" .. i, MateStage.BODY, Color3.fromRGB(74, 58, 46), self.folder)
		local head = ball("SpiderlingHead" .. i, MateStage.BODY * MateStage.HEAD, Color3.fromRGB(98, 80, 62), self.folder)
		local thread = strand("SpiderlingThread" .. i, Vector3.zero, Vector3.zAxis * 0.1, self.folder, 0.008)
		body.Transparency, head.Transparency, thread.Transparency = 1, 1, 1
		table.insert(self.bodies, { body = body, head = head, thread = thread })
	end
	self.t, self.running, self.finished = 0.0, true, false
end

-- Plays dt seconds of the scene (the simulation's, so a menu holds it) and places the spiderlings. Returns true while it runs.
function MateStage.step(self: any, dt: number, reduced: boolean): boolean
	if not self.running then return false end
	self.t += dt
	local t = self.t
	if self.sac ~= nil then self.sac.Transparency = 0.12 + 0.33 * math.min(1, t / 2) end
	for i, p in self.plan do
		local parts = self.bodies[i]
		local pose = MateStage.pose(p, t, reduced)
		local visible = pose.alpha > 0.001
		parts.body.Transparency = if visible then 1 - pose.alpha else 1
		parts.head.Transparency = parts.body.Transparency
		if visible then
			local fwd = pose.heading
			local at = pose.position + Vector3.yAxis * (MateStage.BODY * 0.5)
			parts.body.Position = at + fwd * (MateStage.BODY * MateStage.BODY_AT)
			parts.head.Position = at + fwd * (MateStage.BODY * MateStage.HEAD_AT)
		end
		local th = parts.thread
		if pose.thread ~= nil and visible then
			local a = pose.position + Vector3.yAxis * (MateStage.BODY * 0.8)
			local len = math.max((pose.thread - a).Magnitude, 0.01)
			th.Size = Vector3.new(0.008, 0.008, len)
			th.CFrame = CFrame.lookAt((a + pose.thread) * 0.5, pose.thread)
			th.Transparency = 0.35 + 0.65 * (1 - pose.alpha)
		else
			th.Transparency = 1
		end
	end
	if t >= MateStage.SCENE_SECONDS then
		self.running, self.finished = false, true
		self:clearSpiderlings()
	end
	return self.running
end

function MateStage.clearSpiderlings(self: any)
	for _, parts in self.bodies do
		parts.body:Destroy()
		parts.head:Destroy()
		parts.thread:Destroy()
	end
	self.bodies, self.plan = {}, {}
end

-- Stops the scene and takes its spiderlings away (the sac is drawn by the stage of the record, not by this).
function MateStage.clearScene(self: any)
	self:clearSpiderlings()
	self.running, self.finished, self.t = false, false, 0.0
end

-- ---- the ride (ROBLOX-120: "Follow one", Life/Ballooning)

-- Draws the followed spiderling at `at` on its thread to `thread` (made when first asked), or takes it away (`at` nil). The rider is drawn bigger than the brood's
-- (RIDER: the camera rides with it, close): a body, a head and the thread, the same colours.
MateStage.RIDER = 0.3
function MateStage.drawRider(self: any, at: Vector3?, thread: Vector3?)
	if at == nil then
		if self.rider ~= nil then
			for _, part in self.rider do part:Destroy() end
			self.rider = nil
		end
		return
	end
	if self.rider == nil then
		self.rider = {
			body = ball("Rider", MateStage.RIDER, Color3.fromRGB(74, 58, 46), self.folder),
			head = ball("RiderHead", MateStage.RIDER * MateStage.HEAD, Color3.fromRGB(98, 80, 62), self.folder),
			thread = strand("RiderThread", Vector3.zero, Vector3.zAxis * 0.1, self.folder, 0.03),
		}
	end
	local r = self.rider
	local top = thread or (at + Vector3.yAxis)
	local fwd = Vector3.new(top.X - at.X, 0, top.Z - at.Z)
	fwd = if fwd.Magnitude > 1e-3 then fwd.Unit else -Vector3.zAxis
	r.body.Position = at + fwd * (MateStage.RIDER * MateStage.BODY_AT)
	r.head.Position = at + fwd * (MateStage.RIDER * MateStage.HEAD_AT)
	local a = at + Vector3.yAxis * (MateStage.RIDER * 0.5)
	r.thread.Size = Vector3.new(0.03, 0.03, math.max((top - a).Magnitude, 0.01))
	r.thread.CFrame = CFrame.lookAt((a + top) * 0.5, top)
end

-- Everything away: a new life, a restored rest.
function MateStage.reset(self: any)
	self:drawRider(nil)
	self:clearScene()
	self:drawSac(false)
	if self.rig ~= nil then
		self.rig:destroy()
		self.rig, self.rigFor = nil, ""
	end
end

-- The count of parts the stage has now, for the budgets in the tests: the sac and its threads, the spiderlings, the mate's rig.
function MateStage.partCount(self: any): number
	local n = if self.sac ~= nil then 1 + #self.sacThreads else 0
	n += #self.bodies * 3
	return n
end

return MateStage
