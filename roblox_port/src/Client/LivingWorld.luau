--!strict
-- The close world: bounded local detail, ambient animals, and weather. No movement/save/attack rules live here.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Environment=require(Shared.World.Environment)
local Sites=require(Shared.World.LivedInSites)
local Shapes=require(Shared.Habitat.Shapes)
local DayLight=require(Shared.Habitat.DayLight)
local DogGait=require(Shared.Rig.DogGait)
local DogGround=require(Shared.World.DogGround)
local Meshes=require(Shared.Data.Meshes)
local AntForage=require(Shared.World.AntForage)
local LivingWorld={}
LivingWorld.__index=LivingWorld
LivingWorld.BUDGET={full=420,low=150}
LivingWorld.CELL=12
local AWAY=CFrame.new(0,-900,0)
local TAU=math.pi*2

local function hex(s: string): Color3 return Color3.fromHex(s) end
local function visible(rig: any,on: boolean)
 if rig.shown==on then return end
 rig.shown=on
 for _,p in rig.parts do p.Transparency=if on then p:GetAttribute("VisibleAlpha") or 0 else 1 end
end
function LivingWorld.part(self: any,parent: Instance,name: string,size: Vector3,color: string,shape: string?,material: string?,alpha: number?): BasePart
 assert(self.count<self.limit,"living-world part budget exceeded")
 local p: BasePart=if shape=="ellipsoid" then Shapes.ellipsoid(parent,name,size,AWAY,hex(color),material or "SmoothPlastic")
  else Shapes.block(parent,name,size,AWAY,hex(color),material or "SmoothPlastic")
 if shape=="grass" then
  p.Color=Color3.new(1,1,1)
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.FileMesh
  mesh.MeshId=Meshes.list.grass_clump.id;mesh.TextureId=Meshes.TEXTURE
  local native=Meshes.list.grass_clump.size
  mesh.Scale=Vector3.new(size.X/native.X,size.Y/native.Y,size.Z/native.Z);mesh.Parent=p
 end
 p:SetAttribute("VisibleAlpha",alpha or 0);p.Transparency=alpha or 0
 self.count+=1;return p
end
function LivingWorld.rig(self: any,kind: string,index: number): any
 local folder=Shapes.folder(self.animals,kind..index)
 local r={folder=folder,parts={},kind=kind,index=index,shown=true}
 local function ell(n: string,size: Vector3,c: string)
  local p=self:part(folder,n,size,c,"ellipsoid");table.insert(r.parts,p);return p
 end
 if kind=="Flea" then
  ell("SideFlattenedBody",Vector3.new(.07,.17,.23),"4a2b1e")
  ell("Head",Vector3.new(.075,.095,.09),"60422a")
  for j=1,4 do table.insert(r.parts,self:part(folder,"Foreleg"..j,Vector3.new(.12,.014,.014),"60422a")) end
  for _,side in {"Left","Right"} do
   table.insert(r.parts,self:part(folder,side.."HindThigh",Vector3.new(.10,.025,.025),"60422a"))
   table.insert(r.parts,self:part(folder,side.."HindTibia",Vector3.new(.12,.014,.014),"60422a"))
  end
 elseif kind=="Grub" then
  for j=1,if self.low then 5 else 7 do ell(if j==1 then "BrownHead" else "CreamSegment"..j,Vector3.new(.32,.32,.32),if j==1 then "76462c" else "dbd0ae") end
 elseif kind=="Ant" then
  ell("Head",Vector3.new(.13,.13,.17),"30241c")
  ell("Thorax",Vector3.new(.09,.09,.14),"493025")
  ell("Abdomen",Vector3.new(.14,.13,.20),"241b18")
  for j=1,8 do table.insert(r.parts,self:part(folder,if j<=6 then "Leg"..j else "Antenna"..j,Vector3.new(.20,.018,.018),"38241a")) end
  ell("CarriedFragment",Vector3.new(.10,.07,.12),"b5a57c")
 end
 return r
