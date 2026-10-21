--!strict
-- Bounded air navigation over the station's actual collision boxes. Grid edges
-- are swept spheres, including the shared doorway; no straight flight through
-- a wall to get to a patrol point. Built once, routes use no player information.
local Map=require(script.Parent.WorldMap)
local Region=require(script.Parent.Region)
local Station=require(script.Parent.StationTerritory)
local Hut=require(script.Parent.Hut)
local Air={}
local RADIUS=.55
local boxes: {any}={}
local loaded=false
local built,preparing=false,false
local nodes: {[number]:Vector3}={}
local links: {[number]:{number}}={}
local Y={-66.5,-42.5,-18.5,5.5,29.5,53.5,77.5,101.5,125.5,146.5}
local NX,NZ=25,10
local function key(x: number,z: number,y: number): number return 1+x+NX*(z+NZ*y) end
local function inside(p: Vector3): boolean
 local room=Hut.ROOM;local back=Hut.BACK;local door=Hut.DOORWAY
 if p.Y<Hut.FLOOR+RADIUS or p.Y>Hut.CEIL-RADIUS then return false end
 if p.Z<room.z0+RADIUS or p.Z>room.z1-RADIUS then return false end
 return (p.X>room.x0+RADIUS and p.X<room.x1-RADIUS)
  or (p.X>back.x0+RADIUS and p.X<back.x1-RADIUS)
  or (p.X>=room.x1-RADIUS and p.X<=back.x0+RADIUS and p.Z>door.z0+RADIUS and p.Z<door.z1-RADIUS and p.Y<door.head-RADIUS)
end
local function loadBoxes()
 if loaded then return end
 loaded=true
 for id in Station.roam() do
  local region=Map.region(id)
  if region then for _,p in Region.pieces(region) do table.insert(boxes,p) end end
 end
end
function Air.clear(a: Vector3,b: Vector3): boolean
 loadBoxes()
 local delta=b-a
 for _,box in boxes do
  local low,high=0,1
  for _,axis in {"X","Y","Z"} do
   local d=if axis=="X" then delta.X elseif axis=="Y" then delta.Y else delta.Z
   local origin=if axis=="X" then a.X elseif axis=="Y" then a.Y else a.Z
   local lo=box.lo[axis]-RADIUS;local hi=box.hi[axis]+RADIUS
   if math.abs(d)<1e-8 then
    if origin<=lo or origin>=hi then low=2;break end
   else
    local t0,t1=(lo-origin)/d,(hi-origin)/d
    if t0>t1 then t0,t1=t1,t0 end
    low=math.max(low,t0);high=math.min(high,t1)
    if low>high then break end
   end
  end
  if low<=high then return false end
 end
 return true
end
local function build(yieldWork: (() -> ())?): boolean
 if built then return true end
 if preparing then return false end
 preparing=true
 local work=0
 local function pause()
  work+=1
  if yieldWork and work%8==0 then yieldWork() end
 end
 for y,height in Y do for z=0,NZ-1 do for x=0,NX-1 do
  local p=Vector3.new(-134.5+24*x,height,24.5+24*z)
  if inside(p) and Air.clear(p,p) then nodes[key(x,z,y-1)]=p end
  pause()
 end end end
 for y=0,#Y-1 do for z=0,NZ-1 do for x=0,NX-1 do
  local id=key(x,z,y);local p=nodes[id]
  if p then
   local list={}
   for _,offset in {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}} do
    local a,b,c=x+offset[1],z+offset[2],y+offset[3]
    if a>=0 and a<NX and b>=0 and b<NZ and c>=0 and c<#Y then
     local to=key(a,b,c)
     if nodes[to] and Air.clear(p,nodes[to]) then table.insert(list,to) end
    end
   end
   links[id]=list
  end
  pause()
 end end end
 built=true;preparing=false
 return true
