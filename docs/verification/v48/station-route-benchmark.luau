-- Run in a fresh CLI process through tests/run.py using this absolute path.
-- Timings are CLI construction cost, never native frame-time evidence.
local Map=require("../src/Shared/World/WorldMap")
local Station=require("../src/Shared/World/StationTerritory")
local Route=require("../src/Shared/Predator/RivalRoute")
Map.use("preserve")
local ids={};for id in Station.roam() do table.insert(ids,id) end;table.sort(ids)
local total=0
for _,id in ids do
 local start=os.clock()
 local g=Route.graph(id)
 local faces=g:allFaces();local seams=g:allSeams();local points=g:waypoints()
 local elapsed=os.clock()-start;total+=elapsed
 local hash=1
 local function value(x)
  local s=if type(x)=="number" then string.format("%.17g",x) else tostring(x)
  for j=1,#s do hash=(hash*131+string.byte(s,j))%2147483647 end
  hash=(hash*131)%2147483647
 end
 local function vector(p) value(p.X);value(p.Y);value(p.Z) end
 for _,f in faces do
  value(f.id);value(f.piece);value(f.axis);value(f.sign);value(f.plane);value(f.area);value(f.forbidden);vector(f.normal)
  for _,n in f.lo do value(n) end;for _,n in f.hi do value(n) end
  for _,p in f.stand do vector(p) end
  for _,e in f.edges do
   value(e.to);value(e.convex);vector(e.ahead)
   for _,p in e.samples do vector(p) end
  end
  for _,e in g:seamsOf(f.id) do
   value(e.region);value(e.to);value(e.convex);value(e.flat);vector(e.ahead)
   for _,p in e.samples do vector(p) end
  end
 end
 for _,p in points do value(p.face);vector(p.pos);vector(p.up) end
 print(string.format("ROUTE %s faces=%d seams=%d waypoints=%d fingerprint=%d cli_ms=%.3f",id,#faces,#seams,#points,hash,elapsed*1000))
end
print(string.format("STATION_ROUTE_TOTAL regions=%d cli_ms=%.3f",#ids,total*1000))
