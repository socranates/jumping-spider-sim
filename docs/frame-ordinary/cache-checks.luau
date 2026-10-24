-- Actual seeded generators, all three read-only views, both worlds and request orders.
local Map=__mods.WorldMap
local Region=__countedRegion
local baseline=__baselineLookPlan
local optimized=__optimizedLookPlan
local count,failed=0,0
local function check(ok,why)count+=1;if not ok then failed+=1;error(why)end end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~="table"then return a==b end
 for k,v in a do if not same(v,b[k])then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
local generate=Region.decor;local calls=0
Region.decor=function(...)calls+=1;return generate(...)end
local totalOld,totalNew,regions=0,0,0
for _,world in {"test_garden","preserve"}do
 Map.use(world)
 local all={};for _,region in Map.regions(Map.SEED)do if Region.streamed(region.kind)then table.insert(all,region)end end
 if Map.drawn then for _,region in Map.drawn(Map.SEED)do table.insert(all,region)end end
 for index,region in all do
  regions+=1;local oldViews={};local newViews={};local order=if index%2==0 then {"low","far","full"}else {"full","far","low"}
  local before=calls
  for _,level in order do oldViews[level]=baseline.records(region,level,"full")end
  totalOld+=calls-before;before=calls
  for _,level in order do newViews[level]=optimized.records(region,level,"full")end
  local generated=calls-before;totalNew+=generated
  check(generated==1,"a cold region was generated more than once")
  for _,level in order do
   check(same(oldViews[level],newViews[level]),"scenery records changed: "..world.."/"..region.id.."/"..level)
   check(optimized.records(region,level,"full")==newViews[level],"warm view identity changed")
  end
  check(same(oldViews.full,newViews.full),"far brick projection mutated complete source")
  if region.kind=="backdrop"then
   before=calls;local low=optimized.records(region,"far","low")
   check(calls==before,"low-tier far projection regenerated the source")
   check(same(baseline.records(region,"far","low"),low),"low-tier far scenery changed")
  end
 end
end
Region.decor=generate
check(totalNew==regions and totalOld>=totalNew*3,"cold generation work did not decrease")
print("SCENERY_CACHE",count,"passed",failed,"failed","regions",regions,"old_generations",totalOld,"new_generations",totalNew)
