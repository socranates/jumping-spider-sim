--!strict
-- Geometry adapter for the frozen PerchGraph. Every planned leg and every flight tick is swept.
local M=require(script.Parent.PreyMath)
local G={};G.__index=G
export type Perch={id:string,position:Vector3,normal:Vector3,shelter:number,food:number,start:boolean,valid:boolean,occupant:string,reserved:string}
function G.new(cast: any,sweep: any,overlap: any,profile: any): any
 return setmetatable({cast=cast,sweep=sweep,overlap=overlap,p=profile,perches={},plans=0,sweeps=0},G)
end
function G.rest(self: any,p: Perch): Vector3 return p.position+p.normal*self.p.body.hover_wu end
function G.clear(self: any,a: Vector3,b: Vector3): boolean
 self.sweeps+=1
 return not self.overlap(a,self.p.flight.clearance_radius_wu) and not self.sweep(a,b,self.p.flight.clearance_radius_wu)
end
function G.add(self: any,id: string,position: Vector3,normal: Vector3,shelter: number,food: number,start: boolean): Perch
 local p: Perch={id=id,position=position,normal=normal,shelter=shelter,food=food,start=start,valid=false,occupant='',reserved=''}
 local hit=self.cast(position+normal*.5,position-normal*.5)
 if hit and math.abs((hit.Position-position):Dot(normal))<=.06 and hit.Normal:Dot(normal)>=math.cos(math.rad(12)) then
  p.position=hit.Position;p.valid=self:clear(self:rest(p),self:rest(p)+normal*self.p.flight.lift_wu)
 end
 table.insert(self.perches,p);return p
end
function G.plan(self: any,start: Vector3,normal: Vector3,target: Perch,threat: Vector3?): {Vector3}?
 self.plans+=1;local p=self.p.flight
 -- (ROBLOX-119) the band its routes climb in: the sill's 0 to 11 studs unless the graph is told its own (`floor`, `ceiling`: PreyDirector.new from a spec that
 -- names them, World/Meadow's and World/Hut's flowers and lamps, far over and under the sill); the sill's routes are as they were
 local floor,ceil=self.floor or 0,self.ceiling or 11
 local rest=self:rest(target);if (start-rest).Magnitude>p.max_flight_wu then return nil end
 local lifted=start+normal*p.lift_wu;local approach=rest+target.normal*p.approach_wu
 if not self:clear(start,lifted) or not self:clear(approach,rest) then return nil end
 local routes: {{Vector3}}={{lifted,approach}};local mid=(lifted+approach)*.5
 for _,h in {2.5,5,8,11} do local y=math.min(mid.Y+h,ceil)
  if y>mid.Y+.5 then table.insert(routes,{lifted,Vector3.new(mid.X,y,mid.Z),approach}) end
 end
 for _,h in {6,9,11} do local y=math.min(math.max(floor+h,math.max(lifted.Y,approach.Y)+.5),ceil)
  if y>math.max(lifted.Y,approach.Y)+.3 then table.insert(routes,{lifted,Vector3.new(lifted.X,y,lifted.Z),Vector3.new(approach.X,y,approach.Z),approach}) end
 end
 for _,route in routes do
  local clear=true
  for i=2,#route do if not self:clear(route[i-1],route[i]) then clear=false;break end end
  if clear then
   local pts={start};for _,v in route do table.insert(pts,v) end;table.insert(pts,rest)
   if (not threat or M.distanceToPath(pts,threat)>=p.path_threat_clearance_wu) and M.pathLength(pts)<=p.max_flight_wu*1.6 then return pts end
  end
 end
 return nil
end
return G
