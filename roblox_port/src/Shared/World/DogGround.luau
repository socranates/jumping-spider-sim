--!strict
-- Cosmetic dog's ground LOD: an index of the same authored physical boxes the
-- server builds. No new floor, queryable part, or player collision is created.
-- The native ray wins when streamed; this covers distant unloaded ground.
local Region=require(script.Parent.Region)
local Environment=require(script.Parent.Environment)
local Ground={}
local CELL=64
local function key(x: number,z: number): string return math.floor(x/CELL)..":"..math.floor(z/CELL) end
function Ground.new(map: any): any
 local cells: {[string]: {any}}={}
 if type(map.regions)~="function" then return {cells=cells} end
 local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for _,p in Environment.DOG_ROUTE do
  minX,maxX=math.min(minX,p.X-50),math.max(maxX,p.X+50)
  minZ,maxZ=math.min(minZ,p.Z-50),math.max(maxZ,p.Z+50)
 end
 for _,r in map.regions() do
  local a,b=r.bounds[1],r.bounds[2]
  if b.X<minX or a.X>maxX or b.Z<minZ or a.Z>maxZ or b.Y< -93 or a.Y> -76 then continue end
  for _,p in Region.pieces(r) do
  -- This dog lives on the outdoor circuit, near its ground level. Upper
  -- leaves, roofs and indoor furniture are not distant proxy terrain.
  if p.hi.Y>=-93 and p.hi.Y<=-76 then
   for x=math.floor(p.lo.X/CELL),math.floor(p.hi.X/CELL) do
    for z=math.floor(p.lo.Z/CELL),math.floor(p.hi.Z/CELL) do
     local k=x..":"..z;cells[k]=cells[k] or {};table.insert(cells[k],p)
    end
   end
  end
 end end
 return {cells=cells}
end
function Ground.at(self: any,at: Vector3,up: number,down: number): Vector3?
 local best=nil :: number?
 for _,p in self.cells[key(at.X,at.Z)] or {} do
  if at.X>=p.lo.X and at.X<=p.hi.X and at.Z>=p.lo.Z and at.Z<=p.hi.Z
   and p.hi.Y<=at.Y+up and p.hi.Y>=at.Y+up-down and (best==nil or p.hi.Y>best) then best=p.hi.Y end
 end
 return if best then Vector3.new(at.X,best,at.Z) else nil
end
return Ground