end
function LivingWorld.new(ws: any,root: Instance,tier: string,map: any): any
 local folder=Shapes.folder(ws,"LivingHabitat")
 local self=setmetatable({ws=ws,root=root,map=map,folder=folder,static=Shapes.folder(folder,"CloseDetail"),
  animals=Shapes.folder(folder,"SmallLives"),weather=Shapes.folder(folder,"Weather"),count=0,staticCount=0,
  low=tier=="low",limit=LivingWorld.BUDGET[if tier=="low" then "low" else "full"],elapsed=0,acc=0,key="",windParts={},windAt=-100,
  rain={},fleas={},grubs={},ants={},litter={},lastLight=-100,rainAt=nil,state=nil,seed=914},LivingWorld)
 self.params=RaycastParams.new();self.params.FilterType=Enum.RaycastFilterType.Include;self.params.FilterDescendantsInstances={root}
 for i=1,if self.low then 2 else 5 do table.insert(self.fleas,self:rig("Flea",i)) end
 for i=1,if self.low then 1 else 3 do table.insert(self.grubs,self:rig("Grub",i)) end
 for i=1,if self.low then 3 else 8 do table.insert(self.ants,self:rig("Ant",i)) end
 for i=1,if self.low then 10 else 32 do
  local p=self:part(self.weather,"Rain"..i,Vector3.new(.018,1.2,.018),"c3d5dd",nil,"SmoothPlastic",.55)
  table.insert(self.rain,{part=p,offset=Vector3.new((Environment.hash(914,i,101)-.5)*42,0,(Environment.hash(914,i,103)-.5)*42),floor=-math.huge})
 end
 for i=1,if self.low then 2 else 5 do
  local p=self:part(self.weather,"Windfall"..i,Vector3.new(.5,.035,.9),"9d774c","ellipsoid")
  table.insert(self.litter,p)
 end
 self:makeDog()
 folder:SetAttribute("PartBudget",self.limit)
 return self
end
function LivingWorld.makeDog(self: any)
 local folder=Shapes.folder(self.folder,"ParkDog")
 local rig={folder=folder,parts={},shown=true,frames={},moved={},gait=DogGait.new(),wander={},sniff=0}
 local function add(name: string,size: Vector3,at: Vector3,c: string,turn: Vector3?)
  local p=self:part(folder,name,size,c,"ellipsoid")
  p.CastShadow=not self.low and (name=="Ribcage" or name=="Chest" or name=="Head")
  table.insert(rig.parts,p);table.insert(rig.frames,CFrame.new(at)*(if turn then CFrame.Angles(turn.X,turn.Y,turn.Z) else CFrame.identity))
 end
 add("Ribcage",Vector3.new(23,24,50),Vector3.new(0,35,0),"a08057")
 add("Chest",Vector3.new(20,27,22),Vector3.new(0,34,-20),"b2946c")
 add("Haunch",Vector3.new(23,22,23),Vector3.new(0,33,20),"92724e")
 add("Neck",Vector3.new(17,23,18),Vector3.new(0,45,-24),"b2946c")
 add("Head",Vector3.new(18,17,22),Vector3.new(0,55,-31),"b89b75")
 add("Muzzle",Vector3.new(13,9,16),Vector3.new(0,50,-43),"c6b18e")
 add("Nose",Vector3.new(8,5,4),Vector3.new(0,51,-51),"28221e")
 add("Jaw",Vector3.new(11,3,12),Vector3.new(0,46,-43),"8c7358")
 for _,s in {-1,1} do
  add("Eye"..s,Vector3.new(1.4,1.4,1.2),Vector3.new(s*7.5,57,-39),"171613")
  add("Ear"..s,Vector3.new(7,17,7),Vector3.new(s*9,50,-27),"775a40",Vector3.new(.2,0,s*.18))
 end
 add("Collar",Vector3.new(19,2,20),Vector3.new(0,46,-24),"536c76")
 add("Tag",Vector3.new(3,4,.5),Vector3.new(0,42,-34),"c2ac69")
 add("Tail",Vector3.new(4,4,25),Vector3.new(0,40,38),"9b7a51",Vector3.new(-.35,0,0))
 rig.legStart=#rig.parts+1
 for _,z in {-20,19} do for _,x in {-8,8} do
  add("UpperLeg",Vector3.new(6,DogGait.UPPER,7),Vector3.new(x,23,z),"a48660")
  add("LowerLeg",Vector3.new(4.5,DogGait.LOWER,5),Vector3.new(x,8,z),"b79e7a")
  add("Paw",Vector3.new(7,3,10),Vector3.new(x,1.7,z-2),"c0aa87")
 end end
 self.dog=rig
