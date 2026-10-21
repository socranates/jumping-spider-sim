--!strict
-- The robin in the world (ROBLOX-120): Predator/Bird's American robin drawn at its true size, 25 cm from bill to tail (Bird.LENGTH), from `parts` (pure: the previewer
-- draws it too): a grey-brown back and folded wings, the rusty red-orange breast, a blackish head with the white eye ring broken in front and behind, a yellow bill, a
-- white throat streaked dark, white under the tail, the dark tail and thin legs. Its poses: standing (its head cocked to one side, as a robin looks at the ground), a
-- hop, a peck at the ground, the watch (head cocked at the spider, still: the honest tell), the strike (bill driven down and forward), and in the air its wings out.
-- Its shadow is a dark soft oval on the ground under it, broad and faint high up, small and dark when it stands. Every part anchored, never collides, never seen by a
-- ray, the body casts no engine shadow of its own (the drawn one is the shadow, so the two never double). One Workspace:BulkMoveTo a frame. Display only.
-- The open ground's voices are here too (SOUNDS, "" until Nathan uploads tools/make_meadow_sounds.py's robin_call.wav and cricket_chirp.wav): the robin's call while it
-- calls, as loud as Predator/Bird.call says, and the nearest singing field cricket's chirps (Prey/PreyKinds.chirping), as loud as the client hears it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shapes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Habitat"):WaitForChild("Shapes"))

local BirdBody = {}
BirdBody.__index = BirdBody

BirdBody.SOUNDS = { call = "", chirp = "" } :: { [string]: string }
BirdBody.COLORS = {
	back = "514940", wing = "443d35", breast = "c0562a", belly = "d0753d", head = "26231f", eye = "0d0c0b", ring = "eeeae0", bill = "e0b020", billTip = "6a5420",
	throat = "e8e4da", streak = "2a2622", vent = "efece4", tail = "2d2925", leg = "6b5444", shadow = "141210",
}

export type Spec = { name: string, size: Vector3, frame: CFrame, color: string, ball: boolean, full: boolean?, transparency: number? }

