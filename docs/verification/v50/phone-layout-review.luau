-- Temporary native visual fixture, not a player-hunt claim. Never publish.
return function(d)
 local RS=game:GetService("RunService")
 local player=game:GetService("Players").LocalPlayer
 local until_=os.clock()+30
 while not d.session.started and os.clock()<until_ do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
 if d.title:holding() then d.title:stop() end
 assert(d.fresh("free",false));assert(d.needs.gentle)
 d.cam.mouse=false
 game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.Default
 game:GetService("UserInputService").MouseIconEnabled=true
 d.place(Vector3.new(-5,.31,-9));task.wait(2)
 d.cam.yaw+=math.rad(110)
 local f=nil
 for _,candidate in d.prey.flies do if candidate.nutrition>0 then f=candidate;break end end
 assert(f,"living prey for capture fixture")
 f.state="CAPTURED";f.captureSerial+=1;f.captureKey=f.id..":"..f.captureSerial;f.velocity=Vector3.zero
 local feed=d.prey.feeding
 feed:capture(f)
 local untilGrip=os.clock()+12
 while feed.struggling and os.clock()<untilGrip do
  d.input:simulate("Feed",true);task.wait(.05);d.input:simulate("Feed",false);task.wait(.15)
 end
 assert(feed.held==f and not feed.struggling,"fixture grip")
 d.setDevice("touch");task.wait(1);print("[CHET_V50_PHONE_LAYOUT]",workspace.CurrentCamera.ViewportSize,"touch_enabled",game:GetService("UserInputService").TouchEnabled,"prompt",d.hud.promptHint.Text,"at",d.hud.promptHint.AbsolutePosition,"size",d.hud.promptHint.AbsoluteSize);task.wait(60);end