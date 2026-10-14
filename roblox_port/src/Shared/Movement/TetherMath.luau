--!strict
-- Pure safety-line operations from frozen Godot tether.gd / spider_motor.gd.
-- No renderer, wall clock, Roblox services or collision decisions here.
local T = {}
T.BRAKE = 0.25
T.MIN_REST = 0.4
T.DROP_SLACK = 0.5
T.DAMPING = 1.6
T.DT = 1/60

function T.constrain(pivot: Vector3, length: number, target: Vector3, velocity: Vector3)
	local d = target-pivot
	local distance = d.Magnitude
	local out = {position=target, velocity=velocity, acted=false, radial_before=0, radial_after=0,
		tangential_change=0, distance_before=distance, distance_after=distance}
	if distance < 1e-9 then return out end
	local radial = d/distance
	local speed = velocity:Dot(radial)
	out.radial_before, out.radial_after = speed, speed
	if distance <= length then return out end
	local v = if speed > 0 then velocity-radial*speed else velocity
	out.position = pivot+radial*math.max(length,0)
	out.velocity, out.acted = v, true
	out.radial_after = v:Dot(radial)
	out.tangential_change = ((v-radial*v:Dot(radial))-(velocity-radial*speed)).Magnitude
	out.distance_after = math.max(length,0)
	return out
end
function T.energy(position: Vector3, velocity: Vector3, gravity: number): number
	return 0.5*velocity:Dot(velocity)+gravity*position.Y
end
function T.reelWorkBound(shortening: number, gravity: number, speed: number, length: number): number
	return math.max(shortening,0)*(gravity+speed*speed/math.max(length,0.05))
end
function T.sagDepth(span: number, length: number): number
	local extra = length-span
	if extra <= 1e-4 or span < 1e-4 then return 0 end
	return math.min(math.sqrt(3*span*extra/8),3)
end
function T.lock(paid: number, path: number, maximum: number, extension: number): (number,number)
	local p = math.min(math.max(paid,path),maximum)
	return p,math.min(p+math.max(extension,0),maximum)
end
function T.reel(rest: number, prefix: number, maximum: number, intent: number, speed: number): number
	return math.clamp(rest-math.clamp(intent,-1,1)*speed*T.DT,math.min(prefix+T.MIN_REST,maximum),maximum)
end

-- A press that started before the grace period can NEVER become a release later.
function T.newRelease()
	return {ticks=0, held=0, down=false, counts=false, progress=0}
end
function T.releaseTick(s, onLine: boolean, down: boolean): boolean
	s.ticks = if onLine then s.ticks+1 else 0
	if down and not s.down then s.counts = onLine and s.ticks>=24; s.held=0 end
	if not down or not onLine then s.counts=false; s.held=0 end
	s.down = down
	s.held = if s.counts then s.held+1 else 0
	s.progress = math.min(s.held/36,1)
	if s.progress>=1 then s.counts=false; s.held=0; s.progress=0; return true end
	return false
end
return T
