--!strict
-- Drawing only: one held-body override and one short-lived, noninteractive husk.
-- No nutrition, collision, sensor or save authority lives here.
local Meal={};Meal.__index=Meal
function Meal.new(parent: Instance,world: Instance): any
 local folder=Instance.new("Folder");folder.Name="MealRemains";folder.Parent=parent
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={world}
 return setmetatable({folder=folder,params=params,heldView={},previous=nil,lastBites=0,pulseLeft=0,husk=nil,age=0},Meal)
end
function Meal.reset(self: any)
 if self.husk then self.husk:Destroy();self.husk=nil end
 self.previous=nil;self.heldView.id=nil;self.pulseLeft=0;self.lastBites=0
end
function Meal.pulse(self: any,dt: number,f: any,paused: boolean): number
 if not paused and f.bites~=self.lastBites then self.pulseLeft=.22 end
 self.lastBites=f.bites
 self.pulseLeft=math.max(0,self.pulseLeft-dt)
 return math.sin(math.pi*self.pulseLeft/.22)
end
function Meal.drop(self: any,at: CFrame)
 if self.husk then self.husk:Destroy() end
 local model=Instance.new("Model");model.Name="EmptyHusk";model.Parent=self.folder
 local p=Instance.new("Part");p.Name="DryBody";p.Shape=Enum.PartType.Ball
 p.Size=Vector3.new(.09,.045,.16);p.Color=Color3.fromRGB(91,75,55);p.Material=Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=model
 self.huskParts={{part=p,side=0}}
 for _,side in {-1,1} do
  local w=Instance.new("Part");w.Anchored=true;w.CanCollide=false;w.CanQuery=false;w.CanTouch=false;w.CastShadow=false;w.Color=p.Color;w.Material=p.Material;w.Name="EmptyWing";w.Size=Vector3.new(.1,.01,.17);w.Transparency=.65;w.Parent=model
  w.CFrame=at*CFrame.new(side*.065,0,.025)*CFrame.Angles(0,side*.4,0)
  table.insert(self.huskParts,{part=w,side=side})
 end
 self.husk=model;self.age=0;self.from=at
 local hit=workspace:Raycast(at.Position+Vector3.yAxis*.05,-Vector3.yAxis*8,self.params)
 -- Without nearby ground, let it fall and vanish instead of floating on an invented floor.
 local direction=at.LookVector
 if hit then
  direction-=hit.Normal*direction:Dot(hit.Normal)
  if direction.Magnitude<.01 then direction=hit.Normal:Cross(if math.abs(hit.Normal.X)<.9 then Vector3.xAxis else Vector3.zAxis) end
 end
 self.to=if hit then CFrame.lookAt(hit.Position+hit.Normal*.025,hit.Position+hit.Normal*.025+direction,hit.Normal) else at+Vector3.new(0,-3,0)
 self.grounded=hit~=nil
end
function Meal.update(self: any,dt: number,f: any,mouth: CFrame,paused: boolean)
 if paused then return end
 local held=f.held
 if self.previous and held~=self.previous and self.previous.state=="CONSUMED" then self:drop(self.lastMouth or mouth) end
 self.previous=held;self.lastMouth=mouth
 local v=self.heldView
 v.id=if held then held.id else nil
 if held then
  v.frame=mouth*CFrame.Angles(0,math.pi/2,0);v.struggling=f.struggling
  local full=held.profile.body.nutrition
  local remaining=if full>0 then math.clamp(held.nutrition/full,0,1) else 0
  -- Quantized sizes reduce property writes; offsets still follow the animated mouth every frame.
  v.scale=.4+.6*math.ceil(remaining*16)/16
 end
 if self.husk then
  self.age+=dt
  local frame=self.to.Rotation+self.from.Position:Lerp(self.to.Position,math.clamp(self.age/.4,0,1))
  for _,entry in self.huskParts do
   local p,side=entry.part,entry.side
   p.CFrame=frame*CFrame.new(side*.065,0,if side==0 then 0 else .025)*CFrame.Angles(0,side*.4,0)
   if self.age>2 then p.Transparency=math.max(if side==0 then 0 else .65,math.clamp((self.age-2)/1.5,0,1)) end
  end
  if self.age>3.5 then self.husk:Destroy();self.husk=nil end
 end
end
return Meal
