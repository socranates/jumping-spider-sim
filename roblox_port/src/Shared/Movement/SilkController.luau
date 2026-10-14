--!strict
-- Engine adapter for the frozen safety line. One local-space anchor, at most one bend.
-- Fixed ticks only. The client owns ordinary walking/jumps; this owns locked-line movement.
local Math = require(script.Parent.TetherMath)
local Silk = {}
Silk.__index = Silk
local HEIGHT, RADIUS = 0.31, 0.30
local DOWN = Vector3.new(0,-1,0)

function Silk.new(world, surfaces, tuning, gravity: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {world}
	return setmetatable({world=world, surfaces=surfaces, params=params, maximum=tuning.max_line_length_wu,
		speed=tuning.reel_speed_wu_s, gravity=gravity, mode="none", paid=0, rest=0, taut=false,
		anchor=Vector3.zero, normal=Vector3.yAxis, anchorPart=nil, bend=nil, bendPart=nil,
		lowering=false, snagged=false, block="", message="", release=Math.newRelease(), walk=nil,
		previous=Vector3.zero},Silk)
end
function Silk.profile(self: any, hit)
	return if hit then self.surfaces[hit.Instance:GetAttribute("ProfileId")] else nil
end
function Silk.clear(self: any)
	self.mode="none"; self.anchorPart=nil; self.bend=nil; self.bendPart=nil
	self.paid=0; self.rest=0; self.taut=false; self.lowering=false; self.snagged=false; self.block=""
	self.walk=nil; self.release=Math.newRelease()
	self.message=""
end
function Silk.anchorAt(self: any, hit, position: Vector3): boolean
	self:clear()
	local profile=self:profile(hit)
	if not profile or not profile.silk_anchor_allowed or not hit.Instance:IsA("BasePart") then
		self.message="This surface cannot hold silk"; return false
	end
	self.anchorPart=hit.Instance
	self.anchorLocal=hit.Instance.CFrame:PointToObjectSpace(hit.Position)
	self.normalLocal=hit.Instance.CFrame:VectorToObjectSpace(hit.Normal)
	self.anchor=hit.Position; self.normal=hit.Normal; self.previous=position
	self.mode="payout"; self.rest=self.maximum; self.paid=math.min((position-self.anchor).Magnitude,self.maximum)
	self.message="Silk attached"
	return true
end
function Silk.pivot(self: any): Vector3 return self.bend or self.anchor end
function Silk.prefix(self: any): number return if self.bend then (self.bend-self.anchor).Magnitude else 0 end
function Silk.path(self: any, position: Vector3): number return self:prefix()+(position-self:pivot()).Magnitude end
function Silk.refresh(self: any): boolean
	if not self.anchorPart or not self.anchorPart:IsDescendantOf(self.world) then
		self:clear(); self.message="Silk anchor lost"; return false
	end
	self.anchor=self.anchorPart.CFrame:PointToWorldSpace(self.anchorLocal)
	self.normal=self.anchorPart.CFrame:VectorToWorldSpace(self.normalLocal)
	if self.bendPart then
		if self.bendPart:IsDescendantOf(self.world) then self.bend=self.bendPart.CFrame:PointToWorldSpace(self.bendLocal)
		else self.bend=nil; self.bendPart=nil end
	end
	return true
end
function Silk.clearRay(self: any, a: Vector3, b: Vector3): boolean
	local d=b-a
	return d.Magnitude<=0.02 or workspace:Raycast(a,d.Unit*(d.Magnitude-0.02),self.params)==nil
end
function Silk.geometry(self: any, position: Vector3)
	local a=self.anchor+self.normal*0.02
	if self:clearRay(a,position) then self.bend=nil; self.bendPart=nil; self.snagged=false
	elseif self.bend then self.snagged=not self:clearRay(self.bend,position)
	elseif self:clearRay(a,self.previous) then
		local lo,hi=0,1
		for _=1,12 do
			local mid=(lo+hi)*0.5
			if self:clearRay(a,self.previous:Lerp(position,mid)) then lo=mid else hi=mid end
		end
		local hit=workspace:Raycast(a,self.previous:Lerp(position,hi)-a,self.params)
		self.snagged=true
		if hit and hit.Instance:IsA("BasePart") then
			local side=position-hit.Position
			side-=hit.Normal*side:Dot(hit.Normal)
			if side.Magnitude>1e-6 then side=side.Unit end
			for _,k in {1,2,4} do
				local point=hit.Position+(hit.Normal+side)*0.03*k
				if self:clearRay(a,point) and self:clearRay(point,position) then
					self.bend=point; self.bendPart=hit.Instance
					self.bendLocal=hit.Instance.CFrame:PointToObjectSpace(point)
					if self.mode=="locked" then self.rest=math.min(math.max(self.rest,self:path(position)),self.maximum) end
					self.snagged=false; break
				end
			end
		end
	else self.snagged=true end
	self.previous=position
end
function Silk.lock(self: any, position: Vector3, extension: number)
	if self.mode=="none" then return end
	self.paid,self.rest=Math.lock(self.paid,self:path(position),self.maximum,extension)
	self.mode="locked"; self.taut=false; self.block=""; self.release=Math.newRelease()
	self.message="Silk catching"
end
function Silk.payout(self: any, position: Vector3)
	if self.mode~="payout" or not self:refresh() then return end
	self:geometry(position)
	self.paid=math.max(self.paid,self:path(position))
	if self.paid>=self.maximum then self.paid=self.maximum; self:lock(position,0) end
end
function Silk.room(self: any, position: Vector3): number
	local hit=workspace:Spherecast(position,RADIUS,DOWN*self.maximum,self.params)
	return if hit then hit.Distance else 0
end
function Silk.planDrop(self: any, position: Vector3, up: Vector3, heading: Vector3): ({direction: Vector3, distance: number}?, string)
	local hit=workspace:Raycast(position,-up*(HEIGHT+0.12),self.params)
	local profile=self:profile(hit)
	if not profile then return nil,"No supporting surface" end
	if not profile.silk_anchor_allowed then return nil,"This surface cannot hold silk" end
	if up:Dot(Vector3.yAxis)<0.707 then
		if self:room(position+up*0.01)>=1 then return {direction=Vector3.zero,distance=0},"" end
		return nil,"Nothing below to lower into"
	end
	local best: {direction: Vector3, distance: number}? = nil
	local limit=6
	for i=0,15 do
		local dir=CFrame.fromAxisAngle(up,i*math.pi/8):VectorToWorldSpace(heading)
		local obstacle=workspace:Spherecast(position,RADIUS,dir*6,self.params)
		local free=if obstacle then obstacle.Distance else 6
		for step=1,math.floor(math.min(free,limit)*10) do
			local distance=step/10
			local q=position+dir*distance
			if not workspace:Raycast(q,-up*(HEIGHT+0.12),self.params) then
				if self:room(q+dir*HEIGHT)>=1 and (not best or distance<limit-1e-6) then best={direction=dir,distance=distance}; limit=distance end
				break
			end
		end
	end
	return best,if best then "" else "Nothing below to lower into"
end
function Silk.startDrop(self: any, position: Vector3, up: Vector3, push: Vector3)
	local hit=workspace:Raycast(position,-up*(HEIGHT+0.12),self.params)
	if not self:anchorAt(hit,position) then return false end
	self.lowering=true; self:lock(position,Math.DROP_SLACK)
	self.message="Lowering on silk"
	return true
end

-- Sweep the body, then slide once. Never satisfy a constraint by teleporting through a wall.
function Silk.move(self: any, position: Vector3, motion: Vector3, velocity: Vector3, intent: number)
	local p=position
	local remaining=motion
	for _=1,2 do
		if remaining.Magnitude<1e-7 then break end
		local hit=workspace:Spherecast(p,RADIUS,remaining,self.params)
		if not hit then p+=remaining; break end
		p+=remaining.Unit*math.max(hit.Distance-0.01,0)
		local profile=self:profile(hit)
		local allowed=not self.lowering or intent>0 or (hit.Normal.Y>=0.707 and hit.Position.Y<=self.anchor.Y-0.5)
		if profile and profile.attachable and allowed then return p,Vector3.zero,hit end
		local rest=remaining-remaining.Unit*math.min(hit.Distance,remaining.Magnitude)
		remaining=rest-hit.Normal*rest:Dot(hit.Normal)
		velocity-=hit.Normal*math.min(0,velocity:Dot(hit.Normal))
	end
	return p,velocity,nil
end
function Silk.step(self: any, position: Vector3, velocity: Vector3, intent: number, releaseDown: boolean)
	if self.mode~="locked" or not self:refresh() then return position,velocity,nil end
	if Math.releaseTick(self.release,true,releaseDown) then
		self:clear(); self.message="Silk released"; return position,velocity,nil
	end
	if intent<=0 and self.block=="blocked" then self.block="" end
	local oldRest=self.rest
	if intent<0 or (self.block=="" and not self.snagged) then self.rest=Math.reel(self.rest,self:prefix(),self.maximum,intent,self.speed) end
	-- "Shortest" only when a reel actually ran and could not shorten (Godot sets it inside its not-snagged reel branch);
	-- a snag while swinging under a leaf must not leave reeling refused once the line is clear again (ROBLOX-10).
	if intent>0 and not self.snagged and self.rest>=oldRest-1e-6 and self.block=="" then self.block="shortest" end
	if intent<0 and self.rest>oldRest then self.block="" end
	local p=position
	-- A padded bend can leave the shortest line just below the lip. Acquire a nearby
	-- real face with the legs (0.6 stud reach), never through an intervening obstacle.
	if intent>0 and self.block=="shortest" and not self.snagged then
		for _,direction in {self:pivot()-p,Vector3.yAxis,-self.normal} do
			if direction.Magnitude>1e-6 then
				local face=workspace:Raycast(p,direction.Unit*0.6,self.params)
				local profile=self:profile(face)
				if face and profile and profile.attachable then
					local seat=face.Position+face.Normal*HEIGHT
					local motion=seat-p
					local obstacle=if motion.Magnitude>1e-7 then workspace:Spherecast(p,RADIUS,motion,self.params) else nil
					if not obstacle or obstacle.Instance==face.Instance then return seat,Vector3.zero,face end
				end
			end
		end
	end
	if self.rest<oldRest then
		local excess=self:path(p)-self.rest
		if excess>1e-6 then
			local hit
			p,velocity,hit=self:move(p,(self:pivot()-p).Unit*excess,velocity,intent)
			if hit then return p,velocity,hit end
			if self:path(p)>self.rest+1e-4 then self.rest=math.min(self:path(p),self.maximum); self.block="blocked" end
		end
	end
	local energy=Math.energy(p,velocity,self.gravity)
	velocity+=DOWN*self.gravity*Math.DT
	if self.taut and (p-self:pivot()).Magnitude>1e-6 then
		local r=(p-self:pivot()).Unit
		velocity-=(velocity-r*velocity:Dot(r))*(1-math.exp(-Math.DAMPING*Math.DT))
	end
	local c=Math.constrain(self:pivot(),math.max(self.rest-self:prefix(),0),p+velocity*Math.DT,velocity)
	local hit
	p,velocity,hit=self:move(p,c.position-p,c.velocity,intent)
	if hit then return p,velocity,hit end
	local over=self:path(p)-self.rest
	if over>1e-4 then
		p,velocity,hit=self:move(p,(self:pivot()-p).Unit*over,velocity,intent)
		if hit then return p,velocity,hit end
	end
	self:geometry(p)
	if Math.energy(p,velocity,self.gravity)>energy+1e-6 then
		local ke=0.5*velocity:Dot(velocity)
		velocity*=if ke>1e-12 then math.sqrt(math.clamp((energy-self.gravity*p.Y)/ke,0,1)) else 0
	end
	local path=self:path(p)
	self.paid=math.min(math.max(self.paid,path),self.rest)
	self.taut=path>=self.rest-0.003
	self.message=if self.snagged then "Silk snagged — lower or let go" elseif self.block=="blocked" then "Reel blocked — lower or let go"
		elseif self.block=="shortest" then "At the shortest line" elseif intent>0 then "Reeling in" elseif intent<0 then "Lowering" else "Hanging on silk"
	return p,velocity,nil
end
return Silk
