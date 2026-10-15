--!strict
-- Godot test_target.gd: a labelled prop, never prey. Path stepping is independent of rendering.
local Target = {}
Target.__index = Target
function Target.new(path: {Vector3}): any
	assert(#path >= 2)
	return setmetatable({path=path, position=path[1], velocity=Vector3.zero, index=2, direction=1,
		pauseLeft=0, speed=0.8, pauseS=1.2, enabled=true, frozen=false, id="test_target", radius=0.45}, Target)
end
function Target.step(self: any, dt: number)
	self.velocity = Vector3.zero
	if not self.enabled or self.frozen then return end
	if self.pauseLeft > 0 then self.pauseLeft -= dt; return end
	local before = self.position
	local delta = self.path[self.index] - before
	if delta.Magnitude <= self.speed * dt then
		self.position = self.path[self.index]
		local nextIndex = self.index + self.direction
		if nextIndex < 1 or nextIndex > #self.path then
			self.direction = -self.direction
			nextIndex = self.index + self.direction
			self.pauseLeft = self.pauseS
		end
		self.index = nextIndex
	else self.position += delta.Unit * self.speed * dt end
	self.velocity = (self.position - before) / dt
end
function Target.percept(self: any): any
	if not self.enabled then return nil end
	return {id=self.id, position=self.position, radius=self.radius, velocity=self.velocity, maxCategory="fly_like_prey"}
end
return Target
