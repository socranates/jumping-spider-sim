--!strict
local CAS=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local Art=require(script.Parent.NotebookArt)
local Panel={}
Panel.__index=Panel
local function text(parent:Instance,name:string,size:number,order:number):TextLabel
	local l=Instance.new("TextLabel");l.Name=name;l.BackgroundTransparency=1
	l.TextColor3=Color3.fromRGB(44,57,54);l.Font=Enum.Font.GothamMedium;l.TextSize=size
	l.TextWrapped=true;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Top
	l.Size=UDim2.new(1,-32,0,0);l.AutomaticSize=Enum.AutomaticSize.Y;l.LayoutOrder=order;l.Parent=parent
	return l
end
function Panel.new(parent:Instance,book:any,onClose:()->()):any
	local gui=Instance.new("ScreenGui");gui.Name="FieldNotebook";gui.ResetOnSpawn=false
	gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=70;gui.Enabled=false;gui.Parent=parent
	local paper=Instance.new("Frame");paper.Name="Paper";paper.BackgroundColor3=Color3.fromRGB(239,234,213)
	paper.AnchorPoint=Vector2.new(.5,.5);paper.Position=UDim2.fromScale(.5,.5);paper.Size=UDim2.fromScale(.94,.96);paper.Active=true;paper.Parent=gui
	local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(920,10000);limit.Parent=paper
	local heading=text(paper,"Heading",22,0);heading.Text="FIELD NOTEBOOK";heading.Position=UDim2.fromOffset(16,8)
	local body=Instance.new("ScrollingFrame");body.Name="Reading";body.Position=UDim2.fromOffset(0,42)
	body.Size=UDim2.new(1,0,1,-150);body.CanvasSize=UDim2.new();body.AutomaticCanvasSize=Enum.AutomaticSize.Y
	body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=8;body.ScrollingDirection=Enum.ScrollingDirection.Y;body.Parent=paper
	local layout=Instance.new("UIListLayout");layout.SortOrder=Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment=Enum.HorizontalAlignment.Center;layout.Padding=UDim.new(0,14);layout.Parent=body
	local art=Instance.new("Frame");art.Name="Illustration";art.Size=UDim2.new(1,-32,0,96);art.BackgroundTransparency=1;art.LayoutOrder=1;art.Parent=body
	local self:any=setmetatable({gui=gui,paper=paper,body=body,art=art,book=book,onClose=onClose,showing=false,index=1,
		title=text(body,"Title",26,2),fact=text(body,"Fact",21,3),gameText=text(body,"InThisGame",19,4),sources=text(body,"Sources",16,5),
		hint=text(paper,"Hint",14,0),buttons={},scrollAxis=0,shown=""},Panel)
	self.hint.Position=UDim2.new(0,16,1,-103);self.hint.Size=UDim2.new(1,-32,0,46);self.hint.AutomaticSize=Enum.AutomaticSize.None
	local specs: {{name:string,run:()->()}} = {{name="Previous",run=function() self:turn(-1) end},{name="Next",run=function() self:turn(1) end},{name="Back",run=function() self:close() end}}
	for i,spec in specs do
		local b=Instance.new("TextButton");b.Name=spec.name;b.Text=spec.name;b.Font=Enum.Font.GothamMedium;b.TextSize=19
		b.BackgroundColor3=Color3.fromRGB(44,57,54);b.TextColor3=Color3.new(1,1,1);b.TextWrapped=true;b.Selectable=false
		b.Position=UDim2.new((i-1)/3,6,1,-52);b.Size=UDim2.new(1/3,-12,0,46);b.Parent=paper
		b.Activated:Connect(spec.run);self.buttons[i]=b
	end
	body:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:fitReading() end)
	return self
end
function Panel.fitReading(self:any)
	-- A short landscape screen needs its first lines of text more than the sketch.
	self.art.Visible=self.body.AbsoluteWindowSize.Y>=180
