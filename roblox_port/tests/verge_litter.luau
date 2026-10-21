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
-- The old two corner starts left a normal edge walk outside encounter range.
-- Measure coverage over a whole soil cell, not only the review's chosen pose.
local sampleRegion=assert(Map.region("verge_-400_-216"))
local sampleSpecs=Verge.bestiary(sampleRegion)
-- Background grass must cover the cell, not all collapse onto one hash-aligned
-- stripe; the low tier's first four clumps need broad distribution too.
for _,tier in {"full","low"} do
 local columns,rows={},{}
 local xmin,xmax,zmin,zmax=math.huge,-math.huge,math.huge,-math.huge
 for _,d in Region.decor(sampleRegion) do
  if not string.find(d.id,"_grass_clump_",1,true) or (tier=="low" and d.full) then continue end
  columns[math.floor((d.at.X+400)/20)]=true
  rows[math.floor((d.at.Z+216)/25)]=true
  xmin=math.min(xmin,d.at.X);xmax=math.max(xmax,d.at.X)
  zmin=math.min(zmin,d.at.Z);zmax=math.max(zmax,d.at.Z)
 end
 local nc,nr=0,0;for _ in columns do nc+=1 end;for _ in rows do nr+=1 end
 check(nc>=(if tier=="full" then 5 else 3) and nr>=(if tier=="full" then 4 else 3),tier.." background grass spans soil columns and rows")
 check(xmax-xmin>55 and zmax-zmin>55,tier.." background cover spreads across the cell")
end
local flySpec=sampleSpecs[2]
local fullStarts,lowStarts,oldStarts,oldLow={},{},{},{}
for _,p in flySpec.perches do
 if p.start then table.insert(fullStarts,p.position);if #lowStarts<flySpec.low then table.insert(lowStarts,p.position) end end
 if string.sub(p.id,-2)=="_4" or string.sub(p.id,-2)=="_9" then table.insert(oldStarts,p.position) end
 if string.sub(p.id,-2)=="_4" then table.insert(oldLow,p.position) end
end
local function coverage(points)
 local hits=0
 for x=0,19 do for z=0,19 do
  local at=Vector3.new(-400+(x+.5)*5,Verge.TOP,-216+(z+.5)*5)
  for _,p in points do if (Vector3.new(p.X,Verge.TOP,p.Z)-at).Magnitude<=25 then hits+=1;break end end
 end end
 return hits
end
check(coverage(fullStarts)>coverage(oldStarts)*1.4,"full starting populations cover more soil than the old opposite corners")
check(coverage(lowStarts)>coverage(oldLow)*1.7,"low starting populations also improve encounter coverage")
for _,spec in sampleSpecs do
 local rows={}
 local n=0
 for _,p in spec.perches do if p.start and n<spec.low then n+=1;rows[math.floor((p.position.Z+216)/ (100/3))]=true end end
 local count=0;for _ in rows do count+=1 end
 check(count==3,"low "..spec.kind.." starts occupy all three soil rows")
end
local walked={}
for _,r in Map.regions() do
 if r.kind~="verge" then continue end
 local pieces=Verge.pieces(r)
 local looks={};local full,low,grassFull,grassLow=0,0,0,0
 for _,d in Region.decor(r) do
  looks[d.id]=d;full+=1;if not d.full then low+=1 end
  local clover=string.find(d.id,"_clover_",1,true)~=nil
  local grass=string.find(d.id,"_grass_clump_",1,true)~=nil
  if clover then
   check(d.material=="SmoothPlastic",d.id.." avoids stretched terrain-grass texture")
   check(d.size.X<=1.5 and d.size.Z<=1.5,d.id.." is a small leaflet or stem rather than a broad slab")
   if string.match(d.id,"_clover_%d+_%d+$") then
    local stem=looks[(string.gsub(d.id,"_%d+$","_stem"))]
    local radial=Vector3.new(d.at.X-stem.at.X,0,d.at.Z-stem.at.Z).Unit
    local yaw=math.rad(d.turn.Y)
    check(radial:Dot(Vector3.new(math.cos(yaw),0,-math.sin(yaw)))>.999,"leaflet yaw uses the renderer's degrees and points away from its stem")
   end
  end
  if grass then
   grassFull+=1;if not d.full then grassLow+=1 end
   check(d.shape=="Mesh:grass_clump","far cover uses the approved mesh")
  end
  if clover or grass then
   local supported=false
   local radius=math.sqrt(d.size.X^2+d.size.Z^2)/2
   for _,soil in pieces do
    if string.find(soil.id,"_soil_",1,true) and d.at.X-radius>=soil.lo.X-1e-6 and d.at.X+radius<=soil.hi.X+1e-6
     and d.at.Z-radius>=soil.lo.Z-1e-6 and d.at.Z+radius<=soil.hi.Z+1e-6 then supported=true end
   end
   check(supported,d.id.." stays above actual ground rather than an excluded region")
  end
 end
 if grassFull>0 then check(grassLow>=3,"low detail retains background grass rather than a bare field") end
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
