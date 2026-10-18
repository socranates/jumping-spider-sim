--!strict
-- Living motion for the drawn spider (ROBLOX-87): the small things an animal does when it is not being asked to do anything. Display only, full
-- detail only (the rig makes one only when its detail tier has `idle`), never fed back into movement, the camera, the collider, the senses or the
-- simulation's clock. Pure numbers, stepped by SpiderRig with the frame's time, so tests/idle.luau steps it on its own: no Roblox types.
--
-- What it keeps: (1) ATTENTION: a yaw offset of the whole drawn body toward what the player is watching, at most `attention.maxDeg`, eased over
-- `attention.easeSeconds` and back to nothing while the spider walks, and a glance of the principal eyes toward the same point; (2) GROOMING: after
-- `groom.after` seconds of standing, a bout every `groom.gap` seconds from a seeded stream (a palp drawn through the jaws, or a leg I pulled forward and
-- wiped by the palps), and after a meal (the "groom" cue) a longer cleaning (both palps, then legs I and II); (3) ALARM: the "alarm" cue (the wasp's warning, the
-- rival's windup) raises legs I and freezes the idle motion for `alarm.seconds`; (4) a tarantula's STRETCH: with `stretch`, every `stretch.gap` seconds one
-- leg reaches out and settles again over `stretch.seconds`, and it never grooms. Breathing is in Rig/Idle (the abdomen's scale) and SpiderRig.
-- Reduced Motion is none of it. Every number is in the appearance's `idle` table (`groom`, `attention`, `alarm`, `stretch`) and is ART, not measured.

local Living = {}
Living.__index = Living

-- One leg's override: `w` is how far it is drawn there (0..1). `rel` says (x, y, z) is an offset from where the foot is (a stretch), else a place in the
-- body frame in studs (x mirrored for the left leg). `kneeOut` and `kneeUp` bend the knee out and up.
export type LegPose = { w: number, rel: boolean, x: number, y: number, z: number, kneeOut: number, kneeUp: number }
export type Pose = {
	yaw: number, -- radians, the drawn body's extra turn (positive turns toward -X: the body frame's +Y axis)
	glanceX: number, glanceY: number, -- -1..1: where the principal eyes look, across and up
	palpYaw: { number }, palpPitch: { number }, -- the palps' extra turn (toward the jaws) and pitch, radians, palp 1 (left) and palp 2 (right)
	legs: { LegPose }, -- by leg: 1..4 the left legs I to IV, 5..8 the right
	freeze: number, -- 0..1: an alarm: the idle motion stands still
	bout: string?, -- the bout now ("palp", "leg", "meal", "stretch"), or nil
	act: string?, -- the act of the bout now (tests)
}
type Act = { kind: string, start: number, dur: number, index: number }
type Bout = { kind: string, t: number, total: number, acts: { Act }, abort: boolean }
export type State = {
	cfg: any,
	t: number, standS: number, wait: number, weight: number,
	yaw: number, glanceX: number, glanceY: number,
	bout: Bout?, pendingMeal: number?, alarmT: number?,
	rng: number,
	pose: Pose,
	log: { { t: number, kind: string } }, -- the bouts begun (tests; kept to the last 64)
}

local TAU = math.pi * 2

function Living.hash(text: string): number
	local h = 5381
	for i = 1, #text do h = (h * 33 + string.byte(text, i)) % 4294967296 end
	return h
end

local function unit(self: State): number -- a seeded stream: a linear congruential generator, not a measured anything
	self.rng = (self.rng * 1664525 + 1013904223) % 4294967296
	return self.rng / 4294967296
end
local function range(self: State, r: { number }): number return r[1] + (r[2] - r[1]) * unit(self) end

local function smooth(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

function Living.new(cfg: any, seed: number): State
	local legs: { LegPose } = {}
	for i = 1, 8 do legs[i] = { w = 0, rel = false, x = 0, y = 0, z = 0, kneeOut = 0, kneeUp = 0 } end
	local self: State = {
		cfg = cfg, t = 0, standS = 0, wait = 0, weight = 0, yaw = 0, glanceX = 0, glanceY = 0,
		bout = nil, pendingMeal = nil, alarmT = nil, rng = seed % 4294967296,
		pose = { yaw = 0, glanceX = 0, glanceY = 0, palpYaw = { 0, 0 }, palpPitch = { 0, 0 }, legs = legs, freeze = 0, bout = nil, act = nil },
		log = {},
	}
	unit(self) -- (the first draws of a small seed are close together)
	unit(self)
	local first = if cfg.groom then cfg.groom.firstWait elseif cfg.stretch then cfg.stretch.firstWait else { 1, 2 }
	self.wait = range(self, first)
	return self
end

-- The cue from the host: "groom" (a meal has ended: a longer cleaning, once it stands still) or "alarm" (a warning: raise legs I and freeze).
function Living.cue(self: State, name: string)
	if name == "groom" and self.cfg.groom then
		self.pendingMeal = 30
	elseif name == "alarm" and self.cfg.alarm then
		self.alarmT = 0
	end
end

local function acts(self: State, kind: string): ({ Act }, number)
	local g, out, at = self.cfg.groom, {} :: { Act }, 0
	local function add(k: string, dur: number, index: number)
		table.insert(out, { kind = k, start = at, dur = dur, index = index })
		at += dur
	end
	if kind == "palp" then
		add("palp", g.palpSeconds, 1 + math.floor(unit(self) * 2))
	elseif kind == "leg" then
		add("leg", g.legSeconds, if unit(self) < 0.5 then 1 else 5)
	elseif kind == "meal" then
		add("palps", g.mealPalpSeconds, 0)
		for _, index in { 1, 5, 2, 6 } do add("leg", g.legSeconds, index) end -- both legs I, then both legs II
	elseif kind == "stretch" then
		add("stretch", self.cfg.stretch.seconds, 1 + math.floor(unit(self) * 8))
	end
	return out, at
end

local function begin(self: State, kind: string)
	local list, total = acts(self, kind)
	self.bout = { kind = kind, t = 0, total = total, acts = list, abort = false }
	table.insert(self.log, { t = self.t, kind = kind })
	if #self.log > 64 then table.remove(self.log, 1) end
end

local function clearPose(pose: Pose)
	pose.yaw, pose.glanceX, pose.glanceY, pose.freeze, pose.bout, pose.act = 0, 0, 0, 0, nil, nil
	pose.palpYaw[1], pose.palpYaw[2], pose.palpPitch[1], pose.palpPitch[2] = 0, 0, 0, 0
	for _, leg in pose.legs do leg.w = 0 end
end

local function setLeg(pose: Pose, index: number, w: number, spec: any, rel: boolean)
	local leg = pose.legs[index]
	leg.w, leg.rel, leg.x, leg.y, leg.z = w, rel, spec.x, spec.y, spec.z
	leg.kneeOut, leg.kneeUp = spec.kneeOut or 0, spec.kneeUp or 0
end

-- One step. standing: still on a surface with nothing else drawn on the body; reduced: Reduced Motion; focusYaw and focusPitch (radians) are where the
-- watched point is from the drawn body's heading (nil when nothing is watched); alarmLegs: the legs may be drawn raised (nothing else has them).
function Living.step(self: State, dt: number, standing: boolean, reduced: boolean, focusYaw: number?, focusPitch: number?, alarmLegs: boolean): Pose
	local cfg, pose = self.cfg, self.pose
	clearPose(pose)
	if reduced then -- no motion at all: whatever was under way is gone
		self.bout, self.weight, self.alarmT, self.yaw, self.glanceX, self.glanceY, self.pendingMeal, self.standS = nil, 0, nil, 0, 0, 0, nil, 0
		return pose
	end
	self.t += dt
	self.standS = if standing then self.standS + dt else 0

	-- attention: the body's turn toward the watched point (only while it stands), the eyes' glance toward it (always)
	local att = cfg.attention
	if att then
		local ease = 1 - math.exp(-dt / (att.easeSeconds / 3))
		local want = if standing and focusYaw ~= nil then math.clamp(focusYaw, -math.rad(att.maxDeg), math.rad(att.maxDeg)) else 0
		self.yaw += (want - self.yaw) * ease
		local span = math.rad(att.glanceSpanDeg)
		local gx = if focusYaw ~= nil then math.clamp(-(focusYaw - self.yaw) / span, -1, 1) else 0
		local gy = if focusPitch ~= nil and focusYaw ~= nil then math.clamp(focusPitch / span, -1, 1) else 0
		self.glanceX += (gx - self.glanceX) * ease
		self.glanceY += (gy - self.glanceY) * ease
		pose.yaw, pose.glanceX, pose.glanceY = self.yaw, self.glanceX, self.glanceY
	end

	-- alarm: legs I up and everything else still
	local alarm = cfg.alarm
	local alarming = false
	if self.alarmT ~= nil and alarm then
		local t = self.alarmT + dt
		self.alarmT = if t >= alarm.seconds then nil else t
		local env = smooth(math.min(t / alarm.riseSeconds, (alarm.seconds - t) / alarm.fallSeconds, 1))
		if env > 0 then
			alarming = true
			pose.freeze = env
			if alarmLegs then
				setLeg(pose, 1, env, alarm.raise, false)
				setLeg(pose, 5, env, alarm.raise, false)
			end
		end
	end

	-- bouts
	local groom = cfg.groom
	local bout = self.bout
	if bout ~= nil then
		if not standing or alarming then bout.abort = true end
		if bout.abort then
			self.weight -= dt / (if groom then groom.abortSeconds else 0.25)
			if self.weight <= 0 then
				self.bout, self.weight = nil, 0
				self.wait = range(self, if groom then groom.gap else cfg.stretch.gap) -- (a bout that was cut short is not begun again at once)
			end
		else
			self.weight = math.min(1, self.weight + dt / 0.2)
			bout.t += dt
			if bout.t >= bout.total then
				self.bout, self.weight = nil, 0
				self.wait = range(self, if groom then groom.gap else cfg.stretch.gap)
			end
		end
	end
	if self.bout == nil and standing and not alarming then
		local pending = self.pendingMeal
		if pending ~= nil then
			self.pendingMeal = if pending - dt <= 0 then nil else pending - dt
		end
		local after = if groom then groom.after else cfg.stretch.after
		if pending ~= nil and groom and self.standS >= groom.mealDelay then
			self.pendingMeal = nil
			begin(self, "meal")
		elseif self.standS >= after and (groom or cfg.stretch) then
			self.wait -= dt
			if self.wait <= 0 then
				begin(self, if groom then (if unit(self) < 0.5 then "palp" else "leg") else "stretch")
			end
		end
	end

	-- the pose of the act now
	local live = self.bout
	if live ~= nil and self.weight > 0 then
		local current: Act = live.acts[#live.acts]
		for _, a in live.acts do
			if live.t >= a.start and live.t < a.start + a.dur then current = a end
		end
		local a = current
		local u = math.clamp((live.t - a.start) / a.dur, 0, 1)
		local w = smooth(math.min(u, 1 - u) / (if groom then groom.fade else 0.18)) * self.weight
		pose.bout, pose.act = live.kind, a.kind
		if a.kind == "palp" or a.kind == "palps" then
			for k = 1, 2 do
				if a.kind == "palp" and a.index ~= k then continue end
				local phase = if a.kind == "palps" and k == 2 then math.pi else 0
				local stroke = 0.5 - 0.5 * math.cos(TAU * groom.strokes * u + phase) -- 0 at the start of a stroke, 1 at its end
				local inward = if k == 1 then -1 else 1 -- (the yaw that turns each palp toward the midline)
				pose.palpYaw[k] = inward * math.rad(groom.palpYawDeg) * w * (0.35 + 0.65 * stroke)
				pose.palpPitch[k] = math.rad(groom.palpPitchDeg) * w * stroke
			end
		elseif a.kind == "leg" then
			local pair = (a.index - 1) % 4 + 1
			local spec = groom.legs[pair]
			local sweep = math.sin(TAU * groom.strokes * u) -- the leg is drawn through the palps to and fro
			setLeg(pose, a.index, w, { x = spec.x, y = spec.y, z = spec.z + spec.sweep * sweep, kneeOut = spec.kneeOut, kneeUp = spec.kneeUp }, false)
			for k = 1, 2 do -- both palps come in to hold it
				local inward = if k == 1 then -1 else 1
				pose.palpYaw[k] = inward * math.rad(groom.legPalpYawDeg) * w
				pose.palpPitch[k] = math.rad(groom.palpPitchDeg) * 0.5 * w * (0.5 + 0.5 * sweep)
			end
		elseif a.kind == "stretch" then
			local st = cfg.stretch
			local pair = (a.index - 1) % 4 + 1
			local along = if pair <= 2 then -st.along else st.along * 0.6
			setLeg(pose, a.index, smooth(math.min(u, 1 - u) / 0.35) * self.weight, { x = st.out, y = st.lift, z = along, kneeUp = st.kneeUp }, true)
		end
	end
	return pose
end

return Living
