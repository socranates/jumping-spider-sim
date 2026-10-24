do
 local count,regions,calls=0,0,0
 local generate=__countedRegion.decor
 __countedRegion.decor=function(...)calls+=1;return generate(...)end
 local function check(ok,why)count+=1;assert(ok,why)end
 local function same(a,b)
  if type(a)~=type(b)then return false end
  if type(a)~="table"then return a==b end
  for k,v in a do if not same(v,b[k])then return false end end
  for k in b do if a[k]==nil then return false end end
  return true
 end
 for _,world in {"test_garden","preserve"}do
  __mods.WorldMap.use(world)
  local all={};for _,r in __mods.WorldMap.regions(__mods.WorldMap.SEED)do if __mods.Region.streamed(r.kind)then table.insert(all,r)end end
  if __mods.WorldMap.drawn then for _,r in __mods.WorldMap.drawn(__mods.WorldMap.SEED)do table.insert(all,r)end end
  for _,region in all do
   regions+=1;local before=calls
   local low=__phoneLookPlan.records(region,"low","low")
   local far=__phoneLookPlan.records(region,"far","low")
   check(calls-before==1,"phone low/far regenerated decoration")
   check(same(low,__baselineLookPlan.records(region,"low","low")),"phone low records changed")
   check(same(far,__baselineLookPlan.records(region,"far","low")),"phone far records changed")
   local full=__phoneLookPlan.records(region,"full","full")
   check(calls-before==2,"phone cache retained unused full-detail decoration")
   check(same(full,__baselineLookPlan.records(region,"full","full")),"later full detail lost records")
   check(__phoneLookPlan.records(region,"low","low")==low and __phoneLookPlan.records(region,"far","low")==far,"tier upgrade changed held view identity")
  end
 end
 __countedRegion.decor=generate
 print("SCENERY_PHONE_CACHE",count,"passed",0,"failed","regions",regions,"low_far_generations",regions,"upgrade_generations",regions)
end
