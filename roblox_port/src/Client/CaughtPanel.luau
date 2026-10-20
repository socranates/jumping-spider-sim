--!strict
-- Plain end/start screens. Scroll within the safe area; the selected button owns accept,
-- and modal input never leaks into a jump or a held walking key.
-- ROBLOX-109: two looks in one typeface (UI/TitleText: Merriweather, the title Light, the subtitle Italic, the rest Regular, in warm paper white).
-- "card" (the default) is the death and ending cards and the life menu, as they were but for the type: the dim comes up, the line, then the choices.
-- "title" is the start menu as a title card over the drifting camera: a light veil darker toward the foot, the title large (sized to the screen's
-- width, one line at a phone's), its one line in italic, the choices on a dark ground, then the saving note and a controller's line in small type
-- under them. A controller moves with the D-pad or the left stick and chooses with A / Cross; B / Circle chooses the screen's `back` choice when it has one.
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaspText = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("WaspText"))
local TitleText = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("TitleText"))
local CaughtPanel = {}
CaughtPanel.__index = CaughtPanel
export type Choice = { id: string, text: string }
-- The sizes (pixels at normal text) of each look: the line (or the title's size when 0: TitleText.titleSize of the screen's width), the line under it,
-- the summary, the buttons' text and height, the column's widest.
local LOOKS = {
	card = { line = 28, sub = 18, summary = 18, button = 20, height = 52, width = 880, dim = nil :: number? },
	title = { line = 0, sub = 20, summary = 14, button = 21, height = 50, width = 560, dim = 1 :: number? },
}
CaughtPanel.LOOKS = LOOKS
local function face(weight: Enum.FontWeight, italic: boolean): Font
	return Font.new(TitleText.FAMILY, weight, if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
end
local function label(parent: Instance, name: string, size: number, order: number): TextLabel
 local l=Instance.new("TextLabel")
 l.Name=name; l.BackgroundTransparency=1; l.TextColor3=TitleText.INK
 l.Font=Enum.Font.GothamMedium; l.TextSize=size; l.TextWrapped=true
 pcall(function() l.FontFace=face(Enum.FontWeight.Regular,false) end)
 l.Size=UDim2.new(1,-24,0,0); l.AutomaticSize=Enum.AutomaticSize.Y; l.LayoutOrder=order; l.Parent=parent
 return l
end
function CaughtPanel.new(playerGui: Instance, onChoose: (string) -> (), name: string?): any
 local gui=Instance.new("ScreenGui")
 gui.Name=name or "SpiderCaught"; gui.ResetOnSpawn=false; gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
 gui.DisplayOrder=50; gui.Enabled=false; gui.Parent=playerGui
 local dim=Instance.new("Frame")
 dim.Name="Dim";dim.Size=UDim2.fromScale(1,1);dim.BackgroundColor3=TitleText.GROUND;dim.BackgroundTransparency=1
 dim.Active=true;dim.Parent=gui
 -- (the title look's veil: light at the top, where the world is seen, darker at the foot under the choices)
 local shade=Instance.new("UIGradient")
 shade.Name="Shade";shade.Rotation=90;shade.Enabled=false
 shade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.85),NumberSequenceKeypoint.new(.45,.7),NumberSequenceKeypoint.new(1,.2)})
 shade.Parent=dim
 local box=Instance.new("ScrollingFrame")
 box.Name="Box";box.BackgroundTransparency=1;box.BorderSizePixel=0;box.AnchorPoint=Vector2.new(.5,.5)
 box.Position=UDim2.fromScale(.5,.5);box.Size=UDim2.fromScale(.92,.88)
 box.CanvasSize=UDim2.new();box.AutomaticCanvasSize=Enum.AutomaticSize.Y;box.ScrollBarThickness=6;box.Parent=dim
 local constraint=Instance.new("UISizeConstraint");constraint.MaxSize=Vector2.new(880,10000);constraint.Parent=box
 local list=Instance.new("UIListLayout");list.HorizontalAlignment=Enum.HorizontalAlignment.Center
 list.SortOrder=Enum.SortOrder.LayoutOrder;list.Padding=UDim.new(0,12);list.Parent=box
 local self=setmetatable({gui=gui,dim=dim,shade=shade,box=box,list=list,constraint=constraint,line=label(box,"Line",28,1),sub=label(box,"Sub",18,2),
 summary=label(box,"Summary",18,3),hint=label(box,"Hint",14,1001),buttons={},choices={},button=nil,onChoose=onChoose,showing=false,
 seconds=0,bound=false,chosen=false,selected=1,stickDown=false,action="WindowsillChoice"..gui.Name,look="card",scale=1,back=nil},CaughtPanel)
 self.hint.Visible=false
 self:setLook("card")
 return self
