-- Diagnostic only, injected as SilkPlayback in a local place. Never publish.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Player=game:GetService("Players").LocalPlayer
local function waitFor(fn,seconds)
 local stop=os.clock()+seconds
 repeat Run.Heartbeat:Wait();if fn() then return true end until os.clock()>stop
 return false
end
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("CaptionProbe")==true)
 local run=tostring(DateTime.now().UnixTimestampMillis)
 local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function stage(name)
  local c=d.hud.caption
  print("[CAPTION_NATIVE_STAGE]",run,name,Http:JSONEncode({visible=c.Visible,text=c.Text,text_size=c.TextSize,
   bounds={c.TextBounds.X,c.TextBounds.Y},size={c.AbsoluteSize.X,c.AbsoluteSize.Y},fits=c.TextFits,
   food_words=d.hud.foodText.Text,food_label_visible=d.hud.foodText.Visible,setting=d.setting("Captions")}))
  WS:SetAttribute("CaptionStage",name)
  -- A short screenshot opportunity; these are UI checks, not performance samples.
  task.wait(5)
 end
 local function hum()
  d.wasp:clearVisit();WS:SetAttribute("WaspForce","floor_middle")
  check(waitFor(function() return d.wasp:isVisiting() end,5),"no audible wasp fixture")
  task.wait(.3)
 end
 local ok,err=pcall(function()
  task.wait(5);d.title.seen=true
  check(waitFor(function() return d.fresh("free",false,nil) end,30),"fresh life not ready")
  Player:SetAttribute("Captions",nil)
  d.place(Vector3.new(2,.31,6));d.life.clock.day=3;d.life.clock.hour=12;d.prey.feeding.mealsFinished=1
  hum()
  check(d.setting("Captions")=="off" and not d.hud.caption.Visible,"default is not wordless")
  check(d.hud.food.Visible and not d.hud.foodText.Visible and d.hud.foodText.Text=="","food reserve was labeled")
  stage("default_off")
  d.settingsPanel:open("game","keyboard",1)
  local row=nil;for _,w in d.settingsPanel.widgets do if w.kind=="setting" and w.id=="Captions" then row=w end end
  check(row~=nil and row.value.Text=="Off","menu default differs")
  -- Use the actual row button, not a direct settings attribute, to enable captions.
  d.settingsPanel.nav:selectId("Captions");d.settingsPanel:_activate()
  d.settingsPanel:close();hum()
  check(d.setting("Captions")=="normal" and d.hud.caption.Visible,"normal caption missing")
  check(d.hud.caption.TextSize==15 and d.hud.caption.TextFits,"normal caption does not fit")
  check(string.find(d.hud.caption.Text,"[a deep, heavy hum outside, ",1,true)~=nil,"wrong caption producer")
  stage("normal")
  d.settingsPanel.io.set("Captions","large");hum()
  check(d.hud.caption.Visible and d.hud.caption.TextSize==23 and d.hud.caption.TextFits,"large caption missing/clipped")
  stage("large")
  d.settingsPanel.io.set("Captions","off");task.wait(.2)
  check(not d.hud.caption.Visible,"off did not hide active caption")
  stage("off")
  d.settingsPanel.io.set("Captions","normal");hum()
  for _,device in {"keyboard","gamepad","touch"} do
   d.setDevice(device);task.wait(.1)
   check(d.hud.caption.Visible,"lost caption on "..device)
  end
  d.settingsPanel.io.reset();task.wait(.2)
  check(d.setting("Captions")=="off" and not d.hud.caption.Visible,"reset restored legacy default")
  check(d.hud.food.Visible and not d.hud.foodText.Visible and d.hud.foodText.Text=="","reset labeled food")
  stage("reset_off")
 end)
 if ok then print("[CAPTION_NATIVE_DONE]",run,checks) else warn("[CAPTION_NATIVE_FAIL]",run,tostring(err)) end
 WS:SetAttribute("CaptionProbeFinished",true);WS:SetAttribute("CaptionProbePassed",ok)
end
