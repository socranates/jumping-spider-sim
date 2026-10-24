-- Regression for the native 378px-content / 330px-window clipping case.
-- The shim does not lay out text: engine-measured sizes and resize signals are
-- inputs here. The companion native check verifies actual rendered bounds.
local CaughtPanel=require("../src/Client/CaughtPanel")
local passed=0
local function check(ok:boolean,message:string) assert(ok,message);passed+=1 end
local p=CaughtPanel.new(Instance.new("Folder"),function()end,"OverflowTest")
p:setLook("title")
p:showChoices("The Windowsill","subtitle","save status",{
 {id="New",text="Begin a new life"},{id="Free",text="Free play"},
 {id="Settings",text="Settings"},{id="Notebook",text="Notebook"}},true)
local function content(height:number)
 p.list.AbsoluteContentSize=Vector2.new(535,height)
 p.list:GetPropertyChangedSignal("AbsoluteContentSize"):Fire()
end
local function viewport(height:number)
 p.box.AbsoluteWindowSize=Vector2.new(550,height)
 p.box:GetPropertyChangedSignal("AbsoluteWindowSize"):Fire()
end
content(378);viewport(330)
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Top,"native overflow still starts above the scroll origin")
check(p.box.CanvasPosition.Y==0,"opening must retain the first row, not scroll past it")
viewport(600)
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Center,"a fitting title lost its centered presentation")
content(720)
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Top,"large text or another save choice must remain reachable")
content(300)
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Center,"shrinking content did not recover centering")
viewport(0)
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Top,"unknown initial viewport must not offset content negatively")
viewport(300)
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Center,"an exact fit needs no scrolling")
p:setLook("card")
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Top,"life/end cards must keep their established top alignment")
viewport(900);content(100)
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Top,"a later resize must not center an ordinary life card")
p:setLook("title")
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Center,"switching to title must use the current metrics")
p:hide();content(1000);p:showChoices("The Windowsill","subtitle","",{{id="New",text="Begin a new life"}},true)
check(p.list.VerticalAlignment==Enum.VerticalAlignment.Top,"reopening after text/layout changes lost the first row")
check(p.line.Text=="The Windowsill" and p.buttons[1].Text=="Begin a new life","content changed while fixing layout")
p:hide()
print("MENU_OVERFLOW passed="..passed.." failed=0")
