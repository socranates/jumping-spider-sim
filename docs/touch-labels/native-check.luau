--!strict
-- Local Studio client command-bar fixture. Never part of the game model.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
local player=assert(game:GetService("Players").LocalPlayer)
local pg=player:WaitForChild("PlayerGui")
local actual=pg:WaitForChild("SpiderTouch")
local Layout=require(game.ReplicatedStorage.Shared.UI.HudLayout)
local Text=game:GetService("TextService")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local previous=pg:FindFirstChild("TouchFontCheck")
-- Only this fixture's disposable GUI is replaced on a bounded-log retry.
if previous then previous:Destroy()end
local gui=Instance.new("ScreenGui");gui.Name="TouchFontCheck";gui.IgnoreGuiInset=true;gui.DisplayOrder=10000;gui.Parent=pg
local paper=Instance.new("Frame");paper.Size=UDim2.fromOffset(670,250);paper.Position=UDim2.fromOffset(20,4);paper.BackgroundColor3=Color3.fromRGB(25,29,27);paper.Parent=gui
local function caption(value:string,x:number,y:number,w:number)
 local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=value;l.Font=Enum.Font.GothamMedium;l.TextSize=16;l.TextColor3=Color3.new(1,1,1);l.Size=UDim2.fromOffset(w,30);l.Position=UDim2.fromOffset(x,y);l.Parent=paper
end
caption("Local font comparison: original / candidate",10,5,640)
caption("Same text, button sizes and action bindings",10,32,640)
local tag=tostring(DateTime.now().UnixTimestampMillis)
print("[TOUCH_FONT_BEGIN]",tag,"bounded_rows_not_one_truncated_message")
local pending:any={};local live:any={}
for _,spec in Layout.TOUCH_BUTTONS do
 local button=actual:FindFirstChild(spec.action) :: TextButton
 assert(button and button:IsA("TextButton") and button.Font==Enum.Font.GothamMedium,spec.action.." runtime font")
 table.insert(live,{action=spec.action,font=tostring(button.Font),text=button.Text,size=button.TextSize})
 local labels={spec.label}
 if spec.action=="Cancel"then table.insert(labels,"Let go\n(hold)")end
 if spec.action=="Lock"then table.insert(labels,"Unlock")end
 if spec.action=="Choose"then table.insert(labels,"Back")end
 if spec.action=="Eye"then table.insert(labels,"View")end
 for _,size in {{1280,720},{568,320}}do
  local layout=Layout.layoutButton(spec,size[1],size[2])
  for _,label in labels do
   for _,legacy in {true,false}do
    local b=button:Clone();b.Active=false;b.Selectable=false;b.Visible=true
    b.Font=if legacy then Enum.Font.Legacy else button.Font
    b.Text=label;b.TextSize=layout.textSize or 18;b.Size=UDim2.fromOffset(layout.size,layout.size)
    b.Position=UDim2.fromOffset(10,300);b.Parent=paper
    local show=label==spec.label and size[2]==720 and (spec.action=="Creep"or spec.action=="Cancel"or spec.action=="Recenter")
    if show then
     local col=if spec.action=="Creep"then 0 elseif spec.action=="Cancel"then 1 else 2
     b.Position=UDim2.fromOffset(30+col*215+(if legacy then 0 else 90),100)
    end
    table.insert(pending,{button=b,show=show,action=spec.action,label=label,short=size[2]<450,legacy=legacy})
   end
  end
 end
end
task.spawn(function()
 -- Allow native text layout/font resolution to run before sampling TextBounds.
 for _=1,10 do Run.RenderStepped:Wait()end
 local rows:any={};local problems=0;local reproduced=0
 for _,item in pending do
  local b:TextButton=item.button
  -- Measure the same glyphs at unrestricted width; this preserves deliberate
  -- newlines and each arrow's font fallback instead of assuming Ag's height.
  local natural=Text:GetTextSize(b.Text,b.TextSize,b.Font,Vector2.new(10000,10000))
  local noExtraRows=b.TextBounds.Y<=natural.Y+1
  local okay=b.TextFits and noExtraRows
  if not item.legacy and not okay then problems+=1 end
  if item.legacy and not okay then reproduced+=1 end
  table.insert(rows,{action=item.action,text=item.label,short=item.short,legacy=item.legacy,
   font=tostring(b.Font),text_size=b.TextSize,width=b.AbsoluteSize.X,height=b.AbsoluteSize.Y,
   text_width=b.TextBounds.X,text_height=b.TextBounds.Y,
   unwrapped_width=natural.X,unwrapped_height=natural.Y,
   text_fits=b.TextFits,no_extra_rows=noExtraRows,okay=okay})
  if not item.show then b:Destroy()end
 end
 caption("Original font at left; candidate font at right in each pair",10,170,640)
 caption("Candidate failures: "..problems.." | Original wrap/fit failures: "..reproduced,10,205,640)
 -- Studio's on-disk CreatorOutput messages truncate near 1KB. Keep each native
 -- record bounded so the original log can prove every row, not just a tally.
 for i,row in rows do print("[TOUCH_FONT_ROW]",tag,i,Http:JSONEncode(row))end
 for i,row in live do print("[TOUCH_FONT_LIVE]",tag,i,Http:JSONEncode(row))end
 print("[TOUCH_FONT_END]",tag,Http:JSONEncode({rows=#rows,live=#live,problems=problems,reproduced=reproduced,fixture_only=true}))
 assert(problems==0,"candidate labels wrap inside words or clip")
end)
