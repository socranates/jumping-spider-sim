--!strict
-- Jump input: a port of the frozen Godot scripts/movement/jump_controller.gd (c87ce00, hold mode). Pure: the motor is passed
-- in, so tests/run.luau checks the same rules without Roblox.
--
-- A tap of the jump button (Space, A, touch Jump) is a short hop forward. Holding it for HOLD_TICKS (0.15 s) starts aiming:
-- the spider holds still and the landing patch shows the plan for whatever the screen centre is on. Releasing commits the
-- plan the patch shows when it is reachable; on anything else nothing is launched and the reason flashes for FLASH_TICKS.
-- Cancel (Q, B, touch Cancel) leaves a press or an aim with no penalty. drop() is focus loss or the Roblox menu: an aim in
-- progress ends quietly, so a button released while away can never leap later (Godot's _drop_input). Events are queued and
-- applied at the start of the next fixed tick, so timing is counted in ticks and does not depend on the frame rate.
-- `last` records the latest outcome for the HUD and tests: launched, cancelled, refused or hop_refused.
local JumpInput = {}
JumpInput.__index = JumpInput

JumpInput.HOLD_TICKS = 9 -- math.max(1, math.ceil(0.15 * 60 - 1e-6)), as jump_controller._hold_ticks()
JumpInput.FLASH_TICKS = 60

export type Phase = "idle" | "pressed" | "aiming"

function JumpInput.new()
	return setmetatable({
		phase = "idle" :: Phase,
		heldTicks = 0,
		events = {} :: { string },
		plan = nil :: any,
		flash = nil :: any,
		flashLeft = 0,
		last = nil :: any,
		tick = 0,
		onAim = nil :: ((boolean) -> ())?,
	}, JumpInput)
end

function JumpInput.press(self: any) table.insert(self.events, "press") end
function JumpInput.release(self: any) table.insert(self.events, "release") end
function JumpInput.cancel(self: any) table.insert(self.events, "cancel") end

-- Focus loss or the menu: forget queued presses and end an aim with no message (applied at once).
function JumpInput.drop(self: any, motor: any)
	table.clear(self.events)
	if self.phase == "aiming" then
		if motor then motor:cancelPrepare() end
		self:_endAim(motor)
	end
	self.phase = "idle"
	self.heldTicks = 0
end

function JumpInput.isAiming(self: any): boolean return self.phase == "aiming" end
-- True while a press or an aim is in progress: the cancel button belongs to it then.
function JumpInput.isBusy(self: any): boolean return self.phase ~= "idle" end

function JumpInput._record(self: any, kind: string, plan: any)
	self.last = { kind = kind, plan = plan, tick = self.tick }
end

function JumpInput._flash(self: any, plan: any)
	if plan ~= nil and plan.kind ~= "none" then
		self.flash = plan
		self.flashLeft = JumpInput.FLASH_TICKS
	end
end

function JumpInput._setAiming(self: any, on: boolean)
	local f = self.onAim
	if f then f(on) end
end

function JumpInput._endAim(self: any, motor: any)
	self.phase = "idle"
	self.heldTicks = 0
	self.plan = nil
	if motor then motor:clearAimTarget() end
	self:_setAiming(false)
end

function JumpInput._beginAim(self: any, motor: any)
	if not motor:beginPrepare() then
		self.phase = "idle"
		return
	end
	self.phase = "aiming"
	self.plan = nil
	self:_setAiming(true)
	self.plan = motor:aimPlan()
end

-- Commit the plan the patch is showing; anything not reachable is refused, with its reason, and launches nothing.
function JumpInput._confirm(self: any, motor: any)
	local shown = self.plan or motor:aimPlan() -- exactly what the patch showed at the last tick
	if shown ~= nil and shown.kind == "reachable" and motor:commit(shown) then
		self:_endAim(motor)
		self:_record("launched", shown)
		return
	end
	self:_flash(shown)
	motor:cancelPrepare()
	self:_endAim(motor)
	self:_record("refused", shown)
end

function JumpInput._hop(self: any, motor: any)
	local hop = motor:hopPlan()
	if hop ~= nil and hop.kind == "reachable" and motor:beginPrepare() then
		if motor:commit(hop) then
			self:_record("launched", hop)
			return
		end
		motor:cancelPrepare()
	end
	self:_flash(hop)
	self:_record("hop_refused", hop)
end

-- One fixed tick: apply the queued events, then count the hold and keep the aim's plan current.
function JumpInput.step(self: any, motor: any)
	self.tick += 1
	local queued = self.events
	self.events = {}
	for _, e in queued do
		if e == "press" then
			if self.phase == "idle" and motor:canPrepare() then
				self.phase = "pressed"
				self.heldTicks = 0
			end
		elseif e == "release" then
			if self.phase == "pressed" then
				self.phase = "idle"
				self:_hop(motor)
			elseif self.phase == "aiming" then
				self:_confirm(motor)
			end
		elseif e == "cancel" then
			if self.phase == "pressed" then
				self.phase = "idle"
				self:_record("cancelled", nil)
			elseif self.phase == "aiming" then
				motor:cancelPrepare()
				self:_endAim(motor)
				self:_record("cancelled", nil)
			end
		end
	end
	if self.flashLeft > 0 then
		self.flashLeft -= 1
		if self.flashLeft == 0 then self.flash = nil end
	end
	if self.phase == "pressed" then
		if not motor:canPrepare() then
			self.phase = "idle"
		else
			self.heldTicks += 1
			if self.heldTicks >= JumpInput.HOLD_TICKS then self:_beginAim(motor) end
		end
	end
	if self.phase == "aiming" then
		if motor:isPreparing() then
			self.plan = motor:aimPlan()
		else
			self:_endAim(motor) -- the spider lost its support, or was put somewhere else
		end
	end
end

return JumpInput
