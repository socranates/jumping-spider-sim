--!strict
-- Walkable infill around the developed garden and its paths. Existing landmarks win
-- overlapping bounds. Do not fill the pond, drain pits, hut interior or water margins.
local Verge = {}
Verge.TOP = -84.6
Verge.CELL = 100
local RECTANGLES = {
 {-400,600,-1716,-16}, -- hut garden, bench and meadow surround
 {90,1690,-1130,-830}, -- east path shoulders
 {1390,1690,-2441,-1030}, -- north path shoulders; stops before the pond
}

local authored: {[number]: {any}} = {}
local pieceCache: {[string]: {any}} = {}
local footprints: {[string]: {any}} = {}
local decorCache: {[string]: {any}} = {}
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
 pieceCache[r.id]=table.freeze(out) :: any
 return pieceCache[r.id]
end

function Verge.decor(r: any): {any}
 local key=r.id.."/"..tostring(r.seed)
 if decorCache[key] then return decorCache[key] end
 local out: {any}={}
 -- Small overlapping clover islands: wide silhouettes remain readable between
 -- landmarks, individual leaves replace part-heavy carpets of upright grass.
 for i=1,12 do
  local h=(r.seed+i*7919)%2147483647
  local a,b=r.bounds[1],r.bounds[2]
  local x=a.X+5+(h%997)/997*math.max(0,b.X-a.X-10)
  local z=a.Z+5+((h*17)%991)/991*math.max(0,b.Z-a.Z-10)
  for l=1,3 do
   local angle=l*math.pi*2/3
   table.insert(out,{id=r.id..`_clover_{i}_{l}`,size=Vector3.new(4.5,.16,3.2),
    at=Vector3.new(x+math.cos(angle)*1.8,Verge.TOP+.12,z+math.sin(angle)*1.8),
    shape="Ellipsoid",color=Color3.fromHex(if i%3==0 then "718b44" else "54713e"),material="Grass",full=i>4})
  end
 end
 decorCache[key]=out
 return out
end

local bestiaryCache: {[string]: {any}} = {}
function Verge.bestiary(r: any): {any}
 local key=r.id.."/"..tostring(r.seed)
 if bestiaryCache[key] then return bestiaryCache[key] end
 local perches: {any}={}
 local a,b=r.bounds[1],r.bounds[2]
 if r.kind=="verge" then
  local largest: any=nil
  for _,f in (footprints[r.id] or {}) :: {any} do
   if largest==nil or (f[2]-f[1])*(f[4]-f[3])>(largest[2]-largest[1])*(largest[4]-largest[3]) then largest=f end
  end
  if largest==nil or largest[2]-largest[1]<3 or largest[4]-largest[3]<3 then bestiaryCache[key]={};return bestiaryCache[key] end
  a,b=Vector3.new(largest[1],Verge.TOP,largest[3]),Vector3.new(largest[2],Verge.TOP,largest[4])
 end
 for i=1,12 do
  local col,row=(i-1)%4,math.floor((i-1)/4)
  table.insert(perches,{id=r.id..`_springtail_perch_{i}`,
   position=Vector3.new(a.X+(col+.5)*(b.X-a.X)/4,r.spawn.pos.Y,a.Z+(row+.5)*(b.Z-a.Z)/3),
   normal=Vector3.yAxis,shelter=.6,food=.4,start=i<=3,kind="soil",hop=true})
 end
 local floor=r.spawn.pos.Y
 local flies: {any}={}
 for i,p in perches do
  local fly=table.clone(p)
  fly.id=r.id..`_housefly_perch_{i}`;fly.hop=false;fly.start=i<=2
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
