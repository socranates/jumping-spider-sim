-- Read-only feasibility data. No runtime mesher, engine mutation or collision changes.
local Map=require("../src/Shared/World/WorldMap")
local Region=require("../src/Shared/World/Region")
local Plan=require("../src/Shared/World/LookPlan")
local Json=require("../src/Shared/Persistence/Json")
Map.use("preserve")
local all={};local seen={}
for _,list in {Map.regions(),Map.drawn(),Map.patches()} do
 for _,r in list do if not seen[r.id] then seen[r.id]=true;table.insert(all,r) end end
end
table.sort(all,function(a,b) return a.id<b.id end)
local totals={full=0,low=0};local n=0
for _,r in all do
 for _,tier in {"full","low"} do
  local records={}
  for _,d in Plan.records(r,tier) do
   local row={id=d.id,size={d.size.X,d.size.Y,d.size.Z},at={d.at.X,d.at.Y,d.at.Z},color={d.color.R,d.color.G,d.color.B}}
   for _,key in {"material","transparency","reflectance","shadow","group","full","far","shape","dew"} do row[key]=d[key] end
   if d.turn~=nil then row.turn={d.turn.X,d.turn.Y,d.turn.Z} end
   table.insert(records,row)
  end
  totals[tier]+=#records;n+=1
  local encoded=assert(Json.canonical({region=r.id,kind=r.kind,tier=tier,records=records}));print(encoded)
 end
end
print("DRAWN_EXPORT rows="..n.." full="..totals.full.." low="..totals.low.." regions="..#all)
