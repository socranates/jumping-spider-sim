-- Private attribution of the broad "sound" frame slice; no production optimization. Never publish.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local UIS=game:GetService("UserInputService")
local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
local specs={
 {"Soundscape","update"},{"Soundscape","updateWasp"},{"Soundscape","updateMeal"},
 {"WaspBody","draw"},{"CrabBody","draw"},{"StationMouseBody","draw"},
 {"PondBodies","draw"},{"BirdBody","draw"},{"CatBody","draw"},
}
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("AnimalCostProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local undo={};local rows={};local active=false;local focusLosses=0
 local connection=UIS.WindowFocusReleased:Connect(function() focusLosses+=1 end)
 local function waitFor(fn,seconds)
  local untilAt=os.clock()+seconds
  repeat Run.Heartbeat:Wait();if fn() then return true end until os.clock()>=untilAt
  return false
 end
 local function wait(seconds) local untilAt=os.clock()+seconds;repeat Run.Heartbeat:Wait() until os.clock()>=untilAt end
 local function state()
  return d.wasp.enabled==true and d.cat.enabled==true and d.bird.enabled==true and d.frog.enabled==true
 end
 local ok,err=xpcall(function()
  print("[NATIVE_ANIMAL_COST_BEGIN]",id)
  assert(waitFor(function() return game.Players.LocalPlayer:GetAttribute("TitleReady")==true end,90),"startup not ready")
  d.title.seen=true;d.session.finishedMain=true
  assert(d.fresh("free",false,nil),"Free life refused")
  local began=os.clock();local changedAt=began;local viewport=WS.CurrentCamera.ViewportSize
  assert(waitFor(function()
   local v=WS.CurrentCamera.ViewportSize;if v~=viewport then viewport=v;changedAt=os.clock() end
   return v.X>=320 and v.Y>=180 and os.clock()-began>=10 and os.clock()-changedAt>=3
  end,45),"viewport did not settle")
  for _,s in specs do
   local module=require(script.Parent[s[1]]);local name=s[2];local original=module[name]
   assert(type(original)=="function",s[1].."."..name)
   local row={name=s[1].."."..name,calls=0,cpu=0,worst=0,positiveHeap=0};table.insert(rows,row)
   module[name]=function(self,...)
    if not active then return original(self,...) end
    local heap=gcinfo();local at=os.clock();original(self,...);local cost=os.clock()-at
    row.cpu+=cost;row.worst=math.max(row.worst,cost);row.calls+=1
    row.positiveHeap+=math.max(0,gcinfo()-heap)
   end
   table.insert(undo,function() module[name]=original end)
  end
  for _,scene in {{id="sill_noon",region="sill",at=Vector3.new(0,.31,6)},{id="garden_mate",region="garden_b4"}} do
   assert(d.fresh("free",false,nil),"scene Free life refused");d.title:stop();d.camera.mouse=false
   d.life.clock.day=1;d.life.clock.hour=12;d.life:applyLight()
   local r=assert(Map.region(scene.region));local at=scene.at or r.spawn.pos+Vector3.yAxis*.31
   assert(waitFor(function()
    d.place(at,Vector3.yAxis);d.motor:place(at,Vector3.yAxis,r.spawn.heading);d.camera:snap()
    return d.world.region.id==r.id and d.world:regionReady(r.id)
   end,30),"scene geometry missing")
   wait(8)
   assert(not d.menu:isShowing() and not d.title:holding() and d.motor.mode=="attached","scene not playing")
   assert(state(),"predator disabled")
   local viewport=WS.CurrentCamera.ViewportSize;local losses=focusLosses
   for _,row in rows do row.calls=0;row.cpu=0;row.worst=0;row.positiveHeap=0 end
   d.prof.start();active=true;local sampleAt=os.clock();wait(12);active=false;d.prof.stop()
   local _,frames,total,worst=d.prof.rows()
   assert(frames>=120 and WS.CurrentCamera.ViewportSize==viewport and focusLosses==losses,"focus/viewport/sample invalid")
   assert(d.world.region.id==r.id and d.motor.mode=="attached" and (d.motor.pos-at).Magnitude<.5,"scene moved")
   assert(state(),"predator disabled after sample")
   print("[NATIVE_ANIMAL_COST_SCENE]",id,scene.id,frames,string.format("%.3f",os.clock()-sampleAt),string.format("%.3f",total),string.format("%.3f",worst),viewport.X,viewport.Y)
   for _,row in rows do
    print("[NATIVE_ANIMAL_COST_ROW]",id,scene.id,row.name,row.calls,string.format("%.6f",row.cpu*1000),string.format("%.6f",row.worst*1000),string.format("%.3f",row.positiveHeap))
   end
   print("[NATIVE_ANIMAL_COST_GROUP]",id,scene.id,d.prof.line())
  end
 end,debug.traceback)
 active=false;d.prof.stop();connection:Disconnect()
 for i=#undo,1,-1 do undo[i]() end
 if ok then print("[NATIVE_ANIMAL_COST_PASS]",id,2,#rows) else warn("[NATIVE_ANIMAL_COST_FAIL]",id,tostring(err)) end
end
