--!strict
-- NeedsModel: a port of the frozen scripts/needs/needs_model.gd (spec 11, 19.3, 21.3 NeedState; LIFE-05). The spider's
-- reserves, and the only place they change. It simulates ENERGY and REST and nothing else (hydration, stress and condition are
-- named placeholders in the record). The numbers change only through approved calls: time passing (advance, addHours) and food
-- (grantEnergy). It never reads the world, never decides that anything is eaten, and does not know what a fly is: Feeding asks
-- it to grant and says which source the energy came from, so its ledger shows that no source ever gave more than it had.
--
-- Two modes (explicit, set by whoever builds it; ROBLOX-24):
--   * sandbox (lifeMode false; Godot's lab and tests that build a model alone): energy drains very slowly with action time and
--     stops at ENERGY_FLOOR. Nothing happens at the floor.
--   * life (lifeMode true; the windowsill, where the life clock runs): energy drains with the game hours LifeLoop reports,
--     faster awake than asleep, and has no floor. It can run out; the hours at zero are counted (starvingHours, and the streak
--     since the last meal). LifeLoop reads the streak: weak (too hungry to sleep) after 24 hours of it and starved after 48, except in the
--     gentle modes (ROBLOX-91: the streak is Godot's reset by any meal, or, in the game's rules, eased by each meal by the hours it covers).
--   * gentle (with lifeMode; Godot's Easy and free play) drains at GENTLE_DRAIN of the rate and never falls below GENTLE_FLOOR.
-- Both drains are integrated at the 2 Hz update (spec 20) over the action time that actually passed, at most MAX_STEP_S a
-- call, so the same time drains the same energy at any frame rate and a stall cannot drain more than a capped step.
-- Rest is a second reserve with no consequence yet: it wears down while the spider is active and builds back while it keeps
-- still, and the retreat restores it.
-- Checked against Godot's own values in tests/life_reference.json (tools/export_life_reference.gd).

local NeedsModel = {}
NeedsModel.__index = NeedsModel

NeedsModel.ENERGY_MAX = 1.0
NeedsModel.ENERGY_START = 0.55
NeedsModel.ENERGY_DRAIN_PER_S = 0.0006
NeedsModel.ENERGY_FLOOR = 0.20
NeedsModel.REST_MAX = 1.0
NeedsModel.REST_START = 1.0
NeedsModel.REST_DRAIN_PER_S = 0.0012
NeedsModel.REST_RECOVER_PER_S = 0.004
NeedsModel.UPDATE_PERIOD_S = 0.5
NeedsModel.MAX_STEP_S = 0.25
NeedsModel.FULL_AT = 0.98
-- Life mode, at Godot's factor 1: a full reserve lasts about three game days without food, and one fly (0.35) feeds the spider for about a day.
-- A real Phidippus goes much longer without food; the game compresses time on purpose (LIFE-05).
NeedsModel.LIFE_DRAIN_AWAKE_PER_H = 0.021
NeedsModel.LIFE_DRAIN_ASLEEP_PER_H = 0.007
-- The game's own rules (ROBLOX-78), opt-in like Data/Wasp.game and Data/Catch.game: `drain` multiplies the life-mode drain (awake and asleep alike; the
-- gentle modes have their own factor, below) of a model that was given them by useGameRules. A model that never is replays Godot (factor 1) and the reference fixtures hold.
-- The factor is worked out from the constants above: a day is about 11 waking hours and 13 asleep, 11 x 0.021 + 13 x 0.007 = 0.322 energy at factor 1,
-- so 1.55 cost 0.499, about half the reserve (it was 1.1, 0.354, Chet's ten percent more, ROBLOX-61). ROBLOX-88: 1.9 costs 0.612 a day (11 x 0.021 x 1.9 =
-- 0.439 awake, 13 x 0.007 x 1.9 = 0.173 asleep): a full reserve lasts 1.63 days, and a housefly (0.35) is 0.57 of a day.
-- ROBLOX-91: the gentle modes (Easy, Free play) have their own factor, `gentleDrain` 1.1 (ROBLOX-61's, which with the gentle half rate costs 0.177 a day), applied
-- INSTEAD of `drain` when the model is gentle: ROBLOX-88's hungrier pacing was meant for the standard rules (the gentle day would otherwise have cost 0.306).
-- `streakDecay`: a meal in the game eases the starving streak by the hours it covers at the current drain (amount / the awake rate) and ends it altogether
-- only when the reserve rises above `streakEndsAbove` (0.1); Godot's rule, a full reset at any meal, stays the default, so one tiny catch a day at 0% energy
-- no longer keeps a spider alive for ever.
NeedsModel.game = { drain = 1.9, gentleDrain = 1.1, streakDecay = true, streakEndsAbove = 0.1 }
NeedsModel.PLAY_DRAIN = NeedsModel.game.drain -- (the name the client and tests have used since ROBLOX-61)
NeedsModel.GENTLE_DRAIN = 0.5
NeedsModel.GENTLE_FLOOR = 0.1
NeedsModel.STAGE_ID = "p0_prototype"

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function unit(v: any): boolean
	return finite(v) and v >= 0.0 and v <= 1.0
end

local function nonNegative(v: any): boolean
	return finite(v) and v >= 0.0
end

local function pair(v: any): boolean
	return type(v) == "table" and #v == 2 and v[3] == nil and nonNegative(v[1]) and nonNegative(v[2])
end

export type Record = {
	energy: number, rest: number, enabled: { string }, update_accumulator: { number }, stage_id: string,
	elapsed_s: number, granted_total: number, granted_by_source: { [string]: number },
	life_mode: boolean, starving_hours: number, hour_accumulator: { number }, starving_streak_h: number,
}

-- `lifeMode` and `gentle` say which rules apply (see above). Both default to false: the sandbox rules.
function NeedsModel.useGameRules(self: any)
	self.drainScale = NeedsModel.game.drain
	self.gentleDrainScale = NeedsModel.game.gentleDrain
	self.streakDecay = NeedsModel.game.streakDecay
end

-- The factor on the life-mode drain in use: Godot's 1 for a model never given the game's rules, else the game's (the gentle modes have their own).
function NeedsModel.drainFactor(self: any): number
	if self.gentle and self.gentleDrainScale ~= nil then return self.gentleDrainScale end
	return self.drainScale or 1
end

function NeedsModel.new(lifeMode: boolean?, gentle: boolean?): any
	return setmetatable({
		energy = NeedsModel.ENERGY_START, rest = NeedsModel.REST_START,
		elapsedS = 0.0, grantedTotal = 0.0, grantedBySource = {} :: { [string]: number }, grantsMade = 0, grantsRefused = 0,
		lifeMode = lifeMode == true, gentle = gentle == true, starvingHours = 0.0, starvingStreakH = 0.0,
		_accActive = 0.0, _accStill = 0.0, _accHoursAwake = 0.0, _accHoursAsleep = 0.0,
		-- Called with (before, after) whenever energy changes (Godot's energy_changed signal). Optional.
		onEnergyChanged = nil :: ((number, number) -> ())?,
	}, NeedsModel)
end

local function changed(self: any, before: number)
	if self.energy ~= before and self.onEnergyChanged then
		self.onEnergyChanged(before, self.energy)
	end
end

-- Changes the numbers for a fixture. Keys: energy, rest. Values outside [0, 1] or not finite are ignored.
function NeedsModel.configure(self: any, values: { energy: number?, rest: number? })
	if values.energy ~= nil and unit(values.energy) then
		self.energy = values.energy
	end
	if values.rest ~= nil and unit(values.rest) then
		self.rest = values.rest
	end
end

function NeedsModel._apply(self: any, period: number, activeShare: number)
	local before = self.energy
	if self.lifeMode then
		local need = (self._accHoursAwake * NeedsModel.LIFE_DRAIN_AWAKE_PER_H + self._accHoursAsleep * NeedsModel.LIFE_DRAIN_ASLEEP_PER_H) * self:drainFactor()
		local hours = self._accHoursAwake + self._accHoursAsleep
		self._accHoursAwake = 0.0
		self._accHoursAsleep = 0.0
		if self.gentle then
			need *= NeedsModel.GENTLE_DRAIN
		end
		if need > 0.0 then
			local floorLeft = if self.gentle then math.max(self.energy - NeedsModel.GENTLE_FLOOR, 0.0) else self.energy
			local used = math.min(floorLeft, need)
			self.energy -= used
			if need > used and not self.gentle then
				local starved = hours * (need - used) / need
				self.starvingHours += starved
				self.starvingStreakH += starved
			end
		end
	elseif self.energy > NeedsModel.ENERGY_FLOOR then
		self.energy = math.max(NeedsModel.ENERGY_FLOOR, self.energy - NeedsModel.ENERGY_DRAIN_PER_S * period)
	end
	self.rest = math.clamp(
		self.rest + (NeedsModel.REST_RECOVER_PER_S * (1.0 - activeShare) - NeedsModel.REST_DRAIN_PER_S * activeShare) * period,
		0.0, NeedsModel.REST_MAX)
	changed(self, before)
end

-- Lets `dt` seconds of action time pass. `active` is whether the spider spent them moving (walking, leaping, hanging) rather
-- than keeping still. Non-finite or non-positive time is ignored; a long step counts as at most MAX_STEP_S.
function NeedsModel.advance(self: any, dt: number, active: boolean)
	if not finite(dt) or dt <= 0.0 then
		return
	end
	dt = math.min(dt, NeedsModel.MAX_STEP_S)
	self.elapsedS += dt
	if active then
		self._accActive += dt
	else
		self._accStill += dt
	end
	local total = self._accActive + self._accStill
	while total >= NeedsModel.UPDATE_PERIOD_S - 1e-9 do
		self:_apply(NeedsModel.UPDATE_PERIOD_S, self._accActive / total)
		local keep = math.max(0.0, (total - NeedsModel.UPDATE_PERIOD_S) / total)
		self._accActive *= keep
		self._accStill *= keep
		total -= NeedsModel.UPDATE_PERIOD_S
	end
end

-- Life mode: `hours` of game time passed, asleep or awake. They are used up at the next 2 Hz update.
function NeedsModel.addHours(self: any, hours: number, asleep: boolean)
	if not self.lifeMode or not finite(hours) or hours <= 0.0 then
		return
	end
	if asleep then
		self._accHoursAsleep += hours
	else
		self._accHoursAwake += hours
	end
end

-- Whether the reserve has run out (life mode).
function NeedsModel.isStarving(self: any): boolean
	return self.lifeMode and self.energy <= 0.0
end

-- Energy that could still be added.
function NeedsModel.room(self: any): number
	return math.max(0.0, NeedsModel.ENERGY_MAX - self.energy)
end

-- Adds food energy from `sourceId` (a meal's capture key). Returns what was actually added: nothing for an amount that is not
-- a positive finite number or a source with no name, and never more than the room left. The caller (Feeding, only while a
-- held prey is being eaten) decides that the energy is deserved; this only keeps the books.
function NeedsModel.grantEnergy(self: any, amount: number, sourceId: string): number
	if sourceId == "" or not finite(amount) or amount <= 0.0 then
		self.grantsRefused += 1
		return 0.0
	end
	local added = math.min(amount, self:room())
	if added <= 0.0 then
		return 0.0
	end
	local before = self.energy
	self.energy = math.min(NeedsModel.ENERGY_MAX, self.energy + added)
	added = self.energy - before
	self.grantedTotal += added
	self.grantedBySource[sourceId] = (self.grantedBySource[sourceId] or 0.0) + added
	self.grantsMade += 1
	if self.streakDecay then
		-- The game: the meal covers the hours it feeds (at the awake rate) and the streak only ends when the reserve is really back.
		local perHour = NeedsModel.LIFE_DRAIN_AWAKE_PER_H * self:drainFactor()
		self.starvingStreakH = math.max(0.0, self.starvingStreakH - added / perHour)
		if self.energy > (NeedsModel.game.streakEndsAbove or 0.1) then self.starvingStreakH = 0.0 end
	else
		self.starvingStreakH = 0.0
	end
	changed(self, before)
	return added
end

-- Energy lost to an injury (ROBLOX-73: the rival's counter-bite). Never more than the spider has, and nothing in the gentle modes. Returns what was
-- lost. It is not time passing, so it leaves the starving hours to the drain; the reserve is already in the record, so nothing else needs keeping.
function NeedsModel.injure(self: any, amount: number): number
	if self.gentle or not finite(amount) or amount <= 0.0 then
		return 0.0
	end
	local before = self.energy
	self.energy = math.max(0.0, self.energy - amount)
	changed(self, before)
	return before - self.energy
end

-- A valid retreat interaction restores rest; it never grants food energy.
function NeedsModel.restoreRest(self: any, amount: number)
	if finite(amount) and amount > 0.0 then
		self.rest = math.min(NeedsModel.REST_MAX, self.rest + amount)
	end
end

function NeedsModel.isFull(self: any): boolean
	return self.energy >= NeedsModel.FULL_AT
end

-- What one source has given so far.
function NeedsModel.grantedFrom(self: any, sourceId: string): number
	return self.grantedBySource[sourceId] or 0.0
end

-- The NeedState record (spec 21.3), with Godot's field names. Hydration, stress and condition are not simulated and so absent.
function NeedsModel.toRecord(self: any): Record
	local by: { [string]: number } = {}
	for k, v in self.grantedBySource do
		by[k] = v
	end
	return {
		energy = self.energy, rest = self.rest, enabled = { "energy", "rest" },
		update_accumulator = { self._accActive, self._accStill }, stage_id = NeedsModel.STAGE_ID,
		elapsed_s = self.elapsedS, granted_total = self.grantedTotal, granted_by_source = by,
		life_mode = self.lifeMode, starving_hours = self.starvingHours,
		hour_accumulator = { self._accHoursAwake, self._accHoursAsleep }, starving_streak_h = self.starvingStreakH,
	}
end

-- Restores a record made by toRecord. False, and nothing changed, for anything that is not one: a missing or non-finite number,
-- a reserve outside [0, 1], an accumulator that is not two non-negative numbers, a grant ledger that does not add up. A record
-- without the life fields (Godot's older records) loads with them at their defaults. `gentle` is not part of the record.
function NeedsModel.load(self: any, d: any): boolean
	if type(d) ~= "table" then
		return false
	end
	for _, key in { "energy", "rest", "elapsed_s", "granted_total" } do
		if not finite(d[key]) then
			return false
		end
	end
	if not unit(d.energy) or not unit(d.rest) or d.elapsed_s < 0.0 or d.granted_total < 0.0 then
		return false
	end
	if not pair(d.update_accumulator) then
		return false
	end
	local by = d.granted_by_source
	if type(by) ~= "table" then
		return false
	end
	local sum = 0.0
	for k, v in by do
		if type(k) ~= "string" or not nonNegative(v) then
			return false
		end
		sum += v
	end
	if math.abs(sum - d.granted_total) > 1e-6 then
		return false
	end
	local lm = if d.life_mode == nil then false else d.life_mode
	local sh = if d.starving_hours == nil then 0.0 else d.starving_hours
	local ha = if d.hour_accumulator == nil then { 0.0, 0.0 } else d.hour_accumulator
	local streak = if d.starving_streak_h == nil then 0.0 else d.starving_streak_h
	if not nonNegative(streak) then
		return false
	end
	if type(lm) ~= "boolean" or not nonNegative(sh) then
		return false
	end
	if not pair(ha) then
		return false
	end
	local copy: { [string]: number } = {}
	for k, v in by do
		copy[k] = v
	end
	self.lifeMode = lm
	self.starvingHours = sh
	self.starvingStreakH = streak
	self._accHoursAwake = ha[1]
	self._accHoursAsleep = ha[2]
	self.energy = d.energy
	self.rest = d.rest
	self.elapsedS = d.elapsed_s
	self.grantedTotal = d.granted_total
	self.grantedBySource = copy
	self._accActive = d.update_accumulator[1]
	self._accStill = d.update_accumulator[2]
	return true
end

return NeedsModel
