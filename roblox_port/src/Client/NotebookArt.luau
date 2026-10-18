--!strict
-- Small authored vector sketches, deliberately diagrams rather than photographs or eye-view claims.
local Art={}
local ink=Color3.fromRGB(44,57,54)
local function shape(parent: Instance,x:number,y:number,w:number,h:number,rotation:number,colour:Color3,round:boolean)
	local p=Instance.new("Frame");p.Name="Ink";p.BorderSizePixel=0;p.BackgroundColor3=colour
	p.AnchorPoint=Vector2.new(.5,.5);p.Position=UDim2.fromOffset(x,y);p.Size=UDim2.fromOffset(w,h);p.Rotation=rotation;p.Parent=parent
	if round then local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=p end
end
function Art.draw(parent: Instance,id:string)
	for _,p in parent:GetChildren() do p:Destroy() end
	local centre=Instance.new("Frame");centre.Name="Sketch";centre.BackgroundTransparency=1
	centre.AnchorPoint=Vector2.new(.5,0);centre.Position=UDim2.fromScale(.5,0);centre.Size=UDim2.fromOffset(210,96);centre.Parent=parent
	if id=="dragline" then shape(centre,105,12,1,24,0,ink,false) end
	if id=="peacock_dance" then
		shape(centre,105,58,78,55,0,Color3.fromRGB(16,125,146),true)
		shape(centre,105,58,58,38,0,Color3.fromRGB(231,125,54),true)
	end
	shape(centre,105,62,34,43,0,ink,true);shape(centre,105,35,30,26,0,ink,true)
	for side=-1,1,2 do
		for i=1,4 do
			shape(centre,105+side*29,26+i*10,38,3,side*(i*19-48),ink,true)
		end
		shape(centre,105+side*6,28,8,8,0,Color3.fromRGB(239,234,213),true)
	end
end
return Art
