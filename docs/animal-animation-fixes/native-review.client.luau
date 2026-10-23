-- Private local scene. No production startup, persistence or network requests.
local Run=game:GetService("RunService")
assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("AnimalAnimationReview")==true)
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Env=require(Shared.World.Environment)
local Living=require(script.Parent:WaitForChild("LivingWorld"))
local CatBody=require(script.Parent:WaitForChild("CatBody"))
local root=Instance.new("Folder");root.Name="ReviewGround";root.Parent=workspace
local ground=Instance.new("Part");ground.Name="ReviewFloor";ground.Anchored=true
ground.Size=Vector3.new(1600,4,1600);ground.Position=Vector3.new(0,-86.6,0);ground.Color=Color3.fromRGB(88,104,73);ground.Parent=root
local living=Living.new(workspace,root,"full",{regions=function() return {} end})
CatBody.SOUNDS={}
local cat=CatBody.new(workspace,"full")
local c={pos=Vector3.new(0,-84.6,0),heading=Vector3.zAxis,pose="walk",spot="floor",surface=-84.6,reactS=0}
local neck,collar,tag
for _,p in living.dog.parts do
 if p.Name=="Neck" then neck=p elseif p.Name=="Collar" then collar=p elseif p.Name=="Tag" then tag=p end
end
assert(neck and collar and tag)
local camera=workspace.CurrentCamera;camera.CameraType=Enum.CameraType.Scriptable
local elapsed=0;local tested=0;local moved=false;local previous=nil;local announced=false;local failed=false
local paw=assert(cat.folder:FindFirstChild("FLPaw"))
print("[ANIMAL_ANIMATION_REVIEW_BEGIN]",script:GetAttribute("SourceCommit"))
Run:BindToRenderStep("AnimalAnimationReview",Enum.RenderPriority.Camera.Value+1,function(dt)
 if failed then return end
 local ok,why=pcall(function()
  elapsed+=math.min(dt,.1)
  local pose=Env.dog(elapsed,0)
  living:drawDog(pose.position,{totalHours=elapsed/75,rain=0},false,math.min(dt,.1))
  assert(living.dog.shown,"dog unsupported on review floor")
  assert((neck.CFrame:PointToObjectSpace(collar.Position)-Vector3.new(0,1,0)).Magnitude<.001,"collar detached")
  assert((neck.CFrame:PointToObjectSpace(tag.Position)-Vector3.new(0,-3,-10)).Magnitude<.001,"tag detached")
  assert(neck.CFrame.UpVector:Dot(collar.CFrame.UpVector)>.99999,"collar rotation detached")
  local dogScene=elapsed%24<12
  local target=if dogScene then neck.Position else c.pos+Vector3.new(0,15,0)
  camera.CFrame=CFrame.lookAt(target+Vector3.new(if dogScene then 70 else 55,20,35),target)
  cat:draw(c,elapsed,math.min(dt,.1),0,0,camera.CFrame.Position)
  if previous and (paw.Position-previous).Magnitude>.01 then moved=true end
  previous=paw.Position;tested+=1
  if elapsed>24 and not announced then
   assert(moved,"cat gait frozen");announced=true
   print("[ANIMAL_ANIMATION_REVIEW_PASS]",tested,"collar_tag_and_cat_paw","isolated_scene_not_gameplay_or_fps")
  end
 end)
 if not ok then failed=true;warn("[ANIMAL_ANIMATION_REVIEW_FAIL]",why) end
end)
