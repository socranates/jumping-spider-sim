--!strict
-- Solo client world of perceivable flies. Godot order: sensor, prey, motor, capture/feeding.
-- ROBLOX-96 (W3, garden life): a director is one region's prey. Without a `spec` it is the sill's, exactly as it always was: the twelve authored perches below, the
-- two window vents, a house fly with every third fly a fruit fly when `mixed`. With a `spec` (World/Garden.prey, for the bed) its perches and vents are the
-- spec's: a perch marked `walker` is a plant perch that only a walker (the aphid, Species body.walker) is spawned on, and never needs a flight to be valid; a
-- vent marked `walker` is where an aphid appears, on a free walker perch within the vent's reach, out of the spider's sight (the population's own check), with
-- no flight. Several directors share one Feeding (the jaws): Prey/PreyWorld runs the home director's `after` with the feeding step and every other active
-- director's `afterShared`, which strikes and tidies but never advances the reserves; a fly that tears free is sent back to the director it belongs to.
local Fly=require(script.Parent.Fly)
local Species=require(script.Parent.Parent.Data.Species)
local Graph=require(script.Parent.PerchGraph)
local Population=require(script.Parent.PreyPopulation)
local Feeding=require(script.Parent.Feeding)
local M=require(script.Parent.PreyMath)
local D={};D.__index=D
local POINTS: {{string | number}}={
 {'sill_first_hunt',-13,0,6},{'rim_hunt',10,4.6,-3},{'leaf_hunt',-1,4.2,-1},{'east_hunt',23,0,7},
 {'west_leaf',-15,4.2,-1},{'east_leaf',22,5.4,-2},{'under_leaf',-12.8,0,-2},{'front_path',1,0,8},
 {'east_corner',27,0,-7},{'back_path',-9,0,-9},{'rim_west',5,4.6,-5},{'rim_east',15,4.6,-5},
}
-- A region's prey, authored or generated (World/Garden.prey): `perches` { id, position, normal, shelter, food, start, walker? }, `vents` { id, position, normal,
-- walker?, reach? }, `prefix` (the flies' ids begin with it; the sill's is 'fly_').
export type Spec={perches:{any},vents:{any},prefix:string?}
function D.new(graph: any,profile: any,seed: number,target: number,mixed: boolean?,spec: Spec?): any
 local self:any=setmetatable({graph=graph,p=profile,mixed=mixed==true,seed=seed,target=target,flies={},serial=0,now=0,tick=0,
  population=Population.new(profile.population,seed+117,target),feeding=Feeding.new(),vents={},strikeEnd=-1,previousMode='attached',
  captures=0,enabled=true,cpu={},candidates=0,entryChecks=0},D)
 if spec then
  self.prefix=spec.prefix or 'fly_' -- (a region's flies carry its name, so no two flies of the world share an id)
  for _,row in spec.perches do
   local p=graph:add(row.id,row.position,row.normal,row.shelter,row.food,row.start==true)
   if row.walker then p.walker=true end
  end
 else
  for i,row in POINTS do
   local id=row[1]::string
   graph:add(id,Vector3.new(row[2]::number,row[3]::number,row[4]::number),Vector3.yAxis,if id=='under_leaf' then .5 else .2,if string.find(id,'rim') then .5 else .1,i<=6)
  end
 end
 -- Keep only perches with a valid outgoing flight (a walker's perch needs none: nothing flies from it).
 for _,p in graph.perches do
  if p.valid and not p.walker then
   local linked=false;local tries=0
   for _,other in graph.perches do if other~=p and other.valid and (other.position-p.position).Magnitude<=profile.flight.max_flight_wu then
    tries+=1;if graph:plan(graph:rest(p),p.normal,other,nil) then linked=true;break end
    if tries>=5 then break end
   end end
   p.valid=linked
  end
 end
 for _,p in graph.perches do if #self.flies<target and p.start and p.valid then self:spawn(p) end end
 if spec then
  for _,v in spec.vents do
   table.insert(self.vents,{id=v.id,position=v.position,normal=v.normal,shelter=0,food=0,start=false,valid=true,occupant='',reserved='',walker=v.walker==true,reach=v.reach or 4})
  end
 else
  for i,x in {-23,23} do
   -- Authored window vents face into the sill. Entry paths are still swept before a fly exists.
   table.insert(self.vents,{id='vent_'..i,position=Vector3.new(x,8,-12.5),normal=Vector3.zAxis,shelter=0,food=0,start=false,valid=true,occupant='',reserved=''})
  end
 end
 return self
end
function D.spawn(self: any,perch: any): any
 self.serial+=1
 local profile = if perch.walker then Species.aphid_prototype elseif self.mixed~=false and self.serial%3==0 then Species.fruit_fly_prototype else self.p
 local f=Fly.new((self.prefix or 'fly_')..self.serial,self.serial,self.seed+self.serial*997,perch,self.graph,profile,self.now)
 table.insert(self.flies,f);return f
end
function D.percepts(self: any): {any}
 local out={};for _,f in self.flies do local p=f:percept();if p then table.insert(out,p) end end;return out
end
-- Whether this director's list holds the fly.
function D.owns(self: any,f: any): boolean
 return table.find(self.flies,f)~=nil
end
function D.before(self: any,dt: number,position: Vector3,observer: any,sensor: any,cast: any,camera: any)
 if not self.enabled then return end
 local started=os.clock();self.now+=dt;self.tick+=1;self.previousPosition=position
 local alive=0;for _,f in self.flies do if f:alive() then alive+=1 end end
 self.population:step(self.now,alive,self.vents,function(v)
  self.entryChecks+=1
  local pos=self.graph:rest(v)
  if (position-pos).Magnitude<self.p.population.vent_min_distance_wu then return false end
  if M.inView(camera.CFrame,camera.FieldOfView,camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y),pos,self.p.population.vent_view_margin_deg) then return false end
  return not sensor:couldSense(observer,pos,self.p.body.radius_wu,cast)
 end,function(v)
  if v.walker then
   -- (ROBLOX-96) a walker is born on a free plant perch within the vent's reach: no flight, out of sight
   for _,target in self.graph.perches do
    if target.walker and target.valid and target.occupant=='' and target.reserved=='' and (target.position-v.position).Magnitude<=v.reach then
     self:spawn(target);return true
    end
   end
   return false
  end
  for _,target in self.graph.perches do
   if target.valid and target.occupant=='' and target.reserved=='' then
    local path=self.graph:plan(self.graph:rest(v),v.normal,target,nil)
    if path and M.pathLength(path)>=self.p.population.entry_min_flight_wu then
     local f=self:spawn(v);f.flight:begin(path,target,'move',self.now);return true
    end
   end
  end
  return false
 end)
 for _,f in self.flies do f:step(dt,self.now,position,.3,cast) end
 self.beforeCost=(os.clock()-started)*1e6
end
function D.escape(self: any,f: any)
 if f.profile.body.walker then
  -- (ROBLOX-96) a walker that tears free is back on its perch if the perch is still free; if not, it is gone (the population owes another)
  local perch=f.perch
  if perch and perch.occupant=='' then
   perch.occupant=f.id;f.position=self.graph:rest(perch);f.prevPosition=f.position;f.normal=perch.normal;f.velocity=Vector3.zero
   f.state='ALERT';f.stateSince=self.now;f.goal='rest';f.goalSince=self.now;f:beginStay(self.now)
  else
   f.state='CONSUMED'
  end
  return
 end
 f.state='SEEK_PERCH';f.stateSince=self.now;f.senses.awareness=f.profile.senses.awareness_max
 f.senses.hasLastSeen=true;f.senses.lastSeenPosition=self.previousPosition;f.senses.lastSeenTime=self.now
 f:launch('flee',self.now)
end
-- The strike: a sweep of the spider's body against every living fly while a strike window is open, and a capture into the jaws. Returns the time it took.
function D.strike(self: any,motor: any,sensor: any,cast: any)
 if motor.mode=='air' and self.previousMode~='air' then
  for _,event in motor.events do if event.kind=='launched' then self.strikeEnd=self.tick+240;break end end
 end
 if self.previousMode=='air' and motor.mode~='air' then self.strikeEnd=math.min(self.strikeEnd,self.tick+3) end
 self.previousMode=motor.mode
 if self.tick<=self.strikeEnd and not self.feeding.held then
  for _,f in self.flies do if f:alive() then
   local t,d=M.sweepClosest(self.previousPosition,motor.pos,f.prevPosition,f.position)
   if d<=f.profile.body.capture_radius_wu+.3 then
    local a=self.previousPosition:Lerp(motor.pos,t);local b=f.prevPosition:Lerp(f.position,t)
    if not cast(a,b) then
     f.flight:release();if f.perch and f.perch.occupant==f.id then f.perch.occupant='' end
     f.state='CAPTURED';f.captureSerial+=1;f.captureKey=f.id..':'..f.captureSerial;f.velocity=Vector3.zero
     sensor:onCapture(b,f.profile.body.radius_wu);self.feeding:capture(f);self.captures+=1;break
    end
   end
  end end
 end
end
-- Flies that have been eaten leave the list.
function D.tidy(self: any)
 for i=#self.flies,1,-1 do if self.flies[i].state=='CONSUMED' then table.remove(self.flies,i) end end
end
-- After the motor: the strike, the feeding (the reserves advance here, once a tick), the meal held in the jaws, and the tidying. `escape` (optional, PreyWorld's)
-- takes a fly that tore free; without it the fly is this director's own.
function D.after(self: any,dt: number,motor: any,sensor: any,cast: any,escape: ((any)->())?)
 if not self.enabled then return end
 local started=os.clock()
 self:strike(motor,sensor,cast)
 self.feeding:step(dt,motor.mode=='attached' and not motor.preparing,motor.moving or motor.vel.Magnitude>.15,escape or function(f) self:escape(f) end)
 local held=self.feeding.held
 if held then
  held.position=motor:eyePosition()+motor.heading*(if self.feeding.struggling then .42 else .2)+motor.up*(if self.feeding.struggling then .04 else -.13)
  held.normal=motor.up;held.heading=motor.heading;held.prevPosition=held.position
 end
 self:tidy()
 table.insert(self.cpu,(self.beforeCost or 0)+(os.clock()-started)*1e6);if #self.cpu>1200 then table.remove(self.cpu,1) end
end
-- After the motor, for a director whose jaws are another's (ROBLOX-96): the strike and the tidying only; the feeding step and the held fly are the home
-- director's, run once a tick.
function D.afterShared(self: any,motor: any,sensor: any,cast: any)
 if not self.enabled then return end
 local started=os.clock()
 self:strike(motor,sensor,cast)
 self:tidy()
 table.insert(self.cpu,(self.beforeCost or 0)+(os.clock()-started)*1e6);if #self.cpu>1200 then table.remove(self.cpu,1) end
end
-- The engine's geometry for a director: the casts against `world` and the clearance probe. Several directors may share one (PreyWorld: one set of closures, so a
-- checkpoint names them once).
function D.casts(world: Instance): any
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={world}
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Include;overlap.FilterDescendantsInstances={world}
 local probe=Instance.new('Part');probe.Name='FlyClearanceProbe';probe.Shape=Enum.PartType.Ball;probe.Anchored=true;probe.CanCollide=false;probe.CanQuery=false;probe.CanTouch=false;probe.Transparency=1;probe.Parent=workspace
 return {
  probe=probe,
  cast=function(a: Vector3,b: Vector3) return workspace:Raycast(a,b-a,params) end,
  sweep=function(a: Vector3,b: Vector3,r: number) if (b-a).Magnitude<1e-7 then return false end;return workspace:Spherecast(a,r,b-a,params)~=nil end,
  overlap=function(a: Vector3,r: number) probe.Size=Vector3.one*r*2;probe.Position=a;return #workspace:GetPartsInPart(probe,overlap)>0 end,
 }
end
function D.engine(world: Instance,profile: any,seed: number,target: number,mixed: boolean?,spec: Spec?,casts: any?): any
 local c=casts or D.casts(world)
 local graph=Graph.new(c.cast,c.sweep,c.overlap,profile)
 local self=D.new(graph,profile,seed,target,mixed,spec);self.probe=c.probe;return self
end
return D
