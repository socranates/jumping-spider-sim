--!strict
-- Plain end/start screens. Scroll within the safe area; the selected button owns accept,
-- and modal input never leaks into a jump or a held walking key.
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaspText = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("WaspText"))
local CaughtPanel = {}
CaughtPanel.__index = CaughtPanel
export type Choice = { id: string, text: string }
local function label(parent: Instance, name: string, size: number, order: number): TextLabel
 local l=Instance.new("TextLabel")
 l.Name=name; l.BackgroundTransparency=1; l.TextColor3=Color3.new(.95,.93,.88)
 l.Font=Enum.Font.GothamMedium; l.TextSize=size; l.TextWrapped=true
 l.Size=UDim2.new(1,-24,0,0); l.AutomaticSize=Enum.AutomaticSize.Y; l.LayoutOrder=order; l.Parent=parent
 return l
end
function CaughtPanel.new(playerGui: Instance, onChoose: (string) -> (), name: string?): any
 local gui=Instance.new("ScreenGui")
 gui.Name=name or "SpiderCaught"; gui.ResetOnSpawn=false; gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
 gui.DisplayOrder=50; gui.Enabled=false; gui.Parent=playerGui
 local dim=Instance.new("Frame")
 dim.Name="Dim";dim.Size=UDim2.fromScale(1,1);dim.BackgroundColor3=Color3.new(.02,.02,.03);dim.BackgroundTransparency=1
 dim.Active=true;dim.Parent=gui
 local box=Instance.new("ScrollingFrame")
 box.Name="Box";box.BackgroundTransparency=1;box.BorderSizePixel=0;box.AnchorPoint=Vector2.new(.5,.5)
 box.Position=UDim2.fromScale(.5,.5);box.Size=UDim2.fromScale(.92,.88)
 box.CanvasSize=UDim2.new();box.AutomaticCanvasSize=Enum.AutomaticSize.Y;box.ScrollBarThickness=6;box.Parent=dim
 local constraint=Instance.new("UISizeConstraint");constraint.MaxSize=Vector2.new(880,10000);constraint.Parent=box
 local list=Instance.new("UIListLayout");list.HorizontalAlignment=Enum.HorizontalAlignment.Center
 list.SortOrder=Enum.SortOrder.LayoutOrder;list.Padding=UDim.new(0,12);list.Parent=box
 local self=setmetatable({gui=gui,dim=dim,box=box,line=label(box,"Line",28,1),sub=label(box,"Sub",18,2),
 summary=label(box,"Summary",18,3),buttons={},choices={},button=nil,onChoose=onChoose,showing=false,
 seconds=0,bound=false,chosen=false,selected=1,stickDown=false,action="WindowsillChoice"..gui.Name},CaughtPanel)
 return self
end
function CaughtPanel.isShowing(self:any):boolean return self.showing end
function CaughtPanel.select(self:any, delta:number)
 if #self.buttons==0 then return end
 self.selected=(self.selected-1+delta)%#self.buttons+1
 pcall(function() GuiService.SelectedObject=self.buttons[self.selected] end)
end
function CaughtPanel.showChoices(self:any, title:string, subtitle:string, summary:string, choices:{Choice}, immediate:boolean?)
 for _,b in self.buttons do b:Destroy() end
 self.buttons={};self.choices=choices;self.selected=1;self.stickDown=false
 self.showing,self.seconds,self.chosen=true,if immediate then 100 else 0,false
 self.line.Text,self.sub.Text,self.summary.Text=title,subtitle,summary
 self.box.CanvasPosition=Vector2.zero
 for i,c in choices do
  local b=Instance.new("TextButton");b.Name=c.id;b.Text=c.text;b.BackgroundColor3=Color3.new(.16,.16,.18)
  b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamMedium;b.TextSize=20;b.TextWrapped=true
  b.Size=UDim2.new(1,-24,0,52);b.AutomaticSize=Enum.AutomaticSize.Y;b.Selectable=true;b.AutoButtonColor=true
  b.LayoutOrder=i+3;b.Parent=self.box
  b.Activated:Connect(function() self:choose(c.id) end)
  table.insert(self.buttons,b)
 end
 self.button=self.buttons[1]
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
    else self:choose() end
   end
   return Enum.ContextActionResult.Sink
  end,false,4000,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.Space,Enum.KeyCode.E,Enum.KeyCode.ButtonA,
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
 self.line.TextSize=28*scale;self.sub.TextSize=18*scale;self.summary.TextSize=18*scale
 for _,b in self.buttons do b.TextSize=20*scale;b.Size=UDim2.new(1,-24,0,52*scale) end
end
function CaughtPanel._apply(self:any)
 local s=WaspText.panel(self.seconds)
 self.dim.BackgroundTransparency=1-s.dim;self.line.Visible=s.line;self.sub.Visible=s.line
 self.summary.Visible=s.choices and self.summary.Text~=""
 for _,b in self.buttons do b.Visible=s.choices end
end
function CaughtPanel.update(self:any,dt:number)
 if not self.showing then return end
 local before=WaspText.panel(self.seconds).choices
 self.seconds+=dt;self:_apply()
 if not before and WaspText.panel(self.seconds).choices then self:select(0) end
end
return CaughtPanel
