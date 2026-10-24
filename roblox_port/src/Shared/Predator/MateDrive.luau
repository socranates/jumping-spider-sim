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
-- ROBLOX-117: in the preserve the mate roams the hut garden's regions as the rival does (`roam`, RivalDrive): its record's `region` goes to and from the proxy, and
-- the exit it leaves by is the waypoint of the region it is in nearest the world's exit (Predator/Mate.exitAt).
local RivalDrive = require(script.Parent.RivalDrive)
local Mate = require(script.Parent.Mate)

local MateDrive = {}
MateDrive.__index = MateDrive

local MAP: { [string]: string } = {
	away = "dormant", wander = "patrol", approach = "stalk", attend = "windup", pair = "windup", leaving = "patrol",
}

-- `motor`: a SpiderMotor made for the mate; `blocked(a, b)`: something opaque between the points (the sight query). ROBLOX-94: `region` (the sill's unless given) is the
-- region it walks in (RivalDrive.new).
-- The waypoint of the drive's region nearest the exit, on a floor.
local function exitOf(drive: any): any
	local exit: any = nil
	local best = math.huge
	local at = Mate.exitAt()
 -- Sparse scenery waypoints may be metres from the authored exit (26 studs
 -- in garden_b4). Prefer the actual supported floor point when in this region.
 local face=drive.g and drive.g:faceAt(at,Vector3.yAxis)
 if face~=nil and not drive.g:inKeepOut(at) then
  return {pos=at-Vector3.yAxis*.31,up=Vector3.yAxis,face=face}
 end
	for _, w in drive.waypoints do
		local d = (w.pos - at).Magnitude
		if w.up.Y > 0.5 and d < best then exit, best = w, d end
	end
	return exit
end

function MateDrive.new(motor: any, blocked: (Vector3, Vector3) -> any, region: string?, roam: { [string]: boolean }?): any
	local drive = RivalDrive.new(motor, blocked, region, roam)
	return setmetatable({
		drive = drive, exit = exitOf(drive), exitRegion = drive.region, leaving = false, sees = false, player = {}, avoid = { steer = true },
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
	proxy.region = mate.region
	if self.exitRegion ~= (mate.region or self.drive.region) then
		-- (ROBLOX-117: the region changed under it: the exit is this region's)
		if mate.region ~= nil then self.drive:useRegion(mate.region) end
		self.exit, self.exitRegion, self.leaving = exitOf(self.drive), self.drive.region, false
	end
	-- Leaving: the one place it goes to is the exit; entering the state sets it once.
	if state == "leaving" then
		if (not self.leaving or self.drive.goal == nil or self.drive.goalKey ~= "patrol") and self.exit ~= nil and mapped == "patrol" then
			self.drive:_setGoal(self.exit, "patrol")
			self.leaving = true
		end
	else
		self.leaving = false
	end
	-- Courtship/scene flags keep the rival away from this pair. They must not
	-- blind the mate to its own partner. Preserve retreat, rest, wasp and sight
	-- restrictions in a reused private snapshot; never mutate the caller's table.
	local player = self.player
	table.clear(player)
	for k,v in s do player[k]=v end
	player.courting, player.scene = nil, nil
 local motor=self.drive.motor
 motor.avoid=nil
 if state~="away" and state~="pair" and s.grounded~=false and not s.airborne and not s.onLine and not s.wasp then
  local avoid=self.avoid
  avoid.pos,avoid.up,avoid.radius=s.position,s.up or Vector3.yAxis,s.bodyClearance or 1.15
  if avoid.allowed==nil then avoid.allowed=function(at: Vector3): boolean
   return self.drive.g~=nil and not self.drive.g:inKeepOut(at)
  end end
  motor.avoid=avoid
 end
	self.drive:update(proxy, dt, player)
	mate.position, mate.up, mate.heading, mate.leg = proxy.position, proxy.up, proxy.heading, proxy.leg
	if proxy.region ~= nil then mate.region = proxy.region end
	if self.drive.region ~= self.exitRegion then self.exit, self.exitRegion = exitOf(self.drive), self.drive.region end
	self.sees = self.drive.sees == true and state ~= "away"
end

return MateDrive
