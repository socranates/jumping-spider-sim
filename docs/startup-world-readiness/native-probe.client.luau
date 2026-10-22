-- Local component diagnostic only; never publish. Actor and persistence are disabled.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldClient=require(script.Parent.WorldClient)
local Splash=require(game:GetService("ReplicatedFirst"):WaitForChild("SplashScreen"))
local Map=require(Shared.World.WorldMap)
local Region=require(Shared.World.Region)
local Text=require(Shared.UI.TitleText)
assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("StartupComponentProbe")==true)
local player=Players.LocalPlayer
local gui=player:WaitForChild("PlayerGui",10)
local camera=workspace.CurrentCamera
local startCamera={kind=camera.CameraType,cf=camera.CFrame,fov=camera.FieldOfView}
local run=tostring(DateTime.now().UnixTimestampMillis)
local checks,cases=0,0
local owned={}
local realHost=Splash.host
local function own(it) table.insert(owned,it);return it end
local function settle() for _=1,3 do Run.RenderStepped:Wait() end end
local function check(ok,why) checks+=1;assert(ok,why) end
local function case(name,want,fn)
 local before=checks;fn();assert(checks-before==want,"case assertion count: "..name)
 cases+=1;print("[STARTUP_COMPONENT_CASE]",run,cases,checks,name)
end
local function carrier() return own(Instance.new("Folder")) end
local function allDisconnected(h)
 for _,c in h.connections do if c.Connected then return false end end
 return true
end
local function currentUI() return gui:FindFirstChild(Splash.GUI_NAME) end
local function teardown(h)
 if h.screen and h.screen.Parent then h.screen:Destroy() end
 settle()
end
-- UI timing is deliberately accelerated. Layout/signals are native; this is not a load-time benchmark.
local function uiHost(o)
 assert(currentUI()==nil,"a previous component screen still exists")
 local state=carrier()
 if o.failed then state:SetAttribute(Splash.FAIL_ATTRIBUTE,true) end
 if o.large then state:SetAttribute("LargeText",true) end
 local h={frames=0,connections={},warnings={},removed=0,removedAfterGui=false,screen=nil}
 local fake={}
 function fake:WaitForChild(name) if o.noGui then return nil end;assert(name=="PlayerGui");return gui end
 function fake:GetAttribute(name) return state:GetAttribute(name) end
 function fake:GetAttributeChangedSignal(name)
  if o.badConnect then error("synthetic readiness subscription failure") end
  local event=state:GetAttributeChangedSignal(name)
  return {Connect=function(_,fn) local c=event:Connect(fn);table.insert(h.connections,c);return c end}
 end
 h.state=state
 h.service=function(name)
  if name=="Players" then if o.noPlayer then error("synthetic missing Players") end;return {LocalPlayer=fake} end
  if name=="Workspace" then return workspace end
  if name=="ReplicatedFirst" then return {RemoveDefaultLoadingScreen=function()
   h.removed+=1;h.removedAfterGui=currentUI()~=nil
   game:GetService("ReplicatedFirst"):RemoveDefaultLoadingScreen()
  end} end
  error("unexpected service "..name)
 end
 h.frame=function()
  Run.RenderStepped:Wait();h.frames+=1
  h.screen=currentUI() or h.screen
  if h.screen then own(h.screen) end
  if o.readyAt and h.frames==o.readyAt then state:SetAttribute(Splash.READY_ATTRIBUTE,true) end
  if o.frameError and h.frames==3 then error("synthetic frame failure") end
  return 1
 end
 h.now=os.clock;h.loaded=function() return true end;h.world=function() return "preserve" end
 h.find=function()
  if o.noWords then return nil,nil end
  return Text,{drift=function() return startCamera.cf,startCamera.fov end}
 end
 h.warn=function(message) table.insert(h.warnings,message) end
 Splash.host=h
 local ok,result=pcall(Splash.run)
 Splash.host=realHost
 assert(ok,result);h.result=result;h.screen=currentUI() or h.screen
 settle();return h
end
local function fits(label)
 local untilTime=os.clock()+2
 while not label.TextFits and os.clock()<untilTime do Run.RenderStepped:Wait() end
 return label.TextFits
