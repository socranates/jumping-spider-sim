-- Incremental construction must not expose private work or change route data.
local Map=require("../src/Shared/World/WorldMap")
local Station=require("../src/Shared/World/StationTerritory")
local Route=require("../src/Shared/Predator/RivalRoute")
local Drive=require("../src/Shared/Predator/RivalDrive")
local Build=require("../src/Shared/World/WorldBuild")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local expected=require("./route_preparation_reference")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL ROUTE_PREPARATION "..msg) end end
local function fingerprint(g)
 local hash=1
 local function value(x)
  local s=if type(x)=="number" then string.format("%.17g",x) else tostring(x)
  for j=1,#s do hash=(hash*131+string.byte(s,j))%2147483647 end
  hash=(hash*131)%2147483647
 end
 local function vector(p) value(p.X);value(p.Y);value(p.Z) end
 for _,f in g:allFaces() do
  value(f.id);value(f.piece);value(f.axis);value(f.sign);value(f.plane);value(f.area);value(f.forbidden);vector(f.normal)
  for _,n in f.lo do value(n) end;for _,n in f.hi do value(n) end
  for _,p in f.stand do vector(p) end
  for _,e in f.edges do value(e.to);value(e.convex);vector(e.ahead);for _,p in e.samples do vector(p) end end
  for _,e in g:seamsOf(f.id) do
   value(e.region);value(e.to);value(e.convex);value(e.flat);vector(e.ahead)
   for _,p in e.samples do vector(p) end
  end
 end
 for _,p in g:waypoints() do value(p.face);vector(p.pos);vector(p.up) end
 return hash
end
Map.use("preserve")
local public=Route.graph(Station.REGION)
check(#public.faces==0,"legacy placeholder begins unbuilt")
check(not Route.request(Station.REGION),"cold request queues work")
check(not Route.request(Station.REGION) and Route.preparationStats().pending==1,"duplicate request shares one job")
local ok=Route.advance(1,100)
check(ok and Route.preparationStats().lastUnits==1,"one-work-unit budget yields")
check(Route.prepared(Station.REGION)==nil and #public.faces==0,"private partial build is invisible")
Route.cancelPreparation()
check(Route.preparationStats().pending==0 and Route.prepared(Station.REGION)==nil,"interrupted work publishes nothing")
check(#public:allFaces()==expected[Station.REGION].faces,"legacy query still builds a whole independent graph")
Route.request("hut_desk");Route.advance(1,100)
Map.use("test_garden");Route.advance(8,100)
Map.use("preserve")
check(Route.preparationStats().pending==0 and Route.prepared("hut_desk")==nil,"world change cancels private work")
local accepted=pcall(function() Route.request("not_a_region") end)
check(not accepted and Route.preparationStats().pending==0,"unknown region cannot enter the queue")

-- A cold incremental drive can wait safely, then move once its graph is ready.
local root=Build.world(workspace)
local lo,hi=Map.bounds()
local drive=Drive.new(Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Station.ARRIVE,heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi}),function() return false end,Station.REGION,Station.roam(),true)
local rival={state="patrol",position=Station.ARRIVE,heading=Vector3.xAxis,up=Vector3.yAxis,region=Station.REGION,origin=Station.ARRIVE,leg=0}
local spider={position=Vector3.new(-25.5,.31,6),up=Vector3.yAxis,safe=true,resting=true,seed=914}
drive:update(rival,1/60,spider)
check(drive.g==nil and drive.wish==Vector3.zero and rival.position==Station.ARRIVE,"waiting drive neither crashes nor teleports")
local coldSlices=0
while Route.prepared(Station.REGION)==nil and coldSlices<50000 do
 Route.advance(128,100);coldSlices+=1
end
drive:useRegion(Station.REGION)
check(drive.g~=nil,"cold drive attaches its completed graph")
local pendingLeg=nil
for leg=0,100 do
 local goal=drive:crossLeg(914,leg)
 if drive.preparingCross then pendingLeg=leg;check(goal==nil,"cold crossing waits for destination");break end
end
check(pendingLeg~=nil,"fixture exercises an unprepared neighbouring graph")
if pendingLeg~=nil then
 rival.leg=pendingLeg
 local goal=drive:_pickWaypoint(rival,spider)
 check(goal==nil and drive.preparingCross and rival.leg==pendingLeg,"pending crossing retains seeded patrol leg")
 check(Route.preparationStats().pending>0,"destination is queued rather than synchronously built")
 while Route.preparationStats().pending>0 do Route.advance(128,100) end
 local crossing=drive:_pickWaypoint(rival,spider)
 check(crossing~=nil and crossing.cross~=nil and not drive.preparingCross,"same patrol leg resumes after destination preparation")
end
Drive.prepare(Station.roam(),Station.REGION)
local frames=0
while Route.preparationStats().pending>0 and frames<50000 do
 local advanced,why=Route.advance(128,100)
 check(advanced,"preparation succeeds: "..tostring(why))
 check(Route.preparationStats().lastUnits<=128,"work quota is shared across jobs")
 frames+=1
end
check(Route.preparationStats().pending==0,"whole station eventually becomes ready")
for id,want in expected do
 local g=Route.prepared(id)
 check(g~=nil,id.." becomes available")
 if g then
  check(#g:allFaces()==want.faces and #g:allSeams()==want.seams and #g:waypoints()==want.waypoints,id.." retains counts")
  check(fingerprint(g)==want.fingerprint,id.." retains every face, standing sample, seam and waypoint")
 end
end
local g=assert(Route.prepared(Station.REGION))
local first=Route.preparedWaypoints(g);local original=first[1].pos
first[1].pos=Vector3.new(999,999,999);table.clear(first)
check(Route.preparedWaypoints(g)[1].pos==original,"drive waypoint copies do not mutate the cache")
local start=rival.position
for _=1,240 do drive:update(rival,1/60,spider) end
check((rival.position-start).Magnitude>.2 and Station.contains(rival.region),"prepared rival patrols inside the full station territory")
drive.preparingCross=true;drive:crossLeg(914,100)
-- A non-crossing draw clears an earlier pending crossing, rather than stalling
-- every later patrol leg. Find such a deterministic draw without altering it.
local cleared=false
for leg=0,100 do drive.preparingCross=true;drive:crossLeg(914,leg);if not drive.preparingCross then cleared=true;break end end
check(cleared,"crossing readiness does not leave stale pending state")
print(`ROUTE_PREPARATION passed={passed} failed={failed} slices={frames}`)
if failed>0 then error("route preparation checks failed") end
