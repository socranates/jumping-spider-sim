--!strict
-- Walkable infill around the developed garden and its paths. Existing landmarks win
-- overlapping bounds. Do not fill the pond, drain pits, hut interior or water margins.
local Environment = require(script.Parent.Environment)
local Verge = {}
Verge.TOP = -84.6
Verge.CELL = 100
local RECTANGLES = {
 {-400,190,-1416,-16}, -- compact garden/bench/meadow shoulders
 {90,525,-966,-530}, -- short pond approach and dry bank under the western boardwalk
 -- The outer hut paths used to end at drawn-only grass. Keep a compact,
 -- planted shoulder on both sides and around the corners. These strips stop
 -- at the building's outer faces; none runs beneath either room's floor.
 {60,650,284,407}, -- south apron, 60 cm beyond the gravel's outer edge
 {473.5,650,-256,284}, -- east wall to the path and its outer shoulder
 {190,473.5,-256,-16}, -- north path back into the existing garden infill
}

local authored: {[number]: {any}} = {}
local pieceCache: {[string]: {any}} = {}
local footprints: {[string]: {any}} = {}
local decorCache: {[string]: {any}} = {}
local function largestFootprint(id: string): {number}?
 local largest: {number}?=nil
 local area=0
 for _,fragment in (footprints[id] or {}) :: {{number}} do
  local nextArea=(fragment[2]-fragment[1])*(fragment[4]-fragment[3])
  if nextArea>area then largest=fragment;area=nextArea end
 end
 return largest
end
-- Rectangle subtraction leaves intentional drain pits and existing authored ground untouched.
local function subtract(rect: {number}, hole: {number}): {{number}}
 local a,b,c,d=math.max(rect[1],hole[1]),math.min(rect[2],hole[2]),math.max(rect[3],hole[3]),math.min(rect[4],hole[4])
 if a>=b or c>=d then return {rect} end
 local out: {{number}}={}
 if rect[1]<a then table.insert(out,{rect[1],a,rect[3],rect[4]}) end
 if b<rect[2] then table.insert(out,{b,rect[2],rect[3],rect[4]}) end
 if rect[3]<c then table.insert(out,{a,b,rect[3],c}) end
 if d<rect[4] then table.insert(out,{a,b,d,rect[4]}) end
 return out
end
function Verge.author(seed: number, seedOf: (number,string)->number, existing: {any}?): {any}
 if authored[seed] then return authored[seed] end
 local occupied: {{number}}={}
 for _,r in (existing or {}) :: {any} do
  if (r.spawn.pos.Y>=Verge.TOP-3 and r.spawn.pos.Y<=Verge.TOP+3) or r.kind=="garden_bed" then
   local a,b=r.bounds[1],r.bounds[2]
   table.insert(occupied,{a.X,b.X,a.Z,b.Z})
  end
  if r.kind=="boardwalk" then
   -- Its authored bank strips already support the dry ground below the deck.
   -- Keep that footprint owned by the boardwalk, including its narrow seams.
   local a,b=r.bounds[1],r.bounds[2]
   table.insert(occupied,{a.X,b.X,a.Z,b.Z})
  end
 end
 local out: {any} = {}
 local seen: {[string]: boolean} = {}
 for _,b in RECTANGLES do
  for x=b[1],b[2]-1,Verge.CELL do
   for z=b[3],b[4]-1,Verge.CELL do
    local x1,z1=math.min(x+Verge.CELL,b[2]),math.min(z+Verge.CELL,b[4])
    local id=`verge_{x}_{z}`
    if not seen[id] then
     seen[id]=true
     local fragments: {{number}}={{x,x1,z,z1}}
     for _,hole in occupied do
      local nextList: {{number}}={}
      for _,fragment in fragments do for _,piece in subtract(fragment,hole) do table.insert(nextList,piece) end end
      fragments=nextList
      if #fragments==0 then break end
     end
     table.insert(occupied,{x,x1,z,z1})
     if #fragments==0 then continue end
     footprints[id]=fragments
     local largest=fragments[1]
     for _,f in fragments do if (f[2]-f[1])*(f[4]-f[3])>(largest[2]-largest[1])*(largest[4]-largest[3]) then largest=f end end
     local at=Vector3.new((largest[1]+largest[2])/2,Verge.TOP,(largest[3]+largest[4])/2)
     table.insert(out,{id=id,kind="verge",origin=at,seed=seedOf(seed,id),
      bounds={Vector3.new(x,Verge.TOP-3,z),Vector3.new(x1,Verge.TOP+35,z1)},
      neighbors={},retreats={},spawn={pos=at,heading=Vector3.new(0,0,-1)},clockScale=.33})
    end
   end
  end
 end
 authored[seed]=out
 return out
