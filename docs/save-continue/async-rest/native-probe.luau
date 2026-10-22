-- Isolated actual-client rest preparation cost/safety check. No online store.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Json=require(Shared.Persistence.Json)
local Map=require(Shared.World.WorldMap)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("AsyncRestProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function settle(token,name)
  local manager=d.saveState.rest;local original=manager.update
  local steps,total,worst,gap=0,0,0,0
  manager.update=function(self)
   local at=os.clock();original(self);local cost=os.clock()-at
   steps+=1;total+=cost;worst=math.max(worst,cost)
  end
  local start=os.clock();local deadline=start+120
  while token.pending and os.clock()<deadline do gap=math.max(gap,Run.Heartbeat:Wait()) end
  manager.update=original
  check(not token.pending and token.ok and steps>1,name.." did not finish over frames")
  print("[NATIVE_ASYNC_REST_WORK]",id,name,steps,string.format("%.3f",worst*1000),string.format("%.3f",gap*1000),string.format("%.3f",total*1000),string.format("%.3f",(os.clock()-start)*1000))
 end
 local ok,problem=xpcall(function()
  print("[NATIVE_ASYNC_REST_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true;check(d.fresh("main",false,nil),"fresh refused")
  d.openMenu();local attempts=0
  for _,r in Map.regions() do
   d.world.prey:directors(r.id);d.world.prey:bugs(r.id);d.world.prey:ambient(r.id)
   attempts+=1;if attempts%4==0 then Run.Heartbeat:Wait() end
  end
  -- Pause simulation for repeatable cost measurements, not as production behavior.
  d.place(Vector3.new(-25.5,.31,6));d.motor.vel=Vector3.zero;d.life.clock.hour=12;d.needs.energy=.9
  local old=d.currentStore();local oldText=assert(Json.canonical(old.store.data));local count=d.life.checkpoints
  local at=os.clock();local first=d.life.save();local captureMs=(os.clock()-at)*1000
  check(first.pending and not first.ok and d.life.checkpoints==count,"capture announced success")
  check(d.currentStore()==old and Json.canonical(old.store.data)==oldText,"capture changed visible store")
  print("[NATIVE_ASYNC_REST_SYNC]",id,"capture",string.format("%.3f",captureMs))
  settle(first,"first_rest")
  local kept=d.currentStore();check(kept~=old and d.life.checkpoints==count+1,"rest not published once")
  local record=kept:loadBest();check(record.ok,"committed checkpoint invalid")
  local text=assert(Json.canonical(record.record))
  print("[NATIVE_ASYNC_REST_RECORD]",id,attempts,#text,"resident_regions_unmeasured")
  local previous=assert(Json.canonical(kept.store.data.checkpoint))
  local second=d.life.save();Run.Heartbeat:Wait();local newest=d.life.save()
  check(second.cancelled and not second.pending and d.currentStore()==kept,"superseded rest published")
  d.life:showNotice("You can now run.")
  settle(newest,"replacement_rest")
  check(Json.canonical(d.currentStore().store.data["checkpoint.bak"])==previous,"previous backup changed")
  check(d.life.notice=="You can now run.","delayed completion erased newer notice")
  local cancelled=d.life.save();check(d.fresh("main",false,nil),"new life refused")
  check(cancelled.cancelled and not cancelled.pending,"new life did not finalize obsolete token")
  -- A separate running case proves production simulation need not be held.
  d.place(Vector3.new(-25.5,.31,6));d.motor.vel=Vector3.zero;d.needs.energy=.9;d.life.clock.hour=12
  for _=1,3 do Run.Heartbeat:Wait() end
  local tick,elapsed=d.prey.tick,d.life.elapsed
  local running=d.life.save();settle(running,"running_rest")
  check(d.prey.tick>tick and d.life.elapsed>elapsed,"simulation stopped during preparation")
  print("[NATIVE_ASYNC_REST_PASS]",id,checks)
 end,debug.traceback)
 if not ok then warn("[NATIVE_ASYNC_REST_FAIL]",id,tostring(problem)) end
end
