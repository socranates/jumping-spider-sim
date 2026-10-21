-- Command-bar probe for an already running Studio client. Does not join its ecology.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsRunning())
local S=game.ReplicatedStorage.Shared
local Map=require(S.World.WorldMap);Map.use("preserve")
local Garden=require(S.World.Garden)
local Director=require(S.Prey.PreyDirector)
local Species=require(S.Data.Species)
local point=Vector3.new(100,-84.29,-550)
local region=assert(Map.at(point))
print("[CHET_SHOULDER_REGION]",region.id)
for _,spec in Garden.bestiary(region) or {} do
 local d=Director.engine(workspace.World,Species[spec.profile],spec.seed,spec.target,false,spec)
 print("[CHET_SHOULDER_DIRECTOR]",spec.kind,#d.flies,#d.graph.perches)
 for _,p in d.graph.perches do
  if p.start then
   local h=d.graph.cast(p.position+Vector3.yAxis*.5,p.position-Vector3.yAxis*.5)
   print("[CHET_SHOULDER_START]",spec.kind,p.valid,p.position,(p.position-point).Magnitude,h and h.Instance.Name)
  end
 end
 d.probe:Destroy()
end
workspace:SetAttribute("CompactReviewSite","pond")
