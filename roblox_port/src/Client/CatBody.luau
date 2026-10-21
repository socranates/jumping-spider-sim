--!strict
-- The ranger's cat in the world (ROBLOX-118): Rig/CatPose's parts, built once and moved each frame from Predator/Cat (where it is, which way it faces, what it is
-- doing, what it looks at, where its pat goes). Every part is anchored, never collides, is never seen by a ray (a spider walks through a cat's drawing, never on
-- it; the cat is not ground), and the biggest cast shadows. One Workspace:BulkMoveTo places all its parts each frame. At the low tier the full tier's parts
-- (the stripes, the whiskers, the inner ears, the bib) are not made. Display only: nothing here feeds back to the sim. Its voices, the bell and the purr, are
-- Client/CatBody's too (SOUNDS: empty until the recordings are uploaded, tools/make_cat_sounds.py; then the bell rings while it moves and the purr while it
-- settles, each as loud as Predator/Cat.sound says for the spider's ears).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatPose = require(Shared:WaitForChild("Rig"):WaitForChild("CatPose"))
local Shapes = require(Shared:WaitForChild("Habitat"):WaitForChild("Shapes"))

local CatBody = {}
CatBody.__index = CatBody

-- The recordings (assets/audio/cat_bell.wav, assets/audio/cat_purr.wav from tools/make_cat_sounds.py): "" until Nathan uploads them; no voice is made for an empty id.
CatBody.SOUNDS = { bell = "rbxassetid://78706177142395", purr = "rbxassetid://81495950754571" } :: { [string]: string }
CatBody.SHADOW = 6 -- parts at least this wide cast a shadow

function CatBody.new(parent: Instance, detail: string): any
	local folder = Instance.new("Folder")
	folder.Name = "Cat"
	local parts: { BasePart? } = {}
	local first = CatPose.parts({ pose = "sleep", t = 0 })
	for i, spec in first do
		if spec.full and detail == "low" then
			parts[i] = nil
			continue
		end
		local part: Part
		if spec.kind == "cylinder" then
			part = Shapes.block(folder, spec.name, spec.size, CFrame.new(), Color3.fromHex(spec.color), "Fabric")
			part.Shape = Enum.PartType.Cylinder
		elseif spec.kind == "ball" then
			part = Shapes.block(folder, spec.name, spec.size, CFrame.new(), Color3.fromHex(spec.color), "SmoothPlastic")
			part.Shape = Enum.PartType.Ball
		else
			part = Shapes.ellipsoid(folder, spec.name, spec.size, CFrame.new(), Color3.fromHex(spec.color), "Fabric")
		end
		if string.sub(spec.name, 1, 3) == "Eye" then part.Material = Enum.Material.Glass; part.Reflectance = 0.15 end
		if spec.name == "Bell" then part.Material = Enum.Material.Metal; part.Reflectance = 0.3 end
		part.CastShadow = math.max(spec.size.X, spec.size.Y, spec.size.Z) >= CatBody.SHADOW
		parts[i] = part
	end
	folder.Parent = parent
	local self = setmetatable({
		folder = folder, parts = parts, moved = {} :: { BasePart }, world = {} :: { CFrame }, last = nil :: Vector3?, speed = 0, voices = {} :: { [string]: Sound },
	}, CatBody)
	for name, id in CatBody.SOUNDS do
		if id ~= "" then
			local s = Instance.new("Sound")
			s.Name = name
			s.SoundId = id
			s.Looped = true
			s.Volume = 0
			s.RollOffMinDistance = 20
			s.RollOffMaxDistance = 600
			s.Parent = folder
			self.voices[name] = s
		end
	end
	return self
end

-- The state CatPose draws, from the sim's cat (Predator/Cat) at `now` (seconds), its body's frame, and the gait's speed from how far it went.
function CatBody.state(self: any, cat: any, now: number, dt: number): (CatPose.State, CFrame)
	local frame = CatPose.frame(cat.pos, cat.heading)
	if self.last ~= nil and dt > 0 then
		local d = Vector3.new(cat.pos.X - self.last.X, 0, cat.pos.Z - self.last.Z).Magnitude / dt
		self.speed = self.speed + (math.min(d, 120) - self.speed) * math.clamp(dt * 8, 0, 1)
	end
	self.last = cat.pos
	local state: CatPose.State = {
		pose = cat.pose, t = now, speed = math.max(self.speed, if cat.pose == "walk" then 40 else 0),
		look = if cat.look ~= nil then frame:PointToObjectSpace(cat.look) else nil,
		paw = if cat.pawAt ~= nil then frame:PointToObjectSpace(cat.pawAt) else nil,
		swat = if cat.pose == "swat" then math.clamp(cat.reactS / 0.25, 0, 1) else nil,
		seated = cat.spot == "window" or cat.surface > -60,
	}
	return state, frame
end

-- Draws it as the sim has it; `bell` and `purr` are how loud each is for the spider's ears (Predator/Cat.sound).
function CatBody.draw(self: any, cat: any, now: number, dt: number, bell: number?, purr: number?)
	local state, frame = self:state(cat, now, dt)
	local list = CatPose.parts(state)
	local moved, world = self.moved, self.world
	table.clear(moved)
	table.clear(world)
	for i, spec in list do
		local part = self.parts[i]
		if part ~= nil then
			if part.Size ~= spec.size then part.Size = spec.size end
			table.insert(moved, part)
			table.insert(world, frame * spec.cf)
		end
	end
	Workspace:BulkMoveTo(moved, world, Enum.BulkMoveMode.FireCFrameChanged)
	for name, s in self.voices do
		local level = if name == "bell" then bell or 0 else purr or 0
		s.Volume = level * (if name == "bell" then 0.5 else 0.35)
		if level > 0 and not s.IsPlaying then s:Play() elseif level <= 0 and s.IsPlaying then s:Stop() end
	end
end

function CatBody.destroy(self: any)
	self.folder:Destroy()
end

return CatBody
