-- Existing actual-client populations with locally removed engine geometry. Never publish.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Map=require(Shared.World.WorldMap)
local Region=require(Shared.World.Region)
local Sensor=require(Shared.Perception.Sensor)
local Memory=require(Shared.Perception.ObservationMemory)
local Species=require(Shared.Data.Species)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("PreyReadyProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local count=0;local undo={}
 local function check(ok,why) count+=1;assert(ok,why) end
 local ok,err=xpcall(function()
  print("[NATIVE_PREY_READY_BEGIN]",id)
  local r=assert(Map.region("garden_b4"));local pw=d.world.prey
  check(d.menu:isShowing() and d.world.region.id==r.id and d.world:regionReady(r.id),"requires paused ready predecessor fixture")
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={d.world.root}
  local cast=Sensor.workspaceCast(params);local sensor=Sensor.new(Memory.new());sensor:configureFrom(Species.phidippus_audax_prototype.perception)
  local at=d.motor.pos;local observer={eye=at+Vector3.yAxis*.09,gaze=Vector3.zAxis,up=Vector3.yAxis,heading=Vector3.zAxis}
  local function tick() pw:before(1/60,at,observer,sensor,cast,workspace.CurrentCamera,12);pw:after(1/60,d.motor,sensor,cast) end
  tick();local entry=assert(pw.garden[r.id]);local directors=pw:directors(r.id)
  check(#directors>0,"fixture has no cached prey director")
  check(table.find(pw.active,r.id)~=nil,"fixture not initially active")
  local clocks,flies,ids={},{},{}
  for _,director in directors do
   clocks[director]=director.now
   for _,f in director.flies do flies[f]={id=f.id,position=f.position,state=f.state,rng=f.rng.state};ids[f.id]=true end
  end
  local function waited() for director,now in clocks do if director.now~=now then return false end end;return true end
  local folder=assert(d.world:folderOf(r));local root=folder.Parent
  table.insert(undo,function() folder.Parent=root end);folder.Parent=nil
  check(not d.world:regionReady(r.id),"fixture geometry not absent")
  for _=1,12 do tick() end
  check(table.find(pw.active,r.id)==nil,"missing cached population still active")
  check(waited(),"cached director advanced without geometry")
  local hidden=true
  for _,f in pw:flies() do if ids[f.id] then hidden=false end end
  for _,f in pw:percepts() do if ids[f.id] then hidden=false end end
  check(hidden,"unavailable prey still drawn or perceived")
  local same=true
  for f,v in flies do if f.id~=v.id or f.position~=v.position or f.state~=v.state or f.rng.state~=v.rng then same=false end end
  check(same,"unavailable population changed pose/state/RNG")
  check(pw.garden[r.id]==entry,"cached population replaced while unavailable")
  folder.Parent=root
  local piece=assert(folder:FindFirstChild(Region.pieces(r)[1].id));table.insert(undo,function() piece.Parent=folder end);piece.Parent=nil
  tick();check(not d.world:regionReady(r.id) and table.find(pw.active,r.id)==nil and waited(),"partial rearrival stepped cached prey")
  piece.Parent=folder;tick()
  local advanced=true;for director,now in clocks do if director.now<=now then advanced=false end end
  check(table.find(pw.active,r.id)~=nil and pw.garden[r.id]==entry and advanced,"complete rearrival did not resume same population")
 end,debug.traceback)
 for i=#undo,1,-1 do pcall(undo[i]) end
 if ok then print("[NATIVE_PREY_READY_PASS]",id,count) else warn("[NATIVE_PREY_READY_FAIL]",id,tostring(err)) end
end
