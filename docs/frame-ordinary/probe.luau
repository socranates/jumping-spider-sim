--!strict
-- Unpublished measurement only. Read-only engine counters; bounded samples.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Stats:any=game:GetService("Stats")
local Http=game:GetService("HttpService")
local Prof=require(script.Parent.FrameProfile)
local Probe={}
local tag=tostring(DateTime.now().UnixTimestampMillis)
local state:any={begun=false,phase="not-started",marks={},failures={},sample=nil,last=nil}
local keys={"FrameTime","RenderCPUFrameTime","RenderGPUFrameTime","PhysicsStepTime","HeartbeatTime","SceneDrawcallCount","SceneTriangleCount","InstanceCount"}
local function emit(kind:string,value:any)print("[ORDINARY_FRAME_"..kind.."]",tag,Http:JSONEncode(value))end
local function metric():any
 local out={}
 for _,key in keys do
  local ok,value=pcall(function()return Stats[key]end)
  if ok and type(value)=="number"then out[key]=value else state.failures[key]=tostring(value)end
 end
 return out
end
local function heap():number return gcinfo()end
local function fresh(name:string):any
 return {name=name,began=os.clock(),frames=0,duration=0,times={},worst={},engine={},outliers={},over33=0,over50=0,over100=0,phase=state.phase,heap=heap()}
end
function Probe.mark(name:string)
 if not state.begun then return end
 local at=os.clock()
 table.insert(state.marks,{name=name,t=at-state.born,delta=at-state.lastMark,heap_kb=heap()})
 state.phase=name;state.lastMark=at
end
function Probe.begin()
 assert(not state.begun and Run:IsStudio() and Run:IsClient() and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("OrdinaryPerf")==true)
 state.begun=true;state.born=os.clock();state.lastMark=state.born
 Probe.mark("client-enter");state.sample=fresh("client-startup");Prof.start()
 state.connection=Run.Heartbeat:Connect(function(dt:number)
  local sample=state.sample;if sample==nil then return end
  sample.frames+=1;sample.duration+=dt;table.insert(sample.times,dt)
  local metrics=metric()
  for key,value in metrics do
   local row=sample.engine[key];if row==nil then row={total=0,max=0,n=0};sample.engine[key]=row end
   row.n+=1;row.total+=value;row.max=math.max(row.max,value)
  end
  if dt>1/30 then sample.over33+=1 end
  if dt>.05 then sample.over50+=1 end
  if dt>.1 then sample.over100+=1 end
  -- Retain the 12 largest gaps, keeping next-frame engine values as well.
  for _,old in sample.outliers do if old.next==nil then old.next=metrics end end
  if dt>.04 then
   local row={t=os.clock()-state.born,dt_ms=dt*1000,phase=state.phase,engine=metrics,previous=state.last,
    parts=table.clone(Prof.state.current),heap_kb=heap()}
   table.insert(sample.outliers,row);table.sort(sample.outliers,function(a:any,b:any):boolean return a.dt_ms>b.dt_ms end)
   if #sample.outliers>12 then table.remove(sample.outliers)end
  end
  state.last=metrics
 end)
end
function Probe.call(name:string,fn:any):any
 Probe.mark(name.."-begin");local value=fn();Probe.mark(name.."-end");return value
end
function Probe.watchLooks(looks:any)
 assert(looks)
 for _,name in {"replan","work","dew"}do
  local original=looks[name]
  looks[name]=function(self:any,...:any):...any
   local start=os.clock();local result=table.pack(original(self,...));local elapsed=os.clock()-start
   local sample=state.sample
   if sample then
    sample.methods=sample.methods or {};local row=sample.methods[name]or {n=0,total=0,worst=0}
    row.n+=1;row.total+=elapsed;row.worst=math.max(row.worst,elapsed);sample.methods[name]=row
   end
   return table.unpack(result,1,result.n)
  end
 end
end
function Probe.endSample(extra:any)
 local s=assert(state.sample);state.sample=nil;Prof.stop()
 table.sort(s.times)
 local function percentile(q:number):number return (s.times[math.max(1,math.ceil(#s.times*q))]or 0)*1000 end
 local engine={}
 for key,row in s.engine do engine[key]={mean=row.total/math.max(1,row.n),max=row.max,n=row.n}end
 local rows,n,mean,worst=Prof.rows()
 table.sort(rows,function(a:any,b:any):boolean return a.mean>b.mean end)
 for _,row in rows do emit("PART",{sample=s.name,name=row.name,mean_ms=row.mean,worst_ms=row.worst})end
 -- One metric and gap per line: Roblox's line truncation cannot hide a result.
 for key,value in engine do emit("ENGINE",{sample=s.name,name=key,mean=value.mean,max=value.max,n=value.n})end
 for name,row in s.methods or {}do emit("METHOD",{sample=s.name,name=name,calls=row.n,mean_ms=row.total/math.max(1,row.n)*1000,worst_ms=row.worst*1000})end
 for index,row in s.outliers do
  emit("GAP",{sample=s.name,index=index,t=row.t,dt_ms=row.dt_ms,phase=row.phase,heap_kb=row.heap_kb})
  for label,value in {current=row.engine,previous=row.previous,next=row.next}do emit("GAP_ENGINE",{sample=s.name,index=index,when=label,values=value})end
  for name,value in row.parts do if value>.001 then emit("GAP_PART",{sample=s.name,index=index,name=name,ms=value*1000})end end
 end
 emit("END",{sample=s.name,frames=s.frames,seconds=s.duration,wall_seconds=os.clock()-s.began,render_frames=n,
  p50_ms=percentile(.5),p95_ms=percentile(.95),p99_ms=percentile(.99),worst_ms=percentile(1),over33=s.over33,over50=s.over50,over100=s.over100,
  render_mean_ms=mean,render_worst_ms=worst,heap_growth_kb=heap()-s.heap,extra=extra})
end
function Probe.startSample(name:string)
 assert(state.begun and state.sample==nil);Probe.mark(name);state.sample=fresh(name);Prof.start()
end
function Probe.ready(extra:any)
 Probe.mark("client-constructed");Probe.endSample(extra)
 for _,row in state.marks do emit("MARK",row)end
 emit("COUNTERS",{unavailable=state.failures})
end
function Probe.finish(ok:boolean,why:any)
 if state.sample then Probe.endSample({partial=true})end
 if state.connection then state.connection:Disconnect()end
 emit(if ok then "PASS"else "FAIL",{problem=if ok then nil else tostring(why),ordinary_ui=true,cat_enabled=true,storage="yielding-memory",online=false})
 WS:SetAttribute("OrdinaryPerfFinished",true);WS:SetAttribute("OrdinaryPerfPassed",ok)
end
return Probe
