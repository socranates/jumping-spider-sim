local Growth=require("../src/Shared/Life/Growth")
local LifeLoop=require("../src/Shared/Life/LifeLoop")
local Needs=require("../src/Shared/Life/NeedsModel")
local Session=require("../src/Shared/Life/LifeSession")
local Rig=require("../src/Shared/Rig/SpiderRig")
local Dance=require("../src/Shared/Rig/PeacockDance")
local Camera=require("../src/Client/SpiderCamera")
local OldSkins=require("../src/Client/OldSkins")
local Soundscape=require("../src/Client/Soundscape")
local reference=require("./growth_reference")
local passed,failed=0,0
local function check(v,msg) if v then passed+=1 else failed+=1;print("FAIL GROWTH "..msg) end end
local function same(a,b): boolean
 if type(a)~="table" then return if type(a)=="number" and type(b)=="number" then math.abs(a-b)<1e-8 else a==b end
 if type(b)~="table" then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 return true
end
local g=Growth.new()
for i,r in reference do
 local a=r.action;local result=nil
 if a.kind=="eat" then result=g:eat(a.n)
 elseif a.kind=="begin" then result=g:beginMoult()
 elseif a.kind=="hours" then result=g:passHours(a.n,Vector3.new(-25.5,.31,6))
 else local record=g:toRecord();g=Growth.new();assert(g:load(record)) end
 check(result==r.result,`golden {i} result`)
 check(same(g:toRecord(),r.record),`golden {i} state`)
 check(same(g:reachFactor(),r.reach) and same(g:softness(),r.softness) and g:stageName()==r.name,`golden {i} presentation`)
end
for _,n in {0/0,math.huge,-math.huge,-1,0} do
 local before=g:toRecord();g:eat(n);g:passHours(n,Vector3.zero)
 check(same(g:toRecord(),before),"invalid inputs do nothing")
