--!strict
-- Unpublished follow-up, called with the ordinary controller's hooks after the
-- short matrix. Observe every Heartbeat; output bounded minute rows. No saves,
-- transport, AI disabling, forced collections or changes to game source.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Stats:any=game:GetService("Stats")
local UIS=game:GetService("UserInputService")
return function(d:any,seconds:number)
 assert(Run:IsStudio() and Run:IsClient() and game.PlaceId==0 and game.GameId==0)
 assert(WS:GetAttribute("MatrixPerf")==true and seconds>=60 and seconds<=3600)
 assert(d.session.mode=="free" and d.world.region.id=="garden_a3" and d.motor.mode=="attached")
 local tag=tostring(DateTime.now().UnixTimestampMillis)
 local function emit(kind:string,value:any)
  print("[MATRIX_TRACE_"..kind.."]",tag,Http:JSONEncode(value))
 end
 local started=os.clock();local last=started;local nextReport=started
 local frames,turns,loadingFrames,pausedFrames=0,0,0,0
 local modes={};local regions={};local findings=0;local lastFinding=-100
 local minY=d.motor.pos.Y;local maxStep=0;local previous=d.motor.pos
 local focusLost,focusGained=0,0
 local lost=UIS.WindowFocusReleased:Connect(function()focusLost+=1 end)
 local gained=UIS.WindowFocused:Connect(function()focusGained+=1 end)
 local action,target="Left","garden_a1"
 local viewport=WS.CurrentCamera.ViewportSize
 local heap0=gcinfo();local simulation0=d.life.elapsed
 local function memory():any
  local okay,total=pcall(function():number return Stats:GetTotalMemoryUsageMb()end)
  local valid,count=pcall(function():number return Stats.InstanceCount end)
  return {lua_kb=gcinfo(),engine_mb=if okay then total else nil,instances=if valid then count else nil,
   unavailable=if not okay then tostring(total)elseif not valid then tostring(count)else nil}
 end
 emit("BEGIN",{seconds=seconds,detail=d.detail,viewport={viewport.X,viewport.Y},
  region=d.world.region.id,storage="unbound yielding memory only"})
 d.input:simulate(action,true,"long-trace")
 local okay,why=xpcall(function()
  repeat
   Run.Heartbeat:Wait()
   local now=os.clock();frames+=1
   local mode=d.motor.mode;modes[mode]=(modes[mode]or 0)+1
   regions[d.world.region.id]=true
   if d.world.playerLoading then loadingFrames+=1 end
   local paused=d.menu:isShowing()or d.title:holding()or d.life.resting
   if paused then pausedFrames+=1 end
   local pos=d.motor.pos;local step=(pos-previous).Magnitude
   minY=math.min(minY,pos.Y);maxStep=math.max(maxStep,step)
   if (mode~="attached"or step>5 or pos.Y< -89)and now-lastFinding>=1 then
    findings+=1;lastFinding=now
    emit("FINDING",{elapsed=now-started,mode=mode,step=step,position={pos.X,pos.Y,pos.Z},
     notice=d.life.notice,rival=d.life.rival and d.life.rival.state,
     wasp=d.wasp.wasp and d.wasp.wasp.phase,bird=d.bird and d.bird.state})
   end
   previous=pos
   assert(not d.saveState.broken and not d.life.lifeOver and not d.session.ended,"long trace lost its live life")
   assert(WS.CurrentCamera.ViewportSize==viewport,"long trace viewport changed")
   if d.world.region.id==target and mode=="attached"and not d.world.playerLoading then
    d.input:simulate(action,false,"long-trace")
    local wasLeft=action=="Left"
    action=if wasLeft then "Right"else "Left"
    target=if wasLeft then "garden_a3"else "garden_a1"
    d.input:simulate(action,true,"long-trace");turns+=1
   end
   if now>=nextReport then
    emit("ROW",{elapsed=now-started,simulation=d.life.elapsed-simulation0,memory=memory(),frames=frames,
     turns=turns,loading_frames=loadingFrames,paused_frames=pausedFrames,minimum_y=minY,
     max_step=maxStep,modes=modes,focus_lost=focusLost,focus_gained=focusGained})
    nextReport=now+60
   end
   last=now
  until last-started>=seconds
 end,debug.traceback)
 d.input:simulate(action,false,"long-trace")
 lost:Disconnect();gained:Disconnect()
 emit("END",{completed=okay,problem=if okay then nil else tostring(why),elapsed=os.clock()-started,
  simulation=d.life.elapsed-simulation0,frames=frames,turns=turns,regions=regions,modes=modes,
  loading_frames=loadingFrames,paused_frames=pausedFrames,minimum_y=minY,max_step=maxStep,
  findings=findings,lua_growth_kb=gcinfo()-heap0,memory=memory(),focus_lost=focusLost,focus_gained=focusGained})
 assert(okay,why)
end
