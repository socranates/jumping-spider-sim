-- Read-only authored-record inventory. No native Instance, collision or FPS claim.
local Map=require("../src/Shared/World/WorldMap")
local Region=require("../src/Shared/World/Region")
local Looks=require("../src/Shared/World/LookPlan")
local Station=require("../src/Shared/World/StationTerritory")
local Json=require("../src/Shared/Persistence/Json")
local function vector(v) return {v.X,v.Y,v.Z} end
local rows=0
for _,world in {"test_garden","preserve"} do
 Map.use(world)
 local seen={}
 for _,group in {"walkable","drawn","patch"} do
  local regions=if group=="walkable" then Map.regions() elseif group=="drawn" then Map.drawn() else Map.patches()
  for _,r in regions do
   assert(not seen[r.id],"duplicate authored region identity: "..world.."/"..r.id);seen[r.id]=true
   local neighbors,retreats={},{}
   for _,n in r.neighbors do table.insert(neighbors,n.id) end
   for _,home in r.retreats do table.insert(retreats,home.id) end
   local policy=if group~="walkable" then "client-only-look" elseif r.kind=="sill" then "startup-sill"
    elseif r.kind=="verge" or Station.contains(r.id) then "persistent" else "atomic"
   local item={world=world,revision=Map.revision(),group=group,id=r.id,kind=r.kind,seed=r.seed,
    min=vector(r.bounds[1]),max=vector(r.bounds[2]),spawn=vector(r.spawn.pos),neighbors=neighbors,retreats=retreats,
    walkable_records=#Region.pieces(r),full_draw_records=#Looks.records(r,"full","full"),
    low_draw_records=#Looks.records(r,"low","low"),far_full_records=#Looks.records(r,"far","full"),
    far_low_records=#Looks.records(r,"far","low"),streaming_policy=policy}
   assert(group=="walkable" or item.walkable_records==0,"draw-only region has support records")
   print("WORLD_INVENTORY "..assert(Json.canonical(item)))
   rows+=1
  end
 end
end
assert(rows>0,"inventory is empty")
print("WORLD_INVENTORY_END rows="..rows)
