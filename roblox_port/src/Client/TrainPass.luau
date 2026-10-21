--!strict
-- The trains beyond the preserve's north fence, drawn (ROBLOX-115): a silhouette of cars that runs along the railway's track when World/PreserveTrain's timetable
-- says a train is passing, and its sound. Presentation only: nothing reads it, no ray sees it (drawn-only parts, as every look is), and it is this client's own.
-- The cars are made once (as many as the longest train) and moved each frame; a car is shown only while it lies wholly inside the line (PreserveTrain.cars), so
-- a train comes out of one covered way and goes into the other. Each car is a body, a band of windows (a commuter's; a freight car's is its doors' darker band;
-- the full tier only) and the underframe with its bogies. The sound is a looped rumble on the middle car, heard by distance (Roblox's roll-off); its recording
-- (assets/audio/train.wav) is not uploaded yet, so SOUND is "" and no voice is made until it is (docs/HANDOFF-roblox-world.md).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PreserveTrain = require(Shared:WaitForChild("World"):WaitForChild("PreserveTrain"))
local Materials = require(Shared:WaitForChild("Habitat"):WaitForChild("Materials"))

local TrainPass = {}
TrainPass.__index = TrainPass

-- The rumble's asset (assets/audio/train.wav once uploaded); "" makes no voice.
TrainPass.SOUND = "rbxassetid://127788334000523"
TrainPass.VOLUME = 0.5
-- The most cars a train has (PreserveTrain.CARS), so the most made.
TrainPass.MOST = math.max(PreserveTrain.CARS.commuter[2], PreserveTrain.CARS.freight[2])

local COLORS = {
	commuter = { body = "b9bdc1", band = "2b343c", under = "3a3b3c" },
	freight = { body = "7b4a36", band = "5e3a2b", under = "2f2f2f" },
}

local function part(parent: Instance, name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Material = Materials.get("Metal")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- `parent`: where the train's folder goes (the looks' WorldDecor folder); `seed`: the timetable's (WorldMap.seed(world seed, "train")); `tier`: "full" or "low".
function TrainPass.new(parent: Instance, seed: number, tier: string): any
	local folder = Instance.new("Folder")
	folder.Name = "Train"
	folder.Parent = parent
	local C = PreserveTrain.CAR
	local cars = {}
	for i = 1, TrainPass.MOST do
		local f = Instance.new("Folder")
		f.Name = "Car" .. i
		local body = part(f, "Body", Vector3.new(C.length, C.height - C.floor, C.width))
		local band = if tier == "low" then nil else part(f, "Band", Vector3.new(C.length - 60, 90, C.width + 2))
		local under = part(f, "Under", Vector3.new(C.length - 100, 70, C.width - 40))
		cars[i] = { folder = f, body = body, band = band, under = under, shown = false }
	end
	local sound: Sound? = nil
	if TrainPass.SOUND ~= "" then
		local s = Instance.new("Sound")
		s.Name = "Rumble"
		s.SoundId = TrainPass.SOUND
		s.Looped = true
		s.Volume = TrainPass.VOLUME
		s.RollOffMinDistance = 600
		s.RollOffMaxDistance = 9000
		sound = s
	end
	return setmetatable({ folder = folder, schedule = PreserveTrain.schedule(seed), cars = cars, sound = sound, pass = nil :: any, shownCount = 0, passes = 0 }, TrainPass)
end

-- Each frame (`now`: the client's clock, seconds): the cars where the timetable puts them, shown or hidden, and the sound on the middle car while a train passes.
-- Returns how many cars are shown.
function TrainPass.update(self: any, now: number): number
	local p = self.schedule.at(now)
	local mids: { number } = {}
	if p ~= nil then
		local _, list = PreserveTrain.cars(p, now)
		mids = list
		if self.pass ~= p then
			self.pass = p
			self.passes += 1
			local colors = COLORS[p.kind] or COLORS.commuter
			for _, car in self.cars do
				car.body.Color = Color3.fromHex(colors.body)
				if car.band ~= nil then car.band.Color = Color3.fromHex(colors.band) end
				car.under.Color = Color3.fromHex(colors.under)
			end
		end
	else
		self.pass = nil
	end
	local L, C = PreserveTrain.LINE, PreserveTrain.CAR
	local n = 0
	for i, car in self.cars do
		local x = mids[i]
		if x ~= nil then
			n += 1
			local y0 = L.y + C.floor
			car.body.CFrame = CFrame.new(x, y0 + (C.height - C.floor) / 2, L.z)
			if car.band ~= nil then car.band.CFrame = CFrame.new(x, y0 + 170, L.z) end
			car.under.CFrame = CFrame.new(x, L.y + 50, L.z)
			if not car.shown then car.folder.Parent = self.folder; car.shown = true end
		elseif car.shown then
			car.folder.Parent = nil
			car.shown = false
		end
	end
	local s = self.sound
	if s ~= nil then
		local middle = self.cars[math.max(1, math.ceil(n / 2))]
		if n > 0 then
			if s.Parent ~= middle.body then s.Parent = middle.body end
			if not s.IsPlaying then s:Play() end
		elseif s.IsPlaying then
			s:Stop()
		end
	end
	self.shownCount = n
	return n
end

-- The parts the train holds in the workspace now.
function TrainPass.parts(self: any): number
	local n = 0
	for _, car in self.cars do
		if car.shown then n += if car.band ~= nil then 3 else 2 end
	end
	return n
end

function TrainPass.destroy(self: any)
	for _, car in self.cars do car.folder:Destroy() end
	self.folder:Destroy()
end

return TrainPass
