--!strict
-- Walkable infill around the developed garden and its paths. Existing landmarks win
-- overlapping bounds. Do not fill the pond, drain pits, hut interior or water margins.
local Verge = {}
Verge.TOP = -84.6
Verge.CELL = 100
local RECTANGLES = {
 {-400,190,-1416,-16}, -- compact garden/bench/meadow shoulders
 {90,525,-966,-530}, -- short pond approach and dry bank under the western boardwalk
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
 -- Small overlapping clover islands: wide silhouettes remain readable between
 -- landmarks, individual leaves replace part-heavy carpets of upright grass.
 local soil: {{number}}={}
 for _,fragment in (footprints[r.id] or {}) :: {{number}} do
  if fragment[2]-fragment[1]>=8.2 and fragment[4]-fragment[3]>=7 then table.insert(soil,fragment) end
 end
 for i=1,12 do
  if #soil==0 then break end
  local h=(r.seed+i*7919)%2147483647
  local fragment=soil[1+(i-1)%#soil]
  local x=fragment[1]+4.1+(h%997)/997*math.max(0,fragment[2]-fragment[1]-8.2)
  local z=fragment[3]+3.5+((h*17)%991)/991*math.max(0,fragment[4]-fragment[3]-7)
  for l=1,3 do
   local angle=l*math.pi*2/3
   table.insert(out,{id=r.id..`_clover_{i}_{l}`,size=Vector3.new(4.5,.16,3.2),
    at=Vector3.new(x+math.cos(angle)*1.8,Verge.TOP+.12,z+math.sin(angle)*1.8),
    shape="Ellipsoid",color=Color3.fromHex(if i%3==0 then "718b44" else "54713e"),material="Grass",full=i>4})
  end
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
 local perches: {any}={}
 local a,b=r.bounds[1],r.bounds[2]
 if r.kind=="verge" then
  local largest=largestFootprint(r.id)
  if largest==nil or largest[2]-largest[1]<3 or largest[4]-largest[3]<3 then bestiaryCache[key]={};return bestiaryCache[key] end
  a,b=Vector3.new(largest[1],Verge.TOP,largest[3]),Vector3.new(largest[2],Verge.TOP,largest[4])
 end
 for i=1,12 do
  local col,row=(i-1)%4,math.floor((i-1)/4)
  table.insert(perches,{id=r.id..`_springtail_perch_{i}`,
   position=Vector3.new(a.X+(col+.5)*(b.X-a.X)/4,r.spawn.pos.Y,a.Z+(row+.5)*(b.Z-a.Z)/3),
   -- Occupy all three rows at startup. Clustering every animal in the first
   -- row left the far end of a narrow shoulder apparently lifeless.
   normal=Vector3.yAxis,shelter=.6,food=.4,start=i==2 or i==7 or i==10,kind="soil",hop=true})
 end
 local floor=r.spawn.pos.Y
 local flies: {any}={}
 for i,p in perches do
  local fly=table.clone(p)
  fly.id=r.id..`_housefly_perch_{i}`;fly.hop=false;fly.start=i==4 or i==9
  table.insert(flies,fly)
 end
 local out={{kind="springtail",profile="springtail_prototype",perches=perches,
  vents={{id=r.id.."_litter",position=perches[12].position,normal=Vector3.yAxis,appear=true,reach=8}},
  target=3,low=2,seed=r.seed,prefix=r.id.."_springtail_",floor=floor-2,ceiling=floor+11},
  {kind="housefly",profile="fly_like_prototype",perches=flies,
   vents={{id=r.id.."_fly_arrival",position=flies[12].position+Vector3.new(0,5,0),normal=Vector3.yAxis,appear=true,reach=30}},
   target=2,low=1,seed=(r.seed+104729)%2147483647,prefix=r.id.."_housefly_",floor=floor-2,ceiling=floor+11}}
 bestiaryCache[key]=out
 return out
end
return table.freeze(Verge)
