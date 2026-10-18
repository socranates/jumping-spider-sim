--!strict
-- The grip on a caught rival (ROBLOX-77): the same tapping struggle as the fly's (Prey/Feeding's grip math, so the HUD's grip bar and the Grip button
-- work as they do for a fly) with the rival's own numbers (Data/Catch.rival; the gentle modes get the house fly's, and nothing here ever harms the
-- player). A second Feeding controller is kept for it: only its `struggle` runs, never `step`, so it does not advance the reserves a second time.
-- RivalSpider holds the rival (`subdued` false) and this decides how it ends: subdued (RivalSpider.subdue, then it is eaten as before) or it tears
-- free (RivalSpider.tearFree: back to recover, nothing lost). The grip itself is scratch, never recorded: a rival found held and not subdued begins a
-- fresh grip, and a checkpoint is never taken while it is held (Checkpoint.boundaryProblem), so a return can only land at a rest.
local Feeding = require(script.Parent.Parent.Prey.Feeding)
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)
local Rival = require(script.Parent.RivalSpider)

local Grip = {}

-- A new grip. `needs` is only given to the controller (its struggle never touches it).
function Grip.new(needs: any?): any
	return { feeding = Feeding.new(needs), began = 0 }
end

-- Is the player's grip on a rival being fought for now (so the jump button is a tap and the HUD shows the grip)?
function Grip.active(g: any): boolean
	return g.feeding.struggling == true
end

-- The grip's strength 0..1 for the HUD, or nil when there is no struggle.
function Grip.level(g: any): number?
	if g.feeding.struggling then return g.feeding.grip end
	return nil
end

-- A tap of the Grip button.
function Grip.tap(g: any)
	g.feeding:press()
end

-- The seeded stream of this rival's struggle: the world's seed, the day and which contest it was (the rival's own count), so the same encounter
-- fights the same way. Nothing else in the game draws from it.
local function seedOf(seed: number, day: number, n: number): number
	return (seed * 19349663 + (day * 1013 + 7) * 83492791 + n * 73856093 + 54321) % 2147483647
end

-- One tick. `r` is the rival's record, `s` the same table RivalSpider.step gets (grounded, gentle, day, seed) plus `auto` (Automatic grip).
-- Returns "" (nothing happened), "begin" (a fresh grip on a rival just held), "subdued" (it is yours: eat it) or "tore" (it tore free).
function Grip.step(g: any, r: any, dt: number, s: any): string
	local f = g.feeding
	if not Rival.struggling(r) then
		if f.struggling then f.struggling = false; f.held = nil; f.tap = false end -- the rival is gone from the fangs by some other way
		return ""
	end
	local event = ""
	if not f.struggling then
		f.rng = PreyRandom.new(seedOf(s.seed or 0, s.day or 0, r.contests or 0))
		f:useRivalRules(s.gentle == true)
		f.tap = false
		f:capture(r)
		g.began += 1
		event = "begin"
	end
	f.auto = s.auto == true
	local tore = false
	f:struggle(dt, s.grounded ~= false, function() tore = true end)
	if tore then
		Rival.tearFree(r)
		return "tore"
	end
	if not f.struggling and f.held ~= nil then
		f.held = nil
		f.feeding = false
		f.swallow = 0
		Rival.subdue(r)
		return "subdued"
	end
	return event
end

return Grip
