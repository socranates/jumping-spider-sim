do
local Original=__mods.WaspBody
local Candidate=__waspReuse
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function vec(a,b) return (a-b).Magnitude<1e-7 end
local function compare(a,b)
 check(#a.parts==#b.parts and a.shown==b.shown,"part count/visibility changed")
 check((a.folder.Parent==nil)==(b.folder.Parent==nil),"hidden folder state changed")
 for i,p in a.parts do
  local q=b.parts[i]
  check(p.Name==q.Name and p.Shape==q.Shape and p.Material==q.Material and p.Reflectance==q.Reflectance,"appearance recipe changed")
  check(vec(p.Size,q.Size) and vec(p.CFrame.Position,q.CFrame.Position),"size or position changed: "..p.Name)
  check(vec(p.CFrame.RightVector,q.CFrame.RightVector) and vec(p.CFrame.UpVector,q.CFrame.UpVector) and vec(p.CFrame.LookVector,q.CFrame.LookVector),"orientation changed: "..p.Name)
  check(p.Transparency==q.Transparency and p.CastShadow==q.CastShadow and p.CanCollide==q.CanCollide and p.CanQuery==q.CanQuery,"visibility/physics changed")
 end
end
local root=Instance.new("Folder");root.Parent=workspace
local a=Original.new(root);local b=Candidate.new(root);local other=Candidate.new(root)
local state={position=Vector3.zero,heading=Vector3.zAxis,visible=true,mode="flying",search=0}
local i=0
for _,mode in {"flying","holding","walking","walking","flying","unknown","holding","walking","flying"} do
 for frame=1,27 do
  i+=1;state.position=Vector3.new(i*.07,math.sin(i)*3,i%13);state.heading=Vector3.new(math.sin(i*.03),.1,math.cos(i*.03)).Unit
  state.search=(frame%8)/7;state.mode=mode;state.visible=frame%13~=0
  local now=i*.017
  a:draw(state,now);b:draw(state,now);compare(a,b)
  -- Another rig must not overwrite this one's cached local transforms.
  other:draw({position=-state.position,heading=-state.heading,visible=true,mode=if mode=="walking" then "holding" else "walking",search=1},now+2)
  compare(a,b)
 end
end
-- Direct pose calls are public, and must also leave the next drawn state exact.
for _,mode in {"walking","holding","flying","walking"} do
 a:pose(mode,17,.6);b:pose(mode,17,.6)
 state.mode=mode;state.visible=true;a:draw(state,19);b:draw(state,19);compare(a,b)
end
check(a.parts~=b.parts and b.frames~=other.frames and b.sizes~=other.sizes,"instances share mutable pose storage")
a:destroy();b:destroy();other:destroy();check(root.Parent==workspace,"destroy removed caller root");root:Destroy()
print("WASP_REUSE passed="..count.." failed=0")
end