end
function Air.prepare(yieldWork: () -> ()) build(yieldWork) end
local function nearest(p: Vector3): number?
 local sorted={}
 for id,node in nodes do table.insert(sorted,{id=id,d=(node-p).Magnitude}) end
 table.sort(sorted,function(a,b) return a.d<b.d end)
 for i=1,math.min(24,#sorted) do
  local id=sorted[i].id
  if Air.clear(p,nodes[id]) then return id end
 end
 return nil
end
function Air.route(a: Vector3,b: Vector3): {Vector3}
 if Air.clear(a,b) then return {a,b} end
 if not build() then return {a} end -- An incremental warm-up never exposes a partial graph.
 local first,last=nearest(a),nearest(b)
 if not first or not last then return {a} end
 local heap: {any}={}
 local function push(id: number,cost: number)
  local i=#heap+1;heap[i]={id=id,cost=cost}
  while i>1 do local parent=i//2;if heap[parent].cost<=cost then break end;heap[i],heap[parent]=heap[parent],heap[i];i=parent end
 end
 local function pop(): any
  local item=heap[1];local tail=table.remove(heap)
  if #heap>0 then
   heap[1]=tail;local i=1
   while i*2<=#heap do
    local child=i*2;if child<#heap and heap[child+1].cost<heap[child].cost then child+=1 end
    if heap[i].cost<=heap[child].cost then break end
    heap[i],heap[child]=heap[child],heap[i];i=child
   end
  end
  return item
 end
 local cost: {[number]:number}={[first]=0}
 local previous: {[number]:number}={};local closed: {[number]:boolean}={}
 push(first,(nodes[first]-nodes[last]).Magnitude)
 while #heap>0 do
  local id=pop().id
  if closed[id] then continue end
  if id==last then
   local reversed={b,nodes[last]};local at=last
   while at~=first do at=previous[at];table.insert(reversed,nodes[at]) end
   table.insert(reversed,a)
   local path={}
   for i=#reversed,1,-1 do table.insert(path,reversed[i]) end
   -- Remove needless grid bends only when the whole body fits the shortcut.
   local result={a};local i=1
   while i<#path do
    local nextIndex=i+1
    for j=#path,i+1,-1 do if Air.clear(path[i],path[j]) then nextIndex=j;break end end
    table.insert(result,path[nextIndex]);i=nextIndex
   end
   return result
  end
  closed[id]=true
  for _,to in links[id] do
   local distance=cost[id]+(nodes[to]-nodes[id]).Magnitude
   if cost[to]==nil or distance<cost[to] then
    cost[to]=distance;previous[to]=id;push(to,distance+(nodes[to]-nodes[last]).Magnitude)
   end
  end
 end
 return {a}
end
Air.entry=Vector3.new(22,8,6)
-- A circuit, not a nearest-neighbour trap: sill, both rooms, floor, furniture,
-- upper walls and back through the actual doorway at a permitted height.
Air.points={
 {id="station_sill",hover=Air.entry},
 {id="station_desk",hover=Vector3.new(80,8,45)},
 {id="station_desk_foot",hover=Vector3.new(60,-66.5,85)},
 {id="station_chair",hover=Vector3.new(86,-19,108)},
 {id="station_hut_floor",hover=Vector3.new(0,-66.5,150)},
 {id="station_shelf",hover=Vector3.new(-110,16,160)},
 {id="station_exit",hover=Vector3.new(0,-60,240)},
 {id="station_doorway",hover=Vector3.new(160,-20,215)},
 {id="station_sofa",hover=Vector3.new(310,-20,185)},
 {id="station_back_floor",hover=Vector3.new(410,-66.5,150)},
 {id="station_games",hover=Vector3.new(400,40,70)},
 {id="station_tv",hover=Vector3.new(230,20,70)},
 {id="station_back_ceiling",hover=Vector3.new(330,146.5,134)},
 {id="station_doorway_high",hover=Vector3.new(160,115,215)},
 {id="station_hut_ceiling",hover=Vector3.new(0,146.5,134)},
 {id="station_board",hover=Vector3.new(-80,10,30)},
}
return table.freeze(Air)
