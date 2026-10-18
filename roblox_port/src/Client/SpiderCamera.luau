--!strict
-- The spider's camera: a Roblox port of the frozen Godot rig, scripts/movement/camera_rig.gd (c87ce00).
-- A Scriptable camera, so Roblox's own orbit (which centres on the body and so aimed jumps at the spider's feet)
-- never runs. Pure math lives in Shared/Movement/CameraMath and LineFraming and is checked against Godot's values.
--
-- Orbit view: yaw/pitch only, never rolls (horizon-stable). The pivot stands PIVOT_HEIGHT along the spider's drawn up (so
-- on a wall it stands out from the wall, under an overhang it hangs below). The boom is a sphere cast from the pivot; a hit
-- retracts at once, recovery is rate limited. A squeezed boom searches steeper, then flatter pitches (auto-pitch). Close
-- in, the body is hidden so it never fills the screen. A cast that starts touching geometry counts as blocked (Godot's
-- cast_motion; Roblox's Spherecast would not see that part), so the camera is never placed inside the sill.
-- Line framing (LineFraming, A-017 with Chet's 45-degree cap): hanging on the safety line with the player's own view
-- squeezed where the spider will hang, the view turns by the smallest 15-degree step (at most 45) that sees the spider
-- and the lip; the player's look, a recenter or aiming takes the turn over at once and nothing jumps.
-- Aiming: the screen-centre ray picks the jump target. Vertical look then tilts the camera about its own position
-- (aim pitch) instead of orbiting, so the player can aim above the pivot; it eases back after.
-- Spider-eye view (V / Y): the camera sits just ahead of the principal eyes looking along a gaze the player turns; its up
-- follows the body's at most EYE_ROLL_DEG_S. Walking is relative to the gaze. Switching back snaps behind the spider.
-- The picture (field of view, colour, blur: ROBLOX-20) is Client/SpiderEyes'; it only sets the field of view and lookScale here.
-- The mating scene's two-shot (ROBLOX-89): `setShot` hands the camera the pair's framing (Life/MatingScene.shot: a point, a direction from it and a distance) each frame
-- of the scene; the view then eases into it over SHOT_EASE_SECONDS from wherever the orbit camera was, the player's own look is ignored while it holds, and when the
-- shot ends (setShot(nil)) it eases back out over the same time to the orbit camera, which has not moved. The boom is cast against the sill like the orbit's, so the
-- view is never inside geometry, and the body is never hidden by it.
-- Mouse: locked to the screen centre while playing (as the Godot game captures it); the Roblox menu frees it.
-- Placement order (Godot chunk 6B): no boom is trusted until the sill can be seen by queries; until then the camera sits
-- at the pivot with a boom of 0.

local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Movement = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Movement")
local CameraMath = require(Movement:WaitForChild("CameraMath"))
local SupportMath = require(Movement:WaitForChild("SupportMath"))
local LineFraming = require(Movement:WaitForChild("LineFraming"))

local SpiderCamera = {}
SpiderCamera.__index = SpiderCamera

local MIN_DISTANCE, MAX_DISTANCE = 2.0, 12.0
local TOUCH_DEG_PER_PIXEL = 0.25

export type Shot = { focus: Vector3, dir: Vector3, distance: number, up: Vector3 }
local SHOT_EASE_SECONDS = 0.8
SpiderCamera.SHOT_EASE_SECONDS = SHOT_EASE_SECONDS

export type Target = { pos: Vector3, drawnUp: Vector3, heading: Vector3, onLine: boolean?, rest: Vector3?, lip: Vector3?, cameraScale: number? }

function SpiderCamera.new(camera: Camera, params: RaycastParams, target: () -> Target, onEye: (boolean) -> ())
	local overlap = OverlapParams.new()
	overlap.FilterType = params.FilterType
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	local self = setmetatable({
		camera = camera,
		params = params,
		overlap = overlap,
		target = target,
		onEye = onEye,
		yaw = 0,
		elevation = math.rad(CameraMath.DEFAULT_ELEVATION_DEG),
		autoPitch = 0, autoPitchPrev = 0, settle = 0,
		aimPitch = 0,
		aiming = false,
		distance = CameraMath.CAMERA_DISTANCE,
  appearanceScale = 1,
		boom = 0, pivot = 0,
		pivotDir = Vector3.yAxis,
		recenterT = -1, recenterYaw0 = 0, recenterElev0 = 0, recenterGaze0 = Vector3.zero,
		eyeView = false,
		shot = nil :: Shot?, lastShot = nil :: Shot?, shotT = 0, -- the mating two-shot (ROBLOX-89): the shot now, the last one (to ease out of) and the ease, 0 to 1
		lookScale = 1, -- the eye view only: SpiderEyes sets it with the field of view, so a turn of the view moves the picture as fast at any zoom
		gaze = -Vector3.zAxis,
		gazeUp = Vector3.yAxis,
		bodyHidden = false,
		hide = nil :: ((boolean) -> ())?,
		framing = LineFraming.new(),
		wantedKey = "", wantedCache = 0,
		worldReady = false,
		mouse = true, -- false in tests: no mouse lock or mouse look (the Studio specs run on the server)
		-- The player's settings (ROBLOX-49; SpiderCamera.configure, called every frame): look speeds, inversion, the third person's field of
		-- view and distance, the framing switch and the spider-eye view's level horizon.
		mouseSens = 1, stickSens = 1, touchSens = 1, invertX = false, invertY = false,
		fov = CameraMath.FOV_DEG, settingDistance = CameraMath.CAMERA_DISTANCE, framingOn = true, levelHorizon = false, levelUp = Vector3.yAxis,
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

export type Settings = {
	mouse: number?, stick: number?, touch: number?, invertX: boolean?, invertY: boolean?,
	fov: number?, distance: number?, framing: boolean?, levelHorizon: boolean?,
}
-- Takes the player's settings (every field optional; call it each frame with what they are now). A changed distance starts the camera at it
-- (the wheel then zooms from there until the setting changes again); a changed field of view is shown at once, except in the eye view,
-- which keeps its own; the framing switch is passed on to the line framing when it changes.
function SpiderCamera.configure(self: any, c: Settings)
	if c.mouse ~= nil then self.mouseSens = c.mouse end
	if c.stick ~= nil then self.stickSens = c.stick end
	if c.touch ~= nil then self.touchSens = c.touch end
	if c.invertX ~= nil then self.invertX = c.invertX end
	if c.invertY ~= nil then self.invertY = c.invertY end
	if c.fov ~= nil and c.fov ~= self.fov then
		self.fov = c.fov
		if not self.eyeView then self.camera.FieldOfView = c.fov end
	end
	if c.distance ~= nil and c.distance ~= self.settingDistance then
		self.settingDistance = c.distance
		self.distance = math.clamp(c.distance, MIN_DISTANCE, MAX_DISTANCE)
	end
	if c.framing ~= nil and c.framing ~= self.framingOn then
		self.framingOn = c.framing
		self:setFraming(c.framing)
	end
	if c.levelHorizon ~= nil then self.levelHorizon = c.levelHorizon end
end

-- A look from the mouse, stick or touch in degrees, scaled by that device's speed and turned round by the inversion switches.
function SpiderCamera.lookScaled(self: any, dx: number, dy: number, speed: number)
	self:look(dx * speed * (if self.invertX then -1 else 1), dy * speed * (if self.invertY then -1 else 1))
end

-- The view's yaw: the player's own plus the line framing's turn. Walking steers by it, so the stick means what is on screen.
function SpiderCamera.viewYaw(self: any): number
	return self.yaw + self.framing.assist
end

-- True once the geometry the camera casts against has arrived (placement order).
function SpiderCamera._ready(self: any): boolean
	if not self.worldReady then
		for _, root in self.params.FilterDescendantsInstances do
			if root:FindFirstChildWhichIsA("BasePart", true) then
				self.worldReady = true
				break
			end
		end
	end
	return self.worldReady
end

-- Boom length clear of the sill from `from` along `motion`. A start touching geometry is blocked at once.
function SpiderCamera._cast(self: any, from: Vector3, motion: Vector3): number
	local length = motion.Magnitude
	if length < 1e-6 or not self:_ready() then return 0 end
	if #Workspace:GetPartBoundsInRadius(from, CameraMath.BOOM_RADIUS, self.overlap) > 0 then return 0 end
	local hit = Workspace:Spherecast(from, CameraMath.BOOM_RADIUS, motion, self.params)
	return if hit then math.max(0, hit.Distance - 0.01) else length
end

function SpiderCamera.viewDistance(self: any): number
 return self.distance * self.appearanceScale
end

function SpiderCamera._boomAt(self: any, from: Vector3, yaw: number, pitch: number): number
	return self:_cast(from, CameraMath.backDirection(yaw, pitch) * self:viewDistance())
end

-- camera_rig._pitch_search: the auto-pitch offset from the pivot `from` at this yaw, and the boom it gives.
function SpiderCamera._pitchSearch(self: any, from: Vector3, yaw: number): (number, number)
	local comfort = math.min(CameraMath.COMFORT_BOOM, self:viewDistance())
	local offsets, lengths = { 0 }, { self:_boomAt(from, yaw, self.elevation) }
	local step = math.rad(CameraMath.AUTO_PITCH_STEP_DEG)
	local roomDown = math.max(math.rad(CameraMath.MAX_ELEVATION_DEG) - self.elevation, 0)
	local roomUp = math.max(self.elevation - math.rad(CameraMath.MIN_AUTO_ELEVATION_DEG), 0)
	local offset = 0
	while lengths[#lengths] < comfort and offset < roomDown - 1e-6 do
		offset = math.min(offset + step, roomDown)
		table.insert(offsets, offset)
		table.insert(lengths, self:_boomAt(from, yaw, self.elevation + offset))
	end
	offset = 0
	while lengths[#lengths] < comfort and offset < roomUp - 1e-6 do
		offset = math.min(offset + step, roomUp)
		table.insert(offsets, -offset)
		table.insert(lengths, self:_boomAt(from, yaw, self.elevation - offset))
	end
	local picked = CameraMath.pickPitchOffset(offsets, lengths, comfort)
	local index = table.find(offsets, picked) or 1
	return picked, lengths[index]
end

-- True when nothing in the sill stands between the two points (camera_rig._sees).
function SpiderCamera._sees(self: any, a: Vector3, b: Vector3): boolean
	local d = b - a
	if d.Magnitude < 1e-6 then return true end
	local hit = Workspace:Raycast(a, d, self.params)
	return hit == nil or (hit.Position - a).Magnitude >= d.Magnitude - LineFraming.SIGHT_TOLERANCE
end

-- camera_rig._good_view: from the pivot `from`, at this yaw and the pitch the search picks, the boom is comfortable and
-- the camera sees both the spider where it will hang and the lip.
function SpiderCamera._goodView(self: any, from: Vector3, yaw: number, spot: Vector3, lip: Vector3): boolean
	local offset, length = self:_pitchSearch(from, yaw)
	if length < math.min(CameraMath.COMFORT_BOOM, self:viewDistance()) then return false end
	local camPos = from + CameraMath.backDirection(yaw, CameraMath.effectiveElevation(self.elevation, offset)) * length
	return self:_sees(camPos, spot) and self:_sees(camPos, lip)
end

-- The framing's wanted turn for the rest point and lip, recomputed only when they, the pivot or the player's view move.
function SpiderCamera._wantedTurn(self: any, t: Target): number
	local rest = t.rest or t.pos
	local lip = t.lip or rest
	local from = rest + self.pivotDir * self.pivot
	local function q(v: Vector3): string return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z) end
	local key = q(from) .. "|" .. q(lip) .. "|" .. string.format("%.4f,%.4f,%.2f,%.4f", self.yaw, self.elevation, self:viewDistance(), self.framing.target)
	if key ~= self.wantedKey then
		self.wantedKey = key
		self.wantedCache = LineFraming.wantedTurn(self.framing.target, self.framing.maxTurn, function(turn: number): boolean
			return self:_goodView(from, self.yaw + turn, rest, lip)
		end)
	end
	return self.wantedCache
end

function SpiderCamera._bodyForward(self: any): Vector3
	return self.target().heading
end

-- Puts the orbit camera behind the spider at once (spawn, reset, leaving the eye view). No framing turn survives it.
function SpiderCamera.snap(self: any)
	local t = self.target()
	self.yaw = CameraMath.recenterYaw(t.heading, t.drawnUp, self.yaw)
	self.elevation = math.rad(CameraMath.DEFAULT_ELEVATION_DEG)
	self.recenterT = -1
	self.framing:reset()
	self.wantedKey = ""
	self.pivotDir = t.drawnUp
	self.pivot = CameraMath.PIVOT_HEIGHT
	self.settle = 2
	self.boom = 0
	self:tick(0)
end

-- R / middle mouse / right-stick click: behind the spider over a quarter second. On the line it takes the framing's turn
-- over first (nothing jumps) and keeps the framing off until the line ends. Aiming wins over a recenter.
function SpiderCamera.startRecenter(self: any)
	if self.aiming then return end
	self.recenterT = 0
	if self.eyeView then
		self.recenterGaze0 = self.gaze
	else
		self.yaw += self.framing:playerTurns(self.target().onLine == true)
		self.recenterYaw0, self.recenterElev0 = self.yaw, self.elevation
	end
end

-- Aiming starts or ends (JumpInput). Starting takes the framing's turn over, so the view of the landing stays put.
function SpiderCamera.setAiming(self: any, on: boolean)
	self.aiming = on
	if on then
		self.yaw += self.framing:takeOver()
		self.recenterT = -1
	end
end

-- "Frame the line after a catch" (default on). Switched off with a turn held, the view stays where it is.
function SpiderCamera.setFraming(self: any, on: boolean)
	self.yaw += self.framing:setEnabled(on)
end

function SpiderCamera.setEyeView(self: any, on: boolean)
	if on == self.eyeView then return end
	self.eyeView = on
	self.recenterT = -1
	self.camera.FieldOfView = if on then CameraMath.EYE_FOV_DEG else self.fov
	if on then
		local t = self.target()
		self.yaw += self.framing:takeOver()
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

-- look(dx, dy) in degrees: dx > 0 looks right, dy > 0 looks down (Godot camera_rig.look). Any look takes the line
-- framing's turn over at once; on the line the framing then stays off until the line ends.
function SpiderCamera.look(self: any, dx: number, dy: number)
	if dx == 0 and dy == 0 then return end
	if self.shot ~= nil then return end -- (the mating scene's two-shot is not the player's to turn)
	if self.recenterT >= 0 and math.abs(dx) + math.abs(dy) > 1.5 then self.recenterT = -1 end
	if self.eyeView then
		-- The mouse, the stick and a touch drag all arrive here; lookScale (ROBLOX-20) shrinks them with the field of view.
		local scale = self.lookScale
		local turnUp: Vector3? = if self.levelHorizon then self.levelUp else nil
		self.gaze = CameraMath.lookEye(self.gaze, self.gazeUp, math.rad(dx * scale), math.rad(dy * scale), self:_bodyForward(), turnUp)
		return
	end
	self.yaw += self.framing:playerTurns(self.target().onLine == true)
	self.yaw -= math.rad(dx)
	if self.aiming then
		self.aimPitch = CameraMath.clampAimPitch(self.aimPitch - math.rad(dy), CameraMath.effectiveElevation(self.elevation, self.autoPitch))
	else
		self.elevation = math.clamp(self.elevation + math.rad(dy), math.rad(CameraMath.MIN_ELEVATION_DEG), math.rad(CameraMath.MAX_ELEVATION_DEG))
	end
end

function SpiderCamera.touchLook(self: any, delta: Vector2)
	self:lookScaled(delta.X * TOUCH_DEG_PER_PIXEL, delta.Y * TOUCH_DEG_PER_PIXEL, self.touchSens)
end

-- One fixed 60 Hz tick: pivot, line framing, auto-pitch and boom (orbit), or the gaze carried with the body (eye view).
function SpiderCamera.tick(self: any, dt: number)
 local wantedScale = math.clamp(self.target().cameraScale or 1,0.5,1.5)
 self.appearanceScale += (wantedScale-self.appearanceScale)*(1-math.exp(-4*dt))
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
	if dt > 0 then
		self.yaw += self.framing:tick(t.onLine == true, self.aiming, function(): number return self:_wantedTurn(t) end, dt)
	end
	local yaw = self:viewYaw()
	local wanted = self:_pitchSearch(from, yaw)
	if self.settle > 0 then
		self.settle -= 1
		self.autoPitch = wanted
	else
		self.autoPitch = CameraMath.easeOffset(self.autoPitch, wanted, dt, CameraMath.AUTO_PITCH_IN_SECONDS, CameraMath.AUTO_PITCH_OUT_SECONDS)
	end
	local elev = CameraMath.effectiveElevation(self.elevation, self.autoPitch)
	self.boom = CameraMath.nextLength(self.boom, self:_boomAt(from, yaw, elev), self:viewDistance(), CameraMath.RECOVER_SPEED, if self.settle > 0 then 1 else dt)
end

local function smooth(k: number): number
	return k * k * (3 - 2 * k)
end

-- Every rendered frame: the player's look, recentring and the aim's return, then the camera is placed.
function SpiderCamera.render(self: any, frameDt: number, lookX: number, lookY: number)
	if self.mouse then
		local menu = GuiService.MenuIsOpen
		UIS.MouseBehavior = if menu then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
		UIS.MouseIconEnabled = menu
		if not menu then
			local m = UIS:GetMouseDelta()
			self:lookScaled(m.X * CameraMath.MOUSE_DEG_PER_PIXEL, m.Y * CameraMath.MOUSE_DEG_PER_PIXEL, self.mouseSens)
		end
	end
	local rate = CameraMath.STICK_DEG_PER_SECOND * frameDt
	self:lookScaled(lookX * rate, lookY * rate, self.stickSens)
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
		local viewUp = self.gazeUp
		if self.levelHorizon then
			viewUp = CameraMath.viewUp(self.gaze, self.gazeUp, self.levelUp)
		end
		self.levelUp = viewUp
		self.camera.CFrame = CFrame.lookAt(eye, eye + self.gaze, viewUp)
		self:_hideBody(true)
		return
	end
	if not self.aiming and self.aimPitch ~= 0 then
		self.aimPitch = CameraMath.easeOffset(self.aimPitch, 0, frameDt, CameraMath.AIM_RETURN_SECONDS, CameraMath.AIM_RETURN_SECONDS)
	end
	local yaw = self:viewYaw()
	local elev = CameraMath.effectiveElevation(self.elevation, self.autoPitch)
	local from = t.pos + self.pivotDir * self.pivot
	-- A flick between ticks: cast again along the direction about to be used; only shortening is taken.
	local length = math.min(self.boom, self:_boomAt(from, yaw, elev))
	self.boom = length
	local orbit = CFrame.new(from) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-elev, 0, 0)
	self.camera.CFrame = orbit * CFrame.new(0, 0, length) * CFrame.Angles(CameraMath.clampAimPitch(self.aimPitch, elev), 0, 0)
	self:_hideBody(length < CameraMath.BODY_HIDE_LENGTH)
	self:_applyShot(frameDt)
end

-- The mating scene's two-shot (ROBLOX-89): `shot` is the framing for this frame, or nil when the scene is not playing.
function SpiderCamera.setShot(self: any, shot: Shot?)
	self.shot = shot
	if shot ~= nil then self.lastShot = shot end
end

-- Whether the two-shot has any hold on the view now (easing in, held or easing out).
function SpiderCamera.shotActive(self: any): boolean
	return self.shot ~= nil or self.shotT > 0
end

-- After the orbit camera is placed: ease toward (or away from) the two-shot and put the camera between them by the ease.
function SpiderCamera._applyShot(self: any, frameDt: number)
	local step = frameDt / SHOT_EASE_SECONDS
	local want = if self.shot ~= nil then 1 else 0
	self.shotT = math.clamp(self.shotT + math.clamp(want - self.shotT, -step, step), 0, 1)
	local s: Shot? = self.shot or self.lastShot
	if self.shotT <= 0 or s == nil then
		if self.shot == nil then self.lastShot = nil end
		return
	end
	local boom = math.max(self:_cast(s.focus, s.dir * s.distance), 0.9)
	local there = s.focus + s.dir * math.min(boom, s.distance)
	local k = smooth(self.shotT)
	local here: CFrame = self.camera.CFrame
	local pos = here.Position:Lerp(there, k)
	local look = here.LookVector:Lerp((s.focus - there).Unit, k)
	if look.Magnitude < 1e-4 then look = (s.focus - there).Unit end
	local up = here.UpVector:Lerp(s.up, k)
	if up.Magnitude < 1e-4 then up = s.up end
	self.camera.CFrame = CFrame.lookAt(pos, pos + look.Unit, up.Unit)
	self:_hideBody(false)
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

-- Walking intent for a stick (x right, y forward) on a surface with normal n, relative to the view on screen.
function SpiderCamera.mapStick(self: any, x: number, y: number, n: Vector3): Vector3
	if self.eyeView then
		return CameraMath.mapStickEye(x, y, self.gaze, self:_bodyForward(), n)
	end
	return CameraMath.mapStick(x, y, self:viewYaw(), CameraMath.effectiveElevation(self.elevation, self.autoPitch), n)
end

return SpiderCamera
