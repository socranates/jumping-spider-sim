-- Local Studio diagnostic only. Persistence is disabled; never publish.
-- Stall surface work without replacing the production clock or timeout constant.
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Preparation=require(Shared.World.NavigationPreparation)
local Splash=require(game:GetService("ReplicatedFirst").SplashScreen)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("StartupNavigationCase")=="timeout")
 local player=game:GetService("Players").LocalPlayer
 local nav=assert(d.navigation)
 local run=tostring(DateTime.now().UnixTimestampMillis)
 local started=os.clock();local frames,checks,maxGap=0,0,0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function waitUntil(fn,seconds)
  local deadline=os.clock()+seconds;local previous=os.clock()
  repeat
   if fn() then return true end
   Run.RenderStepped:Wait();frames+=1
   local now=os.clock();maxGap=math.max(maxGap,now-previous);previous=now
  until os.clock()>deadline
  return fn()
 end
 local ok,problem=pcall(function()
  print("[NAVIGATION_TIMEOUT_BEGIN]",run)
  check(nav.status=="pending" and Preparation.TIMEOUT_SECONDS==40,"cold owner or production timeout changed")
  local hour,energy,pos=d.life.clock.hour,d.needs.energy,d.motor.pos
  check(not d.fresh("main",false,nil),"early Begin must be refused")
  -- Leave routes pending. Air still builds normally, using the real owner.
  nav.config.advance=function() return true end
  check(waitUntil(function()
   if nav.status=="pending" then
    assert(d.life.clock.hour==hour and d.needs.energy==energy and d.motor.pos==pos,"pending timeout advanced simulation")
    assert(player:GetAttribute("TitleReady")~=true,"pending timeout exposed the title")
   end
   return nav.status=="failed"
  end,50),"actual elapsed-time timeout did not fire")
  local elapsed=nav.now()-nav.started
  check(string.find(tostring(nav.problem),"navigation preparation timed out",1,true)~=nil,"wrong failure reason")
  check(elapsed>=Preparation.TIMEOUT_SECONDS,"timeout fired before its real clock deadline")
  check(player:GetAttribute("WorldStartupFailed")==true and player:GetAttribute("TitleReady")~=true,"timeout did not gate readiness")
  check(d.life.clock.hour==hour and d.needs.energy==energy and d.motor.pos==pos,"timeout advanced gameplay")
  local screen=nil
  check(waitUntil(function()
   local gui=player:FindFirstChild("PlayerGui");screen=gui and gui:FindFirstChild(Splash.GUI_NAME)
   return screen~=nil and screen:FindFirstChild("Subtitle")~=nil and screen.Subtitle.Text==Splash.FAILURE_TEXT
  end,10),"actual splash recovery text missing")
  check(screen.Subtitle.TextTransparency==0 and screen.Subtitle.TextFits,"timeout recovery text not visible/fitting")
  local slices=nav.slices;Run.RenderStepped:Wait();Run.RenderStepped:Wait()
  check(nav.status=="failed" and nav.slices==slices and d.life.clock.hour==hour and d.motor.pos==pos,"timeout resumed work")
  assert(checks==10)
  local view=workspace.CurrentCamera.ViewportSize
  print("[NAVIGATION_TIMEOUT_DONE]",run,checks,frames,string.format("%.6f",elapsed),string.format("%.6f",os.clock()-started),string.format("%.6f",maxGap),nav.slices,view.X,view.Y)
 end)
 if not ok then warn("[NAVIGATION_TIMEOUT_FAIL]",run,tostring(problem)) end
 workspace:SetAttribute("StartupNavigationProbeDone",true)
 workspace:SetAttribute("StartupNavigationProbePassed",ok)
end
