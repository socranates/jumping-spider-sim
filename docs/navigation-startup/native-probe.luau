-- Local Studio diagnostic only. Never publish; production persistence is disabled.
-- Uses the normal controller's Studio playback hook; not a physical-input test.
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Air=require(Shared.World.StationAir)
local Route=require(Shared.Predator.RivalRoute)
local Station=require(Shared.World.StationTerritory)
local Splash=require(game:GetService("ReplicatedFirst").SplashScreen)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("StartupNavigationProbe")==true)
 local mode=workspace:GetAttribute("StartupNavigationCase")
 assert(mode=="success" or mode=="failure")
 local player=game:GetService("Players").LocalPlayer
 local nav=assert(d.navigation)
 local run=tostring(DateTime.now().UnixTimestampMillis)
 local started=os.clock();local frames=0;local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function waitUntil(fn,seconds)
  local deadline=os.clock()+seconds
  repeat if fn() then return true end;Run.RenderStepped:Wait();frames+=1 until os.clock()>deadline
  return fn()
 end
 local ok,problem=pcall(function()
  print("[NAVIGATION_NATIVE_BEGIN]",run,mode)
  check(nav.status=="pending" and not Air.ready(),"cold navigation must not already be published")
  local hour,energy,pos=d.life.clock.hour,d.needs.energy,d.motor.pos
  check(not d.fresh("main",false,nil),"Begin before preparation must be refused")
  if mode=="failure" then
   nav.config.advance=function() return false,"synthetic native startup route failure" end
   check(waitUntil(function() return nav.status=="failed" end,10),"injected failure was not caught")
   check(player:GetAttribute("WorldStartupFailed")==true and player:GetAttribute("TitleReady")~=true,"failure cannot become ready")
   check(d.life.clock.hour==hour and d.needs.energy==energy and d.motor.pos==pos,"failure advanced simulation")
   local screen=nil
   check(waitUntil(function()
    local gui=player:FindFirstChild("PlayerGui");screen=gui and gui:FindFirstChild(Splash.GUI_NAME)
    return screen~=nil and screen:FindFirstChild("Subtitle")~=nil and screen.Subtitle.Text==Splash.FAILURE_TEXT
   end,10),"actual production splash did not keep recovery text")
   check(screen.Subtitle.TextTransparency==0 and screen.Subtitle.TextFits,"native recovery text not visible/fitting")
   Run.RenderStepped:Wait();Run.RenderStepped:Wait()
   check(nav.status=="failed" and d.life.clock.hour==hour and d.motor.pos==pos,"failed startup resumed work")
   assert(checks==8)
  else
   local held=0
   check(waitUntil(function()
    if nav.status=="failed" then error(nav.problem) end
    if nav.status=="pending" then
     held+=1
     assert(d.life.clock.hour==hour and d.needs.energy==energy and d.motor.pos==pos,"pending loading advanced simulation")
     assert(player:GetAttribute("TitleReady")~=true,"pending loading exposed the title")
    end
    return nav.status=="ready"
   end,45),"native warm-up did not finish")
   check(held>0 and Air.ready(),"both navigation systems must finish")
   local all=true;for id in Station.roam() do if not Route.prepared(id) then all=false end end
   check(all,"resident crossing destination still unprepared")
   check(waitUntil(function() return player:GetAttribute("TitleReady")==true end,10),"ready navigation never produced a playable capture")
   local slices=nav.slices
   d.title.seen=true
   for _,kind in {"main","free","easy"} do
    if kind=="easy" then d.session.finishedMain=true end -- diagnostic fixture unlock, no production rule change
    check(d.fresh(if kind=="easy" then "main" else kind,kind=="easy",nil),"fresh mode refused after readiness: "..kind)
    d.openMenu();Run.RenderStepped:Wait()
   end
   check(nav.status=="ready" and nav.slices==slices,"new lives restarted navigation")
   assert(checks==10)
  end
  local view=workspace.CurrentCamera.ViewportSize
  print("[NAVIGATION_NATIVE_DONE]",run,mode,checks,frames,string.format("%.6f",os.clock()-started),nav.slices,view.X,view.Y)
 end)
 if not ok then warn("[NAVIGATION_NATIVE_FAIL]",run,mode,tostring(problem)) end
 workspace:SetAttribute("StartupNavigationProbeDone",true)
 workspace:SetAttribute("StartupNavigationProbePassed",ok)
end
