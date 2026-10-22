-- Private engine-backed missing-geometry checks through the actual client's gate. Never publish.
local Run=game:GetService("RunService")
local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
local Region=require(game.ReplicatedStorage.Shared.World.Region)
local Station=require(game.ReplicatedStorage.Shared.World.StationTerritory)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("ReadinessProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local count=0;local undo={}
 local function check(ok,why) count+=1;assert(ok,why) end
 local function move(it,parent)
  local old=it.Parent;table.insert(undo,function() it.Parent=old end);it.Parent=parent
 end
 local ok,err=xpcall(function()
  print("[NATIVE_READINESS_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true;check(d.fresh("main",false,nil),"fresh refused")
  d.openMenu() -- Pause movement/creature stepping while geometry is deliberately removed locally.
  local r=assert(Map.region("garden_b4"));check(not Station.contains(r.id),"fixture is Persistent station path")
  d.place(r.spawn.pos+Vector3.yAxis*.31)
  deadline=os.clock()+30
  while (d.world.region.id~=r.id or not d.world:regionReady(r.id)) and os.clock()<deadline do
   d.world:report(r.spawn.pos,os.clock());Run.Heartbeat:Wait()
  end
  check(d.world.region.id==r.id and d.world:creatureLive(r.id),"initial region not ready")
  local folder=assert(d.world:folderOf(r));local root=folder.Parent
  check(folder:IsA("Model") and folder.ModelStreamingMode==Enum.ModelStreamingMode.Atomic,"fixture not Atomic")
  move(folder,nil)
  check(not d.world:regionReady(r.id),"missing folder still ready")
  check(not d.world:creatureLive(r.id),"cached gate admits removed model")
  folder.Parent=root
  check(d.world:creatureLive(r.id),"whole model did not resume")
  local piece=assert(folder:FindFirstChild(Region.pieces(r)[1].id));move(piece,nil)
  check(not d.world:regionReady(r.id) and not d.world:creatureLive(r.id),"cached gate admits partial geometry")
  folder.Parent=nil;folder.Parent=root
  check(not d.world:creatureLive(r.id),"partial rearrival admitted")
  piece.Parent=folder
  check(d.world:creatureLive(r.id),"complete rearrival did not resume")
  local cpu,worst=0,0
  for _=1,10 do
   Run.Heartbeat:Wait();local start=os.clock()
   for _=1,100 do assert(d.world:creatureLive(r.id)) end
   local cost=(os.clock()-start)*1000;cpu+=cost;worst=math.max(worst,cost)
  end
  print("[NATIVE_READINESS_COST]",id,1000,string.format("%.3f",cpu),string.format("%.3f",worst))
 end,debug.traceback)
 for i=#undo,1,-1 do pcall(undo[i]) end
 if ok then print("[NATIVE_READINESS_PASS]",id,count) else warn("[NATIVE_READINESS_FAIL]",id,tostring(err)) end
end