-- The parts in its own frame (its feet's middle on the ground at the origin, ahead -z). `pose`: "stand", "hop", "peck", "watch", "strike", "fly", "land", "leave";
-- `t` seconds for the wingbeat; `cock` -1 or 1, the side the head tips; `strike` 0..1 through the stab.
function BirdBody.parts(pose: string, t: number, cock: number, strike: number): { Spec }
	local C = BirdBody.COLORS
	local out: { Spec } = {}
	local function ell(name: string, frame: CFrame, size: Vector3, color: string, full: boolean?)
		table.insert(out, { name = name, size = size, frame = frame, color = color, ball = true, full = full })
	end
	local function rod(name: string, a: Vector3, b: Vector3, d: number, color: string, full: boolean?)
		local len = (b - a).Magnitude
		table.insert(out, { name = name, size = Vector3.new(d, d, len), frame = CFrame.lookAt((a + b) / 2, b), color = color, ball = false, full = full })
	end
	local flying = pose == "fly" or pose == "land" or pose == "leave"
	-- the body: level in flight, its tail tipped down a little standing
	local lift = if flying then 0 else 6.2
	local pitch = if flying then 0 elseif pose == "peck" or pose == "strike" then math.rad(-22) else math.rad(-8)
	local body = CFrame.new(0, lift + 3.2, 0.5) * CFrame.Angles(pitch, 0, 0)
	ell("Body", body, Vector3.new(7.6, 7.4, 13.5), C.back)
	ell("Breast", body * CFrame.new(0, -0.7, -2.9), Vector3.new(7.3, 6.9, 9.2), C.breast)
	ell("Belly", body * CFrame.new(0, -2.4, 1.2), Vector3.new(5.6, 3.6, 6.4), C.belly, true)
	ell("Vent", body * CFrame.new(0, -1.8, 4.6), Vector3.new(3.6, 2.6, 3.4), C.vent, true)
	-- the head: on the neck at the body's front; cocked (rolled to a side, looking down at the ground with one eye), down for a peck, forward and down in the stab
	local neck = body * CFrame.new(0, 2.6, -5.6)
	local headTurn = CFrame.new()
	if pose == "stand" or pose == "watch" then headTurn = CFrame.Angles(math.rad(-10), 0, math.rad(32) * cock)
	elseif pose == "peck" then headTurn = CFrame.Angles(math.rad(-60), 0, 0) * CFrame.new(0, -1.5, -1.0)
	elseif pose == "strike" then headTurn = CFrame.new(0, -2.5 * strike, -3.0 * strike) * CFrame.Angles(math.rad(-55) * strike, 0, 0) end
	local head = neck * headTurn * CFrame.new(0, 1.4, -0.8)
	ell("Head", head, Vector3.new(4.2, 4.1, 4.7), C.head)
	-- the white throat under the bill, streaked dark
	ell("Throat", head * CFrame.new(0, -1.75, -1.5), Vector3.new(1.7, 1.0, 1.5), C.throat, true)
	ell("Streak", head * CFrame.new(0, -1.85, -1.75), Vector3.new(0.35, 0.9, 1.2), C.streak, true)
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		ell("Eye" .. side, head * CFrame.new(1.85 * s, 0.5, -0.9), Vector3.new(0.6, 1.0, 1.0), C.eye)
		-- the white eye ring, broken in front and behind: an arc over the eye and one under it
		ell("RingTop" .. side, head * CFrame.new(1.8 * s, 1.1, -0.9), Vector3.new(0.4, 0.3, 0.9), C.ring, true)
		ell("RingLow" .. side, head * CFrame.new(1.8 * s, -0.1, -0.9), Vector3.new(0.4, 0.3, 0.9), C.ring, true)
	end
	-- the bill: yellow, a little dusky at the tip, tapering (two ellipsoids)
	ell("Bill", head * CFrame.new(0, -0.1, -2.7) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(1.0, 0.85, 2.2), C.bill)
	ell("BillTip", head * CFrame.new(0, -0.3, -3.9) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(0.55, 0.45, 1.4), C.billTip, true)
	-- the tail: long, dark, from the back of the body
	local tailBase = body * CFrame.new(0, 0.8, 6.0)
	local tailDown = if flying then 0 else math.rad(-12)
	ell("Tail", tailBase * CFrame.Angles(tailDown, 0, 0) * CFrame.new(0, 0, 4.2), Vector3.new(4.2, 0.9, 9.4), C.tail)
	-- the wings: folded along its sides standing, out and beating in the air
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		if flying then
			local beat = if pose == "land" then math.rad(40) else math.sin(t * 2 * math.pi * 6) * math.rad(35)
			local root = body * CFrame.new(3.0 * s, 2.0, -1.0)
			ell("Wing" .. side, root * CFrame.Angles(0, 0, beat * s) * CFrame.new(8.0 * s, 0, 1.0), Vector3.new(16, 0.7, 7.5), C.wing)
		else
			ell("Wing" .. side, body * CFrame.new(3.0 * s, 1.2, 2.0) * CFrame.Angles(math.rad(-6), math.rad(4) * s, 0), Vector3.new(1.2, 4.6, 11.0), C.wing)
		end
	end
	-- the legs: thin, from under the body to the ground, tucked in the air
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local hip = (body * CFrame.new(1.3 * s, -3.2, 0.6)).Position
		local foot = if flying then hip + Vector3.new(0, -1.5, 2.5) elseif pose == "hop" then Vector3.new(1.3 * s, 1.0, 0.4) else Vector3.new(1.4 * s, 0.25, -0.4)
		rod("Leg" .. side, hip, foot, 0.45, C.leg)
		if not flying then rod("Toe" .. side, foot, foot + Vector3.new(0, -0.2, -2.0), 0.3, C.leg, true) end
	end
	return out
end

function BirdBody.new(parent: Instance, detail: string): any
	local folder = Instance.new("Folder")
	folder.Name = "Robin"
	folder.Parent = parent
	local shadow = Shapes.ellipsoid(folder, "Shadow", Vector3.new(14, 0.05, 20), CFrame.new(), Color3.fromHex(BirdBody.COLORS.shadow), "SmoothPlastic")
	shadow.Transparency = 1
	shadow.CastShadow = false
	-- (in the air the shadow is a bird's: the wings' oval across and the body and tail's along, a cross that sweeps over the ground)
	local shadowBody = Shapes.ellipsoid(folder, "ShadowBody", Vector3.new(8, 0.05, 26), CFrame.new(), Color3.fromHex(BirdBody.COLORS.shadow), "SmoothPlastic")
	shadowBody.Transparency = 1
	shadowBody.CastShadow = false
	local self = setmetatable({ folder = folder, detail = detail, model = nil :: Instance?, parts = {} :: { [string]: BasePart }, shadow = shadow, shadowBody = shadowBody, t = 0,
		voices = {} :: { [string]: Sound }, shown = false }, BirdBody)
	for name, id in BirdBody.SOUNDS do
		if id ~= "" then
			local s = Instance.new("Sound")
			s.Name = name
			s.SoundId = id
			s.Looped = true
			s.Volume = 0
			s.Parent = folder
			self.voices[name] = s
		end
	end
	return self
end

-- Builds the model's parts once (by name: the poses move the same parts).
local function build(self: any)
	local model = Instance.new("Folder")
	model.Name = "Body"
	for _, pose in { "stand", "fly" } do
		for _, spec in BirdBody.parts(pose, 0, 1, 0) do
			if self.parts[spec.name] == nil and not (spec.full and self.detail == "low") then
				local material = if string.sub(spec.name, 1, 3) == "Eye" or string.sub(spec.name, 1, 4) == "Bill" then "SmoothPlastic" else "Fabric" -- (feathers are matte)
				local p = if spec.ball then Shapes.ellipsoid(model, spec.name, spec.size, CFrame.new(), Color3.fromHex(spec.color), material)
					else Shapes.block(model, spec.name, spec.size, CFrame.new(), Color3.fromHex(spec.color), material)
				p.CastShadow = false
				self.parts[spec.name] = p
			end
		end
	end
	model.Parent = self.folder
	self.model = model
end

-- Draws the robin (`bird`, Predator/Bird's) where it is, in its pose, with its shadow; hides it when it is away. `dt` the frame's seconds; `call` how loud its call is,
-- `chirp` how loud the nearest cricket's song (0..1 each).
function BirdBody.draw(self: any, bird: any, dt: number, call: number, chirp: number?)
	self.t += dt
	for name, s in self.voices do
		local loud = if name == "chirp" then chirp or 0 else call
		s.Volume = loud * 0.6
		if loud > 0 and not s.IsPlaying then s:Play() elseif loud <= 0 and s.IsPlaying then s:Stop() end
	end
	if bird == nil or not bird.here then
		if self.shown then
			for _, p in self.parts do p.Transparency = 1 end
			self.shadow.Transparency = 1
			self.shadowBody.Transparency = 1
			self.shown = false
		end
		return
	end
	if self.model == nil then build(self) end
	local strike = if bird.strikeS ~= nil and bird.strikeS >= 0 then math.clamp(bird.strikeS / 0.1, 0, 1) * (1 - math.clamp((bird.strikeS - 0.2) / 0.3, 0, 1)) else 0
	local pose = if strike > 0 then "strike" else bird.pose
	local frame = CFrame.lookAt(bird.pos, bird.pos + bird.heading)
	local moved: { BasePart } = {}
	local frames: { CFrame } = {}
	local seen: { [string]: boolean } = {}
	for _, spec in BirdBody.parts(pose, self.t, bird.cock or 1, strike) do
		local p = self.parts[spec.name]
		if p ~= nil then
			seen[spec.name] = true
			if p.Size ~= spec.size then p.Size = spec.size end
			table.insert(moved, p)
			table.insert(frames, frame * spec.frame)
		end
	end
	for name, p in self.parts do p.Transparency = if seen[name] then 0 else 1 end
	-- the shadow: under it on the ground, broad and faint the higher it flies
	local ground = bird.shadow or Vector3.new(bird.pos.X, bird.pos.Y, bird.pos.Z)
	local high = math.max(0, bird.pos.Y - ground.Y)
	local spread = 1 + high / 220
	local flying = bird.flying == true or bird.pose == "land" or bird.pose == "leave"
	self.shadow.Size = if flying then Vector3.new(34 * spread, 0.05, 9 * spread) else Vector3.new(9, 0.05, 18)
	self.shadow.Transparency = math.clamp(0.45 + high / 700, 0.45, 0.85)
	self.shadowBody.Size = Vector3.new(7 * spread, 0.05, 24 * spread)
	self.shadowBody.Transparency = if flying then self.shadow.Transparency else 1
	local onGround = CFrame.lookAt(ground + Vector3.new(0, 0.12, 0), ground + Vector3.new(0, 0.12, 0) + bird.heading)
	table.insert(moved, self.shadow)
	table.insert(frames, onGround * CFrame.new(0, 0, -2 * spread))
	table.insert(moved, self.shadowBody)
	table.insert(frames, onGround * CFrame.new(0, 0.01, 0))
	Workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
	self.shown = true
end

return BirdBody
