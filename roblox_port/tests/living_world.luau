-- Connected habitat checks: continuity, persistence-derived weather, real support geometry, streaming and bounded rendering.
local Environment=require("../src/Shared/World/Environment")
local Sites=require("../src/Shared/World/LivedInSites")
local Region=require("../src/Shared/World/Region")
local WorldMap=require("../src/Shared/World/WorldMap")
local WorldBuild=require("../src/Shared/World/WorldBuild")
local LivingWorld=require("../src/Client/LivingWorld")
local Verge=require("../src/Shared/World/Verge")
local Garden=require("../src/Shared/World/Garden")
local Pocket=require("../src/Shared/World/GardenPocket")
local passed,failed=0,0
local function check(ok,name)
 if ok then passed+=1 else failed+=1;print("FAIL LIVING_WORLD "..name) end
end
local function near(a,b,epsilon) return math.abs(a-b)<(epsilon or 1e-6) end
local function finite(x) return x==x and math.abs(x)<1e9 end
local function case(name,fn)
 local ok,err=pcall(fn);if not ok then failed+=1;print("FAIL LIVING_WORLD "..name..": "..tostring(err)) end
end
case("sun and weather are continuous and deterministic",function()
 local morning,noon,evening,night=Environment.solar(1,8),Environment.solar(1,12),Environment.solar(1,17),Environment.solar(1,0)
 check(morning.direction.X>0 and evening.direction.X<0,"sun crosses from east to west")
 check(noon.altitude>morning.altitude and noon.altitude>evening.altitude and night.altitude<0,"noon culmination and night below horizon")
 check(noon.altitude>55 and noon.altitude<70,"late-summer noon at the authored northern latitude")
 check(Environment.solar(180,12).altitude<noon.altitude-20,"winter noon lower than late summer")
 local nativeAccurate=true
 for day=1,365,14 do for hour=0,23,.5 do
  local v=Environment.solar(day,hour).direction
  local native=Environment.nativeSun(v)
  local h=math.rad((native.clock-12)*15);local tilt=math.rad(native.latitude-23.5)
  local rendered=Vector3.new(-math.sin(h)*math.cos(tilt),math.cos(h)*math.cos(tilt),math.sin(tilt))
  nativeAccurate=nativeAccurate and (rendered-v).Magnitude<1e-6 and native.latitude>=-90 and native.latitude<=90
 end end
 check(nativeAccurate,"native sky conversion follows the astronomical direction throughout the year")
 local safe,unit,transitions=true,true,true;local kinds={}
 for day=1,365,7 do for h=0,23,.25 do
  local a=Environment.sample(day,h,914);local b=Environment.sample(day,h,914)
  unit=unit and near(a.solar.direction.Magnitude,1,1e-6)
  safe=safe and finite(a.temperature) and a.temperature>-20 and a.temperature<45 and a.cloud>=0 and a.cloud<=1 and a.rain>=0 and a.rain<=1
   and a.wetness>=0 and a.wetness<=1 and a.wind.Magnitude<6 and a.humidity>=0 and a.humidity<=1
  safe=safe and a.rain==b.rain and a.wind==b.wind and a.temperature==b.temperature
  kinds[a.name]=true
 end end
 for slot=1,60 do
  local a=Environment.sample(1,slot*2-1e-6,914);local b=Environment.sample(1,slot*2+1e-6,914)
  transitions=transitions and math.abs(a.rain-b.rain)<1e-5 and (a.wind-b.wind).Magnitude<.01
 end
 check(unit,"solar direction remains a unit vector across the year")
 check(safe,"weather bounds and exact restoration across a year")
 check(transitions,"no discontinuity at weather-front boundaries")
 check(kinds.fair and kinds.overcast and kinds.drizzle and kinds.rain,"all four weather conditions occur")
 local a=Environment.sample(1,24,914);local b=Environment.sample(2,0,914)
 check(a.rain==b.rain and a.wind==b.wind,"midnight uses the same absolute weather timeline")
 local bad=Environment.sample(0/0,math.huge,914)
 check(finite(bad.temperature) and finite(bad.solar.altitude),"invalid clock samples do not poison the renderer")
end)
case("small lives respect their habitat and motion bounds",function()
 local dampSeen,dryGone,bounded=false,true,true
 for step=0,600 do
  local hour=9+step/750
  local wet=Environment.grub(1,hour,1,.8)
  local dry=Environment.grub(1,hour,1,0)
  dampSeen=dampSeen or wet>.1;dryGone=dryGone and dry==0
  local flea=Environment.flea(step*.05,1)
  bounded=bounded and flea.Y>=0 and flea.Y<=1.8+1e-6 and flea.Magnitude<3
 end
 check(dampSeen and dryGone,"grubs occasionally emerge in damp soil, never in the dry-condition sample")
 check(bounded,"flea jumps stay ballistic and bounded at spider scale")
 local stopped,moved,grounded=false,false,true
 for i=0,300 do
  local dog=Environment.dog(i*.1,0)
  stopped=stopped or dog.sniff;moved=moved or dog.stride~=0
  grounded=grounded and finite(dog.position.X) and near(dog.position.Y,-84.6)
 end
 check(stopped and moved,"dog travels and stops to sniff")
 check(grounded,"dog stays on the ground throughout its route")
end)
case("new props are additive and the cans are truly hollow",function()
 WorldMap.use("preserve")
 local ids={};local seen=0
 for id in Sites.CANS do
  local region=WorldMap.region(id);check(region~=nil,"can region exists: "..id)
  local site=Sites.CANS[id];local pieces=Sites.pieces(region)
  local interior=site.at+Vector3.new(6,4,0);local opening=site.at+Vector3.new(12.1,4.1,0)
  local function contains(p,at) return at.X>=p.lo.X and at.X<=p.hi.X and at.Y>=p.lo.Y and at.Y<=p.hi.Y and at.Z>=p.lo.Z and at.Z<=p.hi.Z end
  local clear,spawnClear=true,true
  for _,p in pieces do
   check(not ids[p.id],"unique stable support "..p.id);ids[p.id]=true
   clear=clear and not contains(p,interior) and not contains(p,opening)
   spawnClear=spawnClear and not contains(p,region.spawn.pos+Vector3.new(0,.31,0))
  end
  check(clear,"can interior and drinking aperture are traversable")
  check(spawnClear,"new shell does not enclose an existing spawn")
  local drawn=Region.drawnPieces(region)
  for _,p in pieces do check(table.find(drawn,p.id)~=nil,"support has a replacement look: "..p.id) end
  check(#Region.decor(region)>#Sites.decor(region),"existing room dressing retained")
  seen+=1
 end
 check(seen==2,"two authored discarded cans")
 local hill=WorldMap.region("garden_b1")
 check(#Sites.pieces(hill)==3 and #Sites.decor(hill)>3,"garden ant nest has climbable earth and surface detail")
 WorldMap.use("test_garden")
 check(#Sites.pieces(WorldMap.region("sill"))==0,"nursery geometry remains untouched")
end)
case("path shoulders have ground and living populations",function()
 WorldMap.use("preserve")
 local total=0
 for x=-375,175,25 do for z=-1390,-40,25 do
  local r=WorldMap.at(Vector3.new(x,Verge.TOP+.31,z))
  check(r~=nil,`walkable outside the stone path at {x},{z}`)
  total+=1
 end end
 local r=WorldMap.at(Vector3.new(100,Verge.TOP+.31,-550))
 check(r~=nil and r.kind=="verge","former empty path shoulder is real habitat")
 if r then
  local parent=Instance.new("Folder");parent.Parent=workspace
  local built=WorldBuild.region(r,parent)
  check(built.ModelStreamingMode==Enum.ModelStreamingMode.Persistent,"small safety floor cannot stream away")
  local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={parent}
  local hit=workspace:Raycast(Vector3.new(100,Verge.TOP+3,-550),Vector3.new(0,-10,0),ray)
  check(hit~=nil and near(hit.Position.Y,Verge.TOP),"actual ray hits the previously missing ground")
  local specs=Garden.bestiary(r)
  check(specs~=nil and specs[1].target>=3 and specs[1].low>=2,"off-path life exists at both graphics tiers")
  parent:Destroy()
 end
 -- Infill must stop before the intentional water hazard rather than putting a floor on the pond.
 for _,v in Verge.author(914,WorldMap.seed) do
  check(v.bounds[2].Z<=-16 and v.bounds[1].Z>=-1416,"ground infill excludes the hut interior and pond")
 end
 check(total>500,"coverage checks sample ordinary travel, not just landmark spawns")
 WorldMap.use("test_garden")
end)
case("the first outdoor pocket has close climbable layers and living prey",function()
 WorldMap.use("preserve")
 local region=WorldMap.region(Pocket.REGION)
 local additions=Pocket.pieces()
 check(#additions>25 and #Pocket.PLANTS==3,"three plants plus low shelter routes in one cell")
 local worst=0
 for x=20,85,5 do for z=-105,-45,5 do
  local nearest=math.huge
  for _,p in additions do
   local dx=math.max(p.lo.X-x,0,x-p.hi.X)
   local dz=math.max(p.lo.Z-z,0,z-p.hi.Z)
   nearest=math.min(nearest,math.sqrt(dx*dx+dz*dz))
  end
  worst=math.max(worst,nearest)
 end end
 check(worst<24,"ordinary travel stays within a few jumps of a climbable feature")
 local actual=Region.pieces(region)
 for _,p in additions do
  check(table.find(actual,p)~=nil,"pocket surfaces participate in the real motor world")
  check(p.lo.X>=region.bounds[1].X and p.hi.X<=region.bounds[2].X and p.lo.Z>=region.bounds[1].Z and p.hi.Z<=region.bounds[2].Z
   and p.hi.Y+.31<region.bounds[2].Y,"climbing and jumping remain inside the region")
 end
 local leafLow=0
 for _,p in Pocket.decor() do if string.find(p.id,"Pocket_Leaf",1,true) and not p.full then leafLow+=1 end end
 check(leafLow>=18,"structural leaves remain visible on the low graphics tier")
 check(Garden.bestiary(region)==Pocket.bestiary() and Pocket.bestiary()[1].low==2,"real hoverflies live in the pocket at both tiers")
 WorldMap.use("test_garden")
end)
case("real renderer remains bounded while moving and pauses cleanly",function()
 WorldMap.use("preserve")
 local root=Instance.new("Folder");root.Name="LivingTestWorld";root.Parent=workspace
 local region=WorldMap.region("room_floor_b")
 WorldBuild.region(region,root)
 for _,tier in {"full","low"} do
  local living=LivingWorld.new(workspace,root,tier,WorldMap)
  local pos=region.spawn.pos+Vector3.new(0,.31,0)
  local clock={day=1,hour=12}
  living:update(.1,pos,clock,region,false,false)
  local first=living.count
  for i=1,20 do
   local point=pos+Vector3.new((i%5-2)*24,0,(math.floor(i/5)-2)*24)
   clock.hour=12+i*.01;living:update(.1,point,clock,region,false,false)
   check(living.count<=LivingWorld.BUDGET[tier],tier.." part budget while crossing detail cells")
  end
  local actual=0
  for _,p in living.folder:GetDescendants() do
   if p:IsA("BasePart") then actual+=1;check(not p.CanCollide and not p.CanQuery and not p.CanTouch,"ambient detail never becomes a hidden collision") end
  end
  check(actual==living.count,tier.." part accounting matches actual instances")
  check(first>0 and living.staticCount>=0,tier.." actually constructs close detail")
  local elapsed=living.elapsed;living:update(1,pos,clock,region,false,true)
  check(living.elapsed==elapsed,tier.." pause stops visual time")
  clock.hour=15;for _=1,7 do living:update(.1,pos,clock,region,true,false) end
  local sun=Environment.nativeSun(Environment.solar(clock.day,clock.hour).direction)
  check(near(game:GetService("Lighting").ClockTime,sun.clock),"afternoon sky follows the astronomical direction")
  clock.hour=23;for _=1,7 do living:update(.1,pos,clock,region,true,false) end
  sun=Environment.nativeSun(Environment.solar(clock.day,clock.hour).direction)
  check(near(game:GetService("Lighting").ClockTime,sun.clock),"night sky follows the same astronomical direction")
  living:destroy();check(living.folder.Parent==nil,tier.." cleanup removes all local detail")
 end
 root:Destroy();WorldMap.use("test_garden")
end)
print(`LIVING_WORLD passed={passed} failed={failed}`)
if failed>0 then error("living habitat checks failed") end
