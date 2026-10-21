--!strict
-- One ambient house mouse: authored floor routes, seeded pauses, no prey or
-- damage interface. It adds life without becoming another source of meals.
local Mouse = {}
Mouse.__index = Mouse
local v = Vector3.new
Mouse.ROUTE = table.freeze({
	v(-132,-70,88), v(-110,-70,88), v(-110,-70,150),
	v(-105,-70,215), v(20,-70,215), v(125,-70,215),
	v(195,-70,215), v(214,-70,220), v(245,-70,220),
})
Mouse.SPEED = 24
Mouse.FLEE_SPEED = 42
function Mouse.new(seed: number): any
	return setmetatable({pos=Mouse.ROUTE[1],heading=Vector3.xAxis,leg=1,direction=1,
		wait=8,seed=math.max(1,seed % 2147483647),moving=false,distance=0},Mouse)
end
local function random(self: any): number
	self.seed=self.seed*16807%2147483647
	return (self.seed-1)/2147483646
end
function Mouse.step(self: any, dt: number, spider: Vector3?, cat: Vector3?)
	local alarm=(spider~=nil and (spider-self.pos).Magnitude<9)
		or (cat~=nil and (cat-self.pos).Magnitude<65)
	self.moving=false
	if self.wait>0 then
		self.wait=math.max(0,self.wait-dt)
		-- A refuge is a safe stopping place even while the cat passes.
		if self.leg==1 or self.leg==#Mouse.ROUTE or not alarm then return end
		self.wait=0
	end
	local target=Mouse.ROUTE[self.leg+self.direction]
	local delta=target-self.pos
	local length=delta.Magnitude
	local travel=math.min(length,(if alarm then Mouse.FLEE_SPEED else Mouse.SPEED)*dt)
	if length>1e-6 then
		self.heading=delta.Unit;self.pos+=self.heading*travel
		self.distance+=travel;self.moving=travel>0
	end
	if travel>=length then
		self.leg+=self.direction
		if self.leg==1 or self.leg==#Mouse.ROUTE then
			self.direction=-self.direction;self.wait=12+random(self)*18
		else self.wait=if alarm then 0 else .3+random(self)*1.8 end
	end
end
return Mouse
