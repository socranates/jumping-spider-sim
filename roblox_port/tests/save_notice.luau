-- Save failures survive preserve projection; routine game prose stays suppressed.
-- Scripted remotes below are not a real online DataStore/rejoin test.
local Hud=require("../src/Client/SpiderHud")
local Text=require("../src/Shared/UI/SaveText")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL SAVE_NOTICE "..why) end end
-- The plain CLI has no Roblox warn; count this expected diagnostic explicitly.
local oldWarn=warn;local warnings=0
getfenv().warn=function(...) warnings+=1 end
for _,pair in {{nil,nil},{"saving",nil},{"saved",nil}} do
 check(Text.notice(nil,nil,pair[1],pair[2])=="","ordinary startup/save status stays quiet")
end
for _,reason in {"write_failed","rest_refused","rest_protected"} do
 check(Text.notice("saved",nil,"saving",reason)==Text.menuLine("saving",reason),"failure explains actual scope: "..reason)
 check(Text.notice(nil,nil,"saving",reason)~="","initial failure is not lost: "..reason)
 check(Text.notice("saving",reason,"saving",reason)=="","retry does not refresh notice: "..reason)
 check(Text.notice("saving",reason,"saving",nil)=="","pending retry does not promise recovery: "..reason)
 check(Text.notice("saving",reason,"saved",nil)==Text.BACK,"acknowledged recovery: "..reason)
end
for _,reason in {"offline","no_api","load_failed","other_session","corrupt","newer"} do
 check(Text.notice("saved",nil,"session",reason)==Text.menuLine("session",reason),"session refusal reason: "..reason)
 check(Text.notice("session",reason,"session",reason)=="","unchanged refusal stays quiet: "..reason)
end
local hud=Hud.new(Instance.new("Folder"))
local view={minimal=true,food=.6,dot=true,device="keyboard",status={},caption={text="tutorial",alpha=1}}
check(not hud.saveNoticeLabel.Visible and hud.saveNoticeLeft==0,"no default warning")
hud:saveNotice(Text.REST_REFUSED);hud:toast("a routine message","danger")
hud:update(view,1/60)
check(hud.saveNoticeLabel.Visible and hud.saveNoticeLabel.Text==Text.REST_REFUSED,"failure survives minimal projection and gameplay toast")
check(not hud.toastLabel.Visible and not hud.caption.Visible and hud.foodText.Text=="","routine words remain suppressed")
local remaining=hud.saveNoticeLeft
view.saveNoticePaused=true;hud:update(view,60)
check(not hud.saveNoticeLabel.Visible and hud.saveNoticeLeft==remaining,"modal screen pauses reading time")
view.saveNoticePaused=false;view.largeText=true;hud:update(view,1/60)
check(hud.saveNoticeLabel.Visible and hud.saveNoticeLabel.TextSize==24,"warning returns with large text")
hud:saveNotice("");check(hud.saveNoticeLeft<remaining,"empty transition does not refresh timer")
hud:update(view,13);check(not hud.saveNoticeLabel.Visible and hud.saveNoticeLeft==0,"warning expires to quiet screen")
hud:saveNotice(Text.BACK);hud:update(view,1/60)
check(hud.saveNoticeLabel.Visible and hud.saveNoticeLabel.Text==Text.BACK,"recovery replaces failure")

local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Scenery=require("../src/Shared/Habitat/Scenery")
local Rules=require("../src/Shared/Data/SaveRules")
local Progress=require("../src/Shared/Persistence/SaveProgress")
workspace:ClearAllChildren();workspace:SetAttribute("World","preserve");workspace:SetAttribute("SelfTest",false);workspace:SetAttribute("SaveWait",true)
Map.use("preserve")
local decor,replaced=Scenery.decor(nil,"preserve");decor.Parent=workspace
local hidden={};for id in replaced do hidden[id]=true end
Build.world(workspace,Map.SEED,hidden)
local handlers={}
local function deliver(message) for _,fn in handlers do fn(message) end end
local folder=Instance.new("Folder");folder.Name=Rules.REMOTES_NAME
local server=Instance.new("Folder");server.Name="ToServer"
rawset(server,"FireServer",function(_self,msg)
 if msg.kind=="begin_life" then deliver({kind="life",mode=msg.mode,serial=msg.serial,token="save-notice-fixture"}) end
end);server.Parent=folder
local client=Instance.new("Folder");client.Name="ToClient"
rawset(client,"OnClientEvent",{Connect=function(_self,fn) table.insert(handlers,fn) end});client.Parent=folder
folder.Parent=game:GetService("ReplicatedStorage")
assert(pcall(function() require("../src/Client/SpiderClient.client") end),"client did not load")
local d=assert(ClientStubs.driver);local frame=assert(ClientStubs.renderSteps.SpiderSim)
local function frames(n) for _=1,n do frame(1/60) end end
-- A server cannot answer hello before the client has connected its transport.
-- Loading navigation now precedes that frame work; await the real connection.
for _=1,5000 do frames(1);if #handlers>0 then break end end
assert(#handlers==1,"save transport never connected")
deliver({kind="loaded",v=1,status="saved",progress=Progress.default(),rests={}});frames(3)
d.title.seen=true
local ready=false;for _=1,5000 do if d.fresh("free",false,nil) then ready=true;break end;frames(1) end
assert(ready,"fresh life did not start")
d.menu:hide();frames(2)
for _,reason in {"write_failed","rest_refused","rest_protected"} do
 deliver({kind="status",status="saving",reason=reason});frames(2)
 check(d.hud.saveNoticeLabel.Text==Text.menuLine("saving",reason),"real transport reaches save notice: "..reason)
 check(d.hud.saveNoticeLabel.Visible,"real failure is visible during active play: "..reason)
 local left=d.hud.saveNoticeLeft;frames(2)
 check(d.hud.saveNoticeLeft<=left,"real repeated status does not reset timer")
end
deliver({kind="status",status="saved"});frames(2)
check(d.hud.saveNoticeLabel.Text==Text.BACK,"real acknowledged recovery reaches HUD")
d.openMenu();frames(2);local left=d.hud.saveNoticeLeft;frames(2)
check(not d.hud.saveNoticeLabel.Visible and d.hud.saveNoticeLeft==left,"real menu pauses notice while showing persistent save status")
d.menu:hide();frames(2)
check(d.hud.saveNoticeLabel.Visible,"real menu close resumes notice")
d.saveState.fail("synthetic callback failure");frames(2)
check(d.saveState.broken and d.hud.saveNoticeLabel.Text==Text.brokenLine(),"callback failure has truthful independent notice")
check(warnings==1,"callback failure warns exactly once")
check(not d.hud.foodText.Visible and d.hud.foodText.Text=="","save failure does not label food meter")
getfenv().warn=oldWarn
print(`SAVE_NOTICE passed={passed} failed={failed}`)
if failed>0 then error("save notice regression failed") end
