--!strict
-- The spider's camera: a Roblox port of the frozen Godot rig, scripts/movement/camera_rig.gd (c87ce00).
-- A Scriptable camera, so Roblox's own orbit (which centres on the body and so aimed jumps at the spider's feet)
-- never runs. Pure math lives in Shared/Movement/CameraMath and is checked against Godot's values.
--
-- Orbit view: yaw/pitch only, never rolls. The pivot stands PIVOT_HEIGHT along the spider's drawn up (so on a wall it
-- stands out from the wall, under an overhang it hangs below). The boom is a sphere cast from the pivot; a hit retracts at
-- once, recovery is rate limited. A squeezed boom searches steeper, then flatter pitches (auto-pitch). Close in, the body
-- is hidden so it never fills the screen.
-- Aiming: the screen-centre ray picks the jump target. Vertical look then tilts the camera about its own position
-- (aim pitch) instead of orbiting, so the player can aim above the pivot; it eases back after.
-- Spider-eye view (V / Y): the camera sits just ahead of the principal eyes looking along a gaze the player turns; its up
-- follows the body's at most EYE_ROLL_DEG_S. Walking is relative to the gaze. Switching back snaps behind the spider.
-- Mouse: locked to the screen centre while playing (as the Godot game captures it); the Roblox menu frees it.

local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CameraMath = require(game:GetService("ReplicatedStorage").Shared.Movement.CameraMath)
local SupportMath = require(game:GetService("ReplicatedStorage").Shared.Movement.SupportMath)

local SpiderCamera = {}
SpiderCamera.__index = SpiderCamera

local MIN_DISTANCE, MAX_DISTANCE = 2.0, 12.0
local TOUCH_DEG_PER_PIXEL = 0.25

export type Target = { pos: Vector3, drawnUp: Vector3, heading: Vector3 }

function SpiderCamera.new(camera: Camera, params: RaycastParams, target: () -> Target, onEye: (boolean) -> ())
	local self = setmetatable({
		camera = camera,
		params = params,
		target = target,
		onEye = onEye,
		yaw = 0,
		elevation = math.rad(CameraMath.DEFAULT_ELEVATION_DEG),
		autoPitch = 0, autoPitchPrev = 0, settle = 0,
		aimPitch = 0,
		aiming = false,
		distance = CameraMath.CAMERA_DISTANCE,
		boom = 0, pivot = 0,
		pivotDir = Vector3.yAxis,
		recenterT = -1, recenterYaw0 = 0, recenterElev0 = 0, recenterGaze0 = Vector3.zero,
		eyeView = false,
		gaze = -Vector3.zAxis,
		gazeUp = Vector3.yAxis,
		bodyHidden = false,
		hide = nil :: ((boolean) -> ())?,
	}, SpiderCamera)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CameraMath.FOV_DEG
	UIS.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed and not self.eyeView then
			self.distance = math.clamp(self.distance * (if input.Position.Z > 0 then 0.88 else 1 / 0.88), MIN_DISTANCE, MAX_DISTANCE)
		end
	end)
	self:snap()
	return self
end

-- Boom length clear of the sill from `from` along `motion`.
function SpiderCamera._cast(self: any, from: Vector3, motion: Vector3): number
	local length = motion.Magnitude
	if length < 1e-6 then return 0 end
	local hit = Workspace:Spherecast(from, CameraMath.BOOM_RADIUS, motion, self.params)
	return if hit then math.max(0, hit.Distance - 0.01) else length
end

function SpiderCamera._boomAt(self: any, from: Vector3, yaw: number, pitch: number): number
	return self:_cast(from, CameraMath.backDirection(yaw, pitch) * self.distance)
end