end

function Verge.pieces(r: any): {any}
 if pieceCache[r.id] then return pieceCache[r.id] end
 local out: {any}={}
 for i,b in (footprints[r.id] or {}) :: {any} do
  table.insert(out,{id=r.id.."_soil_"..i,lo=Vector3.new(b[1],Verge.TOP-2,b[3]),
   hi=Vector3.new(b[2],Verge.TOP,b[4]),profile="bare_wood_rough",color=Color3.fromHex("71804e"),material="Ground"})
 end
 -- Two small litter shelters in the largest real soil fragment. Keep the
 -- spawn corridor clear and never bridge an excluded drain, bed or water gap.
 local largest=largestFootprint(r.id)
 if largest then
  local b=largest :: {number}
  local width,depth=b[2]-b[1],b[4]-b[3]
  if width>=7 and depth>=16 then
   for i,fraction in {.25,.75} do
    local h=(r.seed+i*104729)%2147483647
    local leafWidth=math.min(12,width-2)*(.78+.22*(h%997)/997)
    local leafDepth=math.min(6,depth/4)*(.85+.15*((h*17)%991)/991)
    local height=1.05+.35*((h*31)%983)/983
    local palette=if r.seed%3==0 then {"94714a","a78451","856346","b18b59"} else {"6b864d","7d9259","677e42","8a975e"}
    local color=palette[1+h%4]
    local x,z=(b[1]+b[2])/2,b[3]+depth*fraction
    local function box(name: string,a: Vector3,c: Vector3,color: string)
     table.insert(out,{id=r.id..`_litter_{i}_`..name,lo=a,hi=c,profile="bare_wood_rough",color=Color3.fromHex(color),material="Wood"})
    end
    local y=Verge.TOP
    for _,side in {-1,1} do
     local edge=x+side*(leafWidth/2-.18)
     box("curl_"..side,Vector3.new(edge-.12,y,z-leafDepth/2),Vector3.new(edge+.12,y+height,z+leafDepth/2),color)
    end
    box("leaf",Vector3.new(x-leafWidth/2,y+height,z-leafDepth/2),Vector3.new(x+leafWidth/2,y+height+.18,z+leafDepth/2),color)
    if width>=18 and depth>=30 then
     local tx=x+leafWidth/2+1.6
     box("stem",Vector3.new(tx-.4,y,z-6),Vector3.new(tx+.4,y+.8,z+6),"756047")
    end
   end
  end
 end
 pieceCache[r.id]=table.freeze(out) :: any
 return pieceCache[r.id]
end