end
function CaughtPanel.isShowing(self:any):boolean return self.showing end
function CaughtPanel.select(self:any, delta:number)
 if #self.buttons==0 then return end
 self.selected=(self.selected-1+delta)%#self.buttons+1
 pcall(function() GuiService.SelectedObject=self.buttons[self.selected] end)
end
-- The look of the next screens shown ("card" or "title"); the line's, the summary's and the column's sizes follow it.
function CaughtPanel.setLook(self:any, look:string)
 if LOOKS[look]==nil then look="card" end
 self.look=look
 local title=look=="title"
 self.shade.Enabled=title
 self.summary.LayoutOrder=if title then 1000 else 3
 self.summary.TextColor3=if title then TitleText.SOFT else TitleText.INK
 self.sub.TextColor3=if title then TitleText.SOFT else TitleText.INK
 self.list.VerticalAlignment=if title then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
 self.constraint.MaxSize=Vector2.new(LOOKS[look].width,10000)
 pcall(function()
  self.line.FontFace=face(if title then Enum.FontWeight.Light else Enum.FontWeight.Regular,false)
  self.sub.FontFace=face(Enum.FontWeight.Regular,true)
  self.summary.FontFace=face(Enum.FontWeight.Regular,title)
  self.hint.FontFace=face(Enum.FontWeight.Regular,false)
 end)
 self:setTextScale(self.scale)
