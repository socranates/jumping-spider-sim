-- Litter must add real shelter and stable footholds without breaking ground,
-- population starts, low-detail visibility or the spawn corridor.
local Map=require("../src/Shared/World/WorldMap")
local Region=require("../src/Shared/World/Region")
local Build=require("../src/Shared/World/WorldBuild")
local Verge=require("../src/Shared/World/Verge")
local Garden=require("../src/Shared/World/Garden")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Director=require("../src/Shared/Prey/PreyDirector")
local passed,failed,leaves,colliders=0,0,0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL LITTER "..msg) end end
local function overlap(a,b)
 return a.lo.X<b.hi.X-1e-6 and a.hi.X>b.lo.X+1e-6 and a.lo.Y<b.hi.Y-1e-6 and a.hi.Y>b.lo.Y+1e-6 and a.lo.Z<b.hi.Z-1e-6 and a.hi.Z>b.lo.Z+1e-6
end
Map.use("preserve")
local root=Build.world(workspace)
local casts=Director.casts(root)
local lo,hi=Map.bounds()
local motor=Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Vector3.new(-25.5,.31,6),heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi})
local idle=Motor.idleInput()
local walked={}
for _,r in Map.regions() do
 if r.kind~="verge" then continue end
 local pieces=Verge.pieces(r)
 local looks={};local full,low=0,0
 for _,d in Region.decor(r) do
  looks[d.id]=d;full+=1;if not d.full then low+=1 end
  if string.find(d.id,"_clover_",1,true) then
   local supported=false
   for _,soil in pieces do
    if string.find(soil.id,"_soil_",1,true) and d.at.X-d.size.X/2>=soil.lo.X-1e-6 and d.at.X+d.size.X/2<=soil.hi.X+1e-6
     and d.at.Z-d.size.Z/2>=soil.lo.Z-1e-6 and d.at.Z+d.size.Z/2<=soil.hi.Z+1e-6 then supported=true end
   end
   check(supported,d.id.." stays above actual ground rather than an excluded region")
  end
 end
 check(full<=Region.budget(r.kind,"full") and low<=Region.budget(r.kind,"low"),r.id.." fits both detail budgets")
 for i,a in pieces do
  for j=i+1,#pieces do check(not overlap(a,pieces[j]),a.id.." has no overlapping collision") end
  if not string.find(a.id,"_litter_",1,true) then continue end
  colliders+=1
  local ground=false
  for _,soil in pieces do
   if string.find(soil.id,"_soil_",1,true) and a.lo.X>=soil.lo.X and a.hi.X<=soil.hi.X and a.lo.Z>=soil.lo.Z and a.hi.Z<=soil.hi.Z then ground=true end
  end
  check(ground,a.id.." remains over real soil, outside excluded hazards")
  check(looks[a.id.."_look"]~=nil and not looks[a.id.."_look"].full,a.id.." remains visible on low detail")
  if string.sub(a.id,-5)~="_leaf" then continue end
  leaves+=1
  local centre=(a.lo+a.hi)/2
  local shelterHit=casts.cast(Vector3.new(centre.X,Verge.TOP+5,centre.Z),Vector3.new(centre.X,Verge.TOP+.5,centre.Z))
  check(shelterHit~=nil and shelterHit.Instance.Name==a.id,a.id.." provides real overhead occlusion")
  for _,y in {a.hi.Y+.31,Verge.TOP+.31} do
   local at=Vector3.new(centre.X,y,centre.Z)
   motor:place(at,Vector3.yAxis,Vector3.xAxis)
   for _=1,20 do motor:tick(idle) end
   check(motor.mode=="attached" and (motor.pos-at).Magnitude<.02,a.id.." is stable above and beneath its leaf")
  end
  local sizeClass=if a.hi.X-a.lo.X<10 then "narrow" else "wide"
  if not walked[sizeClass] then
   walked[sizeClass]=true
   motor:place(Vector3.new(centre.X,Verge.TOP+.31,a.lo.Z-1),Vector3.yAxis,Vector3.zAxis)
   local forward=Motor.idleInput();forward.wish=Vector3.zAxis
   for _=1,480 do motor:tick(forward);if motor.pos.Z>=centre.Z then break end end
   check(motor.mode=="attached" and motor.pos.Z>=centre.Z and math.abs(motor.pos.Y-Verge.TOP-.31)<.02,
    sizeClass.." shelter can be entered by walking through its open end")
  end
 end
 motor:place(r.spawn.pos+Vector3.yAxis*.31,Vector3.yAxis,r.spawn.heading)
 for _=1,20 do motor:tick(idle) end
 check((motor.pos-r.spawn.pos-Vector3.yAxis*.31).Magnitude<.02,r.id.." keeps its spawn clear")
 for _,spec in Garden.bestiary(r) or {} do
  local population=Director.engine(root,Species[spec.profile],spec.seed,spec.target,false,spec,casts)
  check(#population.flies==spec.target,r.id.." retains its "..spec.kind.." startup population")
 end
end
check(leaves>=40,"shelter is distributed across the shoulders")
check(walked.narrow and walked.wide,"walked both narrow and broad shoulder shelters")
print(`VERGE_LITTER passed={passed} failed={failed} shelters={leaves} colliders={colliders}`)
if failed>0 then error("litter checks failed") end
