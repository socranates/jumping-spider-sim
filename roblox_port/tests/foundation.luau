-- Foundation regressions on real species/region specs; no Roblox performance claims.
local Map=require("../src/Shared/World/WorldMap")
local Garden=require("../src/Shared/World/Garden")
local PreyWorld=require("../src/Shared/Prey/PreyWorld")
Map.use("preserve")
local calls,passed=0,0
local ready=false
local world={home=Map.HOME,map=Map,regionReady=function() calls+=1;return ready end}
local ecology=PreyWorld.new({feeding={}},world,{},nil,{})
local emptyPrey,emptyBugs,hasBugs
for _,r in Map.regions() do
 if r.id~=Map.HOME then
  if Garden.prey(r)==nil then emptyPrey=emptyPrey or r end
  if Garden.bugs(r)==nil then emptyBugs=emptyBugs or r else hasBugs=hasBugs or r end
 end
end
assert(emptyPrey and emptyBugs and hasBugs,"preserve supplies both empty and populated regions")
for _=1,1000 do
 assert(ecology:director(emptyPrey.id)==nil)
 assert(ecology:bugs(emptyBugs.id)==nil)
end
assert(calls==0,"regions without those species must not scan streamed geometry");passed+=1
assert(ecology:bugs(hasBugs.id)==nil and calls==1,"woodlice still wait for all collision geometry");passed+=1
ready=true
assert(ecology:bugs(hasBugs.id)~=nil and calls==2,"stream arrival can create woodlice after an earlier refusal");passed+=1
local same=ecology:bugs(hasBugs.id)
assert(same==ecology:bugs(hasBugs.id) and calls==2,"existing colony is retained without further readiness scans");passed+=1
print(`FOUNDATION passed={passed} failed=0 avoided_scans=2000`)
