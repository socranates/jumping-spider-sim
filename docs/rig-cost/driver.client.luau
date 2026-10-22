-- Isolated diagnostic only. Never publish; does not load the game or any save service.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local UIS=game:GetService("UserInputService")
assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("RigExperiment")==true)
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Original=require(Shared.Rig.SpiderRig)
local Cached=require(Shared.Rig.RigCached)
local Measured=require(Shared.Rig.RigMeasured)
local Living=require(Shared.Rig.Living)
local Appearances=require(Shared.Data.Appearances)
local run=tostring(DateTime.now().UnixTimestampMillis)
local losses=0
local conn=UIS.WindowFocusReleased:Connect(function() losses+=1 end)
local function emit(kind,value)
 local text=Http:JSONEncode(value);local a,b=1,0
 for i=1,#text do a=(a+string.byte(text,i))%65521;b=(b+a)%65521 end
 local n=math.ceil(#text/250)
 print("[CHET_RIG_BEGIN]",run,kind,#text,n,b*65536+a)
 for i=1,n do print("[CHET_RIG_DATA]",run,kind,i,Http:JSONEncode(text:sub((i-1)*250+1,i*250))) end
 print("[CHET_RIG_END]",run,kind)
end
local function summary(values)
 local sorted=table.clone(values);table.sort(sorted);local sum=0
 for _,v in values do sum+=v end
 return {n=#values,mean=sum/#values,p95=sorted[math.ceil(#values*.95)],max=sorted[#values]}
end
local floor=Instance.new("Folder");floor.Name="RigExperimentFloor";floor.Parent=WS
local ground=Instance.new("Part");ground.Name="Ground";ground.Anchored=true
ground.Size=Vector3.new(100,1,100);ground.Position=Vector3.new(0,-.5,0);ground.Parent=floor
local rigs=Instance.new("Folder");rigs.Name="DiagnosticRigs";rigs.Parent=WS
task.wait(8)
local camera=WS.CurrentCamera;camera.CameraType=Enum.CameraType.Scriptable
camera.CFrame=CFrame.lookAt(Vector3.new(0,5,8),Vector3.new(0,.5,-1))
local viewport=camera.ViewportSize
local cases=0
local function sameViewport() return WS.CurrentCamera.ViewportSize==viewport end
local function measure(id,tier,mode)
 local mods={Original,Cached,Measured};local objects={};local parts={};local offsets={-2.5,0,2.5}
 for i,module in mods do
  local rig=module.new(rigs,floor,id,tier)
  if rig._living then rig._living=Living.new(rig._appearance.idle,4242) end
  objects[i]=rig;parts[i]={}
  for _,p in rig.model:GetChildren() do if p:IsA("BasePart") then table.insert(parts[i],p) end end
 end
 assert(#parts[1]==#parts[2] and #parts[1]==#parts[3],"part count changed")
 local n=if id==Appearances.default and tier=="full" then 240 else 90
 local values={{},{},{}};local maxPos,maxAxis,maxSize=0,0,0
 local focus=losses
 local function frame(t,capture)
  local scale=if mode=="growth_hang" then (if t<3 then 1.32 else 1.7) else 1
  local moving=mode=="walk"
  local at=Vector3.new(if moving then .25*math.sin(t*2) else 0,if mode=="growth_hang" then 2.5 else .31*scale,if moving then -t*1.5 else 0)
  local body=CFrame.Angles(0,if moving then .15*math.sin(t*2) else 0,0)
  -- Alternating order prevents one variant always paying first-in-frame cost.
  local order=if math.floor(t*60)%2==0 then {1,2,3} else {3,2,1}
  for _,i in order do
   local rig=objects[i];rig:setScale(scale)
   rig.hangDirection=if mode=="growth_hang" then Vector3.new(.07,1,.035).Unit else nil
   rig.focusPoint=if mode=="stand" then Vector3.new(offsets[i]+1.5,.5,-2) else nil
   local cf=body+(at+Vector3.new(offsets[i],0,0))
   local began=os.clock();rig:update(cf,1/60,mode~="growth_hang",moving)
   if capture then table.insert(values[i],(os.clock()-began)*1000) end
  end
  if capture then
   for j,a in parts[1] do
    local b=parts[2][j]
    assert(a.Name==b.Name and a.Color==b.Color and a.Material==b.Material and a.Transparency==b.Transparency,"appearance changed")
    local ca,cb=a.CFrame,b.CFrame
    maxPos=math.max(maxPos,(ca.Position-Vector3.new(offsets[1],0,0)-cb.Position).Magnitude)
    maxAxis=math.max(maxAxis,(ca.RightVector-cb.RightVector).Magnitude,(ca.UpVector-cb.UpVector).Magnitude,(ca.LookVector-cb.LookVector).Magnitude)
    maxSize=math.max(maxSize,(a.Size-b.Size).Magnitude)
   end
  end
 end
 for f=1,90 do Run.RenderStepped:Wait();frame(f/60,false) end
 for key in Measured._probe do Measured._probe[key]=0 end
 for f=1,n do Run.RenderStepped:Wait();frame((f+90)/60,true) end
 local probe=table.clone(Measured._probe)
 local result={id=id,tier=tier,mode=mode,n=n,parts=#parts[1],raw_ms={original=values[1],cached=values[2],instrumented=values[3]},
  cpu_ms={original=summary(values[1]),cached=summary(values[2]),instrumented=summary(values[3])},
  probe=probe,max_position_error=maxPos,max_axis_error=maxAxis,max_size_error=maxSize,
  focus_preserved=focus==losses,viewport_unchanged=sameViewport(),
  scope="Isolated rig update CPU time; includes three visible rigs and diagnostic overhead; not game frame time"}
 emit(id.."_"..tier.."_"..mode,result)
 assert(maxPos<1e-4 and maxAxis<2e-3 and maxSize<1e-5,"cached pose differs beyond existing visual tolerance")
 assert(focus==losses and sameViewport(),"focus or viewport changed")
 for _,rig in objects do rig:destroy() end
 cases+=1
end
local ok,err=pcall(function()
 emit("header",{source=WS:GetAttribute("RigSource"),engine=version(),viewport={viewport.X,viewport.Y},seed=4242,
  scope="Local rig experiment only; no production change or save/network API; not whole-game performance"})
 local ids={};for id in Appearances.profiles do table.insert(ids,id) end;table.sort(ids)
 for _,id in ids do
  for _,tier in {"full","low"} do measure(id,tier,"walk") end
 end
 measure(Appearances.default,"full","stand")
 measure(Appearances.default,"full","growth_hang")
end)
conn:Disconnect()
if ok then print("[CHET_RIG_DONE]",run,cases) else warn("[CHET_RIG_FAIL]",run,tostring(err)) end
WS:SetAttribute("RigExperimentFinished",true);WS:SetAttribute("RigExperimentPassed",ok)
