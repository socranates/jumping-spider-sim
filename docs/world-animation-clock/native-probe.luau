-- Private actual-client presentation/UI fixture. No production persistence. Never publish.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Player=game:GetService("Players").LocalPlayer
local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
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
  print("[WORLD_ANIMATION_NATIVE_BEGIN]",run)
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
  print("[WORLD_ANIMATION_NATIVE_VIEWPORT]",run,WS.CurrentCamera.ViewportSize.X,WS.CurrentCamera.ViewportSize.Y)
 end,debug.traceback)
 for i=#undo,1,-1 do undo[i]() end
 Player:SetAttribute("LargeText",nil)
 if ok then print("[WORLD_ANIMATION_NATIVE_PASS]",run,checks) else warn("[WORLD_ANIMATION_NATIVE_FAIL]",run,tostring(problem)) end
 WS:SetAttribute("WorldAnimationProbeFinished",true);WS:SetAttribute("WorldAnimationProbePassed",ok)
end
