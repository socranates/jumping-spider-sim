--!strict
-- Engine adapter for the frozen safety line. One local-space anchor, at most one bend.
-- Fixed ticks only. The client owns ordinary walking/jumps; this owns locked-line movement.
local Math = require(script.Parent.TetherMath)
local Silk = {}
Silk.__index = Silk
local HEIGHT, RADIUS = 0.31, 0.30
local DOWN = Vector3.new(0,-1,0)
-- The game's own rule (ROBLOX-99), opt-in like NeedsModel.game and Data/Catch.game: how fast the spider lets itself down a line, as a share of Godot's
-- reel speed (Species silk.reel_speed_wu_s, 1.5 studs a second either way). Nathan: "make the hang just go slower by default". Lowering (the stick back, or
-- the drop key held) runs at `lowerScale` of it; reeling in keeps Godot's speed, so the climb back is as brisk as it was and the rig's head-up climb
-- (look.hang.climb.speed) still trips. A controller never given the rule (Silk:useGameRules) replays Godot: the tether goldens and the box-world scenarios.
-- ROBLOX-96: and how long a line may be. Godot's 20 studs (silk.max_line_length_wu) was never reached on the sill; the garden's first set piece is the let-down from
-- the outer sill's front edge to the bed, 90 studs of brick, so the game's line is `maxLine` studs (a game value: jumping spiders do descend on draglines far
-- farther than their body length, but no measured length is claimed here). Everything else about the line (the slack, the hang, the release) is Godot's.
Silk.game = { lowerScale = 0.5, maxLine = 100 }

