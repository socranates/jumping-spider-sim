-- Network-owned delivery adapter and actual menu; injected LOCAL transport.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local P=Shared.Persistence
local Checkpoint=require(P.Checkpoint)
local Json=require(P.Json)
local Progress=require(P.SaveProgress)
local Map=require(Shared.World.WorldMap)
local Client=require(script.Parent.SaveClient)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("AsyncOffersProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function timed(name,fn)
  local at=os.clock();fn()
  print("[NATIVE_ASYNC_OFFERS_SYNC]",id,name,string.format("%.3f",(os.clock()-at)*1000))
 end
 local function watch(name,owner,method,pending)
  local original=owner[method];local steps,maxStep,total,maxGap=0,0,0,0
  owner[method]=function(self)
   local at=os.clock();original(self);local elapsed=os.clock()-at
   steps+=1;total+=elapsed;maxStep=math.max(maxStep,elapsed)
  end
  local start=os.clock();local untilAt=start+120
  while pending() and os.clock()<untilAt do maxGap=math.max(maxGap,Run.Heartbeat:Wait()) end
  owner[method]=original
  check(not pending() and steps>1,name.." did not complete across frames")
  print("[NATIVE_ASYNC_OFFERS_WORK]",id,name,steps,string.format("%.3f",maxStep*1000),string.format("%.3f",maxGap*1000),string.format("%.3f",total*1000),string.format("%.3f",(os.clock()-start)*1000))
 end
 local ok,problem=xpcall(function()
  print("[NATIVE_ASYNC_OFFERS_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true;check(d.fresh("main",false,nil),"fresh life refused")
  d.openMenu();local attempts=0
  for _,r in Map.regions() do
   d.world.prey:directors(r.id);d.world.prey:bugs(r.id);d.world.prey:ambient(r.id)
   attempts+=1;if attempts%4==0 then Run.Heartbeat:Wait() end
  end
  local world={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,wasp=d.wasp,garden=d.world.garden,cat=d.cat,water=d.water}
  local record=assert(Checkpoint.capture(world,120));local expected=assert(Json.canonical(record))
  print("[NATIVE_ASYNC_OFFERS_RECORD]",id,attempts,#expected,"resident_regions_unmeasured")
  -- The captured plain record stays stable throughout this diagnostic. The
  -- adapter takes ownership; retained probe references are read-only.
  local sequence=0;local sent={}
  local function receive(msg)
   sequence+=1;msg.sequence=sequence;msg.epoch="native-async-offers"
   if msg.kind=="loaded" then msg.v=3 end
   Client.receiveOwned(d.saveClient,msg)
  end
  d.saveClient.remotes={server={FireServer=function(_,msg) table.insert(sent,msg) end}}
  d.session.started=false
  local oldStore=d.currentStore();local oldPosition=d.motor.pos
  timed("initial_owned_receive",function()
   receive({kind="loaded",status="session",reason="other_session",progress=Progress.default(),offers={main={id="original",protected=false,record=record}}})
  end)
  check(d.saveClient:offerPending("main") and d.saveClient:offerInfo("main")==nil,"unvalidated record became visible")
  check(not d.menu:choose("New") and not d.fresh("main",false,nil),"unvalidated initial observation allowed New")
  check(d.currentStore()==oldStore and (d.motor.pos-oldPosition).Magnitude<.001,"initial queue changed world")
  watch("initial_offer",d.saveClient.bound,"stepOffers",function() return d.saveClient:offerPending() end)
  check(d.saveClient:offerInfo("main").id=="original" and not d.saveClient:offerReadProblem(),"validated offer missing")
  check(Json.canonical(d.saveClient:offer("main").record)==expected,"validated private offer differs")
  timed("five_known_repeats",function()
   for _=1,5 do receive({kind="offer",mode="main",offer={id="original",protected=false,record=record}}) end
  end)
  check(not d.saveClient:offerPending(),"immutable repeats queued preparation")
  d.openMenu();check(d.menu:choose("Continue") and d.saveState.restore.job~=nil,"actual Continue not queued")
  watch("actual_continue",d.saveState.restore,"update",function() return d.saveState.restore.job~=nil end)
  check(d.currentStore()~=oldStore and d.currentStore()==d.stores.main and d.session.started,"actual Continue did not install rest")
  local installed=d.currentStore();check(installed:hasKnownRest(),"verified store has no menu availability")
  local canonical=Json.canonical;local calls=0
  Json.canonical=function(...) calls+=1;return canonical(...) end
  timed("populated_menu",function() d.openMenu() end)
  Json.canonical=canonical
  check(calls==0,"menu synchronously encoded a known local rest")
  timed("replacement_owned_receive",function()
   receive({kind="offer",mode="main",offer={id="replacement",protected=false,record=record}})
  end)
  Run.Heartbeat:Wait()
  check(d.saveClient:offerPending() and d.currentStore()==installed,"replacement did not remain private")
  receive({kind="offer",mode="main",offer=nil})
  check(not d.saveClient:offerPending() and d.saveClient:offerInfo("main")==nil and d.currentStore()==installed,"withdrawal failed to cancel private work")
  receive({kind="offer",mode="main",offer={id="latest",protected=false,record=record}})
  local request=assert(d.saveClient:decision("main"))
  receive({kind="decision",decision={mode="main",kind="continue",serial=request.serial,offerId="original",revision=1,state="changed",reason="changed"}})
  check(d.saveClient:decision("main").state=="changed","authority change was delayed behind offer work")
  watch("replacement_offer",d.saveClient.bound,"stepOffers",function() return d.saveClient:offerPending() end)
  check(d.saveClient:offerInfo("main").id=="latest" and d.currentStore()==installed and d.saveState.restore.job==nil,"offer preparation restored a world without a choice")
  check(Json.canonical(installed:loadBest().record)==expected,"replacement changed current local rest")
  print("[NATIVE_ASYNC_OFFERS_DONE]",id,checks,"local_transport_only")
 end,debug.traceback)
 if not ok then warn("[NATIVE_ASYNC_OFFERS_FAIL]",id,tostring(problem)) end
 workspace:SetAttribute("AsyncOffersProbeDone",true);workspace:SetAttribute("AsyncOffersProbePassed",ok)
end
