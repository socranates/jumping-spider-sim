--!strict
-- The drawn woodlice (ROBLOX-96, Prey/Woodlouse): a grey segmented body about a centimetre long, made of seven overlapping plates over the back, a small head
-- with two antennae and seven pairs of short legs (woodlice are isopods: seven pairs of walking legs), each louse PARTS parts under the fly's budget, all
-- anchored, never colliding, never seen by a ray and casting no shadow (Habitat/Shapes), placed with one Workspace:BulkMoveTo each frame like the flies. A louse
-- under cover (state "hidden") is drawn a stud and a half under the soil, inside the solid ground, so nothing of it shows; it comes back up where it went under.
-- Display only: the sim decides where each louse is and whether it is hiding; nothing here feeds back.
-- ROBLOX-103 (W3c): pose only, no part added. The fourteen legs step in a metachronal wave (each pair a little behind the one in front, the two sides in
-- opposite phase), a full wave per stride of soil covered, so a louse that stops stops stepping and one that scurries for cover steps fast; the antennae sway.
-- The common garden woodlouse the page names (Porcellio scaber) cannot roll into a ball, so it scurries: no rolling. Far from the camera (FlyLook.far, as the
-- rival's rig) a louse is drawn ten times a second; Reduced Motion keeps the steps and stills the antennae.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shapes = require(Shared:WaitForChild("Habitat"):WaitForChild("Shapes"))
local FlyLook = require(Shared:WaitForChild("Data"):WaitForChild("FlyLook"))

local BugBodies = {}
BugBodies.__index = BugBodies

-- The most parts a woodlouse may be drawn with (the sheet below makes exactly this many).
BugBodies.PARTS = 24
-- How far under the soil a hidden louse is kept.
BugBodies.UNDER = 1.5

-- The sheet: body frame -Z forward, +Y up, the origin the body's centre at Woodlouse.HOVER above the soil, the feet at y = -0.12.
BugBodies.look = {
	colors = { plate = "6b6d6a", plateDark = "5c5e5b", head = "55575a", antenna = "4a4c4f", leg = "7a7c78" },
	plates = 7, plateLength = 0.17, plateWidth = 0.5, plateHeight = 0.26, from = -0.33, pitch = 0.12, -- seven plates from z -0.33 back, every 0.12: a 1.0 long body
	head = { at = { 0, -0.02, -0.44 }, size = { 0.3, 0.2, 0.16 } },
	antenna = { from = { 0.08, 0.02, -0.5 }, to = { 0.22, 0.06, -0.72 }, d = 0.016 },
	leg = { hipX = 0.2, hipY = -0.02, footX = 0.32, footY = -0.12, d = 0.018, from = -0.33, pitch = 0.12 },
	-- (ROBLOX-103) the gait (as Data/FlyLook's `motion`): a wave of `wave` radians from pair to pair, a cycle per `stride` studs; the antennae's sway
	motion = { gait = { stride = 0.4, swing = 0.3, lift = 0.28, settle = 10, jump = 1.0, wave = 0.9 }, antenna = { amp = 0.18, hz = 1.4 } },
}

-- `hip`, `side`, `pair` (ROBLOX-103): where a leg turns from and which it is, or an antenna's base (`pair` 0)
type Spec = { name: string, rod: boolean, color: Color3, size: Vector3, frame: CFrame, hip: Vector3?, side: number?, pair: number? }

local function rodBetween(a: Vector3, b: Vector3, diameter: number): (Vector3, CFrame)
	local dir = (b - a).Unit
	local up = if math.abs(dir.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return Vector3.new((b - a).Magnitude, diameter, diameter), CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0)
end

local function build(): { Spec }
	local L = BugBodies.look
	local specs: { Spec } = {}
	local function color(name: string): Color3
		return Color3.fromHex(L.colors[name])
	end
	for i = 1, L.plates do
		local z = L.from + (i - 1) * L.pitch
		local arch = 1 - 0.18 * math.abs((i - (L.plates + 1) / 2) / ((L.plates - 1) / 2)) -- the back is highest and widest in the middle
		table.insert(specs, { name = "Plate" .. i, rod = false, color = color(if i % 2 == 0 then "plateDark" else "plate"),
			size = Vector3.new(L.plateWidth * arch, L.plateHeight * arch, L.plateLength), frame = CFrame.new(0, 0.01, z) })
	end
	table.insert(specs, { name = "Head", rod = false, color = color("head"), size = Vector3.new(L.head.size[1], L.head.size[2], L.head.size[3]), frame = CFrame.new(L.head.at[1], L.head.at[2], L.head.at[3]) })
	for _, side in { -1, 1 } do
		local word = if side < 0 then "Left" else "Right"
		local a = Vector3.new(L.antenna.from[1] * side, L.antenna.from[2], L.antenna.from[3])
		local b = Vector3.new(L.antenna.to[1] * side, L.antenna.to[2], L.antenna.to[3])
		local size, frame = rodBetween(a, b, L.antenna.d)
		table.insert(specs, { name = word .. "Antenna", rod = true, color = color("antenna"), size = size, frame = frame, hip = a, side = side, pair = 0 })
		for i = 1, 7 do
			local z = L.leg.from + (i - 1) * L.leg.pitch
			local hip, foot = Vector3.new(L.leg.hipX * side, L.leg.hipY, z), Vector3.new(L.leg.footX * side, L.leg.footY, z + 0.02)
			local ls, lf = rodBetween(hip, foot, L.leg.d)
			table.insert(specs, { name = `{word}Leg{i}`, rod = true, color = color("leg"), size = ls, frame = lf, hip = hip, side = side, pair = i })
		end
	end
	return specs
end

function BugBodies.new(parent: Instance): any
	local folder = Instance.new("Folder")
	folder.Name = "Bugs"
	folder.Parent = parent
	return setmetatable({ folder = folder, rigs = {}, template = build(), parts = {}, frames = {} }, BugBodies)
end

-- One louse's parts.
function BugBodies.spawn(self: any, id: string): any
	local folder = Instance.new("Folder")
	folder.Name = id
	folder.Parent = self.folder
	local parts: { Part } = {}
	for i, spec in self.template do
		local part: Part
		if spec.rod then
			part = Shapes.block(folder, spec.name, spec.size, spec.frame, spec.color, "SmoothPlastic")
			part.Shape = Enum.PartType.Cylinder
		else
			part = Shapes.ellipsoid(folder, spec.name, spec.size, spec.frame, spec.color, "SmoothPlastic")
		end
		parts[i] = part
	end
	local rig = { folder = folder, parts = parts, stride = 0, gait = 0, t = 0, owed = 0, drawn = false, lastPos = nil :: Vector3?, seed = (#id * 1.37) % (2 * math.pi) }
	self.rigs[id] = rig
	return rig
end

-- (ROBLOX-103) how a part moves this drawing (a leg about its hip, an antenna about its base), or nil
local function moveOf(spec: Spec, rig: any, reduced: boolean): CFrame?
	local hip = spec.hip
	if hip == nil then return nil end
	local M = BugBodies.look.motion
	local side = spec.side or 1
	if spec.pair == 0 then
		if reduced then return nil end
		local A = M.antenna
		local up = A.amp * math.sin(rig.t * A.hz * 2 * math.pi * (1 + rig.gait) + rig.seed + side)
		local out = A.amp * 0.5 * math.sin(rig.t * A.hz * 1.4 * math.pi + rig.seed * 1.7) * side
		return CFrame.new(hip) * CFrame.fromAxisAngle(Vector3.xAxis, up) * CFrame.fromAxisAngle(Vector3.yAxis, out) * CFrame.new(-hip)
	end
	if rig.gait <= 0 then return nil end
	local G = M.gait
	local phase = rig.stride - (spec.pair or 1) * G.wave + (if side < 0 then math.pi else 0)
	local swing = rig.gait * G.swing * math.sin(phase)
	local lift = rig.gait * G.lift * math.max(0, math.cos(phase))
	return CFrame.new(hip) * CFrame.fromAxisAngle(Vector3.yAxis, side * swing) * CFrame.fromAxisAngle(Vector3.zAxis, side * lift) * CFrame.new(-hip)
end

-- Places every louse's parts: `lice` are the sim's (id, position, heading, state). `now` (ROBLOX-103): the prey's clock, for the steps and the sway (nil: no
-- motion); `cameraAt`: the camera's place, for the far rule; `reduced`: Reduced Motion.
function BugBodies.draw(self: any, lice: { any }, now: number?, cameraAt: Vector3?, reduced: boolean?)
	local parts: { BasePart } = self.parts
	local frames: { CFrame } = self.frames
	table.clear(parts)
	table.clear(frames)
	local dtAll = if now ~= nil and self.lastNow ~= nil then math.clamp(now - self.lastNow, 0, 0.25) else 0
	self.lastNow = now
	local G = BugBodies.look.motion.gait
	local present: { [string]: boolean } = {}
	for _, w in lice do
		present[w.id] = true
		local rig = self.rigs[w.id] or self:spawn(w.id)
		rig.owed += dtAll
		if rig.drawn and cameraAt ~= nil and (cameraAt - w.position).Magnitude > FlyLook.far.studs and rig.owed < FlyLook.far.seconds - 1e-6 then continue end
		local dt = rig.owed
		rig.owed, rig.drawn = 0, true
		local heading: Vector3 = w.heading
		if heading.Magnitude < 1e-6 then heading = -Vector3.zAxis end
		local position: Vector3 = w.position
		-- the steps: from the soil covered since the last drawing (none under cover, none in a jump of more than `jump`)
		local moved = if rig.lastPos ~= nil then Vector3.new(position.X - rig.lastPos.X, 0, position.Z - rig.lastPos.Z).Magnitude else 0
		rig.lastPos = position
		if dt > 0 then
			if moved > G.jump or w.state == "hidden" then moved = 0 end
			if moved > 1e-5 then rig.stride = (rig.stride + moved / G.stride * 2 * math.pi) % (2 * math.pi) end
			local want = if moved > 1e-5 then 1 else 0
			rig.gait += (want - rig.gait) * math.min(1, dt * G.settle)
			if want == 0 and rig.gait < 0.02 then rig.gait = 0 end
			rig.t += dt
		end
		if w.state == "hidden" then position -= Vector3.new(0, BugBodies.UNDER, 0) end
		local body = CFrame.lookAt(position, position + heading, Vector3.yAxis)
		for i, part in rig.parts do
			local spec = self.template[i]
			local move = moveOf(spec, rig, reduced == true)
			table.insert(parts, part)
			table.insert(frames, body * (if move ~= nil then move * spec.frame else spec.frame))
		end
	end
	for id, rig in self.rigs do
		if not present[id] then
			rig.folder:Destroy()
			self.rigs[id] = nil
		end
	end
	if #parts > 0 then Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
end

return BugBodies
