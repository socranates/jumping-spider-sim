--!strict
-- Unpublished candidate: bounded, read-only observer for the owner's private test.
-- No game state, input, camera, UI, network messages or save writes are changed.
local Run=game:GetService("RunService")
if Run:IsStudio()or game.GameId~=10771634917 or game.PlaceId~=109879630247781 then return end
local WS=game:GetService("Workspace")
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Http=game:GetService("HttpService")
local Stats:any=game:GetService("Stats")
local EXPECTED_STORE="WindowsillTest_playerRig_20261024a1"
local EXPECTED_EVIDENCE="032b5985ac17eeb2"
local born=os.clock();local lastBeat=born;local windowStart=born
local tag=tostring(DateTime.now().UnixTimestampMillis)
local connections:{RBXScriptConnection}={}
local counts:{[string]:number}={};local unavailable:{[string]:string}={}
local raw:{number}={};local intervals:{number}={};local gaps:{any}={}
local frames,rawTotal,observedTotal=0,0,0
local nextReport,windows,skipped=15,0,0
local focusLost,focusGained=0,0
local lastPhase="";local truncated=false;local finished=false
local earlyName="WindowsillPrivateArrivalFirst";local lateName="WindowsillPrivateArrivalLast"
local function emit(kind:string,value:any)
 print("[PRIVATE_CURRENT_"..kind.."]",tag,Http:JSONEncode(value))
end
local function phase():string
 if not game:IsLoaded()then return"initial-replication"end
 if WS:FindFirstChild("World")==nil then return"waiting-world"end
 if WS:GetAttribute("SaveStartupReady")~=true then return"waiting-save-startup"end
 local player=Players.LocalPlayer
 if not player or player:GetAttribute("TitleReady")~=true then return"navigation-or-title"end
 return"title-ready"
end
local function first(name:string,dt:number)
 local n=(counts[name]or 0)+1;counts[name]=n
 if n==1 then emit("ENGINE_FIRST",{name=name,t=os.clock()-born,raw_dt_ms=dt*1000})end
end
local function distribution(values:{number}):any
 table.sort(values)
 local function q(p:number):number return(values[math.max(1,math.ceil(#values*p))]or 0)*1000 end
 return{n=#values,p50_ms=q(.5),p95_ms=q(.95),p99_ms=q(.99),max_ms=q(1)}
end
local function engine():any
 local values:any={}
 for _,key in {"FrameTime","RenderCPUFrameTime","RenderGPUFrameTime","PhysicsStepTime","InstanceCount","SceneDrawcallCount"}do
  local okay,value=pcall(function():any return Stats[key]end)
  if okay and type(value)=="number"then values[key]=value else unavailable[key]=tostring(value)end
 end
 return values
end
emit("BEGIN",{universe=game.GameId,place=game.PlaceId,place_version=game.PlaceVersion,
 readonly=true,detail=WS:GetAttribute("Detail")or"auto",duration_s=90})
for _,name in {"PreRender","PreAnimation","PreSimulation","PostSimulation"}do
 table.insert(connections,(Run::any)[name]:Connect(function(dt:number)first(name,dt)end))
end
Run:BindToRenderStep(earlyName,Enum.RenderPriority.First.Value,function(dt:number)first("render-first",dt)end)
Run:BindToRenderStep(lateName,Enum.RenderPriority.Last.Value+1,function(dt:number)first("render-last",dt)end)
table.insert(connections,UIS.WindowFocusReleased:Connect(function()focusLost+=1 end))
table.insert(connections,UIS.WindowFocused:Connect(function()focusGained+=1 end))
table.insert(connections,Run.Heartbeat:Connect(function(dt:number)
 if finished then return end
 local now=os.clock();local elapsed=now-born;local interval=now-lastBeat;lastBeat=now
 local current=phase()
 if current~=lastPhase then emit("PHASE",{name=current,t=elapsed});lastPhase=current end
 if windows==0 and frames==0 then
  emit("FIRST",{t=elapsed,raw_dt_ms=dt*1000,observed_since_begin_ms=interval*1000,
   preprobe_span_lower_bound_ms=math.max(0,dt-interval)*1000})
 end
 frames+=1;rawTotal+=dt;observedTotal+=interval
 if #raw<16384 then table.insert(raw,dt);table.insert(intervals,interval)else truncated=true end
 if dt>.05 or interval>.05 then
  table.insert(gaps,{t=elapsed,raw_dt_ms=dt*1000,callback_interval_ms=interval*1000,
   phase=current,first=windows==0 and frames==1,engine_phases=table.clone(counts)})
  table.sort(gaps,function(a:any,b:any):boolean return math.max(a.raw_dt_ms,a.callback_interval_ms)>math.max(b.raw_dt_ms,b.callback_interval_ms)end)
  if #gaps>10 then table.remove(gaps)end
 end
 if elapsed>=nextReport then
  windows+=1
  local crossed=math.max(1,math.floor((elapsed-nextReport)/15)+1);skipped+=crossed-1;nextReport+=15*crossed
  emit("WINDOW",{index=windows,t=elapsed,started_at=windowStart-born,wall_seconds=now-windowStart,
   frames=frames,raw_seconds=rawTotal,observed_seconds=observedTotal,raw=distribution(raw),
   callbacks=distribution(intervals),samples_truncated=truncated,phase=current,
   store=WS:GetAttribute("SaveStoreName"),evidence=WS:GetAttribute("PortEvidence"),engine=engine(),
   focus_lost=focusLost,focus_gained=focusGained})
  frames,rawTotal,observedTotal=0,0,0;raw={};intervals={};truncated=false;windowStart=now
 end
 if elapsed>=90 then
  finished=true
  for _,connection in connections do connection:Disconnect()end
  Run:UnbindFromRenderStep(earlyName);Run:UnbindFromRenderStep(lateName)
  for _,row in gaps do emit("GAP",row)end
  local player=Players.LocalPlayer
  emit("END",{t=elapsed,phase=current,windows=windows,skipped_windows=skipped,
   place_version=game.PlaceVersion,evidence=WS:GetAttribute("PortEvidence"),store=WS:GetAttribute("SaveStoreName"),
   expected_evidence=EXPECTED_EVIDENCE,expected_store=EXPECTED_STORE,unavailable=unavailable,
   engine_phases=counts,connections_disconnected=#connections,render_bindings_removed=true,
   focus_lost=focusLost,focus_gained=focusGained,
   world_failed=player~=nil and player:GetAttribute("WorldStartupFailed")==true})
 end
end))
