-- Local diagnostic only; no online save backend. Never publish this place.
local Run=game:GetService("RunService")
local Text=require(game.ReplicatedStorage.Shared.UI.SaveText)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("SaveNoticeProbe")==true)
 local run=tostring(DateTime.now().UnixTimestampMillis);local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function settle() Run.Heartbeat:Wait();Run.Heartbeat:Wait();Run.Heartbeat:Wait() end
 local ok,err=pcall(function()
  task.wait(5);d.title.seen=true
  local ready=false;local deadline=os.clock()+30
  repeat if d.fresh("free",false,nil) then ready=true;break end;task.wait(.1) until os.clock()>deadline
  check(ready,"fresh life did not start");d.menu:hide();settle()
  d.saveState.fail("synthetic guarded native callback failure");settle()
  local h=d.hud;local label=h.saveNoticeLabel
  check(d.saveState.broken,"actual failure path ran")
  check(label.Visible and label.Text==Text.brokenLine(),"actual failure is readable in preserve play")
  check(label.TextFits,"failure text fits native desktop label")
  check(not h.toastLabel.Visible and not h.foodText.Visible and h.foodText.Text=="","routine HUD remains wordless")
  d.openMenu();settle();local left=h.saveNoticeLeft;task.wait(.3)
  check(not label.Visible and h.saveNoticeLeft==left,"menu pauses warning")
  check(string.find(d.menu.summary.Text,"Saving is off",1,true)~=nil,"menu retains persistent error explanation")
  d.menu:hide();settle();check(label.Visible and h.saveNoticeLeft<left,"closing menu resumes reading time")
  game:GetService("Players").LocalPlayer:SetAttribute("LargeText",true);settle()
  check(label.TextSize==24 and label.TextFits,"large warning fits native desktop label")
  for _,text in {Text.REST_REFUSED,Text.REST_PROTECTED,Text.TROUBLE,Text.OFF,Text.BACK} do
   h:saveNotice(text);settle()
   check(label.Visible and label.Text==text and label.TextFits,"native notice fits: "..text)
  end
  h:toast("routine gameplay text","danger");settle()
  check(label.Visible and label.Text==Text.BACK and not h.toastLabel.Visible,"gameplay toast does not overwrite operational notice")
  task.wait(12.2);check(not label.Visible and h.saveNoticeLeft==0,"notice expires back to quiet HUD")
 end)
 if ok then print("[SAVE_NOTICE_DONE]",run,checks) else warn("[SAVE_NOTICE_FAIL]",run,tostring(err)) end
 workspace:SetAttribute("SaveNoticeFinished",true);workspace:SetAttribute("SaveNoticePassed",ok)
end