end
function LivingWorld.ground(self: any,at: Vector3,up: number?,down: number?): any
 return self.ws:Raycast(at+Vector3.new(0,up or 18,0),Vector3.new(0,-(down or 130),0),self.params)
end
function LivingWorld.rebuild(self: any,pos: Vector3,region: any)
 self.static:Destroy();self.count-=self.staticCount;self.staticCount=0
 self.static=Shapes.folder(self.folder,"CloseDetail")
 self.grass={};self.grassParts={};self.grassFrames={}
 self.patches={}
 local floor=region.kind=="hut_floor" or region.kind=="room_floor" or region.kind=="kitchen_floor" or region.kind=="hut_doorway"
 local soil=region.kind=="verge" or region.kind=="hut_path" or region.kind=="mown_path" or string.match(region.id,"^garden_[a-d][1-4]$")~=nil or string.match(region.id,"^meadow_")~=nil or region.kind=="bed" or region.kind=="shrub"
 if not floor and not soil then return end
 local limit=if self.low then 48 else 150
 local cx,cz=math.floor(pos.X/LivingWorld.CELL),math.floor(pos.Z/LivingWorld.CELL)
 local offsets={{0,0},{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{1,1},{-1,1},{1,-1}}
 for _,off in offsets do
  local gx,gz=cx+off[1],cz+off[2]
  for i=1,if self.low then 3 else 6 do
   local salt=gx*7919+gz*104729
   local x=(gx+Environment.hash(914,salt,i*2))*LivingWorld.CELL
   local z=(gz+Environment.hash(914,salt,i*2+1))*LivingWorld.CELL
   local point=Vector3.new(x,region.spawn.pos.Y,z)
   local hit=self:ground(point)
   if hit==nil or hit.Normal.Y<.75 or math.abs(hit.Position.Y-pos.Y)>30 then continue end
   local at=hit.Position+Vector3.new(0,.025,0)
   local groundPart=hit.Instance
   local grows=(region.kind=="verge" and groundPart.Material==Enum.Material.Ground and string.find(groundPart.Name,"_soil_",1,true)~=nil)
    or (string.match(region.id,"^meadow_")~=nil and groundPart.Material==Enum.Material.Grass)
   if grows and i==1 then table.insert(self.patches,at) end
   local before=self.count
   local function part(n: string,size: Vector3,cf: CFrame,c: string,shape: string?,material: string?,alpha: number?): BasePart?
    if self.staticCount+self.count-before>=limit or self.count>=self.limit then return nil end
    local p=self:part(self.static,n,size,c,shape,material,alpha);p.CFrame=cf;return p
   end
   local a=Environment.hash(914,salt,i+81)*TAU
   if floor and i==1 then
    part("DustBunny",Vector3.new(1.1,.19,.75),CFrame.new(at+Vector3.new(0,.08,0)),"99918b","ellipsoid","SmoothPlastic",.42)
    if not self.low then
     part("DustFibreClump",Vector3.new(.64,.21,.47),CFrame.new(at+Vector3.new(.3,.09,-.18)),"8c8681","ellipsoid","SmoothPlastic",.38)
     part("DustFibreClump",Vector3.new(.72,.16,.52),CFrame.new(at+Vector3.new(-.29,.065,.12)),"a39b91","ellipsoid","SmoothPlastic",.4)
    end
    -- Joined strands lie mostly along the boards; part count stays 7/3.
    for j=1,if self.low then 1 else 2 do
     local h=a+j*2.4
     local joint=at+Vector3.new(math.sin(h)*.25,.13,math.cos(h)*.18)
     for k,angle in {h,h+.7} do
      local direction=Vector3.new(math.cos(angle),.10*(if k==1 then 1 else -1),math.sin(angle)).Unit
      local length=if k==1 then .5 else .36
      local centre=joint+direction*length*(if k==1 then -.5 else .5)
      part("EntangledFibre",Vector3.new(length,.012,.012),CFrame.lookAt(centre,centre+direction)*CFrame.Angles(0,math.pi/2,0),"b7b0a5",nil,nil,.12)
     end
    end
   elseif floor and i<=3 then
    part("BreadCrumb",Vector3.new(.10+.15*i,.12,.18),CFrame.new(at+Vector3.new(0,.045,0))*CFrame.Angles(.15,a,.1),"ba9b69","ellipsoid")
   elseif floor then
    part(if i==4 then "LooseHair" else "TextileThread",Vector3.new(1.1,.018,.024),CFrame.new(at)*CFrame.Angles(0,a,.04),if i==4 then "51473b" else "8a8a96")
   elseif grows and (i%3==2 or (not self.low and i>=4)) then
     local height=4+Environment.hash(914,salt,i*71)*3.5
     local size=Meshes.list.grass_clump.size*(height/Meshes.list.grass_clump.size.Y)
     local cf=CFrame.new(at)*CFrame.Angles(0,a,0)*CFrame.new(0,height/2,0)
     local p=part("GrassClump",size,cf,"ffffff","grass")
     if p then
      table.insert(self.grass,{part=p,base=cf,pivot=at,rootLocal=cf:PointToObjectSpace(at),phase=a})
      table.insert(self.grassParts,p);table.insert(self.grassFrames,cf)
     end
   elseif i%3==0 then
    part("SeedHusk",Vector3.new(.24,.12,.66),CFrame.new(at+Vector3.new(0,.06,0))*CFrame.Angles(0,a,.15),"b79a63","ellipsoid")
   elseif i%3==1 then
    part("CurledLeafLitter",Vector3.new(1.5,.07,.65),CFrame.new(at+Vector3.new(0,.08,0))*CFrame.Angles(.17,a,.11),"8c6744","ellipsoid")
    part("LeafMidrib",Vector3.new(1.3,.025,.025),CFrame.new(at+Vector3.new(0,.13,0))*CFrame.Angles(0,a,.11),"c3a26c")
   else
    part("SoilGrain",Vector3.new(.12,.09,.17),CFrame.new(at+Vector3.new(0,.03,0)),"9b8565","ellipsoid")
   end
   self.staticCount+=self.count-before
  end
 end
end
function LivingWorld.lighting(self: any,state: any,clock: any)
 local lighting=game:GetService("Lighting")
 local targets=DayLight.targets(state.solar.daylight,clock.hour)
 local sun=Environment.nativeSun(state.solar.direction)
 targets.clock=sun.clock;targets.brightness*=1-state.cloud*.45;targets.exposure-=state.rain*.30
 targets.sunRays*=1-state.cloud*.9;targets.shafts*=1-state.cloud*.85
 if state.solar.direction.Y<.15 or state.solar.direction.Z>-.05 then targets.shafts=0 end
 DayLight.apply(lighting,targets,self.ws:FindFirstChild("Decor"))
 local decor=self.ws:FindFirstChild("Decor")
 local shafts=if decor then decor:FindFirstChild("Shafts") else nil
 if shafts and targets.shafts>.01 then
  for _,anchor in shafts:GetChildren() do
   if anchor:IsA("BasePart") then
    local endpoint=anchor:FindFirstChild("End")
    if endpoint and endpoint:IsA("Attachment") then
     local distance=math.max(0,anchor.Position.Y-.05)/state.solar.direction.Y
     endpoint.Position=anchor.CFrame:VectorToObjectSpace(-state.solar.direction*distance)
    end
   end
  end
 end
 lighting.GeographicLatitude=sun.latitude
 local a=lighting:FindFirstChild("Atmosphere")
 if a then a.Density=.28+.08*state.cloud+state.mist*.18;a.Haze=1+state.rain*1.5 end
 local terrain=self.ws:FindFirstChildWhichIsA("Terrain")
 if terrain then local clouds=terrain:FindFirstChildWhichIsA("Clouds");if clouds then clouds.Cover=state.cloud;clouds.Density=.35+.5*state.cloud end end
 self.ws.GlobalWind=state.wind*12
 self.folder:SetAttribute("Weather",state.name);self.folder:SetAttribute("Wetness",state.wetness)
 self.folder:SetAttribute("TemperatureC",state.temperature);self.folder:SetAttribute("SolarAltitude",state.solar.altitude)
end
function LivingWorld.sway(self: any,pos: Vector3,state: any,reduced: boolean)
 if self.elapsed-self.windAt>3 then
  for _,row in self.windParts do if row.part.Parent then row.part.CFrame=row.base end end
  self.windParts={};self.windAt=self.elapsed
  local decor=self.ws:FindFirstChild("WorldDecor")
  if decor then
   for _,p in decor:GetDescendants() do
    if #self.windParts>=(if self.low then 8 else 28) then break end
    if p:IsA("BasePart") and not p.CanQuery and not string.find(p.Name,"_litter_",1,true)
     and (string.find(p.Name,"Leaf",1,true) or string.find(p.Name,"Blade",1,true)) and (p.Position-pos).Magnitude<60 then
     table.insert(self.windParts,{part=p,base=p.CFrame,phase=p.Position.X*.3+p.Position.Z*.14})
    end
   end
  end
 end
 for _,row in self.windParts do
  if row.part.Parent then row.part.CFrame=row.base*CFrame.Angles(if reduced then 0 else math.sin(self.elapsed*2+row.phase)*math.min(.012,state.wind.Magnitude*.003),0,0) end
 end
 for i,row in self.grass or {} do
  local angle=if reduced then 0 else math.sin(self.elapsed*2+row.phase)*math.min(.1,state.wind.Magnitude*.025)
  self.grassFrames[i]=CFrame.new(row.pivot)*CFrame.Angles(angle,0,-angle*.4)*CFrame.new(-row.pivot)*row.base
 end
 if self.grassParts and #self.grassParts>0 then self.ws:BulkMoveTo(self.grassParts,self.grassFrames,Enum.BulkMoveMode.FireCFrameChanged) end
end
function LivingWorld.small(self: any,pos: Vector3,region: any,state: any,reduced: boolean)
 local indoor=region.kind=="hut_floor" or region.kind=="room_floor"
 local patches=self.patches or {}
 for i,r in self.fleas do
  local on=indoor and math.abs(pos.Y+70)<12;visible(r,on)
  if on then
   local lo,hi=region.bounds[1],region.bounds[2]
   local at=Vector3.new(lo.X+(hi.X-lo.X)*(.12+i*.14),-69.89,lo.Z+(hi.Z-lo.Z)*Environment.hash(region.seed,i,73))
   on=(at-pos).Magnitude<30
   if r.region~=region.id then
    r.region=region.id;r.supported=self:ground(at,2,5)~=nil
   end
   on=on and r.supported
   visible(r,on)
   if not on then continue end
   local delta,hop,heading=Environment.flea(if reduced then 0 else state.totalHours*75,i)
   if reduced then delta=Vector3.zero;hop=false end
   local frame=CFrame.lookAt(at+delta,at+delta+heading)
   r.parts[1].CFrame=frame
   r.parts[2].CFrame=frame*CFrame.new(0,.025,-.145)
   local function segment(part: BasePart,a: Vector3,b: Vector3)
    part.CFrame=frame*CFrame.lookAt((a+b)*.5,b)*CFrame.Angles(0,math.pi/2,0)
   end
   for leg=1,4 do
    local sign=if leg%2==0 then 1 else -1
    local hip=Vector3.new(sign*.025,-.035,if leg<=2 then -.08 else 0)
    local direction=Vector3.new(sign*.8,if hop then -.2 else -.6,if leg<=2 then -.2 else .1).Unit
    segment(r.parts[leg+2],hip,hip+direction*.12)
   end
   for side=1,2 do
    local sign=if side==1 then -1 else 1
    local hip=Vector3.new(sign*.035,-.015,.06)
    local knee=hip+Vector3.new(sign*.5,if hop then -.15 else -.7,.4).Unit*.10
    local foot=knee+Vector3.new(sign*.3,if hop then .5 else -.2,if hop then -.9 else .9).Unit*.12
    segment(r.parts[5+side*2],hip,knee);segment(r.parts[6+side*2],knee,foot)
   end
  end
 end
 for i,r in self.grubs do
  local at=patches[i];local rise,phase=Environment.grub(state.day,state.hour,i,state.wetness)
  local on=at~=nil and rise>.04 and not indoor;visible(r,on)
  if on then
   local base=at+Vector3.new(0,-.25+(if reduced then .6 else rise)*.6,0)
   for j,p in r.parts do
    local a=(j-1)*.42
    p.CFrame=CFrame.new(base+Vector3.new(math.cos(a)*.52,if reduced then 0 else .10*math.sin(phase*2+j),math.sin(a)*.52))
   end
  end
 end
 local hill=Sites.nearAnthill(pos)
 for i,r in self.ants do
  local seconds=if reduced then 0 else state.totalHours*75
  local pose=AntForage.sample(seconds,i);r.pose=pose
  local on=hill~=nil and state.rain<.5 and state.solar.daylight>.15 and pose.visible;visible(r,on)
  if on then
   local at=hill.at+pose.offset+Vector3.new(0,Sites.antHeight(pose.offset)+.11-pose.burrow,0)
   local frame=CFrame.lookAt(at,at+pose.heading)
   for j=1,3 do r.parts[j].CFrame=frame*CFrame.new(0,0,(j-2)*.13) end
   for j=1,6 do
    local side=if j%2==0 then 1 else -1;local wave=if reduced or not pose.moving then 0 else math.sin(seconds*TAU*3+j)*.18
    r.parts[j+3].CFrame=frame*CFrame.new(side*.12,-.04,(math.ceil(j/2)-2)*.09)*CFrame.Angles(0,side*.5+wave,side*.3)
   end
   local feel=if reduced or pose.mode~="forage" then 0 else math.sin(seconds*5+i)*.16
   for j=1,2 do r.parts[9+j].CFrame=frame*CFrame.new((if j==1 then -1 else 1)*.07,.05,-.23)*CFrame.Angles(0,(if j==1 then -.4-feel else .4+feel),0) end
   r.parts[12].CFrame=frame*CFrame.new(0,.015,-.28)
   r.parts[12].Transparency=if pose.carrying then 0 else 1
  end
 end
end
function LivingWorld.drawDog(self: any,pos: Vector3,state: any,reduced: boolean,dt: number)
 local r=self.dog
 local pose=Environment.stepDog(r.wander,state.totalHours*75,state.rain)
 local on=pose.visible and (pose.position-pos).Magnitude<520
 if not on then visible(r,false);r.gait.previous=nil;return end
 if r.terrain==nil then r.terrain=DogGround.new(self.map) end
 local function terrain(at: Vector3,up: number,down: number): Vector3?
  local hit=self:ground(at,up,down)
  if hit and hit.Normal.Y>.5 then return hit.Position end
  return DogGround.at(r.terrain,at,up,down)
 end
 local base=terrain(pose.position,6,18)
 if base==nil then visible(r,false);r.gait.previous=nil;return end
 local frame=CFrame.lookAt(base,base+pose.heading)
 local gait=DogGait.step(r.gait,frame,dt,function(at: Vector3): Vector3?
  local hit=terrain(at,10,30)
  return if hit and math.abs(hit.Y-base.Y)<8 then hit else nil
 end,reduced)
 visible(r,gait.supported);if not gait.supported then return end
 local stride=if reduced or pose.sniff then 0 else pose.stride
 r.sniff=if reduced then (if pose.sniff then 1 else 0) else math.clamp(r.sniff+(if pose.sniff then dt*3.5 else -dt*5),0,1)
 local headTurn=CFrame.new(0,-36*r.sniff,-12*r.sniff)*CFrame.new(0,55,-31)*CFrame.Angles(-.55*r.sniff,0,0)*CFrame.new(0,-55,31)
 for i,p in r.parts do
  local f=r.frames[i]
  if p.Name=="Head" or p.Name=="Muzzle" or p.Name=="Nose" or p.Name=="Jaw" or string.find(p.Name,"Eye",1,true) or string.find(p.Name,"Ear",1,true) then
   f=headTurn*f
  elseif p.Name=="Neck" then f=CFrame.new(0,45-15*r.sniff,-24-6.5*r.sniff)*CFrame.Angles(.882*r.sniff,0,0)
  elseif p.Name=="Tail" then f=CFrame.new(0,36,27)*CFrame.Angles(0,if reduced then 0 else pose.tail,0)*CFrame.new(0,-36,-27)*f
  elseif i>=r.legStart then
   local leg=math.floor((i-r.legStart)/3)+1
   local bone=(i-r.legStart)%3
   local foot=gait.feet[leg]
   if bone<2 then
    local a,b=if bone==0 then foot.hip else foot.knee,if bone==0 then foot.knee else foot.ankle
    r.moved[i]=CFrame.lookAt((a+b)/2,b)*CFrame.Angles(math.pi/2,0,0)
   else
    local at=foot.anchor+Vector3.yAxis*1.5
    r.moved[i]=CFrame.lookAt(at,at+foot.heading)
   end
   continue
  end
  r.moved[i]=frame*CFrame.new(0,math.abs(stride)*.6,0)*f
 end
 self.ws:BulkMoveTo(r.parts,r.moved,Enum.BulkMoveMode.FireCFrameChanged)
end
function LivingWorld.rainfall(self: any,pos: Vector3,region: any,state: any,reduced: boolean)
 local indoor=Environment.INDOORS[region.kind]==true
 local centre=pos
 if indoor then centre=Vector3.new(pos.X,pos.Y,-105) end
 if self.rainAt==nil or (centre-self.rainAt).Magnitude>8 then
  self.rainAt=centre
  for _,r in self.rain do
   local hit=self:ground(centre+r.offset,220,500)
   r.floor=if hit then hit.Position.Y else pos.Y-60
  end
 end
 for i,r in self.rain do
  local on=state.rain>.035 and not reduced and (not indoor or math.abs(pos.Z)<40)
  local phase=(self.elapsed*400+i*13.77)%65
  local at=centre+r.offset+Vector3.new(0,45-phase,0)
  on=on and at.Y>r.floor+.15
  r.part.Transparency=if on then .5+(1-state.rain)*.28 else 1
  if on then r.part.CFrame=CFrame.new(at)*CFrame.Angles(state.wind.Z*.018,0,-state.wind.X*.018) end
 end
 for i,p in self.litter do
  local on=not indoor and state.wind.Magnitude>.8 and not reduced
  p.Transparency=if on then .05 else 1
  if on then
   local t=self.elapsed*(.8+state.wind.Magnitude*.6)+i*7
   local direction=state.wind.Unit
   local across=Vector3.new(-direction.Z,0,direction.X)
   local leafCentre=Vector3.new(math.floor(pos.X/24)*24+12,pos.Y,math.floor(pos.Z/24)*24+12)
   local at=leafCentre+direction*((t%30)-15)+across*math.sin(i*8)*12
   self.litterGround=self.litterGround or {}
   local cached=self.litterGround[i]
   if cached==nil or self.elapsed-cached.time>.5 or (at-cached.at).Magnitude>5 then
    local hit=self:ground(at,12,40)
    cached={at=at,time=self.elapsed,y=if hit then hit.Position.Y else nil};self.litterGround[i]=cached
   end
   if cached.y then p.CFrame=CFrame.new(Vector3.new(at.X,cached.y+.15+math.abs(math.sin(t*2))*.3,at.Z))*CFrame.Angles(.2,t,.15) else p.Transparency=1 end
  end
 end
end
function LivingWorld.update(self: any,dt: number,pos: Vector3,clock: any,region: any,reduced: boolean,paused: boolean)
 if paused then return end
 self.elapsed+=math.clamp(dt,0,.15);self.acc+=dt
 local first=self.state==nil
 if not first then
  -- Body and planted feet run every rendered frame. Weather/detail keep their
  -- bounded 20 Hz update; cached rain does not quantise the animal's travel.
  self:drawDog(pos,{totalHours=(clock.day-1)*24+clock.hour,rain=self.state.rain},reduced,dt)
 end
 if self.acc<.05 then return end;self.acc=0
 local state=Environment.sample(clock.day,clock.hour,self.seed);self.state=state
 local key=region.id..":"..math.floor(pos.X/24)..":"..math.floor(pos.Z/24)..":"..math.floor(pos.Y/30)
 if key~=self.key then self.key=key;self:rebuild(pos,region) end
 if self.elapsed-self.lastLight>.5 then self:lighting(state,clock);self.lastLight=self.elapsed end
 self:small(pos,region,state,reduced);if first then self:drawDog(pos,state,reduced,dt) end
 self:rainfall(pos,region,state,reduced);self:sway(pos,state,reduced)
 self.folder:SetAttribute("Parts",self.count)
end
function LivingWorld.destroy(self: any)
 for _,row in self.windParts do if row.part.Parent then row.part.CFrame=row.base end end
 self.folder:Destroy()
end
return LivingWorld
