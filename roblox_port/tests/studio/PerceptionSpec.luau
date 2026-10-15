--!strict
-- P01 F1-F8: real WORLD rays plus the actual memory-only view builder. Isolated from playable geometry.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sensor = require(Shared.Perception.Sensor)
local Memory = require(Shared.Perception.ObservationMemory)
local View = require(Shared.UI.PerceptionView)
local Species = require(Shared.Data.Species)
local Motor = require(Shared.Movement.SpiderMotor)
local Surfaces = require(Shared.Data.Surfaces)
return function(check: (string, () -> ()) -> ())
	local folder: Folder? = nil
	local memory: any; local sensor: any; local observer: any; local cast: any; local target: any
	local function rig()
		if folder then folder:Destroy() end
		folder = Instance.new("Folder"); folder.Name="P01World"; folder.Parent=workspace
		local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include; params.FilterDescendantsInstances={folder :: Folder}
		cast=Sensor.workspaceCast(params)
		memory=Memory.new(); sensor=Sensor.new(memory); sensor:configureFrom(Species.phidippus_audax_prototype.perception)
		observer={eye=Vector3.new(0,100,0),gaze=-Vector3.zAxis,heading=-Vector3.zAxis,up=Vector3.yAxis}
		target={id="marker",position=Vector3.new(0,100,-8),radius=0.45,velocity=Vector3.zero,maxCategory="fly_like_prey"}
	end
	local function wall()
		local p=Instance.new("Part"); p.Size=Vector3.new(6,6,0.2); p.Position=Vector3.new(0,100,-4)
		p.Anchored=true; p.CanCollide=false; p.CanQuery=true; p.Parent=folder
		return p
	end
	local function run(n: number, present: boolean?)
		for _=1,n do sensor:step(1/60,observer,if present==false then {} else {target},cast) end
	end
	local function contact(): any return memory:getContact(sensor:trackIdFor(target.id)) end
	local adapter={
		project=function(p: Vector3, _: number) return Vector2.new(p.X,p.Z),true,12 end,
		edge=function(d: Vector3) return {pos=Vector2.new(d.X,d.Z),dir=Vector2.new(1,0)} end,
		covered=function(_: Vector3, _: number) return true end,
	}
	check("P01 F1 peripheral cue has bearing but no position or identity",function()
		rig(); target.position=Vector3.new(8,100,0); target.velocity=Vector3.xAxis*0.8; run(30)
		local c=contact(); assert(c and not c.hasPosition and c.category=="movement" and c.cueCount==1)
		local v=View.build(memory,adapter); assert(#v.edges==1 and #v.labels==0 and #v.rings==0)
	end)
	check("P01 F2 camera projection cannot rotate the sensor cone",function()
		rig(); target.position=Vector3.new(8,100,0); target.velocity=Vector3.xAxis; run(120)
		for _=1,30 do View.build(memory,adapter) end
		assert(not contact().hasPosition and sensor.core.inspectionsMade==0)
	end)
	check("P01 F3 Focus turns at capped rate and inspection refines in time",function()
		rig()
		local motor=Motor.new({world=folder,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,spawn=Vector3.new(0,99.92,0),heading=Vector3.xAxis})
		-- Tick the same capped facing function used by the motor via its normal tick input.
		local floor=Instance.new("Part"); floor.Anchored=true; floor.Size=Vector3.new(30,1,30); floor.Position=Vector3.new(0,99.42,0); floor:SetAttribute("ProfileId","painted_wood_dry"); floor.Parent=folder
		motor:place(Vector3.new(0,99.92,0),Vector3.yAxis,Vector3.xAxis)
		local first, possible, fly = 0,0,0
		for tick=1,180 do
			observer=motor:observer(); sensor:step(1/60,observer,{target},cast)
			local c=contact()
			if c and c:isInspectedNow() then
				if first==0 then first=tick end
				if c.category=="possible_prey" and possible==0 then possible=tick end
				if c.category=="fly_like_prey" and fly==0 then fly=tick end
			end
			local old=motor.heading
			motor:tick({wish=Vector3.zero,focusPoint=target.position})
			assert(math.deg(math.acos(math.clamp(old:Dot(motor.heading),-1,1))) < 3.02,"Focus exceeded 180 deg/s")
		end
		assert(first>0 and possible-first+1>=24 and fly-first+1>=60,"classification timing")
		assert(View.build(memory,adapter).labels[1].text=="fly-like prey")
	end)
	check("P01 F4 hidden motion never updates observation or HUD position",function()
		rig(); run(80); local c=contact(); local pos=c.position; local tick=c.observedTick
		wall(); target.position+=Vector3.new(2,0,0); run(100)
		assert(c:hasMark() and (c.position-pos).Magnitude<1e-5 and c.observedTick==tick)
		local v=View.build(memory,adapter); assert(#v.rings==1 and v.rings[1].pos==Vector2.new(pos.X,pos.Z))
	end)
	check("P01 F5 fixed last-seen mark fades and expires",function()
		rig(); run(80); local c=contact(); wall(); run(12,false)
		local p=c.position; run(175,false); local v=View.build(memory,adapter)
		assert(c:hasMark() and c.position==p and v.rings[1].alpha<0.4 and v.rings[1].dash<0.8)
		run(200,false); assert(memory:count()==0 and #View.build(memory,adapter).rings==0)
	end)
	check("P01 F6 association follows evidence even after world id changes",function()
		rig(); run(80); local c=contact(); local w=wall(); run(30); target.id="renamed"; w:Destroy(); run(7)
		assert(contact()==c and c.reacquisitions==1 and memory:count()==1)
	end)
	check("P01 F7 only an inspected empty visible spot loses its mark",function()
		rig(); run(80); local c=contact(); run(12,false); assert(c:hasMark()); run(40,false); assert(memory:count()==0)
		rig(); run(80); c=contact(); wall(); run(100,false); assert(c:hasMark())
	end)
	check("P01 F8 never-sensed actors leave no overlay",function()
		rig(); target.position=Vector3.new(0,100,8); target.velocity=Vector3.xAxis; run(100)
		local v=View.build(memory,adapter); assert(memory:count()==0 and #v.edges==0 and #v.labels==0 and #v.rings==0)
		rig(); wall(); run(100); assert(memory:count()==0)
	end)
	if folder then folder:Destroy() end
end
