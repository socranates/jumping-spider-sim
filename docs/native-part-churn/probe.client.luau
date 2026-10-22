-- Isolated Studio allocation control. No game code, persistence, assets or publish.
local Run=game:GetService("RunService")
local Stats=game:GetService("Stats")
local Input=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
local Http=game:GetService("HttpService")
local WS=game:GetService("Workspace")
assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("PartChurnProbe")==true)
local COUNT,CYCLES,STATIONARY,QUIET,SAMPLE=1000,60,30,30,5
local run=tostring(DateTime.now().UnixTimestampMillis)
local sequence,frames,frameSeconds,focusLosses,created,destroyed=0,0,0,0,0,0
local root=Instance.new("Folder");root.Name="PartChurnFixture";root.Parent=WS
local camera=WS.CurrentCamera
camera.CameraType=Enum.CameraType.Scriptable
camera.CFrame=CFrame.lookAt(Vector3.new(0,35,50),Vector3.zero)
local connections={}
local viewport: Vector2
local began=0
local tags={"BaseParts","Instances","Signals","LuaHeap","Internal","GraphicsParts"}
local function adler(s: string): number
 local a,b=1,0
 for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end
 return b*65536+a
end
local function emit(record)
 sequence+=1
 local data=Http:JSONEncode(record);assert(#data<900,"record exceeds bounded log size")
 print("[PART_CHURN_RECORD]",run,sequence,#data,adler(data),data)
end
local function guard()
 assert(focusLosses==0,"focus lost")
 assert(camera.ViewportSize==viewport,"viewport changed")
 assert(not Gui.MenuIsOpen,"Roblox menu opened")
end
local function pulse() Run.Heartbeat:Wait();guard() end
local function waitFor(seconds)
 local at=os.clock()
 repeat pulse() until os.clock()-at>=seconds
end
local function makeBatch()
 local folder=Instance.new("Folder");folder.Name="Batch"
 for i=1,COUNT do
  local part=Instance.new("Part")
  part.Name="P"..i;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  part.Size=Vector3.new(.7,.2,.7);part.CFrame=CFrame.new((i%40)-20,0,math.floor(i/40)-12)
  part.Color=Color3.fromRGB(95,125,75);part.Material=Enum.Material.SmoothPlastic
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  part.Parent=folder
  if i%100==0 then pulse() end
 end
 folder.Parent=root;created+=COUNT
 return folder
end
local function sample(phase,cycle,phaseBegan)
 guard()
 local memory={total_mb=Stats:GetTotalMemoryUsageMb(),gc_mib=gcinfo()/1024,instances=Stats.InstanceCount,tags_mb={}}
 for _,name in tags do
  local value=Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag[name])
  assert(value==value and value>=0 and value<math.huge,"invalid memory tag: "..name)
  memory.tags_mb[name]=value
 end
 local count=0;for _,item in root:GetDescendants() do if item:IsA("BasePart") then count+=1 end end
 local expected=if phase=="quiet" then 0 else COUNT
 assert(count==expected and created-destroyed==count,"live balance differs")
 emit({kind="sample",elapsed=os.clock()-began,phase=phase,phase_seconds=os.clock()-phaseBegan,cycle=cycle,
  created=created,destroyed=destroyed,live_parts=count,memory=memory,frames=frames,frame_seconds=frameSeconds,focus_losses=focusLosses})
end
local function hold(phase,seconds,cycle)
 local at=os.clock();sample(phase,cycle,at)
 for n=1,seconds/SAMPLE do
  repeat pulse() until os.clock()-at>=n*SAMPLE
  sample(phase,cycle,at)
 end
 return os.clock()-at
end
local ok,problem=pcall(function()
 task.wait(10) -- settle Play's viewport before the measured/control phases
 assert(Stats.MemoryTrackingEnabled,"memory tracking unavailable")
 viewport=camera.ViewportSize;assert(viewport.X>0 and viewport.Y>0)
 connections[1]=Input.WindowFocusReleased:Connect(function() focusLosses+=1 end)
 connections[2]=Run.RenderStepped:Connect(function(dt) frames+=1;frameSeconds+=dt end)
 began=os.clock()
 emit({kind="header",version=1,probe_sha256=WS:GetAttribute("ProbeSHA256"),engine=version(),viewport={viewport.X,viewport.Y},
  parts=COUNT,cycles=CYCLES,stationary_seconds=STATIONARY,quiet_seconds=QUIET,sample_seconds=SAMPLE,
  source="isolated standard Parts; no Windowsill game scripts",gc="natural; no forced collection",initial_focus="foreground guard and F5; loss events monitored"})
 local batch=makeBatch()
 local stationary=hold("stationary",STATIONARY,0)
 local churnBegan=os.clock();sample("churn",0,churnBegan)
 for cycle=1,CYCLES do
  local at=os.clock()
  batch:Destroy();batch=nil;destroyed+=COUNT
  assert(#root:GetChildren()==0,"destroyed batch still parented")
  batch=makeBatch()
  repeat pulse() until os.clock()-at>=1
  if cycle%SAMPLE==0 then sample("churn",cycle,churnBegan) end
 end
 local churn=os.clock()-churnBegan
 batch:Destroy();batch=nil;destroyed+=COUNT
 local quiet=hold("quiet",QUIET,CYCLES)
 guard();local elapsed=os.clock()-began
 assert(stationary>=STATIONARY and churn>=CYCLES and quiet>=QUIET and frames>elapsed*5 and frameSeconds>=elapsed*.9,"inactive/short control")
 assert(created==61000 and destroyed==61000 and #root:GetChildren()==0,"final fixture balance differs")
 emit({kind="final",elapsed=elapsed,stationary_seconds=stationary,churn_seconds=churn,quiet_seconds=quiet,
  created=created,destroyed=destroyed,live_parts=0,frames=frames,frame_seconds=frameSeconds,focus_losses=focusLosses})
end)
for _,connection in connections do connection:Disconnect() end
root:Destroy()
if ok then print("[PART_CHURN_DONE]",run,sequence) else warn("[PART_CHURN_FAIL]",run,tostring(problem)) end
WS:SetAttribute("PartChurnFinished",true);WS:SetAttribute("PartChurnPassed",ok)
