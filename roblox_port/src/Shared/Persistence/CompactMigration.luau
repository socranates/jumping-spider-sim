--!strict
-- preserve-2 -> preserve-3: relocate habitats, not spider scale or progress.
-- Operates only on decoded fresh objects. Live roots, shared feeding ledgers and
-- named immutable profile references are never traversed or changed.
local Map=require(script.Parent.Parent.World.WorldMap)
local Migration={}
local MEADOW=Vector3.new(0,0,300)
local POND=Vector3.new(-1300,0,1625)
function Migration.applies(map: any): boolean
 return Map.world()=="preserve" and Map.revision()=="preserve-3" and map.world=="preserve"
  and map.revision=="preserve-2" and map.seed==Map.SEED
end
function Migration.offset(id: string): Vector3?
 if string.match(id,"^pad_") or string.match(id,"^meadow_") or string.match(id,"^bench_[we]$") or id=="bin" or string.match(id,"^lamp_[1-4]$") then return MEADOW end
 if string.match(id,"^pond_") or string.match(id,"^deck_") or string.match(id,"^walk_") or string.match(id,"^cattail_") then return POND end
 if not Migration.routeCache(id) and Map.region(id) then return Vector3.zero end
 return nil
end
local function route(id: string): (string?,number?)
 local kind,n=string.match(id,"^mown_([en])(%d+)$")
 if not n then return nil,nil end
 local index=tonumber(n) :: number
 if index<1 or index>(if kind=="e" then 15 else 14) then return nil,nil end
 return kind,index
end
function Migration.alias(id: string): string
 local kind,n=route(id)
 if kind=="e" then return if (n :: number)<=7 then "mown_e1" else "mown_e2" end
 if kind=="n" then return "mown_n1" end
 if string.match(id,"^verge_%-?%d+_%-?%d+$") then return Map.HOME end
 return id
end
function Migration.routeCache(id: string): boolean
 local kind=route(id)
 return kind~=nil or string.match(id,"^verge_%-?%d+_%-?%d+$")~=nil or string.match(id,"^path_m[1-4]$")~=nil
end
function Migration.legacyRegion(id: string): any
 local current=Map.region(id)
 local offset=Migration.offset(id)
 if current and offset then
  local old=table.clone(current);old.bounds={current.bounds[1]-offset,current.bounds[2]-offset}
  old.spawn={pos=current.spawn.pos-offset,heading=current.spawn.heading}
  return old
 end
 local kind,n=route(id)
 if kind then
  local x0,x1,z0,z1
  if kind=="e" then
   x0=90+((n :: number)-1)*100;x1=x0+100;z0=-1030;z1=-930
  else
   x0=1490;x1=1590;z1=-1030-((n :: number)-1)*100;z0=if n==14 then -2441 else z1-100
  end
  return {id=id,kind="mown_path",seed=Map.seed(Map.SEED,id),bounds={Vector3.new(x0,-88,z0),Vector3.new(x1,-44.6,z1)},
   spawn={pos=Vector3.new((x0+x1)/2,-84.6,(z0+z1)/2)},origin=Vector3.new(x0,-84.6,z0),neighbors={},retreats={}}
 end
 local x,z=string.match(id,"^verge_(%-?%d+)_(%-?%d+)$")
 if x and z then
  local a,b=tonumber(x) :: number,tonumber(z) :: number
  if a>=-400 and a<=1590 and b>=-2441 and b<=-16 then
   return {id=id,kind="verge",seed=Map.seed(Map.SEED,id),bounds={Vector3.new(a,-87.6,b),Vector3.new(a+100,-49.6,b+100)},
    spawn={pos=Vector3.new(a+50,-84.6,b+50)},neighbors={},retreats={}}
  end
 end
 return current
end
local function point(value: Vector3,offset: Vector3): boolean
 -- All translated habitats were far north of the origin. Unit normals, local
 -- offsets, velocities, dimensions and direction vectors do not pass this gate.
 return value.Z < -700 and (offset.X==0 or value.X>1000)
end
function Migration.shift(decoded: any,target: any,offset: Vector3)
 local fresh,blocked,seen={},{},{}
 for _,object in decoded.objects do fresh[object]=true end
 for _,root in decoded.roots do blocked[root]=true end
 if decoded.roots.prey.feeding then blocked[decoded.roots.prey.feeding]=true end
 local function visit(object: any)
  if type(object)~="table" or not fresh[object] or blocked[object] or seen[object] then return end
  seen[object]=true
  for key,value in object do
   if typeof(value)=="Vector3" or (type(value)=="table" and type(value.X)=="number" and type(value.Y)=="number" and type(value.Z)=="number" and type(value.Dot)=="function") then
    if point(value,offset) then object[key]=value+offset end
   elseif type(value)=="table" then visit(value) end
  end
 end
 visit(target)
end
function Migration.prepareRival(decoded: any)
 local rival=decoded.roots.life and decoded.roots.life.rival
 if type(rival)=="table" and type(rival.region)=="string" then
  local offset=Migration.offset(rival.region)
  if offset then Migration.shift(decoded,rival,offset) end
 end
end
function Migration.apply(decoded: any)
 for id,entry in decoded.roots.garden or {} do
  local offset=Migration.offset(id)
  if offset then Migration.shift(decoded,entry,offset)
  elseif Migration.routeCache(id) then decoded.roots.garden[id]=nil end
 end
 -- Cast skins are world points too; preserve their relation to the moved leaf
 -- or bench without touching life clocks, energy, meals or generation history.
 local growth=decoded.roots.life.growth
 for i,p in growth.exuviae do
  if p.X>=-310 and p.X<=190 and p.Z<=-816 and p.Z>=-1616 then growth.exuviae[i]=p+MEADOW
  elseif p.X>=1490 and p.X<=2225 and p.Z<=-2441 and p.Z>=-2841 then growth.exuviae[i]=p+POND end
 end
end
return table.freeze(Migration)
