--!strict
-- The mate's legs (ROBLOX-79): the rival's own drive (Predator/RivalDrive: a SpiderMotor over the whole sill, the route graph, the keep-out around the
-- retreat) given a record in the rival's vocabulary. RivalDrive and RivalRoute are used as they are and are not changed; this module only translates:
--   the mate wanders       -> the rival patrols (about 100 places over every face, in a fixed order by the leg number)
--   the mate approaches    -> the rival stalks (toward where it sees the spider; it is Mate.step that stops it at attendWu)
--   the mate attends, pairs-> the rival winds up (it stands, facing the spider)
--   the mate leaves        -> a patrol whose one place is the exit (Data/MatingRules.exitAt)
--   a wasp visit, or away  -> recover (it stands) / dormant (it is not on the sill)
-- Nothing is kept here that cannot be made again from life.mate: the motor stands where the record says (the drive puts it there when the two differ,
-- which is also how a returned rest works). `sees` is the drive's last decision about the spider, which Mate.step reads as s.drive.sees.
local RivalDrive = require(script.Parent.RivalDrive)
local Rules = require(script.Parent.Parent.Data.MatingRules)

local MateDrive = {}
MateDrive.__index = MateDrive

local MAP: { [string]: string } = {
	away = "dormant", wander = "patrol", approach = "stalk", attend = "windup", pair = "windup", leaving = "patrol",
}

-- `motor`: a SpiderMotor made for the mate; `blocked(a, b)`: something opaque between the points (the sight query).
function MateDrive.new(motor: any, blocked: (Vector3, Vector3) -> any): any
	local drive = RivalDrive.new(motor, blocked)
	local exit: any = nil
	local best = math.huge
	for _, w in drive.waypoints do
		local d = (w.pos - Rules.exitAt).Magnitude
		if w.up.Y > 0.5 and d < best then exit, best = w, d end
	end
	return setmetatable({
		drive = drive, exit = exit, leaving = false, sees = false,
		proxy = { state = "dormant", position = motor.pos, previous = motor.pos, up = motor.up, heading = motor.heading, origin = motor.pos, leg = 0, elapsed = 0, notice = 0 },
	}, MateDrive)
end

function MateDrive.destroy(self: any)
	self.drive:destroy()
end

-- One fixed tick, after Mate.step. `s` is the same snapshot Mate.step was given (it has the player's `up` and `grounded` as RivalDrive needs).
function MateDrive.update(self: any, mate: any, dt: number, s: any)
	local proxy = self.proxy
	local state = mate.state
	local mapped = MAP[state] or "dormant"
	if s.wasp and state ~= "away" then mapped = "recover" end
	proxy.state = mapped
	proxy.position, proxy.up, proxy.heading, proxy.leg = mate.position, mate.up or Vector3.yAxis, mate.heading, mate.leg or 0
	-- Leaving: the one place it goes to is the exit; entering the state sets it once.
	if state == "leaving" then
		if not self.leaving and self.exit ~= nil and mapped == "patrol" then
			self.drive:_setGoal(self.exit, "patrol")
			self.leaving = true
		end
	else
		self.leaving = false
	end
	self.drive:update(proxy, dt, s)
	mate.position, mate.up, mate.heading, mate.leg = proxy.position, proxy.up, proxy.heading, proxy.leg
	self.sees = self.drive.sees == true and state ~= "away"
end

return MateDrive
