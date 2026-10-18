local Book=require("../src/Shared/Learning/FieldNotebook")
local Watch=require("../src/Shared/Learning/NotebookWatch")
local Pages=require("../src/Shared/Data/NotebookPages")
local Panel=require("../src/Client/NotebookPanel")
local refs=require("./notebook_reference")
local passed,failed=0,0
local function check(v,msg) if v then passed+=1 else failed+=1;print("FAIL NOTEBOOK "..msg) end end
local b=Book.new();local emitted={}
b.pageOpened:connect(function(id) table.insert(emitted,id) end)
for i,row in refs do
 local a=row.action
 if a.kind=="notice" then b:notice(a.value) elseif a.kind=="jump" then b:noticeJump(a.value) else b:addEyeTime(a.value) end
 check(table.concat(b.opened,",")==table.concat(row.opened,","),"Godot discovered order "..i)
 check(math.abs(b.eyeSeconds-row.eye_seconds)<1e-8,"Godot eye time "..i)
end
check(table.concat(emitted,",")==table.concat(b.opened,","),"each discovery announced once")
local seen={}
for _,page in Pages do
 check(not seen[page.id],"unique "..page.id);seen[page.id]=true
 check(#page.text<=520 and #page.text>20,"short fact "..page.id)
 check(#page.sources>0,"sourced "..page.id)
 for _,source in page.sources do check(#source>20 and string.find(source,"(",1,true),"citation "..page.id) end
end
local fresh=Book.new();check(fresh:page("mud_dauber")==nil,"no unrevealed wasp spoiler")
fresh:load({opened={"dragline","missing","dragline","eight_eyes"},eye_seconds="bad"})
check(table.concat(fresh.opened,",")=="dragline,eight_eyes" and fresh.eyeSeconds==0,"load drops unknown/duplicate IDs")
fresh:load({opened={},eye_seconds=0/0});check(fresh.eyeSeconds==0,"NaN rejected")
fresh:addEyeTime(math.huge);check(fresh.eyeSeconds==0,"infinite timer rejected")
fresh:notice("dance");local record=fresh:toRecord();record.opened[1]="wrong"
check(fresh:isOpen("peacock_dance"),"record doesn't alias discoveries")
for _,rate in {30,60,144} do
 local book=Book.new();local w=Watch.new(book)
 local prey={captures=0,feeding={taken=0}};local needs={energy=.55,gentle=false}
 w:rebase(prey,needs)
 for _=1,rate*21 do w:tick(1/rate,prey,needs,true,false) end
 check(book:isOpen("moving_retinas") and not book:isOpen("green_uv"),"scaled eye time "..rate)
 prey.captures=1;prey.feeding.taken=.01;needs.energy=.9
 w:tick(1/rate,prey,needs,true,true)
 check(book:isOpen("venom") and book:isOpen("drinking") and book:isOpen("full_abdomen") and book:isOpen("motion_first"),"read-only event observations")
 w:life("rest_started",0);w:life("woke",0);w:life("moult_ready",0);w:life("moulted",3)
 check(book:isOpen("retreat") and book:isOpen("home_before_dark") and book:isOpen("new_skin") and book:isOpen("grown_up"),"life events")
 w:wasp({kind="visit_started"});w:wasp({kind="left",escaped=false})
 check(book:isOpen("mud_dauber") and not book:isOpen("getting_away"),"escape requires actual noticed visit")
 w:wasp({kind="left",escaped=true});w:wasp({kind="caught"})
 check(book:isOpen("getting_away") and book:isOpen("what_the_wasp_does"),"wasp evidence")
 local before=table.concat(book.opened,",")
 prey.captures=50;prey.feeding.taken=50;needs.energy=.1;w:rebase(prey,needs);w:tick(1/rate,prey,needs,false,false)
 check(table.concat(book.opened,",")==before,"restore rebase doesn't invent observations or erase notes")
 needs.gentle=true;needs.energy=0;w:tick(1/rate,prey,needs,false,false)
 check(not book:isOpen("going_without_food"),"gentle mode doesn't claim starvation")
end
local gui=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local closed=0;local book=Book.new();book:notice("start");book:notice("jump")
local panel=Panel.new(gui,book,function() closed+=1 end)
panel:show(true,"gamepad","playstation")
check(panel.shown=="dragline" and panel.fact.TextSize==32,"opens newest with large text")
check(string.find(panel.hint.Text,"Circle",1,true)~=nil,"PlayStation prompts")
panel:turn(-1);check(panel.shown=="bold_jumper","previous discovered page")
panel:turn(-1);check(panel.shown=="dragline","wrap only discovered pages")
panel.body.AbsoluteCanvasSize=Vector2.new(300,1400);panel.body.AbsoluteWindowSize=Vector2.new(300,140)
panel:fitReading();check(not panel.art.Visible,"short reading area prioritizes text")
panel.body.AbsoluteWindowSize=Vector2.new(300,220);panel:fitReading();check(panel.art.Visible,"tall reading area restores sketch")
panel.body.AbsoluteWindowSize=Vector2.new(300,140)
local gs=game:GetService("GuiService")
check(gs.SelectedObject==nil and not panel.buttons[1].Selectable,"reader owns directional input instead of native button selection")
local action=ClientStubs.actions.WindowsillNotebook
action("WindowsillNotebook",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.DPadDown,Position=Vector3.zero})
check(panel.body.CanvasPosition.Y==120,"D-pad scroll action")
action("WindowsillNotebook",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.ButtonL1,Position=Vector3.zero})
check(panel.shown=="bold_jumper" and panel.body.CanvasPosition.Y==0,"shoulder changes page and resets scroll")
action("WindowsillNotebook",Enum.UserInputState.Change,{KeyCode=Enum.KeyCode.Thumbstick2,Position=Vector3.new(0,-1,0)})
panel:update(.1);check(panel.body.CanvasPosition.Y==48,"right stick scroll action")
gs.MenuIsOpen=true;action("WindowsillNotebook",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.ButtonB,Position=Vector3.zero})
check(panel:isShowing() and panel.scrollAxis==0,"Roblox menu owns input while open")
gs.MenuIsOpen=false
panel:scroll(9999);check(panel.body.CanvasPosition.Y==1260,"scroll clamps to readable end")
panel:close();check(not panel:isShowing() and closed==1 and ClientStubs.actions.WindowsillNotebook==nil,"close clears input owner")
print("NOTEBOOK passed="..passed.." failed="..failed)
assert(failed==0)
