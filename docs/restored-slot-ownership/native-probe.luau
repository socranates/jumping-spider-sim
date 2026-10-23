-- Private actual-client presentation/UI fixture. No production persistence. Never publish.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Player=game:GetService("Players").LocalPlayer
local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
local Region=require(game.ReplicatedStorage.Shared.World.Region)
local Growth=require(game.ReplicatedStorage.Shared.Life.Growth)
local WaspBody=require(script.Parent.WaspBody)
local CatBody=require(script.Parent.CatBody)
local function frames(n) for _=1,n do Run.Heartbeat:Wait() end end
local function waitFor(fn,seconds)
 local deadline=os.clock()+seconds
 repeat Run.Heartbeat:Wait();if fn() then return true end until os.clock()>=deadline
 return false
end
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("WorldAnimationProbe")==true)
 local run=tostring(DateTime.now().UnixTimestampMillis);local checks=0;local undo={}
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function capture(class,key,wrapper)
  local old=class[key];class[key]=wrapper(old);table.insert(undo,function() class[key]=old end)
 end
 local ok,problem=xpcall(function()
  print("[PLAYER_STREAM_NATIVE_BEGIN]",run)
  check(waitFor(function() return Player:GetAttribute("TitleReady")==true end,90),"startup not ready")
  d.title.seen=true
  check(waitFor(function() return d.fresh("free",false,nil) end,30),"fresh life refused")
  d.title:stop();d.camera.mouse=false
  local room=assert(Map.region("room_floor_e"))
  check(waitFor(function()
   d.place(room.spawn.pos);return d.world.region.id==room.id and d.world:regionReady(room.id)
  end,30),"back room geometry missing")
  d.life.clock.hour=12;d.life.clock.day=1
  WS:SetAttribute("WaspForce",nil)
  local g=d.life.growth;g.stage=0;g.fedSinceMoult=0;g.ready=false;g:useGameRules(true)
  frames(3)
  check(d.hud.moultProgress.Visible and d.hud.moultProgress.Text=="0/7 meals · until next moult","initial counter")
  g:eat(Growth.FLY_FOOD*1.5);frames(2)
  check(d.hud.moultProgress.Text=="1.5/7 meals · until next moult","partial meal counter")
  g.stage=1;g.fedSinceMoult=0;frames(2)
  check(d.hud.moultProgress.Text=="0/10 meals · until next moult","second counter")
  Player:SetAttribute("LargeText",true);frames(3)
  check(d.hud.moultProgress.TextSize==24 and d.hud.moultProgress.TextFits,"large counter fit")
  Player:SetAttribute("LargeText",nil)
  d.life.clock.hour=19;frames(3)
  check(d.hud.promptHint.Visible and d.hud.promptHint.Text=="It is getting dark. Find a home for the night.","dusk home message")
  check(d.hud.promptHint.TextFits,"dusk text fit")
  d.life.clock.hour=12
  local waspRig,catRig
  capture(WaspBody,"draw",function(old) return function(self,... ) waspRig=self;return old(self,...) end end)
  capture(CatBody,"draw",function(old) return function(self,... ) catRig=self;return old(self,...) end end)
  for _,animal in {d.wasp,d.frog,d.cat} do
   local old=animal.step;animal.step=function() end;table.insert(undo,function() animal.step=old end)
  end
  d.wasp.wasp.visible=true;d.wasp.wasp.mode="walking";d.wasp.wasp.search=.8
  d.wasp.wasp.position=room.spawn.pos+Vector3.new(5,1,0);d.wasp.wasp.heading=Vector3.zAxis
  d.frog.here=true;d.frog.pos=room.spawn.pos+Vector3.new(20,0,0);d.frog.heading=Vector3.zAxis
  d.cat.pose="walk";d.cat.pos=room.spawn.pos+Vector3.new(45,0,0);d.cat.heading=Vector3.zAxis
  frames(7)
  check(waspRig~=nil and catRig~=nil,"actual presentation drawers not called")
  local leg=assert(waspRig.folder:FindFirstChild("LegL1Tarsus"))
  local paw=assert(catRig.folder:FindFirstChild("FLPaw"))
  local throat=assert(d.pondBodies.frog.model:FindFirstChild("Throat"))
  local darner=assert(d.pondBodies.darner.parts[1])
  local home=d.prey.now;local world=d.world.prey.clock
  local before={leg.Position,paw.Position,throat.Size,darner.Position}
  local moved={false,false,false,false}
  for _=1,20 do
   frames(1)
   for i,value in {leg.Position,paw.Position,throat.Size,darner.Position} do moved[i]=moved[i] or (value-before[i]).Magnitude>.001 end
  end
  check(d.prey.now==home and d.world.prey.clock>world,"fixture did not isolate paused sill clock")
  check(moved[1],"wasp walking frozen")
  check(moved[2],"cat walking frozen")
  check(moved[3],"frog breath frozen")
  check(moved[4],"darner patrol frozen")
  check(d.world.region.id==room.id and d.motor.mode=="attached","player left test surface")
  check(d.hud.food.Visible and not d.hud.foodText.Visible and d.hud.foodText.Text=="","hunger bar gained words")

  -- Actual-client native collision disappearance, partial return and tick gate.
  do
   check(d.fresh("free",false,nil),"native stream fixture fresh life")
   d.title:stop();d.place(room.spawn.pos);frames(5)
   local folder=assert(d.world:folderOf(room));local parent=folder.Parent
   local part=assert(folder:FindFirstChild(Region.pieces(room)[1].id))
   table.insert(undo,function() part.Parent=folder;folder.Parent=parent end)
   check(d.world:regionReady(room.id) and d.motor.mode=="attached","native stream fixture needs complete supported collision")
   local at,vel,mode=d.motor.pos,d.motor.vel,d.motor.mode
   local life,needs,worldClock=d.life.elapsed,d.needs.elapsedS,d.world.prey.clock
   local lifeObject,motorObject=d.life,d.motor
   folder.Parent=nil;frames(10)
   check(d.world.playerLoading and d.motor.pos==at and d.motor.vel==vel and d.motor.mode==mode,"native missing collision changed player pose/state")
   check(d.life.elapsed==life and d.needs.elapsedS==needs and d.world.prey.clock==worldClock,"native collision wait advanced simulation clocks")
   part.Parent=nil;folder.Parent=parent;frames(4)
   check(d.world.playerLoading and d.motor.pos==at and d.life.elapsed==life,"native partial return resumed player")
   part.Parent=folder;frames(4)
   check(not d.world.playerLoading and d.motor.mode=="attached" and d.life.elapsed>life,"native complete collision did not resume")
   check(d.life==lifeObject and d.motor==motorObject,"native resume replaced simulation objects")
   at=d.motor.pos;life=d.life.elapsed;folder.Parent=nil;frames(4)
   check(d.world.playerLoading and d.motor.pos==at and d.life.elapsed==life,"native cached first arrival hid later disappearance")
   d.openMenu(true);frames(2);check(d.menu:isShowing(),"menu unavailable while waiting for collision")
   d.menu:hide();frames(3);check(d.world.playerLoading and d.motor.pos==at and d.life.elapsed==life,"hiding menu released incomplete collision wait")
   folder.Parent=parent;check(d.fresh("free",false,nil),"native prospective fixture fresh life");frames(4)
   at=d.motor.pos;d.motor.mode="air";d.motor.vel=(room.spawn.pos-at)/(1/60);vel=d.motor.vel
   life,needs=d.life.elapsed,d.needs.elapsedS;folder.Parent=nil
   local predicted=at+vel*(1/60)
   print("[PLAYER_STREAM_NATIVE_DIAGNOSTIC_BEFORE]",run,game:GetService("HttpService"):JSONEncode({at=tostring(at),target=tostring(room.spawn.pos),predicted=tostring(predicted),roundtripError=(predicted-room.spawn.pos).Magnitude,predictedRegion=(Map.at(predicted) or {}).id,targetRegion=(Map.at(room.spawn.pos) or {}).id,targetReady=d.world:regionReady(room.id),mode=d.motor.mode,velocity=tostring(vel),gravity=tostring(d.motor.gravity)}))
   frames(4)
   print("[PLAYER_STREAM_NATIVE_DIAGNOSTIC_AFTER]",run,game:GetService("HttpService"):JSONEncode({loading=d.world.playerLoading,moved=(d.motor.pos-at).Magnitude,position=tostring(d.motor.pos),mode=d.motor.mode,velocityDelta=(d.motor.vel-vel).Magnitude,lifeDelta=d.life.elapsed-life,needsDelta=d.needs.elapsedS-needs,menu=d.menu:isShowing(),title=d.title:holding(),targetReady=d.world:regionReady(room.id)}))
   check(d.world.playerLoading and d.motor.pos==at and d.motor.vel==vel and d.motor.mode=="air" and d.life.elapsed==life and d.needs.elapsedS==needs,"native prospective fixed tick advanced into absent collision")
   for _=1,30 do
    frames(1)
    check(d.world.playerLoading and d.motor.pos==at and d.motor.vel==vel and d.life.elapsed==life and d.needs.elapsedS==needs,"native destination wait flickered between fixed ticks")
   end
   folder.Parent=parent;check(d.fresh("free",false,nil),"native fixture cleanup reset");frames(3)
   print("[PLAYER_STREAM_NATIVE_CASES]",run,"hold partial resume same_objects second_out menu_while_waiting projected_tick")
  end

  -- Exercise the real adoption closure and independent modal hold. This is
  -- deliberately not a recovery grant, service, transport or datastore test.
  do
   check(d.fresh("main",false,nil),"pause fixture fresh Normal life")
   d.title:stop();frames(5);d.life.clock.hour=12;d.needs.energy=.55
   check(d.session.mode=="main" and d.needs.lifeMode and not d.needs.gentle,"pause fixture uses Normal needs")
   local result=d.life.save()
   check(waitFor(function() return not result.pending end,60) and result.ok,"pause fixture real local rest")
   local record=assert(d.currentStore():loadBest().record)
   d.openMenu(true)
   local oldHold=d.saveState.pauseRecovery();local currentHold=d.saveState.pauseRecovery()
   table.insert(undo,function() currentHold.release() end)
   check(not oldHold.held() and currentHold.held() and not oldHold.release(),"obsolete hold released current hold")
   local generation=d.saveState.worldGeneration;local priorStore=d.currentStore()
   local adopt=assert(d.saveState.restore.cfg.prepare(record,{mode="main"}));check(adopt(),"real adoption refused")
   check(d.saveState.worldGeneration==generation+1 and d.currentStore()~=priorStore,"adoption generation/store transition")
   local elapsed,needsTime,energy=d.life.elapsed,d.needs.elapsedS,d.needs.energy
   d.menu:hide();frames(60)
   check(currentHold.held() and not d.menu:isShowing() and d.life.elapsed==elapsed and d.needs.elapsedS==needsTime and d.needs.energy==energy,"menu hide resumed held adopted world")
   check(not oldHold.release() and currentHold.held(),"stale handle released adopted world")
   check(currentHold.release() and not currentHold.release() and not currentHold.held(),"current hold release not single use")
   frames(6)
   check(d.life.elapsed>elapsed and d.needs.elapsedS>needsTime,"explicit current release did not resume actual loop")
   print("[PLAYER_STREAM_NATIVE_RECOVERY_PAUSE]",run,"actual_adoption generation_increment_1 menu_hidden clocks_energy_frozen stale_release_refused current_release_resumes")
  end

  -- Physical-slot compatibility in the real local game; not online durability.
  do
   local Json=require(game.ReplicatedStorage.Shared.Persistence.Json)
   d.session.finishedMain=true
   check(d.fresh("main",true,nil),"legacy slot fixture fresh Easy")
   d.title:stop();frames(5);d.life.clock.hour=12
   local result=d.life.save()
   check(waitFor(function() return not result.pending end,60) and result.ok,"native gentle record capture")
   local record=assert(d.currentStore():loadBest().record)
   local easy=d.currentStore();local easyBytes=assert(Json.canonical(easy.store.data));local main=d.stores.main
   check(main:save(record).ok,"native gentle record in Main")
   d.openMenu();local chosen=d.menu:choose("Continue")
   check(chosen and waitFor(function() return d.saveState.localReturnResult and not d.saveState.localReturnResult.pending end,60) and d.saveState.localReturnResult.ok,"native gentle Main local Continue")
   check(d.currentStore()==main and d.saveClient.activeSlot=="main" and d.session.rules=="gentle" and d.needs.gentle,"native restore changed selected slot or rules")
   result=d.life.save()
   check(waitFor(function() return not result.pending end,60) and result.ok,"native next gentle Main rest")
   check(d.currentStore()==d.stores.main and d.stores.easy==easy and Json.canonical(easy.store.data)==easyBytes,"native Main rest changed Easy")
   d.endLife("starved")
   check(not d.session.ended,"native legacy gentle Main permits starvation death")
   local endLife,offerInfo=d.session.endLife,d.saveClient.offerInfo
   table.insert(undo,function() d.session.endLife=endLife;d.saveClient.offerInfo=offerInfo end)
   d.session.endLife=function(self) self.ended=true;return true end
   d.saveClient.offerInfo=function(_,slot) return {id="native-ending-"..slot} end
   d.endLife("starved")
   check(d.saveState.endOfferId=="native-ending-main","native controlled ending chose wrong slot offer")
   d.session.endLife=endLife;d.saveClient.offerInfo=offerInfo
   check(d.fresh("main",true,nil),"native explicit new Easy refused")
   check(d.currentStore()==d.stores.easy and d.saveClient.activeSlot=="easy" and d.needs.gentle,"native explicit Easy slot differs")
   check(d.fresh("main",false,nil) and d.currentStore()==d.stores.main and d.saveClient.activeSlot=="main" and not d.needs.gentle,"native explicit Normal slot differs")
   print("[PLAYER_STREAM_NATIVE_LEGACY_SLOT]",run,"physical_slot rules easy_bytes end_offer fresh_slots")
  end

  print("[PLAYER_STREAM_NATIVE_VIEWPORT]",run,WS.CurrentCamera.ViewportSize.X,WS.CurrentCamera.ViewportSize.Y)
 end,debug.traceback)
 for i=#undo,1,-1 do undo[i]() end
 Player:SetAttribute("LargeText",nil)
 if ok then print("[PLAYER_STREAM_NATIVE_PASS]",run,checks) else warn("[PLAYER_STREAM_NATIVE_FAIL]",run,tostring(problem)) end
 WS:SetAttribute("WorldAnimationProbeFinished",true);WS:SetAttribute("WorldAnimationProbePassed",ok)
end