end
-- The small line under the choices (TitleText.navHint: a controller's buttons), "" for none.
function CaughtPanel.setHint(self:any, text:string)
 self.hint.Text=text
 self.hint.TextColor3=TitleText.SOFT
 self.hint.Visible=text~="" and self.showing
end
-- `back`: the id B / Circle chooses on this screen (the confirmation's "Keep this life", the life menu's Resume), or nil for none.
function CaughtPanel.showChoices(self:any, title:string, subtitle:string, summary:string, choices:{Choice}, immediate:boolean?, back:string?)
 for _,b in self.buttons do b:Destroy() end
 self.buttons={};self.choices=choices;self.selected=1;self.stickDown=false;self.back=back
 self.showing,self.seconds,self.chosen=true,if immediate then 100 else 0,false
 self.line.Text,self.sub.Text,self.summary.Text=title,subtitle,summary
 self.box.CanvasPosition=Vector2.zero
 local titleLook=self.look=="title"
 for i,c in choices do
  local b=Instance.new("TextButton");b.Name=c.id;b.Text=c.text
  b.BackgroundColor3=if titleLook then TitleText.GROUND else Color3.new(.16,.16,.18)
  b.BackgroundTransparency=if titleLook then .35 else 0
  b.TextColor3=TitleText.INK;b.Font=Enum.Font.GothamMedium;b.TextSize=20;b.TextWrapped=true
  pcall(function() b.FontFace=face(Enum.FontWeight.Regular,false) end)
  b.Size=UDim2.new(1,-24,0,52);b.AutomaticSize=Enum.AutomaticSize.Y;b.Selectable=true;b.AutoButtonColor=true
  b.LayoutOrder=i+3;b.Parent=self.box
  local round=Instance.new("UICorner");round.CornerRadius=UDim.new(0,if titleLook then 6 else 4);round.Parent=b
  b.Activated:Connect(function() self:choose(c.id) end)
  table.insert(self.buttons,b)
 end
 self.button=self.buttons[1]
 self:setTextScale(self.scale)
 self.gui.Enabled=true;self:_apply()
 if not self.bound then
  self.bound=true
  CAS:BindActionAtPriority(self.action,function(_,state,input)
   local k=input and input.KeyCode
   if k==Enum.KeyCode.Thumbstick1 then
    local y=if input then input.Position.Y else 0
    if math.abs(y)<.3 then self.stickDown=false
    elseif math.abs(y)>.6 and not self.stickDown then self.stickDown=true;self:select(if y>0 then -1 else 1) end
   elseif state==Enum.UserInputState.Begin then
    if k==Enum.KeyCode.Up or k==Enum.KeyCode.W or k==Enum.KeyCode.DPadUp then self:select(-1)
    elseif k==Enum.KeyCode.Down or k==Enum.KeyCode.S or k==Enum.KeyCode.DPadDown then self:select(1)
    elseif k==Enum.KeyCode.ButtonB then if self.back~=nil then self:choose(self.back) end
    else self:choose() end
   end
   return Enum.ContextActionResult.Sink
  end,false,4000,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.Space,Enum.KeyCode.E,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,
   Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.W,Enum.KeyCode.S,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.Thumbstick1)
 end
 pcall(function() UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true end)
 if immediate then self:select(0) end
end
function CaughtPanel.show(self:any, summary:string, hasRest:boolean)
 self:showChoices(WaspText.LINE,WaspText.SUB,summary,{{id="Back",text=WaspText.choice(hasRest)}})
end
function CaughtPanel.hide(self:any)
 self.showing=false;self.gui.Enabled=false
 if self.bound then self.bound=false;CAS:UnbindAction(self.action) end
 pcall(function() GuiService.SelectedObject=nil end)
end
function CaughtPanel.choose(self:any, id:string?):boolean
 if not self.showing or self.chosen or not WaspText.panel(self.seconds).choices then return false end
 local choice=id
 if not choice then
  local selected=GuiService.SelectedObject
  for i,b in self.buttons do if b==selected then self.selected=i end end
  choice=self.choices[self.selected].id
 end
 local valid=false
 for _,c in self.choices do if c.id==choice then valid=true end end
 if not valid then return false end
 self.chosen=true;self.onChoose(choice :: string);return true
end
function CaughtPanel.setTextScale(self:any, scale:number)
 scale=math.clamp(scale,1,1.5)
 self.scale=scale
 local L=LOOKS[self.look]
 local width=self.gui.AbsoluteSize and self.gui.AbsoluteSize.X or 1280
 local line=if L.line>0 then L.line else TitleText.titleSize(if width>0 then width else 1280)
 self.line.TextSize=math.min(line*scale,72);self.sub.TextSize=L.sub*scale;self.summary.TextSize=L.summary*scale;self.hint.TextSize=14*scale
 for _,b in self.buttons do b.TextSize=L.button*scale;b.Size=UDim2.new(1,-24,0,L.height*scale) end
end
function CaughtPanel._apply(self:any)
 local s=WaspText.panel(self.seconds)
 local dim=LOOKS[self.look].dim
 self.dim.BackgroundTransparency=if dim~=nil then 1-dim else 1-s.dim;self.line.Visible=s.line;self.sub.Visible=s.line
 self.summary.Visible=s.choices and self.summary.Text~=""
 self.hint.Visible=s.choices and self.hint.Text~=""
 for _,b in self.buttons do b.Visible=s.choices end
end
function CaughtPanel.update(self:any,dt:number)
 if not self.showing then return end
 local before=WaspText.panel(self.seconds).choices
 self.seconds+=dt;self:_apply()
 if not before and WaspText.panel(self.seconds).choices then self:select(0) end
end
return CaughtPanel