end
local ok,problem=pcall(function()
 local signal="unavailable";pcall(function() signal=tostring(workspace.SignalBehavior) end)
 print("[STARTUP_COMPONENT_BEGIN]",run,signal,camera.ViewportSize.X,camera.ViewportSize.Y)
 local actual=WorldClient.new(workspace,carrier())
 local home=assert(Map.region(Map.HOME));local homeName=Region.folderName(home)
 local pieces=Region.pieces(home);local first=pieces[1].id
 local function proxy(mode,streaming)
  local requested={}
  local p=carrier();local bad=own(Instance.new("Folder"));bad.Name=first
  local sill={Name=homeName}
  function sill:FindFirstChild(name)
   if name==first and mode=="piece" then return nil end
   if name==first and mode=="badtype" then return bad end
   return actual.sill:FindFirstChild(name)
  end
  function sill:WaitForChild(name,timeout) table.insert(requested,{name=name,timeout=timeout});return nil end
  local root={Name="World"}
  function root:FindFirstChild(name) if name==homeName and mode~="home" then return sill end;return nil end
  function root:WaitForChild(name,timeout) table.insert(requested,{name=name,timeout=timeout});return nil end
  local ws={StreamingEnabled=streaming~=false};local reads=0
  function ws:GetAttribute(name)
   assert(name=="World");reads+=1
   if mode=="unknown" then return "unknown_world" end
   if mode=="lateid" and reads<3 then return nil end
   return "preserve"
  end
  function ws:FindFirstChild(name)
   if name=="World" and mode~="root" then return root end
   if name=="Decor" and mode~="decor" then return workspace:FindFirstChild("Decor") end
   return nil
  end
  function ws:WaitForChild(name,timeout) table.insert(requested,{name=name,timeout=timeout});return nil end
  return ws,p,requested,function() return reads end
 end
 case("healthy server-built native home",2,function()
  check(actual.root==workspace:FindFirstChild("World") and actual.sill.Name==homeName,"actual server layout")
  check(actual:regionReady(home.id) and actual.player:GetAttribute(WorldClient.FAIL_ATTRIBUTE)==false,"home complete before construction returns")
 end)
 case("delayed home arrives through native WaitForChild",2,function()
  local root=own(Instance.new("Folder"));root.Name="World"
  local p=carrier();local ws={StreamingEnabled=true}
  function ws:GetAttribute() return "preserve" end
  function ws:FindFirstChild(name) if name=="World" then return root end;if name=="Decor" then return workspace:FindFirstChild(name) end;return nil end
  task.delay(.05,function()
   local f=Instance.new("Folder");f.Name=homeName;f.Parent=root
   for _,piece in pieces do local part=Instance.new("Part");part.Name=piece.id;part.Anchored=true;part.Parent=f end
  end)
  local c=WorldClient.new(ws :: any,p)
  check(c.sill.Parent==root and #c.sill:GetChildren()==#pieces,"real delayed child arrival")
  check(c:regionReady(home.id) and p:GetAttribute(WorldClient.FAIL_ATTRIBUTE)==false,"delayed complete native home accepted")
 end)
 case("missing and wrong-class home collision",3,function()
  for _,mode in {"piece","badtype"} do
   local ws,p,asked=proxy(mode);local c=nil
   local accepted,err=pcall(function() c=WorldClient.new(ws :: any,p) end)
   check(not accepted and c==nil and p:GetAttribute(WorldClient.FAIL_ATTRIBUTE)==true and string.find(tostring(err),first,1,true),"invalid collision rejected")
   if mode=="piece" then check(#asked==1 and asked[1].timeout>0 and asked[1].timeout<=WorldClient.PIECES_WAIT,"bounded requested budget") end
  end
 end)
 case("missing essential folders",4,function()
  for _,mode in {"root","home"} do
   local ws,p,asked=proxy(mode)
   local accepted=pcall(function() WorldClient.new(ws :: any,p) end)
   check(not accepted and p:GetAttribute(WorldClient.FAIL_ATTRIBUTE)==true,"missing folder rejected")
   check(#asked==1 and asked[1].timeout>0 and asked[1].timeout<=WorldClient.PIECES_WAIT,"folder wait budget supplied")
  end
 end)
 case("late identity and unknown identity",3,function()
  local ws,p,_,reads=proxy("lateid");local c=WorldClient.new(ws :: any,p)
  check(c.world=="preserve" and reads()>=3,"late known identity accepted")
  local before=Map.world();ws,p=proxy("unknown")
  local accepted=pcall(function() WorldClient.new(ws :: any,p) end)
  check(not accepted and p:GetAttribute(WorldClient.FAIL_ATTRIBUTE)==true,"unknown identity never guesses")
  check(Map.world()==before,"unknown identity did not change active map")
 end)
 case("legacy, non-streaming and optional decor boundaries",3,function()
  local flat=own(Instance.new("Folder"));flat.Name=homeName
  local p=carrier();local calls=0;local ws={StreamingEnabled=false}
  function ws:GetAttribute() return "preserve" end
  function ws:FindFirstChild(name) if name==homeName then return flat end;return nil end
  function ws:WaitForChild() calls+=1;return nil end
  check(WorldClient.new(ws :: any,p).root==flat and calls==0,"legacy flat fixture remains immediate")
  ws,p=proxy("piece",false)
  check(not pcall(function() WorldClient.new(ws :: any,p) end) and p:GetAttribute(WorldClient.FAIL_ATTRIBUTE)==true,"non-streaming server layout still needs collision")
  ws,p=proxy("decor")
  local c=WorldClient.new(ws :: any,p)
  check(c.decor==nil and p:GetAttribute(WorldClient.FAIL_ATTRIBUTE)==false,"decor remains best effort")
 end)
 case("healthy native splash handoff",3,function()
  local h=uiHost({readyAt=3})
  check(h.result=="ready","healthy completion")
  check(currentUI()==nil,"healthy screen removed")
  check(h.removed==1 and h.removedAfterGui,"default removal followed real GUI construction")
 end)
 case("explicit failure is legible and owned",4,function()
  local h=uiHost({failed=true});local screen=assert(currentUI());local sub=screen.Subtitle
  check(h.result=="world" and h.frames<45,"failed world is not shown as ready")
  check(sub.Text==Splash.FAILURE_TEXT and sub.TextTransparency==0,"recovery explanation visible")
  check(fits(sub),"normal text fits native viewport")
  teardown(h);check(allDisconnected(h),"GUI destruction disconnected readiness while carrier still alive")
 end)
 case("missing Shared words and large text recover late",6,function()
  for _,large in {false,true} do
   local h=uiHost({noWords=true,large=large});local screen=assert(currentUI());local sub=screen.Subtitle
   check(h.result=="timeout","unready frame loop terminated")
   check(sub.TextSize==(if large then 24 else 20) and fits(sub),"bootstrap-local native text fits")
   h.state:SetAttribute(Splash.READY_ATTRIBUTE,true);settle()
   check(currentUI()==nil and allDisconnected(h),"late readiness cleared screen and listener")
  end
 end)
 case("caught frame failure keeps recovery",3,function()
  local h=uiHost({frameError=true});local screen=assert(currentUI())
  check(string.find(h.result,"failed",1,true)==1,"frame failure caught")
  check(#h.warnings==1 and fits(screen.Subtitle),"warning retained and message fits")
  teardown(h);check(allDisconnected(h),"caught-error screen disposed cleanly")
 end)
 case("native readiness/destruction race",2,function()
  for _,readyFirst in {false,true} do
   local h=uiHost({});local screen=assert(currentUI())
   if readyFirst then h.state:SetAttribute(Splash.READY_ATTRIBUTE,true);screen:Destroy()
   else screen:Destroy();h.state:SetAttribute(Splash.READY_ATTRIBUTE,true) end
   settle()
   check(currentUI()==nil and allDisconnected(h),"both queued orders leave no readiness connection")
  end
 end)
 case("subscription and early-service failure cleanup",3,function()
  local h=uiHost({badConnect=true})
  check(currentUI()==nil and #h.warnings==1 and allDisconnected(h),"subscription failure disposed recovery UI")
  h=uiHost({noPlayer=true})
  check(string.find(h.result,"failed",1,true)==1 and h.frames==0 and h.removed==0,"missing Players did not remove default via our callback")
  h=uiHost({noGui=true})
  check(string.find(h.result,"failed",1,true)==1 and h.frames==0 and h.removed==0,"missing PlayerGui did not remove default via our callback")
 end)
 assert(cases==12 and checks==38,"native component cases incomplete")
end)
Splash.host=realHost
for _,it in owned do pcall(function() it:Destroy() end) end
camera.CameraType=startCamera.kind;camera.CFrame=startCamera.cf;camera.FieldOfView=startCamera.fov
settle()
if ok then print("[STARTUP_COMPONENT_DONE]",run,cases,checks) else warn("[STARTUP_COMPONENT_FAIL]",run,tostring(problem)) end
workspace:SetAttribute("StartupComponentFinished",true);workspace:SetAttribute("StartupComponentPassed",ok)