function SpiderCamera._pitchSearch(self: any, from: Vector3): number
	local comfort = math.min(CameraMath.COMFORT_BOOM, self.distance)
	local offsets, lengths = { 0 }, { self:_boomAt(from, self.yaw, self.elevation) }
	local step = math.rad(CameraMath.AUTO_PITCH_STEP_DEG)
	local roomDown = math.max(math.rad(CameraMath.MAX_ELEVATION_DEG) - self.elevation, 0)
	local roomUp = math.max(self.elevation - math.rad(CameraMath.MIN_AUTO_ELEVATION_DEG), 0)
	local offset = 0
	while lengths[#lengths] < comfort and offset < roomDown - 1e-6 do
		offset = math.min(offset + step, roomDown)
		table.insert(offsets, offset)
		table.insert(lengths, self:_boomAt(from, self.yaw, self.elevation + offset))
	end
	offset = 0
	while lengths[#lengths] < comfort and offset < roomUp - 1e-6 do
		offset = math.min(offset + step, roomUp)
		table.insert(offsets, -offset)
		table.insert(lengths, self:_boomAt(from, self.yaw, self.elevation - offset))
	end
	return CameraMath.pickPitchOffset(offsets, lengths, comfort)
end

function SpiderCamera._bodyForward(self: any): Vector3
	return self.target().heading
end

-- Puts the orbit camera behind the spider at once (spawn, reset, leaving the eye view).
function SpiderCamera.snap(self: any)
	local t = self.target()
	self.yaw = CameraMath.recenterYaw(t.heading, t.drawnUp, self.yaw)
	self.elevation = math.rad(CameraMath.DEFAULT_ELEVATION_DEG)
	self.recenterT = -1
	self.pivotDir = t.drawnUp
	self.pivot = CameraMath.PIVOT_HEIGHT
	self.settle = 2
	self.boom = 0
	self:tick(0)
end

function SpiderCamera.startRecenter(self: any)
	if self.aiming then return end
	self.recenterT = 0
	if self.eyeView then
		self.recenterGaze0 = self.gaze
	else
		self.recenterYaw0, self.recenterElev0 = self.yaw, self.elevation
	end
end

function SpiderCamera.setAiming(self: any, on: boolean)
	self.aiming = on
	if on then self.recenterT = -1 end
end

function SpiderCamera.setEyeView(self: any, on: boolean)
	if on == self.eyeView then return end
	self.eyeView = on
	self.recenterT = -1
	self.camera.FieldOfView = if on then CameraMath.EYE_FOV_DEG else CameraMath.FOV_DEG
	if on then
		local t = self.target()
		self.aimPitch = 0
		self.gazeUp = t.drawnUp
		self.gaze = CameraMath.clampGaze(t.heading, self.gazeUp, t.heading)
	else
		self:snap()
	end
	self.onEye(on)
end

function SpiderCamera.toggleEyeView(self: any)
	self:setEyeView(not self.eyeView)
end

-- look(dx, dy) in degrees: dx > 0 looks right, dy > 0 looks down (Godot camera_rig.look).
function SpiderCamera.look(self: any, dx: number, dy: number)
	if dx == 0 and dy == 0 then return end
	if self.recenterT >= 0 and math.abs(dx) + math.abs(dy) > 1.5 then self.recenterT = -1 end
	if self.eyeView then
		self.gaze = CameraMath.lookEye(self.gaze, self.gazeUp, math.rad(dx), math.rad(dy), self:_bodyForward())
		return
	end
	self.yaw -= math.rad(dx)
	if self.aiming then
		self.aimPitch = CameraMath.clampAimPitch(self.aimPitch - math.rad(dy), CameraMath.effectiveElevation(self.elevation, self.autoPitch))
	else
		self.elevation = math.clamp(self.elevation + math.rad(dy), math.rad(CameraMath.MIN_ELEVATION_DEG), math.rad(CameraMath.MAX_ELEVATION_DEG))
	end
end

function SpiderCamera.touchLook(self: any, delta: Vector2)
	self:look(delta.X * TOUCH_DEG_PER_PIXEL, delta.Y * TOUCH_DEG_PER_PIXEL)
end

-- One fixed 60 Hz tick: pivot, auto-pitch and boom (orbit), or the gaze carried with the body (eye view).
function SpiderCamera.tick(self: any, dt: number)
	local t = self.target()
	if self.eyeView then
		local up = SupportMath.rotateToward(self.gazeUp, t.drawnUp, math.rad(CameraMath.EYE_ROLL_DEG_S) * dt)
		if SupportMath.angleTo(up, self.gazeUp) > 1e-6 then
			local axis = self.gazeUp:Cross(up)
			if axis.Magnitude > 1e-9 then
				self.gaze = CameraMath.rotate(self.gaze, axis.Unit, SupportMath.angleTo(self.gazeUp, up))
			end
		end
		self.gazeUp = up
		self.gaze = CameraMath.clampGaze(self.gaze, up, t.heading)
		return
	end
	self.pivotDir = t.drawnUp
	self.pivot = CameraMath.nextLength(self.pivot, self:_cast(t.pos, self.pivotDir * CameraMath.PIVOT_HEIGHT), CameraMath.PIVOT_HEIGHT, CameraMath.RECOVER_SPEED, dt)
	local from = t.pos + self.pivotDir * self.pivot
	local wanted = self:_pitchSearch(from)
	if self.settle > 0 then
		self.settle -= 1
		self.autoPitch = wanted
	else
		self.autoPitch = CameraMath.easeOffset(self.autoPitch, wanted, dt, CameraMath.AUTO_PITCH_IN_SECONDS, CameraMath.AUTO_PITCH_OUT_SECONDS)
	end
	local elev = CameraMath.effectiveElevation(self.elevation, self.autoPitch)
	self.boom = CameraMath.nextLength(self.boom, self:_boomAt(from, self.yaw, elev), self.distance, CameraMath.RECOVER_SPEED, if self.settle > 0 then 1 else dt)
end

local function smooth(k: number): number
	return k * k * (3 - 2 * k)
end

-- Every rendered frame: the player's look, recentring and the aim's return, then the camera is placed.
function SpiderCamera.render(self: any, frameDt: number, lookX: number, lookY: number)
	local menu = GuiService.MenuIsOpen
	UIS.MouseBehavior = if menu then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	UIS.MouseIconEnabled = menu
	if not menu then
		local m = UIS:GetMouseDelta()
		self:look(m.X * CameraMath.MOUSE_DEG_PER_PIXEL, m.Y * CameraMath.MOUSE_DEG_PER_PIXEL)
	end
	local rate = CameraMath.STICK_DEG_PER_SECOND * frameDt
	self:look(lookX * rate, lookY * rate)
	local t = self.target()
	if self.recenterT >= 0 then
		self.recenterT += frameDt
		local k = smooth(math.clamp(self.recenterT / CameraMath.RECENTER_SECONDS, 0, 1))
		if self.eyeView then
			self.gaze = CameraMath.clampGaze(self.recenterGaze0:Lerp(t.heading, k), self.gazeUp, t.heading)
		else
			local goal = CameraMath.recenterYaw(t.heading, t.drawnUp, self.yaw)
			local d = (goal - self.recenterYaw0 + math.pi) % (2 * math.pi) - math.pi
			self.yaw = self.recenterYaw0 + d * k
			self.elevation = self.recenterElev0 + (math.rad(CameraMath.DEFAULT_ELEVATION_DEG) - self.recenterElev0) * k
		end
		if k >= 1 then self.recenterT = -1 end
	end
	if self.eyeView then
		local body = SupportMath.bodyCFrame(t.pos, self.gazeUp, t.heading)
		local eye = body:PointToWorldSpace(Vector3.new(0, CameraMath.EYE_HEIGHT, -CameraMath.EYE_AHEAD))
		self.camera.CFrame = CFrame.lookAt(eye, eye + self.gaze, self.gazeUp)
		self:_hideBody(true)
		return
	end
	if not self.aiming and self.aimPitch ~= 0 then
		self.aimPitch = CameraMath.easeOffset(self.aimPitch, 0, frameDt, CameraMath.AIM_RETURN_SECONDS, CameraMath.AIM_RETURN_SECONDS)
	end
	local elev = CameraMath.effectiveElevation(self.elevation, self.autoPitch)
	local from = t.pos + self.pivotDir * self.pivot
	-- A flick between ticks: cast again along the direction about to be used; only shortening is taken.
	local length = math.min(self.boom, self:_boomAt(from, self.yaw, elev))
	self.boom = length
	local orbit = CFrame.new(from) * CFrame.Angles(0, self.yaw, 0) * CFrame.Angles(-elev, 0, 0)
	self.camera.CFrame = orbit * CFrame.new(0, 0, length) * CFrame.Angles(CameraMath.clampAimPitch(self.aimPitch, elev), 0, 0)
	self:_hideBody(length < CameraMath.BODY_HIDE_LENGTH)
end

function SpiderCamera._hideBody(self: any, hidden: boolean)
	if hidden ~= self.bodyHidden then
		self.bodyHidden = hidden
		if self.hide then (self.hide :: (boolean) -> ())(hidden) end
	end
end

-- The aim ray: the camera's centre ray.
function SpiderCamera.aimRay(self: any): (Vector3, Vector3)
	local cf = self.camera.CFrame
	return cf.Position, cf.LookVector
end

-- Walking intent for a stick (x right, y forward) on a surface with normal n.
function SpiderCamera.mapStick(self: any, x: number, y: number, n: Vector3): Vector3
	if self.eyeView then
		return CameraMath.mapStickEye(x, y, self.gaze, self:_bodyForward(), n)
	end
	return CameraMath.mapStick(x, y, self.yaw, CameraMath.effectiveElevation(self.elevation, self.autoPitch), n)
end

return SpiderCamera