end
local invalid=g:toRecord();invalid.stage=4
check(not g:load(invalid) and g.stage==3,"invalid restore changes nothing")
local s={inRetreat=true,attached=true,still=true,holding=false,feeding=false,position=Vector3.new(-25,.31,6)}
for _,fps in {30,60,144} do
 local n=Needs.new(true,false);local saves=0
 local life=LifeLoop.new(n,function() saves+=1;return {ok=true,message="Checkpoint kept."} end)
 n.grantedTotal+=.9
 life:step(1/fps,s,false,false)
 check(life.growth.ready and not life.resting,`{fps} actual food reaches threshold`)
 local outside=table.clone(s);outside.inRetreat=false
 life:step(1/fps,outside,true,false)
 check(not life.growth:isMoulting(),`{fps} cannot moult outside crack`)
 life:step(1/fps,s,true,false)
 check(life.growth:isMoulting() and saves==1,`{fps} rest starts and saves moult`)
 life:step(1/fps,s,true,true)
 check(life.resting and life.growth:isMoulting(),`{fps} inputs cannot cancel moult`)
 local loopRecord=life:toRecord()
 local restored=LifeLoop.new(n,nil);assert(restored:load(loopRecord))
 check(same(life.growth:toRecord(),restored.growth:toRecord()),`{fps} interrupted moult restored`)
 for _=1,math.ceil(12/1.4*fps) do life:step(1/fps,s,false,false) end
 check(life.growth.stage==1 and #life.growth.exuviae==1 and life.growth:isSoft() and saves==2,`{fps} completes once and saves`)
 check(life.growth:reachFactor()==.7,`{fps} soft reach`)
 life.grantedSeen=n.grantedTotal;life:step(1/fps,s,false,false)
 check(life.growth.fedSinceMoult==0,`{fps} food never counted twice`)
end
for _,mode in {"main","free"} do
 local session=Session.new();session:begin(mode,false)
 check(session:finishAdult(3)==(mode=="main"),"only main standard opens Easy")
 check(not session:finishAdult(3),"adult transition idempotent")
end
local floor=BoxWorld.folder("GrowthFloor",{{name="floor",lo=Vector3.new(-5,-1,-5),hi=Vector3.new(5,0,5),profile="painted_wood_dry"}})
for _,id in {"first_spider","maratus_volans_male"} do
 for _,tier in {"full","low"} do
  local rig=Rig.new(floor,floor,id,tier);rig.reducedMotion=true
  local body=CFrame.new(0,.31,0)
  rig:update(body,1/60,true,false)
  local baseSize=rig.model:FindFirstChild("Cephalothorax").Size
  local rootSize=rig.root.Size
  for stage=0,3 do
   rig:setGrowthStage(stage)
   local anchors={};for i,l in rig._legs do anchors[i]=l.foot end
   rig:update(body,0,true,false)
   for i,l in rig._legs do check((l.foot-anchors[i]).Magnitude<1e-6,"growth keeps planted feet") end
   check((rig.model:FindFirstChild("Cephalothorax").Size-baseSize*Growth.SCALES[stage+1]).Magnitude<1e-6,"body scaled per stage")
   check((rig.root.Position-body.Position).Magnitude<1e-6 and rig.root.Size==rootSize,"collider frame and size unchanged")
   for _=1,15 do rig:update(body,1/30,true,false) end
   for _,l in rig._legs do check(l.planted~=nil and math.abs(l.foot.Y)<1e-5,"feet settle on floor") end
  end
  local head=rig.model:FindFirstChild("Cephalothorax");local color=head.Color
  rig:setSoftness(1);check(head.Color.R>color.R,"pale soft skin")
  rig:setSoftness(0);check(math.abs(head.Color.R-color.R)<1e-6 and math.abs(head.Color.G-color.G)<1e-6 and math.abs(head.Color.B-color.B)<1e-6,"pigment returns")
  rig:setCondition(0);rig:update(body,10,true,false)
  local small=rig.model:FindFirstChild("Abdomen").Size
  rig:setCondition(1);rig:update(body,10,true,false)
  check(rig.model:FindFirstChild("Abdomen").Size.X>small.X*1.3,"abdomen fills independently")
  if id=="maratus_volans_male" then
   rig.dance=Dance.rawPose(5.2,false);rig:update(body,1/60,true,false)
   check(rig._fan.front[1].part.Size.X>.4,"adult fan still opens")
   rig:setEyeView(true)
   check(rig._fan.front[1].part.LocalTransparencyModifier==1,"fan hidden in eye view")
  end
  rig:destroy()
 end
end
local params=RaycastParams.new();params.FilterDescendantsInstances={floor}
local camera={CameraType=nil,FieldOfView=70,CFrame=CFrame.identity,ViewportSize=Vector2.new(1280,720)}
local target={pos=Vector3.new(0,.31,0),drawnUp=Vector3.yAxis,heading=-Vector3.zAxis,cameraScale=.62}
local cam=Camera.new(camera,params,function() return target end,function() end);cam.mouse=false
local zoom=cam.distance
for _=1,120 do cam:tick(1/60) end
check(math.abs(cam:viewDistance()-zoom*.62)<.01 and cam.distance==zoom,"peacock closer without changing manual zoom")
target.cameraScale=1
for _=1,120 do cam:tick(1/60) end
check(math.abs(cam:viewDistance()-zoom)<.01,"first spider framing restored")
local skins=OldSkins.new(floor);skins:draw({Vector3.new(0,.31,0),Vector3.new(1,.31,0)})
check(#skins.folder:GetChildren()==18,"old skins rendered")
skins:draw({});check(#skins.folder:GetChildren()==0,"new life removes old skins")
local sound=Soundscape.new(floor)
check(sound.room.Volume<.12,"room hum quieter")
print(`GROWTH passed={passed} failed={failed}`)
if failed>0 then error("growth checks failed") end
