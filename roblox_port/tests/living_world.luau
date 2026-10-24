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
local AntForage=require("../src/Shared/World/AntForage")
local Hut=require("../src/Shared/World/Hut")
local Pond=require("../src/Shared/World/Pond")
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
case("fleas start each hop from their last landing rather than snapping home",function()
 for _,index in {1,2,3,4,5,984371} do
  local previous,wasHop=Environment.flea(0,index)
  local horizontal,vertical,held=0,0,true
  local sawHop,sawRest=wasHop,not wasHop
  for step=1,8000 do
   local point,hop=Environment.flea(step*.005,index)
   local delta=point-previous
   horizontal=math.max(horizontal,Vector3.new(delta.X,0,delta.Z).Magnitude)
   vertical=math.max(vertical,math.abs(delta.Y))
   if not hop and not wasHop then held=held and delta.Magnitude<1e-6 end
   sawHop=sawHop or hop;sawRest=sawRest or not hop
   previous,wasHop=point,hop
  end
  check(horizontal<.07 and vertical<.17,"flea "..index.." has no teleport at a hop boundary")
  check(held and sawHop and sawRest,"flea "..index.." rests where it landed between jumps")
  local a=Environment.flea(17.125,index);local b=Environment.flea(17.125,index)
  check((a-b).Magnitude<1e-9,"flea pose is reconstructed from the saved clock")
 end
end)
case("flea legs meet the floor at rest and Reduced Motion holds the entire rig",function()
 WorldMap.use("preserve")
 local region=WorldMap.region("hut_floor_i")
 local root=Instance.new("Folder");root.Parent=workspace;WorldBuild.region(region,root)
 for _,tier in {"full","low"} do
  local living=LivingWorld.new(workspace,root,tier,WorldMap)
  local state=Environment.sample(1,12);local pos=nil
  for x=region.bounds[1].X+3,region.bounds[2].X-3,10 do
   if pos then break end
   for z=region.bounds[1].Z+3,region.bounds[2].Z-3,10 do
    local point=Vector3.new(x,-69.69,z)
    living:small(point,region,state,false)
    for _,flea in living.fleas do if flea.shown then pos=point;break end end
    if pos then break end
   end
  end
  check(pos~=nil,tier.." floor traversal can actually find a supported flea")
  if pos then
   local samples,gap=0,0
   for step=0,120 do
    state.totalHours=12+step*.05/75;living:small(pos,region,state,false)
    for _,flea in living.fleas do
     local _,hop=Environment.flea(state.totalHours*75,flea.motionIndex or flea.index)
     if not flea.shown or hop then continue end
     for _,name in {"LeftHindTibia","RightHindTibia"} do
      local leg=assert(flea.folder:FindFirstChild(name))
      local a=leg.CFrame:PointToWorldSpace(Vector3.new(-leg.Size.X*.5,0,0))
      local b=leg.CFrame:PointToWorldSpace(Vector3.new(leg.Size.X*.5,0,0))
      gap=math.max(gap,math.abs(math.min(a.Y,b.Y)+70));samples+=1
     end
    end
   end
   check(samples>0 and gap<.02,tier.." resting hind feet touch the actual floor")
   living:small(pos,region,state,true)
   local still={}
   for _,flea in living.fleas do for _,part in flea.parts do still[part]=part.CFrame end end
   state.totalHours+=3;living:small(pos,region,state,true)
   local held=true
   for part,frame in still do held=held and (part.Position-frame.Position).Magnitude<1e-6 and part.CFrame.LookVector:Dot(frame.LookVector)>.99999 end
   check(held,tier.." Reduced Motion stops body, head and legs without an orientation flicker")
  end
  living:destroy()
 end
 root:Destroy();WorldMap.use("test_garden")
end)
case("nearby fleas persist when walking from the floor into the doorway",function()
 WorldMap.use("preserve")
 local floor=WorldMap.region("hut_floor_i");local door=WorldMap.region("hut_doorway")
 local root=Instance.new("Folder");root.Parent=workspace
 WorldBuild.region(floor,root);WorldBuild.region(door,root)
 for _,tier in {"full","low"} do
  local living=LivingWorld.new(workspace,root,tier,WorldMap)
  local state=Environment.sample(1,12)
  living:small(Vector3.new(140,-69.69,226),floor,state,false)
  local before={}
  for _,flea in living.fleas do if flea.shown then table.insert(before,flea.parts[1].Position) end end
  check(#before>0,tier.." nearby floor life is visible on the can-to-door walk")
  living:small(Vector3.new(148,-69.69,226),door,state,false)
  local retained=true
  for _,point in before do
   local found=false
   for _,flea in living.fleas do if flea.shown and (flea.parts[1].Position-point).Magnitude<1e-6 then found=true end end
   retained=retained and found
  end
  check(#before>0 and retained,tier.." the same nearby flea remains at the same clock-derived position across the doorway")
  local identities={};local unique=true
  for _,flea in living.fleas do
   if not flea.shown then continue end
   unique=unique and not identities[flea.site.id]
   identities[flea.site.id]=flea.parts[1].Position
  end
  check(unique,tier.." a site is never drawn by two pooled rigs")
  local cold=LivingWorld.new(workspace,root,tier,WorldMap)
  cold:small(Vector3.new(148,-69.69,226),door,state,false)
  local common,same=0,true
  for _,flea in cold.fleas do
   if flea.shown and identities[flea.site.id] then
    common+=1;same=same and (flea.parts[1].Position-identities[flea.site.id]).Magnitude<1e-6
   end
  end
  check(common>0 and same,tier.." restoring from the doorway reconstructs the same site poses independently of pool history")
  cold:destroy()
  living:small(Vector3.new(5000,-69.69,5000),door,state,false)
  local released=true;for _,flea in living.fleas do released=released and not flea.shown and flea.site==nil end
  check(released,tier.." leaving the habitat releases all local assignments")
  living:destroy()
 end
 root:Destroy();WorldMap.use("test_garden")
end)
case("floor sites wait for streaming, retry and stop rendering when support goes away",function()
 WorldMap.use("preserve")
 local floor=WorldMap.region("hut_floor_i")
 local root=Instance.new("Folder");root.Parent=workspace
 local living=LivingWorld.new(workspace,root,"full",WorldMap)
 local pos=Vector3.new(140,-69.69,226);local clock={day=1,hour=12}
 local function anyShown() for _,flea in living.fleas do if flea.shown then return true end end;return false end
 living:update(.1,pos,clock,floor,false,false)
 check(not anyShown(),"missing floor geometry never produces a floating flea")
 local built=WorldBuild.region(floor,root)
 for _=1,10 do living:update(.1,pos,clock,floor,false,false) end
 check(anyShown(),"a negatively cached site is retried after the floor streams in")
 built:Destroy();living:update(.1,pos,clock,floor,false,false)
 check(not anyShown(),"an unloaded support invalidates its old positive cache")
 WorldBuild.region(floor,root)
 for _=1,10 do living:update(.1,pos,clock,floor,false,false) end
 check(anyShown(),"a replacement floor instance can support the same sites again")
 living:destroy();root:Destroy();WorldMap.use("test_garden")
end)
case("close cover stays ahead after walking one detail cell",function()
 WorldMap.use("preserve")
 local region=WorldMap.region("verge_-400_-216")
 local root=Instance.new("Folder");root.Parent=workspace;WorldBuild.region(region,root)
 local living=LivingWorld.new(workspace,root,"full",WorldMap)
 local clock={day=1,hour=12}
 living:update(.1,Vector3.new(-350,-84.29,-170),clock,region,false,false)
 local nextPoint=Vector3.new(-338,-84.29,-170)
 living:update(.1,nextPoint,clock,region,false,false)
 local furthest=-math.huge
 for _,part in living.static:GetChildren() do if part.Name=="GrassClump" then furthest=math.max(furthest,part.Position.X) end end
 check(furthest-nextPoint.X>8,"walking 12 cm does not leave the leading edge of close cover behind")
 living:update(.1,Vector3.new(-350,-84.29,-206),clock,region,false,false)
 nextPoint=Vector3.new(-350,-84.29,-194)
 living:update(.1,nextPoint,clock,region,false,false)
 furthest=-math.huge
 for _,part in living.static:GetChildren() do if part.Name=="GrassClump" then furthest=math.max(furthest,part.Position.Z) end end
 check(furthest-nextPoint.Z>8,"the same leading-edge coverage holds along Z")
 living:destroy();root:Destroy();WorldMap.use("test_garden")
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
  local decor=Sites.decor(region)
  check(#decor<=30,"can detailing fits the existing thirty-record allowance")
  local rim,tab=0,0
  for _,d in decor do
   if string.find(d.id,"_rolled_lid_",1,true) then rim+=1;check(not d.full,"low detail keeps the rolled rim") end
   if string.find(d.id,"_tab_",1,true) then tab+=1;check(not d.full,"low detail keeps the hollow pull tab") end
   if string.find(d.id,"_lid_",1,true) and not string.find(d.id,"_rolled_",1,true) then
    local metal=Color3.fromHex("aeb5b5")
    check(near(d.color.R,metal.R) and near(d.color.G,metal.G) and near(d.color.B,metal.B),"lid reads as exposed aluminium")
   end
   local frame=CFrame.new(d.at)
   if d.turn then frame*=CFrame.Angles(math.rad(d.turn.X),math.rad(d.turn.Y),math.rad(d.turn.Z)) end
   local q=frame:PointToObjectSpace(opening)
   check(math.abs(q.X)>d.size.X*.5 or math.abs(q.Y)>d.size.Y*.5 or math.abs(q.Z)>d.size.Z*.5,
    "drawn can does not paint over the real drinking aperture")
  end
  check(rim==8 and tab==4,"rolled perimeter and open pull tab survive both graphics tiers")
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
case("ambient workers forage, carry fragments home and re-enter the nest",function()
 for index=1,8 do
  local route=AntForage.route(index)
  local period=AntForage.sample(0,index).period
  local modes={};local bounded,continuous,oriented,loads=true,true,true,true
  local previous=nil;local furthest=0
  for step=0,math.ceil(period/.025) do
   local t=step*.025;local p=AntForage.sample(t,index)
   modes[p.mode]=true;furthest=math.max(furthest,p.offset.Magnitude)
   bounded=bounded and finite(p.offset.X) and finite(p.offset.Z) and p.offset.Magnitude<15.5
   if previous and previous.visible and p.visible then continuous=continuous and (p.offset-previous.offset).Magnitude<.065 end
   if p.moving and p.offset.Magnitude>.4 then
    local dot=p.heading:Dot(route.direction)
    oriented=oriented and (if p.mode=="return" then dot<-.9 else dot>.9)
   end
   loads=loads and (not p.carrying or (p.mode=="return" and p.visible))
   previous=p
  end
  check(bounded and continuous,"worker stays on a bounded continuous trail")
  check(oriented and loads,"worker faces its route and only carries food home")
  check(modes.inside and modes.outbound and modes.forage and modes["return"],"worker has a complete nest/forage cycle")
  check(math.abs(furthest-route.distance)<.01,"forage pause reaches the authored ground fragment")
  local a,b=AntForage.sample(7.25,index),AntForage.sample(7.25+period,index)
  check((a.offset-b.offset).Magnitude<1e-6 and a.mode==b.mode,"restoring the same clock reconstructs the worker")
 end
 WorldMap.use("preserve")
 local region=WorldMap.region("garden_b1");local hill=Sites.ANTHILLS[region.id]
 local worst=0
 for x=-5.5,5.5,.25 do for z=-5.5,5.5,.25 do
  local ground=0
  for _,p in Sites.pieces(region) do
   if hill.at.X+x>=p.lo.X and hill.at.X+x<=p.hi.X and hill.at.Z+z>=p.lo.Z and hill.at.Z+z<=p.hi.Z then ground=math.max(ground,p.hi.Y-hill.at.Y) end
  end
  worst=math.max(worst,math.abs(ground-Sites.antHeight(Vector3.new(x,0,z))))
 end end
 check(worst<.26,"low mound's physical/visible height difference stays below body clearance")
 local caps={};for _,d in Sites.decor(region) do if string.find(d.id,"_earth",1,true) then table.insert(caps,d) end end
 local joined=true
 for x=-5,5,.5 do for z=-5,5,.5 do
  local top=Sites.antHeight(Vector3.new(x,0,z))
  for y=.01,top,.025 do
   local filled=false
   for _,cap in caps do
    local q=hill.at+Vector3.new(x,y,z)-cap.at
    if (q.X/(cap.size.X*.5))^2+(q.Y/(cap.size.Y*.5))^2+(q.Z/(cap.size.Z*.5))^2<=1+1e-6 then filled=true end
   end
   joined=joined and filled
  end
 end end
 check(joined,"drawn soil caps join the ground without air gaps between discs")
 check(Sites.nearAnthill(hill.at+Vector3.new(25,.31,0))==hill,"workers remain visible across nearby region boundaries")
 check(Sites.nearAnthill(hill.at+Vector3.new(41,.31,0))==nil,"ambient workers stay local")
 WorldMap.use("test_garden")
end)
case("colony renderer shows loads, pauses and weather shelter at both tiers",function()
 WorldMap.use("preserve")
 local region=WorldMap.region("garden_b1");local hill=Sites.ANTHILLS[region.id]
 local root=Instance.new("Folder");root.Parent=workspace;WorldBuild.region(region,root)
 local pos=hill.at+Vector3.new(8,.31,0)
 for _,tier in {"full","low"} do
  local living=LivingWorld.new(workspace,root,tier,WorldMap)
  local state=Environment.sample(1,12);state.rain=0;state.solar.daylight=1
  local carried,foraged,hidden=false,false,false
  local loadsMatch=true
  for step=0,200 do
   state.totalHours=step*.25/75;living:small(pos,region,state,false)
   for _,ant in living.ants do
    carried=carried or (ant.shown and ant.pose.carrying)
    foraged=foraged or (ant.shown and ant.pose.mode=="forage")
    hidden=hidden or (not ant.shown and ant.pose.mode=="inside")
    if ant.shown then loadsMatch=loadsMatch and ((ant.parts[12].Transparency==0)==ant.pose.carrying) end
   end
  end
  check(carried and foraged and hidden,tier.." actually renders the full foraging story")
  check(loadsMatch,tier.." fragment is visible only on a returning worker")
  living:small(pos,region,state,true)
  local still={};for i,ant in living.ants do still[i]=ant.parts[1].Position end
  state.totalHours+=1;living:small(pos,region,state,true)
  for i,ant in living.ants do check((ant.parts[1].Position-still[i]).Magnitude<1e-6,"Reduced Motion freezes worker travel") end
  state.rain=.8;living:small(pos,region,state,false)
  for _,ant in living.ants do check(not ant.shown,"workers shelter during heavy rain") end
  state.rain=0;state.solar.daylight=0;living:small(pos,region,state,false)
  for _,ant in living.ants do check(not ant.shown,"colony quietens after dark") end
  check(living.count<=LivingWorld.BUDGET[tier],tier.." added mouth fragments retain renderer budget")
  living:destroy()
 end
 root:Destroy();WorldMap.use("test_garden")
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
 -- Test actual soil footprints: southern/eastern shoulders are legitimate,
 -- but neither the hut nor the intentional water hazard may gain a floor.
 for _,v in Verge.author(914,WorldMap.seed) do
  for _,p in Verge.pieces(v)do
   if string.find(p.id,"_soil_",1,true)then
    local inHut=p.lo.X<Hut.BUILDING.x1 and p.hi.X>Hut.BUILDING.x0 and p.lo.Z<284 and p.hi.Z> -16
    local k=Pond.CORE
    local inPond=p.lo.X<k.x1 and p.hi.X>k.x0 and p.lo.Z<k.z1 and p.hi.Z>k.z0
    check(not inHut and not inPond,"actual infill soil excludes the hut interior and pond: "..p.id)
   end
  end
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
case("floor detail continues through the station doorway",function()
 WorldMap.use("preserve")
 local root=Instance.new("Folder");root.Parent=workspace
 local floor=WorldMap.region("hut_floor_i");local door=WorldMap.region("hut_doorway")
 WorldBuild.region(floor,root);WorldBuild.region(door,root)
 local pos=Vector3.new(148,-69.69,226)
 for _,tier in {"full","low"} do
  local living=LivingWorld.new(workspace,root,tier,WorldMap)
  living:rebuild(pos,floor)
  local before={}
  for _,p in living.static:GetChildren() do if p.Name=="DustBunny" then table.insert(before,p.Position) end end
  living:rebuild(pos,door)
  local after={}
  for _,p in living.static:GetChildren() do if p.Name=="DustBunny" then table.insert(after,p.Position) end end
  check(#before>0 and #after==#before,tier.." doorway retains nearby floor dust")
  for i,p in before do check((after[i]-p).Magnitude<1e-6,"approaching the doorway does not move or erase existing clumps") end
  check(living.count<=LivingWorld.BUDGET[tier],tier.." doorway stays within the existing living budget")
  living:destroy()
 end
 root:Destroy();WorldMap.use("test_garden")
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
case("dog feet have actual physical ground throughout the outdoor circuit",function()
 WorldMap.use("preserve")
 local root=WorldBuild.world(workspace)
 local living=LivingWorld.new(workspace,root,"full",WorldMap)
 local hidden=0;local first=nil;local gap=0;local blocked=0
 local neck,collar,tag
 for _,part in living.dog.parts do
  if part.Name=="Neck" then neck=part elseif part.Name=="Collar" then collar=part elseif part.Name=="Tag" then tag=part end
 end
 assert(neck and collar and tag)
 local obstacles={}
 for _,r in WorldMap.regions() do for _,p in Region.pieces(r) do
  if p.hi.Y> -76.6 and p.lo.Y< -24.6 then table.insert(obstacles,p) end
 end end
 -- The far garden includes non-physical planters. They still occupy visual
 -- space: a native close-up caught a route which passed the collider test but
 -- sent the dog through these drawn beds.
 local PreserveLook=require("../src/Shared/World/PreserveLook")
 for _,p in PreserveLook.records("hut_garden",WorldMap.seed(914,"hut_garden")) do
  if p.size.Y>8 then table.insert(obstacles,{lo=p.at-p.size/2,hi=p.at+p.size/2}) end
 end
 for _,rain in {0,.5,1} do for i=0,1200 do
  local seconds=i/20;local pose=Environment.dog(seconds,rain)
  living:drawDog(pose.position,{totalHours=seconds/75,rain=rain},false,.05)
  if not living.dog.shown then hidden+=1;first=first or pose.position end
  for _,f in living.dog.gait.feet do gap=math.max(gap,(f.ankle-f.anchor-Vector3.yAxis*3.5).Magnitude) end
  if i%100==0 and living.dog.shown then
   check((neck.CFrame:PointToObjectSpace(collar.Position)-Vector3.new(0,1,0)).Magnitude<.001,"collar stays on neck while walking, turning and sniffing")
   check((neck.CFrame:PointToObjectSpace(tag.Position)-Vector3.new(0,-3,-10)).Magnitude<.001,"tag follows neck with collar")
   check(neck.CFrame.UpVector:Dot(collar.CFrame.UpVector)>.99999,"collar follows neck rotation")
   for leg,f in living.dog.gait.feet do
    for bone=0,1 do
     local p=living.dog.parts[living.dog.legStart+(leg-1)*3+bone]
     local a,b=if bone==0 then f.hip else f.knee,if bone==0 then f.knee else f.ankle
     local start=p.CFrame:PointToWorldSpace(Vector3.new(0,-p.Size.Y/2,0))
     local finish=p.CFrame:PointToWorldSpace(Vector3.new(0,p.Size.Y/2,0))
     check(math.min((start-a).Magnitude+(finish-b).Magnitude,(start-b).Magnitude+(finish-a).Magnitude)<.001,"drawn dog bones meet their world-space joints")
    end
   end
  end
  if rain==0 and i%5==0 then
   local frame=CFrame.lookAt(pose.position,pose.position+pose.heading)
   -- Sample the animal's length with ten-centimetre body clearance. Thin
   -- leaves may brush it, but walls/raised beds cannot contain the body.
   for _,y in {5,20,35,50} do for z=-50,45,5 do
    local at=frame:PointToWorldSpace(Vector3.new(0,y,z))
    for _,p in obstacles do
     if at.X>p.lo.X-10 and at.X<p.hi.X+10 and at.Y>p.lo.Y and at.Y<p.hi.Y
      and at.Z>p.lo.Z-10 and at.Z<p.hi.Z+10 then blocked+=1 end
    end
   end end
  end
 end end
 check(hidden==0,`dog circuit has supported paws: {hidden} missing frames, first {first}`)
 check(gap<.001,`dog paws remain joined to the legs through turns and stops: gap {gap}`)
 check(blocked==0,`dog's body clears raised beds and walls: {blocked} intersecting samples`)
 living:destroy();root:Destroy();WorldMap.use("test_garden")
end)
case("distant dog uses authored terrain when native ground is not streamed",function()
 local Ground=require("../src/Shared/World/DogGround")
 WorldMap.use("preserve")
 local root=WorldBuild.world(workspace)
 local living=LivingWorld.new(workspace,root,"full",WorldMap)
 local terrain=Ground.new(WorldMap)
 local rawGround=living.ground
 for i=0,120 do
  local pose=Environment.dog(i*.5,0)
  local native=rawGround(living,pose.position,6,18)
  local known=Ground.at(terrain,pose.position,6,18)
  check(native~=nil and known~=nil and (native.Position-known).Magnitude<.001,"terrain proxy agrees with the server-built physical surface")
 end
 check(Ground.at(terrain,Vector3.new(10000,-84.6,10000),6,18)==nil,"terrain proxy never invents an out-of-map floor")
 living.ground=function() return nil end
 for i=0,1200 do
  local seconds=i/20;local pose=Environment.dog(seconds,0)
  living:drawDog(pose.position,{totalHours=seconds/75,rain=0},false,.05)
  check(living.dog.shown,"distant dog remains visible over known unloaded ground")
 end
 living.dog.wander={}
 for _=1,20 do living:drawDog(Vector3.new(-100,-84.6,-115),{totalHours=3/75,rain=0},false,.05) end
 local nose=nil;for _,p in living.dog.parts do if p.Name=="Nose" then nose=p end end
 check(nose~=nil and nose.Position.Y+84.6>2 and nose.Position.Y+84.6<8,"sniffing nose reaches near the ground")
 living:destroy();root:Destroy();WorldMap.use("test_garden")
end)
case("close grass is rooted, wind-responsive, bounded and absent from hard props",function()
 WorldMap.use("preserve")
 local root=WorldBuild.world(workspace)
 local at=Vector3.new(-310,Verge.TOP+.31,-155)
 local region=assert(WorldMap.at(at))
 local decor=Instance.new("Folder");decor.Name="WorldDecor";decor.Parent=workspace
 local roof=Instance.new("Part");roof.Name="verge_review_litter_1_Leaf_look";roof.CanQuery=false;roof.CFrame=CFrame.new(at);roof.Parent=decor
 local fixed=roof.CFrame
 for _,tier in {"full","low"} do
  local living=LivingWorld.new(workspace,root,tier,WorldMap)
  living:update(.1,at,{day=1,hour=12},region,false,false)
  check(#living.grass>=(if tier=="full" then 12 else 6),tier.." has close upright grass")
  check(living.count<=LivingWorld.BUDGET[tier],tier.." cover stays within the existing total part limit")
  living.elapsed+=.7;living:sway(at,{wind=Vector3.new(3,0,1)},false)
  local moved=false
  for _,row in living.grass do
   local p=row.part
   check(not p.CanCollide and not p.CanQuery and not p.CanTouch,"grass is purely visual")
   local mesh=p:FindFirstChildWhichIsA("SpecialMesh")
   check(mesh and mesh.MeshId=="rbxassetid://93421946013090" and mesh.TextureId=="rbxassetid://116765351721069","both tiers use the approved curved mesh and atlas")
   local base=p.CFrame:PointToWorldSpace(row.rootLocal)
   check((base-row.pivot).Magnitude<1e-5,"wind keeps each grass root fixed to its ground point")
   moved=moved or (p.CFrame.UpVector-row.base.UpVector).Magnitude>.001
  end
  check(moved,"wind actually bends the grass")
  for _,wind in {Vector3.new(3,0,0),Vector3.new(-3,0,0),Vector3.new(0,0,3),Vector3.new(0,0,-3)} do
   living:sway(at,{wind=wind},false)
   local follows,rooted=true,true
   for _,row in living.grass do
    local up=row.part.CFrame.UpVector
    follows=follows and Vector3.new(up.X,0,up.Z):Dot(wind)>.001
    rooted=rooted and (row.part.CFrame:PointToWorldSpace(row.rootLocal)-row.pivot).Magnitude<1e-5
   end
   check(#living.grass>0 and follows,"grass bends downwind on both world axes")
   check(rooted,"directional wind leaves the grass roots planted")
  end
  check((roof.CFrame.UpVector-fixed.UpVector).Magnitude<1e-8,"wind never moves the visual collision roof")
  living:sway(at,{wind=Vector3.zero},false)
  local calm=true
  for _,row in living.grass do calm=calm and (row.part.CFrame.UpVector-row.base.UpVector).Magnitude<1e-8 end
  check(calm,"calm air restores upright grass without a zero-vector normalization")
  living:sway(at,{wind=Vector3.new(3,0,1)},true)
  for _,row in living.grass do check((row.part.CFrame.UpVector-row.base.UpVector).Magnitude<1e-8,"reduced motion restores still grass") end
  local old=living.grassParts[1]
  living:rebuild(at+Vector3.new(12,0,0),region)
  check(old.Parent==nil,"moving detail cells cleans up the previous tuft instances")
  living:destroy()
 end
 local plate=Instance.new("Part");plate.Name="MetalLid";plate.Size=Vector3.new(60,1,60)
 plate.Material=Enum.Material.Metal;plate.CFrame=CFrame.new(at-Vector3.yAxis*.31+Vector3.yAxis*1.5);plate.Parent=root
 local living=LivingWorld.new(workspace,root,"full",WorldMap)
 living:rebuild(at,region)
 check(#living.grass==0 and #living.patches==0,"metal surfaces grow neither grass nor emerging soil grubs")
 living:destroy();decor:Destroy();root:Destroy();WorldMap.use("test_garden")
end)
case("garden lawns have close living cover while paths and beds stay distinct",function()
 WorldMap.use("preserve")
 local root=WorldBuild.world(workspace)
 local lawn=Vector3.new(-182,-84.29,-190)
 for _,tier in {"full","low"} do
  local living=LivingWorld.new(workspace,root,tier,WorldMap)
  local region=assert(WorldMap.at(lawn))
  living:rebuild(lawn,region)
  check(#living.grass>0,tier.." the station garden lawn has upright close grass, not just distant blades")
  local planted=true
  for _,row in living.grass do
   planted=planted and Hut.surfaceAt(region,row.pivot.X,row.pivot.Z)=="lawn"
   local hit=living:ground(row.pivot+Vector3.yAxis*.1,1,3)
   planted=planted and hit~=nil and hit.Instance.Material==Enum.Material.Grass
    and string.match(hit.Instance.Name,"^garden_[a-d][1-4]_soil$")~=nil
  end
  check(planted,tier.." garden cover grows only on the actual lawn, not over a path or prop")
  check(living.count<=living.limit and living.staticCount<=(if tier=="low" then 48 else 150),tier.." lawn cover keeps the existing part limits")
  for _,at in {Vector3.new(-65,-84.29,-270),Vector3.new(-150,-74.29,-270)} do
   living:rebuild(at,assert(WorldMap.at(at)))
   check(#living.grass==0,tier.." gravel paths and the planted herb bed do not acquire lawn grass")
  end
  local plate=Instance.new("Part");plate.Name="GardenMetalProp";plate.Material=Enum.Material.Metal
  plate.Size=Vector3.new(70,1,70);plate.CFrame=CFrame.new(lawn+Vector3.yAxis*1.5);plate.Parent=root
  living:rebuild(lawn,region)
  check(#living.grass==0,tier.." a hard prop above the lawn never grows grass")
  plate:Destroy();living:destroy()
 end
 root:Destroy();WorldMap.use("test_garden")
end)
case("stationary rain notices streamed shelter without an unbounded cast burst",function()
 for _,tier in {"full","low"} do
  local root=Instance.new("Folder");root.Parent=workspace
  local floor=Instance.new("Part");floor.Size=Vector3.new(100,1,100);floor.CFrame=CFrame.new(0,-1,0);floor.Parent=root
  local living=LivingWorld.new(workspace,root,tier,WorldMap)
  local region={kind="meadow"};local state={rain=1,wind=Vector3.zero}
  local casts=0;local ground=living.ground
  living.ground=function(self,...) casts+=1;return ground(self,...) end
  living:rainfall(Vector3.zero,region,state,false)
  local initial=true;for _,drop in living.rain do initial=initial and near(drop.floor,-.5) end
  check(initial,tier.." rain initially stops at the physical floor")
  local roof=Instance.new("Part");roof.Size=Vector3.new(100,1,100);roof.CFrame=CFrame.new(0,6,0);roof.Parent=root
  local bounded=true
  for step=1,20 do
   living.elapsed+=.05;local before=casts
   living:rainfall(Vector3.zero,region,state,false)
   bounded=bounded and casts-before<=(if tier=="low" then 1 else 2)
  end
  local sheltered=true;for _,drop in living.rain do sheltered=sheltered and near(drop.floor,6.5) end
  check(sheltered,tier.." streamed roof is noticed while the observer stands still")
  check(bounded,tier.." stationary shelter refresh uses at most two/full or one/low casts per update")
  roof:Destroy()
  for step=1,20 do living.elapsed+=.05;living:rainfall(Vector3.zero,region,state,false) end
  local exposed=true;for _,drop in living.rain do exposed=exposed and near(drop.floor,-.5) end
  check(exposed,tier.." unloading the roof restores rain down to the floor")
  local before=casts
  state.rain=0;living:rainfall(Vector3.new(20,0,0),region,state,false)
  check(casts==before,tier.." fair weather does no rain support casts")
  state.rain=1;living:rainfall(Vector3.new(40,0,0),region,state,true)
  check(casts==before,tier.." Reduced Motion does no rain support casts")
  living:destroy();root:Destroy()
 end
end)
print(`LIVING_WORLD passed={passed} failed={failed}`)
if failed>0 then error("living habitat checks failed") end