function Verge.decor(r: any): {any}
 local key=r.id.."/"..tostring(r.seed)
 if decorCache[key] then return decorCache[key] end
 local out: {any}={}
 -- Small trifoliate plants, raised on a petiole. Smooth material avoids the
 -- terrain-grass texture stretching across these thin individual leaflets.
 local soil: {{number}}={}
 for _,fragment in (footprints[r.id] or {}) :: {{number}} do
  if fragment[2]-fragment[1]>=8.2 and fragment[4]-fragment[3]>=7 then table.insert(soil,fragment) end
 end
 for i=1,8 do
  if #soil==0 then break end
  local h=(r.seed+i*7919)%2147483647
  local fragment=soil[1+(i-1)%#soil]
  local x=fragment[1]+4.1+(h%997)/997*math.max(0,fragment[2]-fragment[1]-8.2)
  local z=fragment[3]+3.5+((h*17)%991)/991*math.max(0,fragment[4]-fragment[3]-7)
  local height=.28+.24*(h%991)/991
  table.insert(out,{id=r.id..`_clover_{i}_stem`,size=Vector3.new(.035,height,.035),
   at=Vector3.new(x,Verge.TOP+height/2,z),shape="Ellipsoid",color=Color3.fromHex("6c8749"),material="SmoothPlastic",full=i>4})
  for l=1,3 do
   local angle=l*math.pi*2/3+(h%97)*.03
   table.insert(out,{id=r.id..`_clover_{i}_{l}`,size=Vector3.new(1.25,.055,.95),
    at=Vector3.new(x+math.cos(angle)*.45,Verge.TOP+height,z+math.sin(angle)*.45),turn=Vector3.new(math.deg(.06),math.deg(-angle),math.deg(.08)),
    shape="Ellipsoid",color=Color3.fromHex(if i%3==0 then "658645" else "48713d"),material="SmoothPlastic",full=i>4})
  end
 end
 -- A background layer persists beyond the small close-detail neighbourhood.
 -- Twenty curved clumps replace some clover parts within the same look cap.
 for i=1,20 do
  if #soil==0 then break end
  local h=(r.seed+i*2971)%2147483647
  local fragment=soil[1+(i-1)%#soil]
  -- A stratified 5 by 4 scatter avoids correlated hash remainders lining up
  -- the whole meadow in one narrow strip. The first four also span both axes.
  local u=(((i-1)*2)%5+.15+.7*Environment.hash(r.seed,i,197))/5
  local v=(((i-1)*3)%4+.15+.7*Environment.hash(r.seed,i,199))/4
  local x=fragment[1]+4.1+u*math.max(0,fragment[2]-fragment[1]-8.2)
  local z=fragment[3]+3.5+v*math.max(0,fragment[4]-fragment[3]-7)
  local height=6+4*((h*31)%977)/977
  table.insert(out,{id=r.id..`_grass_clump_{i}`,size=Vector3.new(height*.38,height,height*.45),
   at=Vector3.new(x,Verge.TOP+height/2,z),turn=Vector3.new(0,h%360,0),
   shape="Mesh:grass_clump",color=Color3.new(1,1,1),material="SmoothPlastic",full=i>4})
 end
 for _,piece in Verge.pieces(r) do
  if string.find(piece.id,"_litter_",1,true) then
   local size,at=piece.hi-piece.lo,(piece.lo+piece.hi)/2
   local roof=string.sub(piece.id,-5)=="_leaf"
   table.insert(out,{id=piece.id.."_look",size=size,at=at,color=piece.color,
    material=if string.sub(piece.id,-5)=="_stem" then "Wood" else "SmoothPlastic",
    -- Reuse the preserve's approved leaf/bark meshes and their actual veins,
    -- rather than making a leaf look like a little table of primitive slabs.
    shape=if roof then (if r.seed%3==0 then "Mesh:bark_chip" else "Mesh:milkweed_leaf") else "Ellipsoid",full=false})
  end
 end
 decorCache[key]=out
 return out
end

function Verge.drawnPieces(r: any): {string}
 local out: {string}={}
 for _,piece in Verge.pieces(r) do
  if string.find(piece.id,"_litter_",1,true) then table.insert(out,piece.id) end
 end
 return out
end

local bestiaryCache: {[string]: {any}} = {}
function Verge.bestiary(r: any): {any}
 local key=r.id.."/"..tostring(r.seed)
 if bestiaryCache[key] then return bestiaryCache[key] end
 local grid: {any}={}
 local a,b=r.bounds[1],r.bounds[2]
 if r.kind=="verge" then
  local largest=largestFootprint(r.id)
  if largest==nil or largest[2]-largest[1]<3 or largest[4]-largest[3]<3 then bestiaryCache[key]={};return bestiaryCache[key] end
  a,b=Vector3.new(largest[1],Verge.TOP,largest[3]),Vector3.new(largest[2],Verge.TOP,largest[4])
 end
 for i=1,12 do
  local col,row=(i-1)%4,math.floor((i-1)/4)
  table.insert(grid,{id=r.id..`_springtail_perch_{i}`,
   position=Vector3.new(a.X+(col+.5)*(b.X-a.X)/4,r.spawn.pos.Y,a.Z+(row+.5)*(b.Z-a.Z)/3),
   normal=Vector3.yAxis,shelter=.6,food=.4,start=false,kind="soil",hop=true})
 end
 -- Prioritise one start in every row even at low detail, then fill a second
 -- group per row. Existing perch IDs/positions stay stable for saved creatures.
 local perches: {any}={}
 for order,index in {2,7,10,4,9,5,1,3,6,8,11,12} do
  local p=table.clone(grid[index]);p.start=order<=6;table.insert(perches,p)
 end
 local floor=r.spawn.pos.Y
 local flies: {any}={}
 for order,index in {8,1,12,6,2,3,4,5,7,9,10,11} do
  local fly=table.clone(grid[index])
  fly.id=r.id..`_housefly_perch_{index}`;fly.hop=false;fly.start=order<=4
  table.insert(flies,fly)
 end
 local out={{kind="springtail",profile="springtail_prototype",perches=perches,
  vents={{id=r.id.."_litter",position=perches[12].position,normal=Vector3.yAxis,appear=true,reach=8}},
  target=6,low=3,seed=r.seed,prefix=r.id.."_springtail_",floor=floor-2,ceiling=floor+11},
  {kind="housefly",profile="fly_like_prototype",perches=flies,
   vents={{id=r.id.."_fly_arrival",position=flies[12].position+Vector3.new(0,5,0),normal=Vector3.yAxis,appear=true,reach=30}},
   target=4,low=3,seed=(r.seed+104729)%2147483647,prefix=r.id.."_housefly_",floor=floor-2,ceiling=floor+11}}
 bestiaryCache[key]=out
 return out
end
return table.freeze(Verge)
