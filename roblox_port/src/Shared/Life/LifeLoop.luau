--!strict
-- LifeLoop: the rest, sleep and day of the frozen scripts/habitat/habitat_loop.gd (T08, LIFE-04 to LIFE-06), without the
-- world. The client gives it, once a fixed tick and after the spider and its meal have moved, what it needs to know about the
-- spider (in the crack, on a surface, still, holding or eating prey) and the presses of the feed and cancel buttons; it keeps
-- the life clock and the rest, tells the NeedsModel how many game hours passed, says how much daylight there is and how far
-- the eyes reach in it, and asks for the retreat checkpoint when a rest begins and when a night's sleep reaches the morning.
--
-- * Resting: in the silk-lined crack, on a surface, keeping still, holding no prey, E rests (Godot's interact). E or Q again,
--   moving, or anything that makes resting impossible ends it.
-- * Sleeping: a rest in the evening or at night (18:00 to 07:00) sleeps until morning: the hours pass at the sleeping rate,
--   never more than one tick's worth at a time. Moving wakes the spider ("Awake before morning"). The morning ("Morning, day
--   N") keeps a new checkpoint. A rest by day passes no extra time.
-- * Light: daylight 0 to 1 from the hour; the eyes reach NIGHT_SIGHT of their range in the dark (LIFE-06). The reach comes
--   from the clock, never from the lighting on the screen.
--
-- Not ported (later rounds of Godot's loop): growth and moulting (round 3), the wasp (round 4), weakness and starving to death
-- (round 5: it needs the death and continuing rules), the passing shadow (T08's telegraphed disturbance) and the notebook.
-- Checked tick by tick against Godot's own loop in tests/life_reference.json (tools/export_life_reference.gd).

local LifeClock = require(script.Parent.LifeClock)

local LifeLoop = {}
LifeLoop.__index = LifeLoop

-- The sensor's reach at night, as a share of its daytime reach (jumping spiders hunt by sight, in daylight).
LifeLoop.NIGHT_SIGHT = 0.3
-- How long a notice stays on the screen.
LifeLoop.NOTICE_S = 6.0
-- After a checkpoint is restored the spider takes a moment to take hold of its surface again; the restored rest is not ended
-- meanwhile.
LifeLoop.RESTORE_GRACE_TICKS = 30
-- Rest restored per second of resting.
LifeLoop.REST_PER_S = 0.10
LifeLoop.HUNGRY_AT = 0.25
LifeLoop.WEAK_AFTER_H = 24
LifeLoop.STARVE_AFTER_H = 48

-- What the loop needs to know about the spider this tick.
export type Spider = {
	inRetreat: boolean, -- inside the silk-lined crack
	attached: boolean, -- on a surface (not in the air, not on the line)
	still: boolean, -- not walking or sliding (Godot: intent under 0.01, speed under 0.15)
	holding: boolean, -- holds prey (caught, struggling or being eaten)
	feeding: boolean, -- eating right now
}
export type CheckpointResult = { ok: boolean, message: string }
export type Event = { kind: string, day: number? }

-- `needs` is the NeedsModel whose hours this loop reports; `save` keeps the retreat checkpoint (nil: none is kept).
function LifeLoop.new(needs: any, save: (() -> CheckpointResult)?): any
	local self = setmetatable({
		clock = LifeClock.new(), needs = needs, save = save,
		mode = "main", rules = "standard", lifeOver = false,
		resting = false, restSeconds = 0.0, asleep = false, elapsed = 0.0,
		checkpointDue = false, checkpointResult = nil :: CheckpointResult?, checkpoints = 0,
		notice = "", noticeSeconds = 0.0, morningText = "",
		restoreGrace = 0, events = {} :: { Event },
		daylight = 1.0, rangeScale = 1.0,
	}, LifeLoop)
	self:applyLight()
	return self
end

function LifeLoop.canRest(_self: any, s: Spider): boolean
	return s.inRetreat and not s.holding and not s.feeding and s.attached and s.still
end

function LifeLoop.showNotice(self: any, text: string)
	self.notice = text
	self.noticeSeconds = LifeLoop.NOTICE_S
end

function LifeLoop._emit(self: any, kind: string, day: number?)
	table.insert(self.events, { kind = kind, day = day })
end

-- The events since the last call: rest_started, rest_ended, slept, woke (with the day), checkpoint.
function LifeLoop.drainEvents(self: any): { Event }
	local e = self.events
	self.events = {}
	return e
end

function LifeLoop.requestRest(self: any, s: Spider): boolean
	if not self:canRest(s) then
		return false
	end
	self.resting = true
	self.checkpointDue = true
	self:_emit("rest_started")
	return true
end

function LifeLoop.stopRest(self: any)
	if self.resting then
		self.resting = false
		self:_emit("rest_ended")
	end
end

-- The light of the hour, and how far the spider's eyes reach in it.
function LifeLoop.applyLight(self: any)
	self.daylight = self.clock:daylight()
	self.rangeScale = LifeLoop.NIGHT_SIGHT + (1.0 - LifeLoop.NIGHT_SIGHT) * self.daylight
end

function LifeLoop.tooHungryToSleep(self: any): boolean
	return not self.needs.gentle and self.needs.starvingStreakH >= LifeLoop.WEAK_AFTER_H
end

function LifeLoop.starved(self: any): boolean
	return not self.needs.gentle and self.needs.starvingStreakH >= LifeLoop.STARVE_AFTER_H
end

function LifeLoop._stepLife(self: any, dt: number)
	local wasAsleep = self.asleep
	self.asleep = self.resting and (self.clock.sleeping or self.clock:isSleepTime()) and not self:tooHungryToSleep()
	local hours = self.clock:advance(dt, self.asleep)
	if self.asleep and not self.clock.sleeping then
		-- The morning came during this tick: awake, still resting in the crack. The new day keeps a checkpoint.
		self.asleep = false
		self.checkpointDue = true
		self.morningText = `Morning, day {self.clock.day}. Rested through the night in the crack.`
		self:showNotice(self.morningText)
		self:_emit("woke", self.clock.day)
	elseif wasAsleep and not self.asleep then
		self:showNotice(`Awake before morning: it is still {self.clock:partOfDay()}.`)
	end
	if self.asleep and not wasAsleep then
		self:_emit("slept")
	end
	self.needs:addHours(hours, self.asleep)
	self:applyLight()
end

-- One fixed tick, after the spider and its meal have moved. `feedPressed` and `cancelPressed` are this tick's fresh presses.
function LifeLoop.step(self: any, dt: number, s: Spider, feedPressed: boolean, cancelPressed: boolean)
	self.elapsed += dt
	if self.restoreGrace > 0 then
		self.restoreGrace = if s.attached then 0 else self.restoreGrace - 1
	end
	if self.resting and (cancelPressed or feedPressed or (self.restoreGrace == 0 and not self:canRest(s))) then
		self:stopRest()
	elseif feedPressed and not s.holding and not s.feeding then
		self:requestRest(s)
	end
	if self.resting then
		self.restSeconds += dt
		self.needs:restoreRest(dt * LifeLoop.REST_PER_S)
	end
	self:_stepLife(dt)
	if self:starved() and not self.lifeOver then
		self.lifeOver = true
		self:_emit("starved")
	end
	if self.noticeSeconds > 0.0 then
		self.noticeSeconds = math.max(0.0, self.noticeSeconds - dt)
	end
	if self.checkpointDue then
		self.checkpointDue = false
		if self.resting then
			self:makeCheckpoint()
		end
	end
end

-- The retreat checkpoint, now (the end of a tick).
function LifeLoop.makeCheckpoint(self: any): CheckpointResult
	local result: CheckpointResult = if self.save then self.save() else { ok = false, message = "no checkpoint store" }
	self.checkpointResult = result
	if result.ok then
		self.checkpoints += 1
		self:showNotice(result.message)
	else
		self:showNotice("Resting, but the checkpoint was not kept: " .. result.message)
	end
	if self.morningText ~= "" then
		self:showNotice(self.morningText .. "\n" .. self.notice)
		self.morningText = ""
	end
	self:_emit("checkpoint")
	return result
end

-- The loop's part of a checkpoint (Godot's habitat record, with the clock beside it as its "life" field).
function LifeLoop.toRecord(self: any): { [string]: any }
	return {
		retreat_id = "sill_crevice", resting = self.resting, rest_seconds = self.restSeconds, elapsed = self.elapsed,
		life = self.clock:toRecord(),
	}
end

function LifeLoop.problems(r: any): { string }
	local e: { string } = {}
	if type(r) ~= "table" then
		table.insert(e, "habitat: not a record")
		return e
	end
	if r.retreat_id ~= "sill_crevice" then table.insert(e, "habitat: not this windowsill's retreat") end
	if type(r.resting) ~= "boolean" then table.insert(e, "habitat: 'resting' is not true or false") end
	for _, k in { "rest_seconds", "elapsed" } do
		local v = r[k]
		if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then table.insert(e, `habitat: '{k}' is not a time`) end
	end
	for _, p in LifeClock.problems(r.life) do
		table.insert(e, p)
	end
	return e
end

-- Restores a record made by toRecord (validated first; false and nothing changed if it is not one). The rest that was going on
-- goes on; no new checkpoint is owed for it.
function LifeLoop.load(self: any, r: any): boolean
	if #LifeLoop.problems(r) > 0 then
		return false
	end
	self.clock:load(r.life)
	self.resting = r.resting
	self.restSeconds = r.rest_seconds
	self.elapsed = r.elapsed
	self.asleep = false
	self.checkpointDue = false
	self.morningText = ""
	self.restoreGrace = LifeLoop.RESTORE_GRACE_TICKS
	self:applyLight()
	self:showNotice("Returned to the checkpoint: the sill as it was when you rested in the crack. This is checkpoint recovery, not an exact resume.")
	return true
end

return LifeLoop
