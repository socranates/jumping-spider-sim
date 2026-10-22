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
 print("[CHET_V50_VISUAL]",d.detail,"full_meal","jaw_distance",(d.meal.heldView.frame.Position-d.rig():mouthFrame().Position).Magnitude)
 task.wait(10)
 for _,device in {"keyboard","gamepad","touch"} do
  d.setDevice(device);task.wait(1)
  print("[CHET_V50_PROMPT]",d.detail,device,d.hud.promptHint.Text,d.hud.promptHint.Visible)
 end
 d.setDevice("keyboard")
 while feed.held and f.nutrition>f.profile.body.nutrition*.5 do
  d.input:simulate("Feed",true);task.wait(.05);d.input:simulate("Feed",false);task.wait(.4)
 end
 assert(feed.held==f and d.meal.heldView.scale<1)
 print("[CHET_V50_VISUAL]",d.detail,"half_meal","scale",d.meal.heldView.scale,"nutrition",f.nutrition)
 task.wait(10)
 print("[CHET_V50_VISUAL]",d.detail,"husk_soon")
 task.wait(3)
 local untilMeal=os.clock()+12
 while feed.held and os.clock()<untilMeal do
  d.input:simulate("Feed",true);task.wait(.05);d.input:simulate("Feed",false);task.wait(.2)
 end
 assert(f.state=="CONSUMED" and d.meal.husk~=nil,"native husk")
 local children=d.meal.husk:GetChildren()
 for _,p in children do assert(not p.CanCollide and not p.CanQuery and not p.CastShadow) end
 print("[CHET_V50_VISUAL]",d.detail,"husk",#children,"sound_loaded",d.soundscape.bite.IsLoaded)
 task.wait(4)
 assert(d.meal.husk==nil,"native husk cleanup")
 d.life.clock.hour=19;d.place(Vector3.new(-5,.31,-9));task.wait(.5)
 print("[CHET_V50_VISUAL]",d.detail,"dusk",d.hud.promptHint.Text,d.hud.promptHint.Visible)
 task.wait(6)
 d.place(Vector3.new(-25.5,.31,6));task.wait(.6)
 print("[CHET_V50_VISUAL]",d.detail,"rest",d.hud.promptHint.Text,d.hud.promptHint.Visible)
 d.input:simulate("Feed",true);task.wait(.05);d.input:simulate("Feed",false);task.wait(.3)
 assert(d.life.resting,"actual post-v48 rest binding")
 assert(not d.hud.promptHint.Visible,"rest clears dusk cue")
 print("[CHET_V50_VISUAL_END]",d.detail,"meal, prompts, sound load, dusk, rest")
end
