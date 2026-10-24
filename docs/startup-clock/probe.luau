--!strict
-- Unpublished client-clock observer. No gameplay, scheduling or save changes.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Stats:any=game:GetService("Stats")
local Prof=require(script.Parent.FrameProfile)
local P={}
local s:any={begun=false,phase="none",frames=0,gaps={},raw={},intervals={},unavailable={}}
local tag=tostring(DateTime.now().UnixTimestampMillis)
local function emit(kind:string,value:any)print("[STARTUP_CLOCK_"..kind.."]",tag,Http:JSONEncode(value))end
local function census(root:Instance):any
 local counts={instances=0,parts=0,meshes=0,scripts=0,gui=0}
 for _,it in root:GetDescendants()do
  counts.instances+=1
  if it:IsA("BasePart")then counts.parts+=1 end
  if it:IsA("DataModelMesh")then counts.meshes+=1 end
  if it:IsA("LuaSourceContainer")then counts.scripts+=1 end
  if it:IsA("GuiObject")then counts.gui+=1 end
 end
 return counts
end
function P.inventory(name:string)
 local started=os.clock();local roots={}
 for _,key in {"World","Decor","WorldDecor"}do
  local root=WS:FindFirstChild(key)
  if root then roots[key]=census(root)end
 end
 emit("INVENTORY",{name=name,t=os.clock()-s.born,roots=roots,workspace=census(WS),scan_ms=(os.clock()-started)*1000})
end
function P.mark(name:string)
 local now=os.clock()
 s.phase=name
 emit("MARK",{name=name,t=now-s.born,delta=now-s.lastMark,heap_kb=gcinfo(),server_at=WS:GetServerTimeNow()})
 s.lastMark=now
end
function P.note(name:string,value:any)emit(name,value)end
function P.elapsed():number return os.clock()-s.born end
function P.begin()
 assert(not s.begun and Run:IsStudio()and Run:IsClient()and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("StartupClock")==true)
 s.begun=true;s.born=os.clock();s.lastMark=s.born
 Prof.start()
 P.mark("client-enter")
 s.enginePhases={};s.phaseConnections={}
 local function phase(key:string,dt:number)
  local n=(s.enginePhases[key]or 0)+1;s.enginePhases[key]=n
  if n==1 then emit("ENGINE_FIRST",{name=key,t=os.clock()-s.born,raw_dt_ms=dt*1000,profile_frames=Prof.state.frames})end
 end
 for _,name in {"PreRender","PreAnimation","PreSimulation","PostSimulation"}do
  table.insert(s.phaseConnections,(Run::any)[name]:Connect(function(dt:number)phase(name,dt)end))
 end
 Run:BindToRenderStep("WindowsillStartupEarly",Enum.RenderPriority.First.Value,function(dt:number)phase("render-first",dt)end)
 Run:BindToRenderStep("WindowsillStartupLate",Enum.RenderPriority.Last.Value+1,function(dt:number)phase("render-last",dt)end)
 s.connection=Run.Heartbeat:Connect(function(dt:number)
  local now=os.clock();local elapsed=now-s.born
  local interval=now-(s.lastCallback or s.born);s.lastCallback=now;s.frames+=1
  if s.frames==1 then
   emit("FIRST",{t=elapsed,raw_dt_ms=dt*1000,observed_since_begin_ms=interval*1000,
    preprobe_span_lower_bound_ms=math.max(0,dt-interval)*1000,phase=s.phase})
  else table.insert(s.raw,dt);table.insert(s.intervals,interval)end
  if dt>.04 or interval>.04 then
   local row={t=elapsed,raw_dt_ms=dt*1000,callback_interval_ms=interval*1000,first=s.frames==1,phase=s.phase,heap_kb=gcinfo(),
    profile_frames=Prof.state.frames,parts=table.clone(Prof.state.current),engine_phases=table.clone(s.enginePhases)}
   local engine={}
   for _,key in {"FrameTime","RenderCPUFrameTime","RenderGPUFrameTime","PhysicsStepTime","InstanceCount"}do
    local okay,value=pcall(function():any return Stats[key]end)
    if okay and type(value)=="number"then engine[key]=value else s.unavailable[key]=tostring(value)end
   end
   row.engine=engine
   table.insert(s.gaps,row)
   table.sort(s.gaps,function(a:any,b:any):boolean return math.max(a.raw_dt_ms,a.callback_interval_ms)>math.max(b.raw_dt_ms,b.callback_interval_ms)end)
   if #s.gaps>12 then table.remove(s.gaps)end
  end
 end)
end
function P.call(name:string,fn:any):any
 P.mark(name.."-begin");local value=fn();P.mark(name.."-end");return value
end
function P.ready(extra:any)P.mark("client-hooks-ready");emit("CLIENT",extra);P.inventory("client-hooks-ready")end
local function summary(values:{number}):any
 table.sort(values);local sum=0;local over50=0;for _,value in values do sum+=value;if value>.05 then over50+=1 end end
 local function q(f:number):number return(values[math.max(1,math.ceil(#values*f))]or 0)*1000 end
 return{n=#values,mean_ms=sum/math.max(1,#values)*1000,p50_ms=q(.5),p95_ms=q(.95),max_ms=q(1),over50=over50}
end
function P.finish(ok:boolean,why:any)
 if s.connection then s.connection:Disconnect()end
 for _,connection in s.phaseConnections do connection:Disconnect()end
 Run:UnbindFromRenderStep("WindowsillStartupEarly");Run:UnbindFromRenderStep("WindowsillStartupLate")
 emit("ENGINE_COUNTS",{phases=s.enginePhases,heartbeat=s.frames,listeners_disconnected=true,render_bindings_removed=true})
 P.inventory("finish")
 Prof.stop()
 for _,row in s.gaps do
  local parts=row.parts;row.parts=nil;emit("GAP",row)
  for name,seconds in parts do if seconds>.001 then emit("GAP_PART",{t=row.t,name=name,ms=seconds*1000,profile_frames=row.profile_frames})end end
 end
 emit("SUMMARY",{wall_seconds=os.clock()-s.born,frames=s.frames,raw_after_first=summary(s.raw),callback_after_first=summary(s.intervals)})
 for name,why in s.unavailable do emit("UNAVAILABLE",{name=name,problem=why})end
 emit(if ok then"PASS"else"FAIL",{problem=if ok then nil else string.sub(tostring(why),1,400),unbound=true,storage="yielding-memory",detail=WS:GetAttribute("Detail")})
 WS:SetAttribute("StartupClockFinished",true)
end
return P
