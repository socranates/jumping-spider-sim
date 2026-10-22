-- Capture only the four intentionally changed station regions through the legacy synchronous graph, independently of incremental preparation.
local Map=require("../src/Shared/World/WorldMap")
local Route=require("../src/Shared/Predator/RivalRoute")
local function fingerprint(g)
 local hash=1
 local function value(x)
  local s=if type(x)=="number" then string.format("%.17g",x) else tostring(x)
  for j=1,#s do hash=(hash*131+string.byte(s,j))%2147483647 end
  hash=(hash*131)%2147483647
 end
 local function vector(p) value(p.X);value(p.Y);value(p.Z) end
 for _,f in g:allFaces() do
  value(f.id);value(f.piece);value(f.axis);value(f.sign);value(f.plane);value(f.area);value(f.forbidden);vector(f.normal)
  for _,n in f.lo do value(n) end;for _,n in f.hi do value(n) end
  for _,p in f.stand do vector(p) end
  for _,e in f.edges do value(e.to);value(e.convex);vector(e.ahead);for _,p in e.samples do vector(p) end end
  for _,e in g:seamsOf(f.id) do
   value(e.region);value(e.to);value(e.convex);value(e.flat);vector(e.ahead)
   for _,p in e.samples do vector(p) end
  end
 end
 for _,p in g:waypoints() do value(p.face);vector(p.pos);vector(p.up) end
 return hash
end
Map.use("preserve")
for _,id in {"hut_desk","hut_floor_a","hut_shelf","room_window"} do
 local g=Route.graph(id)
 print(string.format("[%q]={faces=%d,seams=%d,waypoints=%d,fingerprint=%d},",id,#g:allFaces(),#g:allSeams(),#g:waypoints(),fingerprint(g)))
end
