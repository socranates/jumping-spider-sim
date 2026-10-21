--!strict
-- Presentation only. Shapes are anchored and non-queryable like other animals.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Shapes=require(Shared.Habitat.Shapes)
local Body={}
Body.__index=Body
function Body.new(parent: Instance): any
	local folder=Instance.new("Folder");folder.Name="StationMouse";folder.Parent=parent
	local parts={}
	local function add(name: string,size: Vector3,color: string)
		table.insert(parts,Shapes.ellipsoid(folder,name,size,CFrame.new(),Color3.fromHex(color),"Fabric"))
	end
	local v=Vector3.new
	add("Body",v(3.3,3,6.3),"7c7467");add("Head",v(2.4,2.4,3),"867d6e")
	for _,s in {-1,1} do
		add("Ear"..s,v(.45,2,1.8),"b68f82")
		add("Eye"..s,v(.4,.4,.4),"211e19")
	end
	add("Nose",v(.6,.55,.55),"c49e91")
	for i=1,4 do add("Foot"..i,v(.65,.45,1.3),"b29380") end
	for i=1,5 do add("Tail"..i,v(.45-i*.06,.45-i*.06,1.75),"a28c7b") end
	return setmetatable({folder=folder,parts=parts},Body)
end
function Body.draw(self: any, mouse: any, reduced: boolean)
	local v=Vector3.new
	local frame=CFrame.lookAt(mouse.pos,mouse.pos+mouse.heading,Vector3.yAxis)
	local p={v(0,1.8,0),v(0,2,-3.7),v(-1.1,3.2,-2.9),v(-1.2,2.4,-4.4),
		v(1.1,3.2,-2.9),v(1.2,2.4,-4.4),v(0,1.9,-5.2)}
	for i=1,4 do
		local side=if i%2==0 then 1 else -1
		local step=if mouse.moving then math.sin(mouse.distance*1.4+(i%3)*math.pi)*.7 else 0
		table.insert(p,v(side*1.45,.3,if i<=2 then -1.8+step else 2+step))
	end
	for i=1,5 do
		local sway=if reduced then 0 else math.sin(mouse.distance*.15-i*.35)*.35
		table.insert(p,v(sway,.45,3.2+i*1.5))
	end
	for i,part in self.parts do part.CFrame=frame*CFrame.new(p[i]) end
end
return Body
