--!strict
-- A one-metre habitat directly below the window. Juvenile plants retain adult
-- leaf widths, with shorter internodes: small ground footprint, several climbable layers.
local Hut = require(script.Parent.Hut)
local Pocket = {}
Pocket.REGION = "garden_a3"
Pocket.PLANTS = table.freeze({
 table.freeze({kind="milkweed",x=27,z=-80,scale=.52}),
 table.freeze({kind="coneflower",x=57,z=-52,scale=.70}),
 table.freeze({kind="beebalm",x=81,z=-79,scale=.60}),
})
Pocket.CLOVER = table.freeze({Vector3.new(45,Hut.GROUND,-82),Vector3.new(54,Hut.GROUND,-74)})
local pieces: {any}?=nil
local decor: {any}?=nil
function Pocket.pieces(): {any}
 if pieces then return pieces end
 local out: {any}={}
 for i,plant in Pocket.PLANTS do Hut.plantPieces(out,Pocket.REGION,plant,Hut.GROUND,"p"..i) end
 -- Old stems under the plants: low stepping routes and cover at a spider's own scale.
 local function box(id: string,a: Vector3,b: Vector3)
  table.insert(out,{id=Pocket.REGION.."_"..id,lo=a,hi=b,profile="bare_wood_rough",color=Color3.fromHex("756346"),material="Wood"})
 end
 local y=Hut.GROUND
 box("fallen_stem_a",Vector3.new(29,y,-73),Vector3.new(45,y+.7,-72.2))
 box("fallen_stem_b",Vector3.new(46,y,-70),Vector3.new(46.9,y+.8,-57))
 box("curled_leaf_foot_a",Vector3.new(37,y,-94),Vector3.new(38,y+1.2,-91))
 box("curled_leaf_foot_b",Vector3.new(48,y,-94),Vector3.new(49,y+1.2,-91))
 box("curled_leaf_roof",Vector3.new(36,y+1.2,-95),Vector3.new(50,y+1.45,-90))
 for i,at in Pocket.CLOVER do
  box(`clover_{i}_stem`,at+Vector3.new(-.08,0,-.08),at+Vector3.new(.08,3,.08))
  box(`clover_{i}_head`,at+Vector3.new(-.4,3,-.4),at+Vector3.new(.4,3.6,.4))
 end
 local result=table.freeze(out) :: {any}
 pieces=result
 return result
end
function Pocket.decor(): {any}
 if decor then return decor end
 local out: {any}={};local byId: {[string]:any}={}
 for _,p in Pocket.pieces() do byId[p.id]=p end
 local function add(d: any): boolean
  if string.sub(d.id,1,4)=="Leaf" then d.full=false end
  d.id="Pocket_"..d.id
  table.insert(out,d);return true
 end
 local seed=914
 local function rand(): number seed=(seed*16807)%2147483647;return seed/2147483647 end
 for i,plant in Pocket.PLANTS do Hut.drawPlant(byId,Pocket.REGION,plant,"p"..i,add,rand,Hut.GROUND) end
 for _,p in Pocket.pieces() do
  if string.find(p.id,"fallen_stem",1,true) or string.find(p.id,"curled_leaf",1,true) then
   add({id=p.id,size=p.hi-p.lo,at=(p.lo+p.hi)/2,color=p.color,material="Wood",shape="Ellipsoid",full=false})
  end
 end
 for i,at in Pocket.CLOVER do
  add({id=`CloverHead{i}`,size=Vector3.new(.95,.75,.95),at=at+Vector3.new(0,3.35,0),
   color=Color3.fromHex("e5dfca"),material="SmoothPlastic",shape="Ellipsoid",full=false})
  for leaf=1,3 do
   local angle=leaf*math.pi*2/3
   add({id=`CloverLeaf{i}_{leaf}`,size=Vector3.new(.95,.09,.7),at=at+Vector3.new(math.cos(angle)*.5,.5,math.sin(angle)*.5),
    color=Color3.fromHex("6c8948"),material="SmoothPlastic",shape="Ellipsoid",full=false})
  end
 end
 local result=table.freeze(out) :: {any}
 decor=result
 return result
end
function Pocket.drawnPieces(): {string}
 local out: {string}={}
 -- Keep stems visible: drawPlant draws leaf blades and flower heads, not their support stems.
 for _,p in Pocket.pieces() do
  if string.find(p.id,"_leaf_",1,true) or string.sub(p.id,-5)=="_head" or string.sub(p.id,-5)=="_cone" then table.insert(out,p.id) end
 end
 return out
end
local bestiary: {any}?=nil
function Pocket.bestiary(): {any}
 if bestiary then return bestiary end
 local perches: {any}={}
 for i,at in Pocket.CLOVER do
  table.insert(perches,{id=`pocket_clover_{i}_hoverfly`,position=at+Vector3.new(0,3.6,0),
   normal=Vector3.yAxis,shelter=.4,food=.9,start=true,kind="leaf"})
 end
 for _,p in Pocket.pieces() do
  if string.find(p.id,"_leaf_",1,true) then
   table.insert(perches,{id=p.id.."_hoverfly",position=Vector3.new((p.lo.X+p.hi.X)/2,p.hi.Y,(p.lo.Z+p.hi.Z)/2),
    normal=Vector3.yAxis,shelter=.4,food=.7,start=#perches<3,kind="leaf"})
  end
 end
 local result: {any}={{kind="hoverfly",profile="hoverfly_prototype",perches=perches,
  vents={{id="pocket_flower_arrival",position=Vector3.new(82,Hut.GROUND+20,-100),normal=Vector3.yAxis,appear=true,reach=45}},
  target=3,low=2,seed=37519,prefix="pocket_hoverfly_",floor=Hut.GROUND-2,ceiling=Hut.GROUND+65}}
 bestiary=result
 return result
end
return table.freeze(Pocket)
