-- Private actual-client engine streaming experiment. Never publish.
-- No collision parenting/deletion; reports go through the production WorldFocus.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Player=game:GetService("Players").LocalPlayer
local Http=game:GetService("HttpService")
local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
local Region=require(game.ReplicatedStorage.Shared.World.Region)
local Station=require(game.ReplicatedStorage.Shared.World.StationTerritory)
-- Serialized fixture settings are checked from XML; radii are not Lua-readable
-- in this Studio build. Do not mistake an unavailable property for zero.
local TARGET_RADIUS=160
local function frames(n) for _=1,n do Run.Heartbeat:Wait() end end
local function waitFor(fn,seconds)
 local deadline=os.clock()+seconds
 repeat Run.Heartbeat:Wait();if fn() then return true end until os.clock()>=deadline
 return false
end
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("WorldAnimationProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local count=0
 local samples={};local observedOut=false;local heldFrames=0
 local function check(ok,why) count+=1;assert(ok,why) end
 local function note(phase,data)
  data.phase=phase;data.run=id
  print("[ENGINE_STREAM_OBSERVATION]",Http:JSONEncode(data))
 end
 local function focusAt(at)
  local foci=WS:FindFirstChild("ReplicationFoci")
  local part=if foci then foci:FindFirstChild("ReplicationFocus_"..tostring(Player.UserId)) else nil
  return part~=nil and part:IsA("BasePart") and (part.Position-at).Magnitude<.1
 end
 local function arrive(region)
  local at=region.spawn.pos+Vector3.yAxis*.31
  d.place(at);d.world:report(at,os.clock())
  local began=os.clock()
  check(waitFor(function() return d.world.region.id==region.id and d.world:regionReady(region.id) and focusAt(at) end,35),"engine collision/focus did not arrive: "..region.id)
  local folder=assert(d.world:folderOf(region))
  check(folder:IsA("Model") and folder.ModelStreamingMode==Enum.ModelStreamingMode.Atomic,"fixture region is not Atomic: "..region.id)
  note("arrival",{region=region.id,seconds=os.clock()-began,collisionReady=true,serverFocusObserved=true,pieces=#Region.pieces(region)})
  return at,folder
 end
 local ok,problem=xpcall(function()
  print("[ENGINE_STREAM_BEGIN]",id)
  check(WS.StreamingEnabled,"fixture needs real instance streaming")
  check(waitFor(function() return Player:GetAttribute("TitleReady")==true end,90),"startup failed")
  d.title.seen=true;check(d.fresh("free",false,nil),"fresh life refused");d.title:stop();d.camera.mouse=false
  d.openMenu(true);check(d.menu:isShowing(),"menu did not pause fixture travel")
  local near=assert(Map.region("garden_b4"));local far=assert(Map.region("deck_n4"))
  check(not Station.contains(near.id) and not Station.contains(far.id),"fixture uses Persistent station collision")
  check((near.spawn.pos-far.spawn.pos).Magnitude>TARGET_RADIUS*3,"fixture destinations too close")
  local _,nearFolder=arrive(near)
  local life,motor=d.life,d.motor
  local nearAt=near.spawn.pos+Vector3.yAxis*.31
  d.menu:hide();frames(6)
  check(not d.world.playerLoading and d.motor.mode=="attached" and (d.motor.pos-nearAt).Magnitude<.02,"complete outdoor collision did not support the spider")
  d.openMenu(true)
  arrive(far)
  local removalAt=os.clock()
  observedOut=waitFor(function()
   return nearFolder.Parent==nil and not d.world:regionReady(near.id)
  end,45)
  note("away",{region=near.id,away=far.id,seconds=os.clock()-removalAt,engineRemoved=observedOut,nearReady=d.world:regionReady(near.id),streamOutBehavior="see immutable fixture manifest"})
  -- Retention is a valid engine choice under Default/low-memory behavior. It is
  -- recorded as not observed, never as proof of stream-out/rearrival.
  if not observedOut then
   note("scope",{streamOutVerified=false,reason="engine retained the near model within the bounded observation window"})
   return
  end
  check(d.life==life and d.motor==motor,"travel replaced the simulation objects")
  check(not d.world:regionReady(near.id),"near region arrived before return was requested")
  d.place(nearAt)
  local heldAt,velocity,mode=d.motor.pos,d.motor.vel,d.motor.mode
  local elapsed,needs,prey=d.life.elapsed,d.needs.elapsedS,d.world.prey.clock
  d.menu:hide();d.world:report(nearAt,os.clock())
  local began=os.clock();local ready=false
  while os.clock()-began<35 do
   frames(1)
   if d.world.playerLoading then
    heldFrames+=1
    check(d.motor.pos==heldAt and d.motor.vel==velocity and d.motor.mode==mode,"player advanced while real engine collision was absent")
    check(d.life.elapsed==elapsed and d.needs.elapsedS==needs and d.world.prey.clock==prey,"simulation clocks advanced while real engine collision was absent")
   elseif d.world:regionReady(near.id) then
    ready=true;break
   end
  end
  check(ready,"near collision did not return before the deadline")
  frames(6)
  check(not d.world.playerLoading and d.motor.mode=="attached" and (d.motor.pos-nearAt).Magnitude<.02,"engine return did not resume on the floor")
  check(d.life==life and d.motor==motor and d.life.elapsed>elapsed,"engine return failed to resume the same life")
  check(focusAt(nearAt),"server focus did not return with the player")
  note("return",{region=near.id,seconds=os.clock()-began,heldFrames=heldFrames,resumedSameObjects=true,collisionReady=true,streamOutVerified=true})
  -- A bounded foreground sample for this one scene, not a before/after FPS gain.
  for _=1,30 do frames(1) end
  for _=1,120 do local dt=Run.RenderStepped:Wait();table.insert(samples,dt*1000) end
  table.sort(samples);local total=0;for _,ms in samples do total+=ms end
  note("render_sample",{region=near.id,frames=#samples,meanMs=total/#samples,p95Ms=samples[math.ceil(#samples*.95)],maxMs=samples[#samples],viewport=tostring(WS.CurrentCamera.ViewportSize),detail=d.detail,comparisonGainClaim=false})
 end,debug.traceback)
 if ok then
  print("[ENGINE_STREAM_PASS]",id,Http:JSONEncode({checks=count,engineStreamOutObserved=observedOut,heldFrames=heldFrames,renderFrames=#samples}))
 else warn("[ENGINE_STREAM_FAIL]",id,tostring(problem)) end
 WS:SetAttribute("WorldAnimationProbeFinished",true);WS:SetAttribute("WorldAnimationProbePassed",ok)
end
