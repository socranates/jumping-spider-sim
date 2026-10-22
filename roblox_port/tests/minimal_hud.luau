local Hud=require("../src/Client/SpiderHud")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL MINIMAL "..msg) end end
local gui=Instance.new("Folder")
local hud=Hud.new(gui)
local view={minimal=true,dot=true,device="keyboard",food=.63,foodGentle=false,
 aiming=true,focus=true,eyeView=true,aimTitle="Reachable",aimHint="Jump",anchorText="Silk",status={"Hunting"},
 day="Day 2",dayLine="Juvenile",caption={text="Wasp",alpha=1},prompt={title="Rest",hint="E",cue="Sleep"},
 grip=.3,court=.4,helpVisible=true,helpText="Controls",notice="Ready to moult. Rest in the silk-lined crack."}
hud:toast("Found a fly");hud:setNote("New notebook page",8)
hud:update(view,1/60)
check(hud.food.Visible and hud.foodText.Text=="" and not hud.foodText.Visible,"visible reserve has no words")
check(hud.food.Size.X.Offset==150 and hud.track.Size.Y.Offset==6,"minimal reserve dimensions")
check(math.abs(hud.foodFill.Size.X.Scale-.63)<1e-8,"reserve represents food accurately")
check(hud.reticle.Visible and hud.reticle.Size.X.Offset==2 and hud.reticle.Size.Y.Offset==2,"tiny manual aim dot available before any moult")
for _,tick in hud.ticks do check(not tick.Visible,"dot adds no focus ticks") end
for _,label in {hud.aimTitle,hud.aimHint,hud.anchorLabel,hud.status,hud.notice,hud.day,hud.dayLine,
 hud.caption,hud.promptTitle,hud.promptHint,hud.promptCue,hud.help,hud.toastLabel,hud.noteLabel,hud.grip,hud.court} do
 check(not label.Visible,"no gameplay overlay: "..label.Name)
end
for _,value in {1,.4,.05,0} do
 view.food=value;hud:update(view,20)
 check(hud.food.Visible and hud.foodFill.Size.X.Scale==value,"reserve stays available at every hunger level")
 check(hud.foodText.Text=="" and not hud.foodText.Visible,"hunger never adds a label")
end
for _,words in {"You can now run. Hold Shift while moving.","You can now lock on. Press R near visible prey, then move to circle it."} do
 view.notice="Moulted: now a juvenile.\n"..words;hud:update(view,1/60)
 check(hud.notice.Visible and hud.notice.Text==words,"earned ability is explained without other life text")
end
view.helpRequested=true;hud:update(view,1/60)
check(hud.help.Visible and hud.help.Text=="Controls","deliberately opened controls remain available")
view.helpRequested=false;view.notice=nil;hud:update(view,1/60)
check(not hud.help.Visible and not hud.notice.Visible,"closing reference returns to the reserve alone")
view.dot=false;hud:update(view,1/60)
check(not hud.reticle.Visible,"sleep, menus and death can suppress the dot")
-- Accessibility captions are explicit, not the eye-view tutorial or routine prose.
view.dot=true;view.caption={text="Eye-view tutorial",alpha=1};view.soundCaption={text="A hum ahead-left",alpha=.4};view.captionScale=1
hud:update(view,1/60)
check(hud.caption.Visible and hud.caption.Text=="A hum ahead-left" and hud.caption.TextSize==15,"minimal view keeps only the sound caption")
check(type(hud.caption.TextTransparency)=="number" and math.abs(hud.caption.TextTransparency-.6)<1e-8,"caption retains its fade")
view.captionScale=1.5;hud:update(view,1/60)
check(hud.caption.TextSize==23,"large accessibility caption retains its text scale")
view.soundCaption=nil;hud:update(view,1/60)
check(not hud.caption.Visible,"ending a sound hides the caption rather than exposing the tutorial")
local Model=require("../src/Shared/UI/SettingsModel")
check(Model.default("Captions","preserve")=="off" and Model.defaults("preserve").Captions=="off","preserve defaults and reset are wordless")
check(Model.default("Captions")=="normal" and Model.default("Captions","test_garden")=="normal","legacy caption default remains intact")
for _,choice in {"off","normal","large"} do
 check(Model.get(function() return choice end,"Captions","preserve")==choice,"saved explicit caption choice survives: "..choice)
end
for _,bad in {false,7,"tiny"} do check(Model.get(function() return bad end,"Captions","preserve")=="off","invalid choice falls back to preserve default") end
check(Model.get(function() return nil end,"Captions","preserve")=="off","unset preserve captions are off")
-- Run the real client in the preserve, not just the HUD projection.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Scenery=require("../src/Shared/Habitat/Scenery")
workspace:ClearAllChildren();workspace:SetAttribute("World","preserve");workspace:SetAttribute("SelfTest",false)
Map.use("preserve")
local decor,replaced=Scenery.decor(nil,"preserve");decor.Parent=workspace
local hidden={};for id in replaced do hidden[id]=true end
Build.world(workspace,Map.SEED,hidden)
local loaded,err=pcall(function() require("../src/Client/SpiderClient.client") end)
assert(loaded,tostring(err))
local driver=assert(ClientStubs.driver);local frame=assert(ClientStubs.renderSteps.SpiderSim)
local function frames(n) for _=1,n do frame(1/60) end end
local player=game:GetService("Players").LocalPlayer
local ready=false;for _=1,5000 do if driver.fresh("free",false,nil) then ready=true;break end;frames(1) end
check(ready,"real preserve client starts a fresh life")
check(player:GetAttribute("Captions")==nil and driver.setting("Captions")=="off","untouched real client uses preserve caption default")
driver.place(Vector3.new(2,.31,6));driver.life.clock.day=3;driver.life.clock.hour=12;driver.prey.feeding.mealsFinished=1
workspace:SetAttribute("WaspForce","floor_middle");frames(30)
check(driver.wasp:isVisiting() and not driver.hud.caption.Visible,"a real audible wasp does not add default HUD words")
local panel=driver.settingsPanel
panel:open("game","keyboard",1)
local captionRow=nil;for _,w in panel.widgets do if w.kind=="setting" and w.id=="Captions" then captionRow=w end end
check(captionRow~=nil and captionRow.value.Text=="Off","menu reports the actual preserve default")
panel:close()
panel.io.set("Captions","normal");frames(2)
local normalSize=driver.hud.caption.TextSize
check(driver.hud.caption.Visible and string.find(driver.hud.caption.Text,"[a deep, heavy hum outside, ",1,true)~=nil,"Normal shows the real wasp caption through the minimal client HUD")
for _,device in {"keyboard","gamepad","touch"} do driver.setDevice(device);frames(1);check(driver.hud.caption.Visible,"caption survives device "..device) end
panel.io.set("Captions","large");frames(2)
check(driver.hud.caption.Visible and driver.hud.caption.TextSize>normalSize,"Large changes the real caption size")
panel.io.set("Captions","off");frames(2)
check(not driver.hud.caption.Visible,"Off hides an active sound immediately")
panel.io.set("Captions","normal");frames(2)
check(driver.hud.caption.Visible,"Normal can reenable an ongoing sound")
panel.io.reset();frames(2)
check(driver.setting("Captions")=="off" and not driver.hud.caption.Visible,"Reset uses preserve Off rather than legacy Normal")
check(driver.hud.food.Visible and not driver.hud.foodText.Visible and driver.hud.foodText.Text=="","caption settings never label the hunger reserve")
print(`MINIMAL passed={passed} failed={failed}`)
if failed>0 then error("minimal HUD checks failed") end
