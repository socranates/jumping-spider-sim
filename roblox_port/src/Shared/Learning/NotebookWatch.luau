--!strict
-- Watches play for the moments the naturalist's notebook opens pages on: a port of the frozen scripts/learning/notebook_watch.gd.
-- It only listens and reads: it changes nothing the spider does, knows or senses. Godot connects signals; the Roblox client has an
-- event loop instead, so the client hands this the events it already has (a committed leap, a refined category, the life loop's and
-- the wasp's events, the eye view each frame) and, once a fixed tick, a view of the state that has no event (catches, a meal ending,
-- the reserve changing, a fly taking off). It never reads the HUD's words. Nothing here runs while the game waits (the client
-- calls it from the fixed tick and the frame it already pauses).
--
-- Which trigger comes from where (Godot's -> Roblox's):
--   start .......... a life is being played (Godot: the world is ready; here, not while the menu waits for the first life)
--   jump, jump_far, jump_long ... a committed leap, by the distance from take-off to the landing point (hops too)
--   eye_view, eye_time_N ....... the spider-eye view is on; seconds in it
--   shimmer ........ the eye view is drawing a movement ring or edge arc
--   fly_recognised . the memory's category for a contact is refined to fly-like prey
--   catch .......... a fly is seized (PreyDirector.captures goes up)
--   meal ........... eating ends with something eaten (Godot's feeding_ended with food taken)
--   buzz ........... a fly takes off within hearWu of the spider (Godot's caption "[buzzing", the flies' take-off within HEAR_WU)
--   rest, sleep .... the life loop's rest_started, and woke (the morning after a night's sleep)
--   moult_ready, moulted, adult ... the life loop's events; adult when the moult reaches the adult stage
--   hungry, well_fed, starving ... the reserve changes to at or under hungryAt, at or over wellFedAt, or to nothing (not on Easy)
--   wasp, wasp_escaped, wasp_caught ... the director's visit_started, left (it had noticed the spider), caught
-- Not wired: felt. It answers to Godot's vibration sense (a felt shake through touching surfaces), which the port does not have, so
-- that page cannot open yet; the notebook never opens a page for something the game does not do.
-- Checked in tests/notebook.luau.

local Data = require(script.Parent.Parent.Data.NotebookPages)

local NotebookWatch = {}
NotebookWatch.__index = NotebookWatch

-- Triggers this watcher can open a page on, and those it cannot (with the reason).
NotebookWatch.UNWIRED = { felt = "the port has no vibration sense" } :: { [string]: string }

-- The adult stage of Growth (Growth.ADULT), read here as a number so the notebook needs nothing of the life modules.
local ADULT_STAGE = 3

-- What the fixed tick tells the watcher (see `step`).
export type View = {
	started: boolean, -- a life is being played
	captures: number, -- PreyDirector.captures
	feeding: boolean, -- Feeding.feeding
	taken: number, -- Feeding.taken
	energy: number, -- the reserve, 0 to 1
	gentle: boolean, -- Easy or free play: it cannot starve
	spider: Vector3,
	flies: { any }, -- the flies: .id, .position and :airborne()
}

function NotebookWatch.new(book: any): any
	local self = setmetatable({
		book = book,
		primed = false, -- whether `step` has taken its first look since the world changed (resync)
		started = false,
		captures = 0, feeding = false, taken = 0.0, takenAtStart = 0.0, energy = 1.0,
		flying = {} :: { [string]: boolean },
	}, NotebookWatch)
	return self
end

-- The world changed under the watcher (a return to a rest, a new spider): the next `step` only takes a fresh look, so nothing that
-- happened before the change, or that the change itself did, opens a page.
function NotebookWatch.resync(self: any)
	self.primed = false
end

-- A committed leap of `distance` studs.
function NotebookWatch.onJump(self: any, distance: number)
	self.book:noticeJump(distance)
end

-- A contact's category was refined or fell back to `category` (ObservationMemory.categoryChanged).
function NotebookWatch.onCategory(self: any, category: string)
	if category == "fly_like_prey" then
		self.book:notice("fly_recognised")
	end
end

-- A life loop event ({kind, day}); `stage` is the growth stage after it.
function NotebookWatch.onLife(self: any, kind: string, stage: number)
	if kind == "rest_started" then
		self.book:notice("rest")
	elseif kind == "woke" then
		self.book:notice("sleep")
	elseif kind == "moult_ready" then
		self.book:notice("moult_ready")
	elseif kind == "moulted" then
		self.book:notice("moulted")
		if stage >= ADULT_STAGE then
			self.book:notice("adult")
		end
	end
end

-- A wasp director signal ({kind, escaped}).
function NotebookWatch.onWasp(self: any, kind: string, escaped: boolean?)
	if kind == "visit_started" then
		self.book:notice("wasp")
	elseif kind == "left" then
		if escaped == true then
			self.book:notice("wasp_escaped")
		end
	elseif kind == "caught" then
		self.book:notice("wasp_caught")
	end
end

-- Each rendered frame: `seconds` of play (0 while the game waits), whether the eye view is on and how many movement marks it draws.
function NotebookWatch.frame(self: any, seconds: number, eyeView: boolean, movers: number)
	if not eyeView then
		return
	end
	self.book:notice("eye_view")
	self.book:addEyeTime(seconds)
	if movers > 0 then
		self.book:notice("shimmer")
	end
end

-- Each fixed tick, after the spider, the flies and the life loop have moved.
function NotebookWatch.step(self: any, v: View)
	local book = self.book
	if v.started and not self.started then
		self.started = true
		book:notice("start")
	end
	if not self.primed then
		-- The first look only takes the baseline.
		self.primed = true
		self.captures, self.feeding, self.taken, self.takenAtStart, self.energy = v.captures, v.feeding, v.taken, v.taken, v.energy
		table.clear(self.flying)
		for _, f in v.flies do
			self.flying[f.id] = f:airborne()
		end
		return
	end
	if v.captures > self.captures then
		book:notice("catch")
	end
	self.captures = v.captures
	-- Eating ending with something eaten is a meal (Godot: feeding_ended with food taken).
	if v.feeding and not self.feeding then
		self.takenAtStart = self.taken
	elseif self.feeding and not v.feeding and v.taken > self.takenAtStart + 1e-9 then
		book:notice("meal")
	end
	self.feeding, self.taken = v.feeding, v.taken
	-- The reserve changed (Godot's energy_changed).
	if v.energy ~= self.energy then
		self.energy = v.energy
		if v.energy <= 0 and not v.gentle then
			book:notice("starving")
		end
		if v.energy <= Data.hungryAt then
			book:notice("hungry")
		elseif v.energy >= Data.wellFedAt then
			book:notice("well_fed")
		end
	end
	-- A fly taking off near enough to hear.
	local seen: { [string]: boolean } = {}
	for _, f in v.flies do
		local up: boolean = f:airborne()
		seen[f.id] = up
		if up and not self.flying[f.id] and (f.position - v.spider).Magnitude <= Data.hearWu then
			book:notice("buzz")
		end
	end
	self.flying = seen
end

return NotebookWatch
