--!strict
-- One bounded local animal. Supports join the custom motor's world query root;
-- drawing does not become prey, a lock target, a hazard or a food credit.
local Workspace=game:GetService("Workspace")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Shapes=require(Shared.Habitat.Shapes)
local Body={};Body.__index=Body
function Body.new(root: Instance): any
 return setmetatable({root=root,model=nil,supports=nil,serial=nil,position=nil,age=0,leaving=0,seen=0},Body)
end
function Body.clear(self: any)
 if self.model then self.model:Destroy() end
 if self.supports then self.supports:Destroy() end
 self.model=nil;self.supports=nil;self.serial=nil;self.position=nil;self.seen=0;self.leaving=0
end
local function build(self: any,visitor: any)
 local model=Instance.new("Folder");model.Name="RareLuna";model.Parent=Workspace;self.model=model
 local supports=Instance.new("Folder");supports.Name="RareLunaSupport";supports.Parent=self.root;self.supports=supports
 self.parts={};self.frames={};self.base=visitor.at;self.serial=visitor.serial;self.age=0;self.leaving=0
 local function ell(name,size,at,color)
  local p=Shapes.ellipsoid(model,name,size,CFrame.new(visitor.at+at),Color3.fromHex(color),"SmoothPlastic")
  p.CastShadow=false;table.insert(self.parts,p);table.insert(self.frames,CFrame.new(at))
 end
 for _,sign in {-1,1} do
  ell("Forewing"..sign,Vector3.new(5,.14,4),Vector3.new(sign*2.35,0,-.9),"adc98c")
  ell("Hindwing"..sign,Vector3.new(3.8,.12,3.2),Vector3.new(sign*1.9,0,1.7),"b5d496")
  for _,z in {-.9,1.7} do
   ell("EyeRing"..sign..z,Vector3.new(.8,.05,.65),Vector3.new(sign*2.1,.1,z),"806b50")
   ell("EyeWindow"..sign..z,Vector3.new(.45,.06,.4),Vector3.new(sign*2.1,.13,z),"d6dfb2")
  end
  for i=1,4 do ell("Tail"..sign..i,Vector3.new(.35,.09,1.2),Vector3.new(sign*(2+.16*i),-.04*i,3+i*.75),"adc98c") end
  ell("Antenna"..sign,Vector3.new(.45,.12,1.25),Vector3.new(sign*.45,.25,-2),"b9a779")
  local p=Instance.new("Part");p.Name="LunaWing"..sign;p.Anchored=true
  p.Size=Vector3.new(4,.12,4);p.CFrame=CFrame.new(visitor.at+Vector3.new(sign*2.05,-.1,.3))
  p.Transparency=1;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.CastShadow=false
  p:SetAttribute("ProfileId","leaf_dry_prototype");p.Parent=supports
 end
 ell("Body",Vector3.new(.7,.65,3.7),Vector3.new(0,.25,0),"ece9d5")
 ell("Head",Vector3.new(.65,.6,.6),Vector3.new(0,.28,-1.8),"eee9d2")
 for _,p in supports:GetChildren() do if p:IsA("BasePart") then p.CanCollide=false;p.CanQuery=false end end
end
function Body.update(self: any,visitor: any,dt: number,spider: Vector3,anchored: boolean,reduced: boolean)
 if visitor and self.serial~=visitor.serial then self:clear();build(self,visitor) end
 if self.model==nil then return end
 self.age+=dt
 local occupied=(spider-self.base).Magnitude<7 or anchored
 if not visitor and not occupied then self.leaving+=dt end
 if self.leaving>=3 then self:clear();return end
 local arrival=if visitor then math.clamp(visitor.ageHours/.015,0,1) else 1
 local offset=Vector3.new(0,12,-18)*(1-arrival)+Vector3.new(0,8,-14)*(self.leaving/3)
 self.position=self.base+offset
 local moving=arrival<1 or self.leaving>0
 if moving or self.drawnPosition~=self.position then
 for i,p in self.parts do
  local frame=self.frames[i]
  local flutter=if arrival<1 or self.leaving>0 then math.sin(self.age*25)*(if reduced then .05 else .22) else 0
  p.CFrame=CFrame.new(self.position)*frame*CFrame.Angles(0,0,if string.find(p.Name,"wing") then flutter else 0)
 end
 self.drawnPosition=self.position
 end
 local solid=arrival>=1 and self.leaving==0
 for _,p in self.supports:GetChildren() do if p.CanCollide~=solid then p.CanCollide=solid;p.CanQuery=solid end end
end
-- A real view, a close range and an unblocked world ray; no notebook discovery
-- through a wall or simply because a remote event is active.
function Body.observe(self: any,dt: number,camera: Camera,spider: Vector3,book: any)
 if self.position==nil or self.leaving>0 then self.seen=0;return end
 local at=self.position+Vector3.yAxis*.3
 local point,onScreen=camera:WorldToViewportPoint(at)
 local visible=onScreen and point.Z>0 and (at-spider).Magnitude<=30
 if visible then
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={self.root}
  local hit=Workspace:Raycast(camera.CFrame.Position,at-camera.CFrame.Position,params)
  visible=hit==nil or hit.Instance:IsDescendantOf(self.supports)
 end
 self.seen=if visible then self.seen+dt else 0
 if self.seen>=.75 then book:notice("rare_luna") end
end
return Body
