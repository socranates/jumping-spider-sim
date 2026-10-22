-- Differential check under the CLI shim. Original module stays unmodified.
local Original=require("../src/Shared/Rig/SpiderRig")
local Cached=require("../src/Shared/Rig/RigCached")
local Appearances=require("../src/Shared/Data/Appearances")
local Living=require("../src/Shared/Rig/Living")
local Support=require("../src/Shared/Movement/SupportMath")
local floor=BoxWorld.folder("RigCacheReferenceFloor",{{name="floor",lo=Vector3.new(-20,-1,-20),hi=Vector3.new(20,0,20),profile="painted_wood_dry"}})
local checks,cases=0,0
local worstPos,worstAxis,worstSize=0,0,0
local function check(ok,why) checks+=1;assert(ok,why) end
local ids={};for id in Appearances.profiles do table.insert(ids,id) end;table.sort(ids)
for _,id in ids do
 for _,tier in {"full","low"} do
  local a,b=Original.new(floor,floor,id,tier),Cached.new(floor,floor,id,tier)
  for _,r in {a,b} do if r._living then r._living=Living.new(r._appearance.idle,4242) end end
  local pa,pb={},{}
  for _,p in a.model:GetChildren() do if p:IsA("BasePart") then table.insert(pa,p) end end
  for _,p in b.model:GetChildren() do if p:IsA("BasePart") then table.insert(pb,p) end end
  check(#pa==#pb,"part count")
  for f=1,200 do
   local grounded=f<141 or f>170
   local up=if f>110 and f<=140 then -Vector3.yAxis elseif f>80 and f<=110 then Vector3.xAxis else Vector3.yAxis
   local at=Vector3.new(.2*math.sin(f*.03),if grounded then .31 else 2,-f*.01)
   local cf=Support.bodyCFrame(at,up,-Vector3.zAxis)
   for _,r in {a,b} do
    if f==61 then r:setGrowthStage(2) elseif f==121 then r:setGrowthStage(3) elseif f==151 then r:setScale(1.7) end
    if f==30 then r:cue("groom") elseif f==75 then r:cue("alarm") end
    r:setCondition(.2+.1*math.sin(f*.02))
    r.hangDirection=if not grounded then Vector3.new(.07,1,.035).Unit else nil
    r.focusPoint=if f<40 then Vector3.new(1.5,.5,-2) else nil
    r.mealHeld=f>=180;r.mealPulse=if f>=180 then .5+.5*math.sin(f) else 0
    r:update(cf,1/60,grounded,f>40 and f<=80)
   end
   for i,p in pa do
    local q=pb[i];local ca,cb=p.CFrame,q.CFrame
    local pos=(ca.Position-cb.Position).Magnitude
    local axis=math.max((ca.RightVector-cb.RightVector).Magnitude,(ca.UpVector-cb.UpVector).Magnitude,(ca.LookVector-cb.LookVector).Magnitude)
    local size=(p.Size-q.Size).Magnitude
    worstPos,worstAxis,worstSize=math.max(worstPos,pos),math.max(worstAxis,axis),math.max(worstSize,size)
    check(p.Name==q.Name and p.Color.R==q.Color.R and p.Color.G==q.Color.G and p.Color.B==q.Color.B and p.Material==q.Material and p.Transparency==q.Transparency,"appearance")
    check(pos<1e-8 and axis<1e-8 and size<1e-8,"pose "..id.." "..tier.." "..f.." "..p.Name)
   end
   for i,leg in a._legs do
    local other=b._legs[i]
    check((leg.planted==nil)==(other.planted==nil),"planted presence")
    if leg.planted then check((leg.planted-other.planted).Magnitude<1e-12,"foot anchor") end
   end
  end
  cases+=1
  print(string.format("RIG_REFERENCE_CASE %s %s parts=%d",id,tier,#pa))
  a:destroy();b:destroy()
 end
end
print(string.format("RIG_REFERENCE passed=%d failed=0 cases=%d frames=%d worst_position=%.12g worst_axis=%.12g worst_size=%.12g",checks,cases,cases*200,worstPos,worstAxis,worstSize))
