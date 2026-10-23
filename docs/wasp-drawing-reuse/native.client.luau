-- Private paired component trial, never publish. No production startup or saves.
local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Http=game:GetService("HttpService")
assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("WaspReuseTrial")==true)
local Original=require(script.Parent:WaitForChild("Original"))
local Candidate=require(script.Parent:WaitForChild("Candidate"))
local root=Instance.new("Folder");root.Name="WaspReuseTrial";root.Parent=workspace
local a,b=Original.new(root),Candidate.new(root)
local camera=workspace.CurrentCamera;camera.CameraType=Enum.CameraType.Scriptable
camera.CFrame=CFrame.lookAt(Vector3.new(3,2,5),Vector3.zero)
local viewport=camera.ViewportSize
local losses=0;local connection=UIS.WindowFocusReleased:Connect(function() losses+=1 end)
local checks=0
local function check(ok,why) assert(ok,why);checks+=1 end
local function near(x,y) return (x-y).Magnitude<1e-5 end
local samples={}
for _,mode in {"flying","holding","walking","alternating"} do
 local list={}
 for i=1,360 do
  list[i]={state={position=Vector3.new(math.sin(i*.03)*.3,0,math.cos(i*.03)*.3),heading=Vector3.new(math.sin(i*.01),.1,math.cos(i*.01)).Unit,mode=if mode=="alternating" then ({"walking","flying","holding"})[i%3+1] else mode,search=(i%17)/16,visible=i%37~=0},time=i/60}
 end
 samples[mode]=list
end
local function compare()
 check(a.shown==b.shown and #a.parts==#b.parts,"visibility/count")
 for i,p in a.parts do
  local q=b.parts[i]
  check(near(p.Size,q.Size) and near(p.Position,q.Position),"native size/position")
  check(near(p.CFrame.RightVector,q.CFrame.RightVector) and near(p.CFrame.UpVector,q.CFrame.UpVector) and near(p.CFrame.LookVector,q.CFrame.LookVector),"native orientation")
  check(p.Transparency==q.Transparency and p.Reflectance==q.Reflectance and p.Color==q.Color,"native appearance")
 end
end
local function batch(rig,list)
 local heap=gcinfo();local started=os.clock()
 for _,s in list do rig:draw(s.state,s.time) end
 return (os.clock()-started)*1000,math.max(0,gcinfo()-heap)
end
local ok,problem=xpcall(function()
 print("[WASP_REUSE_NATIVE_BEGIN]",script:GetAttribute("SourceCommit"))
 -- Studio may report a 1x1 viewport before its first rendered frame.
 local deadline=os.clock()+30;local settled=os.clock()
 repeat
  Run.RenderStepped:Wait()
  local current=camera.ViewportSize
  if current~=viewport then viewport=current;settled=os.clock() end
  assert(os.clock()<deadline,"viewport did not settle")
 until viewport.X>=320 and viewport.Y>=180 and os.clock()-settled>=2
 losses=0
 for _,mode in {"flying","holding","walking","alternating"} do
  for _,s in samples[mode] do a:draw(s.state,s.time);b:draw(s.state,s.time);compare() end
  Run.RenderStepped:Wait()
 end
 local rows={}
 for pair=1,4 do
  for _,mode in {"flying","holding","walking","alternating"} do
   Run.RenderStepped:Wait()
   local ac,ah,bc,bh
   if pair%2==1 then ac,ah=batch(a,samples[mode]);bc,bh=batch(b,samples[mode])
   else bc,bh=batch(b,samples[mode]);ac,ah=batch(a,samples[mode]) end
   table.insert(rows,{pair=pair,mode=mode,original_ms=ac,candidate_ms=bc,original_positive_heap_kb=ah,candidate_positive_heap_kb=bh})
  end
 end
 check(losses==0 and camera.ViewportSize==viewport,"focus or viewport changed during trial")
 for _,row in rows do print("[WASP_REUSE_NATIVE_ROW]",Http:JSONEncode(row)) end
 print("[WASP_REUSE_NATIVE_RESULT]",Http:JSONEncode({source=script:GetAttribute("SourceCommit"),checks=checks,focus_losses=losses,width=viewport.X,height=viewport.Y,calls_per_batch=360}))
 print("[WASP_REUSE_NATIVE_PASS]",checks)
end,debug.traceback)
connection:Disconnect();a:destroy();b:destroy();root:Destroy()
if not ok then warn("[WASP_REUSE_NATIVE_FAIL]",problem) end