function Silk.new(world, surfaces, tuning, gravity: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {world}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = {world}
	return setmetatable({world=world, surfaces=surfaces, params=params, overlap=overlap, maximum=tuning.max_line_length_wu,
		speed=tuning.reel_speed_wu_s, lowerSpeed=tuning.reel_speed_wu_s, gravity=gravity, mode="none", paid=0, rest=0, taut=false,
		anchor=Vector3.zero, normal=Vector3.yAxis, anchorPart=nil, bend=nil, bendPart=nil,
		lowering=false, snagged=false, block="", message="", release=Math.newRelease(), walk=nil,
		previous=Vector3.zero},Silk)
end
-- Opt in to the game's lowering (Silk.game): the let-down at lowerScale of the reel speed. Reeling in is untouched.
function Silk.useGameRules(self: any)
	self.lowerSpeed = self.speed * Silk.game.lowerScale
	self.maximum = Silk.game.maxLine
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

-- ROBLOX-107: the body's skin kept by overlap, not by the sweep alone. The real engine's Spherecast does not see a part the sphere starts in, and a
-- sweep that begins within a hair of a face it is nearly tangent to can miss it (Studio, v35: the self-test's let-down from the outer sill's front edge hung
-- 0.07 from the brick face, inside its 0.31 skin, where the box world keeps it at 0.31). Once inside the skin nothing pushed it out. So after each move the
-- body is pushed out of any box of the world it overlaps, by the shortest way out of the nearest point of that box (never through it: a centre already
-- inside a box is left alone), and the velocity into it is taken away. A box the body is touching (within a thousandth of its radius) that it could land on
-- by the sweep's own rule is a landing, as the sweep's contact would have been. Boxes only (a Part whose Shape is Block; the world's walkable pieces are
-- all boxes). With the box world's exact sweeps the body is never inside its skin, so this changes nothing there.
local SKIN = RADIUS + 0.01
function Silk.unstick(self: any, position: Vector3, velocity: Vector3, intent: number): (Vector3, Vector3, any)
	local p, v = position, velocity
	local ok, parts = pcall(function() return workspace:GetPartBoundsInRadius(p, SKIN, self.overlap) end)
	if not ok or parts == nil then return p, v, nil end
	for _, part in parts do
		local inst = part :: any
		local shape = if inst.ClassName == "Part" then inst.Shape else nil
		if inst:IsA("BasePart") and inst.ClassName == "Part" and (shape == nil or shape == Enum.PartType.Block) then
			local half = inst.Size * 0.5
			local localP = inst.CFrame:PointToObjectSpace(p)
			local near = Vector3.new(math.clamp(localP.X, -half.X, half.X), math.clamp(localP.Y, -half.Y, half.Y), math.clamp(localP.Z, -half.Z, half.Z))
			local out = localP - near
			local d = out.Magnitude
			if d > 1e-6 and d < SKIN - 1e-4 then
				local n = inst.CFrame:VectorToWorldSpace(out / d)
				local contact = { Instance = inst, Position = inst.CFrame:PointToWorldSpace(near), Normal = n, Distance = 0 }
				p += n * (SKIN - d)
				v -= n * math.min(0, v:Dot(n))
				if d < RADIUS + 1e-3 and self:landable(contact, p, intent) then return p, Vector3.zero, contact end
			end
		end
	end
	return p, v, nil
end
-- The sweep's landing rule: an attachable surface; while letting down, only ground under the body below the anchor (and not on a reel in).
function Silk.landable(self: any, hit, p: Vector3, intent: number): boolean
	local profile = self:profile(hit)
	local allowed = not self.lowering or intent > 0 or (hit.Normal.Y >= 0.707 and hit.Position.Y <= self.anchor.Y - 0.5 and self:groundUnder(p, hit))
	return profile ~= nil and profile.attachable == true and allowed
end
-- ROBLOX-107: while letting down, a landing needs ground under the body. The sweep can meet the rounded edge of a box that another box covers (the brick
-- wall's top under the outer sill's slab, y -3: Studio, v35, "left the line 2.0 s into the let-down, at (2.00, -2.70, -24.07)"), with a normal steep enough to
-- pass the landing rule; the spider then stood on a sliver no one can see. A ray straight down from the body's centre must meet the part it touched
-- within the legs' reach, as standing on it asks; otherwise it slides on.
function Silk.groundUnder(self: any, p: Vector3, hit): boolean
	local under = workspace:Raycast(p, DOWN * (HEIGHT + 0.35), self.params)
	return under ~= nil and under.Instance == hit.Instance
end

-- Sweep the body, then slide once. Never satisfy a constraint by teleporting through a wall.
function Silk.move(self: any, position: Vector3, motion: Vector3, velocity: Vector3, intent: number)
	local p=position
	local remaining=motion
	for _=1,2 do
		if remaining.Magnitude<1e-7 then break end
		local hit=workspace:Spherecast(p,RADIUS,remaining,self.params)
		if not hit then p+=remaining; break end
		-- Maintain a skin along the contact normal at grazing angles.
		p=hit.Position+hit.Normal*(RADIUS+0.01)
		if self:landable(hit,p,intent) then return p,Vector3.zero,hit end
		local rest=remaining-remaining.Unit*math.min(hit.Distance,remaining.Magnitude)
		remaining=rest-hit.Normal*rest:Dot(hit.Normal)
		velocity-=hit.Normal*math.min(0,velocity:Dot(hit.Normal))
	end
	-- While lowering alongside the launch wall, a nearly tangent native sweep can
	-- miss a shallow contact. Maintain the wall's skin without grabbing it again.
	-- Other faces still use the swept landing rules above.
	if self.lowering and math.abs(self.normal.Y)<0.707 then
		local face=workspace:Raycast(p,-self.normal*(RADIUS+0.01),self.params)
		if face and face.Normal:Dot(self.normal)>0.99 then
			local clearance=(p-face.Position):Dot(face.Normal)
			if clearance<RADIUS+0.01 then
				p+=face.Normal*(RADIUS+0.01-clearance)
				velocity-=face.Normal*math.min(0,velocity:Dot(face.Normal))
			end
		end
	end
	local touched
	p,velocity,touched=self:unstick(p,velocity,intent)
	if touched then return p,Vector3.zero,touched end
	return p,velocity,nil
end
function Silk.step(self: any, position: Vector3, velocity: Vector3, intent: number, releaseDown: boolean)
	if self.mode~="locked" or not self:refresh() then return position,velocity,nil end
	if Math.releaseTick(self.release,true,releaseDown) then
		self:clear(); self.message="Silk released"; return position,velocity,nil
	end
	if intent<=0 and self.block=="blocked" then self.block="" end
	local oldRest=self.rest
	-- (ROBLOX-99: letting down runs at the game's lowering speed, reeling in at Godot's; both are the reel speed until useGameRules.)
	if intent<0 or (self.block=="" and not self.snagged) then self.rest=Math.reel(self.rest,self:prefix(),self.maximum,intent,if intent<0 then self.lowerSpeed else self.speed) end
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
