--!strict
-- Read-only probe for the owner's isolated test experience. Never production.
local Run=game:GetService("RunService")
if Run:IsStudio() or game.GameId~=10771634917 or game.PlaceId~=109879630247781 then return end
local WS=game:GetService("Workspace")
local Players=game:GetService("Players")
local Stats:any=game:GetService("Stats")
local Http=game:GetService("HttpService")
local tag=tostring(DateTime.now().UnixTimestampMillis)
local born=os.clock();local lastPhase="";local frames=0;local total=0;local largest=0;local over50=0
local keys={"FrameTime","RenderCPUFrameTime","RenderGPUFrameTime","PhysicsStepTime","InstanceCount","SceneDrawcallCount"}
local metrics:any={};local gaps:any={};local failures:any={};local nextReport=15;local connection:RBXScriptConnection
local function emit(kind:string,value:any)print("[PLAYER_ARRIVAL_"..kind.."]",tag,Http:JSONEncode(value))end
local function phase():string
 if not game:IsLoaded()then return "initial-replication"end
 if WS:FindFirstChild("World")==nil then return "waiting-world"end
 if WS:GetAttribute("SaveStartupReady")~=true then return "waiting-save-startup"end
 local player=Players.LocalPlayer
 if not player or player:GetAttribute("TitleReady")~=true then return "navigation-or-title"end
 return "title-ready"
end
emit("BEGIN",{universe=game.GameId,place=game.PlaceId,readonly=true,detail=WS:GetAttribute("Detail")or "auto"})
connection=Run.Heartbeat:Connect(function(dt:number)
 local elapsed=os.clock()-born;local current=phase()
 if current~=lastPhase then emit("PHASE",{name=current,t=elapsed});lastPhase=current end
 frames+=1;total+=dt;largest=math.max(largest,dt);if dt>.05 then over50+=1 end
 local values:any={}
 for _,key in keys do
  local ok,value=pcall(function()return Stats[key]end)
  if ok and type(value)=="number"then
   values[key]=value
   local row=metrics[key]or {total=0,max=0,n=0};row.n+=1;row.total+=value;row.max=math.max(row.max,value);metrics[key]=row
  else failures[key]=tostring(value)end
 end
 if dt>.05 then
  table.insert(gaps,{t=elapsed,ms=dt*1000,phase=current,values=values})
  table.sort(gaps,function(a:any,b:any):boolean return a.ms>b.ms end)
  if #gaps>8 then table.remove(gaps)end
 end
 if elapsed>=nextReport then
  emit("SUMMARY",{t=elapsed,frames=frames,seconds=total,worst_ms=largest*1000,over50=over50,phase=current,store=WS:GetAttribute("SaveStoreName")})
  for key,row in metrics do emit("ENGINE",{t=elapsed,name=key,mean=row.total/math.max(1,row.n),max=row.max,n=row.n})end
  frames,total,largest,over50=0,0,0,0;metrics={};nextReport+=15
 end
 if elapsed>=90 then
  connection:Disconnect()
  for _,row in gaps do emit("GAP",row)end
  emit("END",{t=elapsed,phase=current,unavailable=failures,world_failed=Players.LocalPlayer:GetAttribute("WorldStartupFailed")==true})
 end
end)
