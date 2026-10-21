local Hud=require("../src/Client/SpiderHud")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL MINIMAL "..msg) end end
local gui=Instance.new("Folder")
local hud=Hud.new(gui)
local view={minimal=true,device="keyboard",food=.63,foodGentle=false,
 aiming=true,focus=true,eyeView=true,aimTitle="Reachable",aimHint="Jump",anchorText="Silk",status={"Hunting"},
 day="Day 2",dayLine="Juvenile",caption={text="Wasp",alpha=1},prompt={title="Rest",hint="E",cue="Sleep"},
 grip=.3,court=.4,helpVisible=true,helpText="Controls",notice="Ready to moult. Rest in the silk-lined crack."}
hud:toast("Found a fly");hud:setNote("New notebook page",8)
hud:update(view,1/60)
check(hud.food.Visible and hud.foodText.Text=="" and not hud.foodText.Visible,"visible reserve has no words")
check(hud.food.Size.X.Offset==120 and hud.track.Size.Y.Offset==4,"minimal reserve dimensions")
check(math.abs(hud.foodFill.Size.X.Scale-.63)<1e-8,"reserve represents food accurately")
for _,label in {hud.reticle,hud.aimTitle,hud.aimHint,hud.anchorLabel,hud.status,hud.notice,hud.day,hud.dayLine,
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
print(`MINIMAL passed={passed} failed={failed}`)
if failed>0 then error("minimal HUD checks failed") end
