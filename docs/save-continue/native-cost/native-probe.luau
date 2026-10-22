-- Studio-only actual save/controller timing with injected LOCAL transport.
-- Production Persistence is disabled; never publish this diagnostic.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Checkpoint=require(Shared.Persistence.Checkpoint)
local SaveRest=require(Shared.Persistence.SaveRest)
local Json=require(Shared.Persistence.Json)
local Rules=require(Shared.Data.SaveRules)
local Progress=require(Shared.Persistence.SaveProgress)
local Map=require(Shared.World.WorldMap)
local Client=require(script.Parent.SaveClient)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("SaveCostProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local stage=nil;local gaps={};local connection=Run.RenderStepped:Connect(function(dt)
  if stage then local r=gaps[stage];r.n+=1;r.max=math.max(r.max,dt) end
 end)
 local function timed(name,fn)
  stage=name;gaps[name]={n=0,max=0};Run.RenderStepped:Wait()
  local at=os.clock();local result=fn();local elapsed=os.clock()-at
  for _=1,3 do Run.RenderStepped:Wait() end
  local r=gaps[name];stage=nil
  print("[NATIVE_SAVE_COST_STAGE]",id,name,string.format("%.3f",elapsed*1000),r.n,string.format("%.3f",r.max*1000))
  return result
 end
 local ok,problem=xpcall(function()
  print("[NATIVE_SAVE_COST_BEGIN]",id,"47241c994c7b2fbd4eb3fed0c4affd75ece88c10")
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.RenderStepped:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup did not finish")
  d.title.seen=true;d.session.finishedMain=true
  check(d.fresh("main",false,nil),"fresh synthetic life failed")
  d.openMenu()
  local regions=0
  for _,r in Map.regions() do
   d.world.prey:directors(r.id);d.world.prey:bugs(r.id);d.world.prey:ambient(r.id)
   regions+=1;if regions%4==0 then Run.Heartbeat:Wait() end
  end
  check(regions==233,"unexpected preserve region count")
  local roots={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,wasp=d.wasp,garden=d.world.garden,cat=d.cat,water=d.water}
  local record=timed("capture_full_world",function() return assert(Checkpoint.capture(roots,120)) end)
  check(#SaveRest.check("main",record)==0,"full native record is invalid")
  print("[NATIVE_SAVE_COST_RECORD]",id,regions,#assert(Json.canonical(record)))
  local sequence=0;local sent={};local restCount=0;local allowReceipt=false
  local function receive(msg)
   sequence+=1;msg.epoch="native-local-cost";msg.sequence=sequence
   if msg.kind=="loaded" then msg.v=3 end
   Client.receive(d.saveClient,msg)
  end
  -- Test transport only. No RemoteEvent or online store is used by this table.
  d.saveClient.remotes={server={FireServer=function(_,msg)
   table.insert(sent,msg)
   if msg.kind=="rest" then
    restCount+=1
    check(allowReceipt,"readonly checkpoint escaped")
    receive({kind="stored",mode=msg.mode,serial=msg.serial,credential=msg.credential,restSerial=msg.restSerial})
   end
  end}}
  timed("receive_full_offer",function()
   receive({kind="loaded",status="session",reason="other_session",progress=Progress.default(),offers={main={id="native-full",protected=false,record=record}}})
  end)
  check(d.saveClient:offerInfo("main")~=nil,"offer not accepted")
  timed("five_immutable_repeats",function()
   for _=1,5 do receive({kind="offer",mode="main",offer={id="native-full",protected=false,record=record}}) end
  end)
  -- The test hook marks itself started at startup. Exercise a scripted title
  -- selection explicitly, without claiming this is a physical input test.
  d.session.started=false;d.openMenu()
  timed("actual_menu_continue_restore",function() check(d.menu:choose("Continue"),"menu choice refused") end)
  check(d.currentStore()==d.stores.main and d.session.started,"controller did not restore selected slot")
  local request=assert(d.saveClient:decision("main"));check(request.state=="readonly","selection unexpectedly writable")
  timed("actual_local_rest_and_queue",function() local r=d.life.save();check(r.ok,r.message) end)
  check(restCount==0,"temporary rest was uploaded")
  -- Issue the queued intent through the local transport before its scripted grant.
  d.saveClient.bound.refreshes={};d.saveClient.bound.lifeCursor=0;d.saveClient.bound.lastLife=-1e9;d.saveClient:update()
  local intentSeen=false;for _,m in sent do if m.kind=="life_intent" and m.serial==request.serial then intentSeen=true end end
  check(intentSeen,"scripted grant preceded actual intent")
  allowReceipt=true
  timed("grant_and_actual_upload_copy_local_receipt",function()
   receive({kind="decision",decision={mode="main",kind="continue",serial=request.serial,offerId="native-full",revision=1,state="writable",credential="native-local-grant",life=nil}})
   receive({kind="status",status="saved"})
   d.saveClient.bound.lastRest=-1e9;d.saveClient:update()
  end)
  check(restCount==1 and d.saveClient:status()=="saved","local injected receipt did not confirm stored ticket")
  print("[NATIVE_SAVE_COST_DONE]",id,checks,"local_transport_only")
 end,debug.traceback)
 connection:Disconnect()
 if not ok then warn("[NATIVE_SAVE_COST_FAIL]",id,tostring(problem)) end
 workspace:SetAttribute("SaveCostProbeDone",true);workspace:SetAttribute("SaveCostProbePassed",ok)
end