end
function Panel.isShowing(self:any):boolean return self.showing end
function Panel.render(self:any)
	local id=self.book.opened[self.index]
	local p=if id then self.book:page(id) else nil
	self.shown=id or ""
	self.title.Text=if p then p.title else "A notebook for your discoveries"
	self.fact.Text=if p then p.text else "Explore the sill. As things happen, you can read about their real biology here."
	self.gameText.Text=if p and p.game~="" then "In this game\n"..p.game else ""
	self.sources.Text=if p then "Sources\n"..table.concat(p.sources,"\n\n") else ""
	self.body.CanvasPosition=Vector2.zero
	Art.draw(self.art,id or "")
end
function Panel.turn(self:any,delta:number)
	if #self.book.opened==0 then return end
	self.index=(self.index-1+delta)%#self.book.opened+1;self:render()
end
function Panel.scroll(self:any,delta:number)
	local maximum=math.max(0,self.body.AbsoluteCanvasSize.Y-self.body.AbsoluteWindowSize.Y)
	self.body.CanvasPosition=Vector2.new(0,math.clamp(self.body.CanvasPosition.Y+delta,0,maximum))
end
function Panel.show(self:any,large:boolean,device:string,padStyle:string?)
	self.showing=true;self.gui.Enabled=true;self.index=math.max(1,#self.book.opened);self.scrollAxis=0
	local scale=if large then 1.5 else 1
	self.title.TextSize=math.round(26*scale);self.fact.TextSize=math.round(21*scale);self.gameText.TextSize=math.round(19*scale);self.sources.TextSize=math.round(16*scale)
	self.hint.Text=if device=="gamepad" then (if padStyle=="playstation" then "L1 / R1: page   D-pad / right stick: scroll   Circle: back" else "LB / RB: page   D-pad / right stick: scroll   B: back")
		elseif device=="touch" then "Swipe to read. Only your discoveries are shown. Kept for this session."
		else "Left / right: page   Up / down: scroll   N or Q: back. Session only."
	self:render()
	self:fitReading()
	UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true
	-- This reader owns directional input. A selected GuiObject makes Roblox consume
	-- arrows/D-pad for button navigation before our reading action receives them.
	GuiService.SelectedObject=nil
	CAS:BindActionAtPriority("WindowsillNotebook",function(_,state,input)
		if GuiService.MenuIsOpen then self.scrollAxis=0;return Enum.ContextActionResult.Pass end
		local k=input.KeyCode
		if k==Enum.KeyCode.Thumbstick2 or k==Enum.KeyCode.Thumbstick1 then
			self.scrollAxis=if state==Enum.UserInputState.Cancel then 0 else input.Position.Y
		elseif state==Enum.UserInputState.Begin then
			if k==Enum.KeyCode.Left or k==Enum.KeyCode.DPadLeft or k==Enum.KeyCode.ButtonL1 then self:turn(-1)
			elseif k==Enum.KeyCode.Right or k==Enum.KeyCode.DPadRight or k==Enum.KeyCode.ButtonR1 then self:turn(1)
			elseif k==Enum.KeyCode.Up or k==Enum.KeyCode.DPadUp then self:scroll(-120)
			elseif k==Enum.KeyCode.Down or k==Enum.KeyCode.DPadDown then self:scroll(120)
			else self:close() end
		end
		return Enum.ContextActionResult.Sink
	end,false,5000,Enum.KeyCode.N,Enum.KeyCode.Q,Enum.KeyCode.M,Enum.KeyCode.ButtonB,Enum.KeyCode.ButtonSelect,
		Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,
		Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,Enum.KeyCode.Thumbstick1,Enum.KeyCode.Thumbstick2)
end
function Panel.update(self:any,dt:number)
	if self.showing and not GuiService.MenuIsOpen and math.abs(self.scrollAxis)>.2 then self:scroll(-self.scrollAxis*480*math.min(dt,.1)) end
end
function Panel.hide(self:any)
	self.showing=false;self.gui.Enabled=false;self.scrollAxis=0
	CAS:UnbindAction("WindowsillNotebook");GuiService.SelectedObject=nil
end
function Panel.close(self:any) self:hide();self.onClose() end
return Panel
