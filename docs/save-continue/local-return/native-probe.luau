-- Real local-return controller, unpublished local place, production saving disabled.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Json=require(Shared.Persistence.Json)
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Map=require(Shared.World.WorldMap)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("LocalReturnProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function waitRest(token)
  local deadline=os.clock()+120
  while token.pending and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(token.ok and not token.pending,"fixture rest did not finish")
 end
 local function watch(name)
  local manager=d.saveState.localRestore;local token=d.saveState.localReturnResult
  local original=manager.update;local steps,worst,total,gap=0,0,0,0
  manager.update=function(self)
   local at=os.clock();original(self);local cost=os.clock()-at
   steps+=1;worst=math.max(worst,cost);total+=cost
  end
  local start=os.clock();local deadline=start+120
  while token.pending and os.clock()<deadline do gap=math.max(gap,Run.Heartbeat:Wait()) end
  manager.update=original
  check(token.ok and not token.pending and steps>1,name.." did not finish across frames")
  print("[NATIVE_LOCAL_RETURN_WORK]",id,name,steps,string.format("%.3f",worst*1000),string.format("%.3f",gap*1000),string.format("%.3f",total*1000),string.format("%.3f",(os.clock()-start)*1000))
 end
 local ok,problem=xpcall(function()
  print("[NATIVE_LOCAL_RETURN_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true;check(d.fresh("main",false,nil),"fresh refused")
  d.openMenu();local attempts=0
  for _,r in Map.regions() do
   d.world.prey:directors(r.id);d.world.prey:bugs(r.id);d.world.prey:ambient(r.id)
   attempts+=1;if attempts%4==0 then Run.Heartbeat:Wait() end
  end
  d.place(Vector3.new(-25.5,.31,6));d.motor.vel=Vector3.zero;d.life.clock.hour=12;d.needs.energy=.9
  waitRest(d.life.save())
  local source=d.currentStore();local data=assert(Json.canonical(source.store.data));local record=source:loadBest()
  check(record.ok,"fixture checkpoint invalid")
  local text=assert(Json.canonical(record.record));local savedTick=d.prey.tick
  print("[NATIVE_LOCAL_RETURN_RECORD]",id,attempts,#text,"resident_regions_unmeasured")
  local away=Vector3.new(-5,.31,0);d.place(away);d.life.clock.hour=14
  d.openMenu();local canonical=Json.canonical;local encodes=0
  Json.canonical=function(...) encodes+=1;return canonical(...) end
  local at=os.clock();local accepted=d.menu:choose("Continue");local chooseMs=(os.clock()-at)*1000
  Json.canonical=canonical
  check(accepted and encodes==0 and d.saveState.localRestore.job~=nil,"local Continue did synchronous encoding or failed to queue")
  print("[NATIVE_LOCAL_RETURN_SYNC]",id,"choose",string.format("%.3f",chooseMs),encodes)
  local cancelled=d.saveState.localReturnResult;Run.Heartbeat:Wait()
  check(cancelled.pending and d.currentStore()==source and d.life.clock.hour==14 and (d.motor.pos-away).Magnitude<.001,"pending return changed world/store")
  check(d.menu:choose("CancelRestore") and cancelled.cancelled and d.currentStore()==source,"cancel failed")
  check(Json.canonical(source.store.data)==data,"cancel changed stored bytes")
  local prepare=Checkpoint.prepare;local decodes=0
  Checkpoint.prepare=function(...) decodes+=1;return prepare(...) end
  check(d.menu:choose("Continue"),"second Continue refused")
  watch("local_continue");Checkpoint.prepare=prepare
  check(decodes==1,"valid candidate decoded more than once")
  check(d.currentStore()==source and math.abs(d.life.clock.hour-12)<.01 and d.prey.tick<=savedTick+2,"committed world/store mismatch")
  d.openMenu() -- hold the restored world while inspecting retained storage
  check(Json.canonical(source.store.data)==data,"local Continue rewrote current/backup bytes")
  d.place(away);d.returnToCheckpoint();local stale=d.saveState.localReturnResult
  Run.Heartbeat:Wait();source.store:RemoveAsync("absent")
  Run.Heartbeat:Wait();Run.Heartbeat:Wait()
  check(stale.cancelled and d.currentStore()==source and (d.motor.pos-away).Magnitude<.001,"source mutation failed to fence stale return")
  check(d.menu:choose("Resume"),"resume refused")
  d.endLife("starved");deadline=os.clock()+10
  while d.caughtPanel.seconds<3 and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(d.caughtPanel:choose("Back"),"end-screen Back refused")
  local endToken=d.saveState.localReturnResult
  check(endToken.pending and d.session.ended,"end-screen Back revived too early")
  check(d.menu:choose("CancelRestore") and endToken.cancelled and d.session.ended and d.caughtPanel:isShowing(),"end cancellation lost the end screen")
  check(d.caughtPanel:choose("Back"),"second end-screen Back refused")
  watch("end_screen_return")
  check(not d.session.ended and d.currentStore()==source,"validated end return failed to revive")
  d.openMenu();d.returnToCheckpoint();local obsolete=d.saveState.localReturnResult
  check(d.fresh("main",false,nil) and obsolete.cancelled and d.saveState.localRestore.job==nil,"new life failed to cancel old return")
  print("[NATIVE_LOCAL_RETURN_PASS]",id,checks)
 end,debug.traceback)
 if not ok then warn("[NATIVE_LOCAL_RETURN_FAIL]",id,tostring(problem)) end
end
