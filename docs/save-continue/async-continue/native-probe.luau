-- Actual menu/controller, injected LOCAL transport, production saving disabled.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local P=Shared.Persistence
local Checkpoint=require(P.Checkpoint)
local Json=require(P.Json)
local Progress=require(P.SaveProgress)
local Map=require(Shared.World.WorldMap)
local Client=require(script.Parent.SaveClient)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("AsyncContinueProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local ok,problem=xpcall(function()
  print("[NATIVE_ASYNC_CONTINUE_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true
  check(d.fresh("main",false,nil),"fresh life refused")
  d.openMenu()
  local attempts=0
  for _,r in Map.regions() do
   d.world.prey:directors(r.id);d.world.prey:bugs(r.id);d.world.prey:ambient(r.id)
   attempts+=1;if attempts%4==0 then Run.Heartbeat:Wait() end
  end
  local world={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,wasp=d.wasp,garden=d.world.garden,cat=d.cat,water=d.water}
  local record=assert(Checkpoint.capture(world,120));local expected=assert(Json.canonical(record))
  print("[NATIVE_ASYNC_CONTINUE_RECORD]",id,attempts,#expected,"resident_regions_unmeasured")
  local sequence=0;local sent={}
  local function receive(msg)
   sequence+=1;msg.sequence=sequence;msg.epoch="native-async-continue"
   if msg.kind=="loaded" then msg.v=3 end
   Client.receive(d.saveClient,msg)
  end
  d.saveClient.remotes={server={FireServer=function(_,msg) table.insert(sent,msg) end}}
  local receiveAt=os.clock()
  receive({kind="loaded",status="session",reason="other_session",progress=Progress.default(),offers={main={id="original",protected=false,record=record}}})
  print("[NATIVE_ASYNC_CONTINUE_RECEIVE]",id,string.format("%.3f",(os.clock()-receiveAt)*1000))
  d.session.started=false;d.openMenu()
  local oldStore=d.currentStore();local oldPosition=d.motor.pos
  check(d.menu:choose("Continue") and d.saveState.restore.job~=nil,"actual menu did not start preparation")
  for _=1,3 do Run.Heartbeat:Wait() end
  check(d.currentStore()==oldStore and (d.motor.pos-oldPosition).Magnitude<.001,"preparation changed live state")
  check(d.menu:choose("CancelRestore"),"cancel choice unavailable")
  check(d.saveState.restore.job==nil and d.saveClient:decision("main")==nil and d.currentStore()==oldStore,"cancel left a job, request or replacement store")
  local choiceAt=os.clock();local chosen=d.menu:choose("Continue")
  print("[NATIVE_ASYNC_CONTINUE_SELECT]",id,string.format("%.3f",(os.clock()-choiceAt)*1000))
  check(chosen and d.saveState.restore.job~=nil,"second actual selection refused")
  local request=assert(d.saveClient:decision("main"))
  check(not d.saveClient:abortContinue("main",request.serial-1,"native-async-continue"),"stale cancel revoked selection")
  local update=d.saveState.restore.update
  local steps,maxStep,maxGap,total=0,0,0,0
  d.saveState.restore.update=function(self)
   local at=os.clock();update(self);local elapsed=os.clock()-at
   steps+=1;total+=elapsed;maxStep=math.max(maxStep,elapsed)
  end
  local start=os.clock();local untilAt=start+120
  while d.saveState.restore.job and os.clock()<untilAt do
   maxGap=math.max(maxGap,Run.Heartbeat:Wait())
  end
  d.saveState.restore.update=update
  check(d.saveState.restore.job==nil and steps>1,"actual frame-driven preparation did not complete")
  print("[NATIVE_ASYNC_CONTINUE_TIMING]",id,steps,string.format("%.3f",maxStep*1000),string.format("%.3f",maxGap*1000),string.format("%.3f",total*1000),string.format("%.3f",(os.clock()-start)*1000))
  check(d.currentStore()~=oldStore and d.currentStore()==d.stores.main and d.session.started,"actual controller never installed prepared rest")
  check(Json.canonical(d.currentStore():loadBest().record)==expected,"committed local rest differs from selected record")
  check(d.saveClient:decision("main").serial==request.serial,"selection changed during preparation")
  local installed=d.currentStore()
  receive({kind="decision",decision={mode="main",kind="continue",serial=request.serial,offerId="original",revision=1,state="readonly",reason="other_session"}})
  for _=1,3 do Run.Heartbeat:Wait() end
  check(d.currentStore()==installed and d.saveState.restore.job==nil,"later authority reply replayed restore")
  print("[NATIVE_ASYNC_CONTINUE_DONE]",id,checks,"local_transport_only")
 end,debug.traceback)
 if not ok then warn("[NATIVE_ASYNC_CONTINUE_FAIL]",id,tostring(problem)) end
 workspace:SetAttribute("AsyncContinueProbeDone",true);workspace:SetAttribute("AsyncContinueProbePassed",ok)
end
