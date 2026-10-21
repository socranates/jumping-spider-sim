--!strict
-- Additive, stable landmarks. Existing pieces/retreats never move. One stud is one centimetre.
-- An empty unbranded can is a hollow climbable shell, not a solid invisible cylinder.
local Pocket=require(script.Parent.GardenPocket)
local AntForage=require(script.Parent.AntForage)
local Sites = {}
Sites.CANS = table.freeze({
 hut_floor_i = table.freeze({id="ranger_can",at=Vector3.new(124,-70,226),color="647b6d"}),
 room_floor_b = table.freeze({id="volunteer_can",at=Vector3.new(333,-70,36),color="a45c47"}),
}) :: {[string]: any}
Sites.ANTHILLS=table.freeze({garden_b1=table.freeze({id="garden_ant_nest",at=Vector3.new(-182,-84.6,-205)})}) :: {[string]: any}
-- Low overlapping soil caps avoid the old separated pancake silhouette.
local caps={{10,.5,-.05},{7,.65,.075},{4,.7,.25}}
function Sites.antHeight(offset: Vector3): number
 local height=0
 for _,cap in caps do
  local radius=cap[1]/2;local q=(offset.X^2+offset.Z^2)/(radius*radius)
  if q<=1 then height=math.max(height,cap[3]+cap[2]*.5*math.sqrt(1-q)) end
 end
 return height
end
function Sites.nearAnthill(pos: Vector3): any
 for _,hill in Sites.ANTHILLS do
  if math.abs(pos.Y-hill.at.Y)<12 and (Vector3.new(pos.X,hill.at.Y,pos.Z)-hill.at).Magnitude<40 then return hill end
 end
 return nil
end
function Sites.pieces(region: any): {any}
 if region.id==Pocket.REGION then return Pocket.pieces() end
 local hill=Sites.ANTHILLS[region.id]
 if hill then
  local out: {any}={}
  for i,layer in {{10,.2},{4.8,.2},{2.6,.2}} do
   local y=(i-1)*.2
   table.insert(out,{id=hill.id.."_tier"..i,lo=hill.at+Vector3.new(-layer[1]/2,y,-layer[1]/2),
    hi=hill.at+Vector3.new(layer[1]/2,y+layer[2],layer[1]/2),profile="bare_wood_rough",color=Color3.fromHex("77604a"),material="Ground"})
  end
  return out
 end
 local site=Sites.CANS[region.id];if not site then return {} end
 local out: {any}={};local p=site.at
 local function box(name: string,lo: Vector3,hi: Vector3)
  table.insert(out,{id=site.id.."_"..name,lo=p+lo,hi=p+hi,profile="painted_metal_smooth",color=Color3.fromHex(site.color),material="Metal"})
 end
 -- Stepped thin shell: exact AABBs for the engine's box-based movement, open interior.
 box("bottom",Vector3.new(0,0,-2.1),Vector3.new(12.2,.3,2.1))
 box("top",Vector3.new(0,6.3,-2.1),Vector3.new(12.2,6.6,2.1))
 for _,sign in {-1,1} do
  local z0,z1=if sign<0 then -3.3 else 3,if sign<0 then -3 else 3.3
  box("side"..sign,Vector3.new(.25,1.7,z0),Vector3.new(11.95,4.9,z1))
  local a,b=if sign<0 then -3.1 else 2.0,if sign<0 then -2.0 else 3.1
  box("lower"..sign,Vector3.new(.25,.3,a),Vector3.new(11.95,1.7,b))
  box("upper"..sign,Vector3.new(.25,4.9,a),Vector3.new(11.95,6.3,b))
 end
 box("base",Vector3.new(0,.3,-3),Vector3.new(.25,6.3,3))
 -- A torn drinking aperture 1.8 x 1.8 cm: large enough for the game's spider, not a fake painted hole.
 box("lid_low",Vector3.new(11.95,.3,-3),Vector3.new(12.2,3.2,3))
 box("lid_high",Vector3.new(11.95,5,-2),Vector3.new(12.2,6.3,2))
 box("lid_left",Vector3.new(11.95,3.2,-3),Vector3.new(12.2,5,-.9))
 box("lid_right",Vector3.new(11.95,3.2,.9),Vector3.new(12.2,5,3))
 return out
end
function Sites.decor(region: any): {any}
 if region.id==Pocket.REGION then return Pocket.decor() end
 local hill=Sites.ANTHILLS[region.id]
 if hill then
  local out: {any}={}
  for i,p in Sites.pieces(region) do
   local cap=caps[i]
   table.insert(out,{id=p.id.."_earth",size=Vector3.new(cap[1],cap[2],cap[1]),at=hill.at+Vector3.new(0,cap[3],0),color=p.color,material="Sand",shape="Ellipsoid",shadow=true})
  end
  table.insert(out,{id=hill.id.."_entrance",size=Vector3.new(.8,.025,.7),at=hill.at+Vector3.new(0,.615,0),color=Color3.fromHex("241c15"),shape="Ellipsoid"})
  for i=1,12 do
   local angle=i*2.39996;local radius=2.1+(i%4)*.7
   local offset=Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
   table.insert(out,{id=hill.id.."_grain"..i,size=Vector3.new(.22,.17,.27),at=hill.at+offset+Vector3.new(0,Sites.antHeight(offset)+.06,0),color=Color3.fromHex("8b7151"),shape="Ball",full=i>4})
  end
  for i=1,8 do
   local route=AntForage.route(i)
   table.insert(out,{id=hill.id.."_forage_fragment"..i,size=Vector3.new(.13,.08,.18),at=hill.at+route.direction*route.distance+Vector3.new(0,.04,0),color=Color3.fromHex("b5a57c"),shape="Ellipsoid",full=i>3})
  end
  return out
 end
 local site=Sites.CANS[region.id];if not site then return {} end
 local out: {any}={};local p=site.at
 local function part(name: string,size: Vector3,at: Vector3,color: string,shape: string?,turn: Vector3?,material: string?)
  table.insert(out,{id=site.id.."_"..name,size=size,at=p+at,color=Color3.fromHex(color),material=material or "Metal",shape=shape,turn=turn,shadow=true})
 end
 -- Keep the existing walkable shell and aperture; exposed ends are aluminium,
 -- with a rolled rim and a hollow pull tab rather than a painted solid face.
 for _,spec in Sites.pieces(region) do
  local lid=string.find(spec.id,"_lid_",1,true)~=nil or spec.id==site.id.."_base"
  part(spec.id,spec.hi-spec.lo,(spec.lo+spec.hi)*.5-p,if lid then "aeb5b5" else site.color)
 end
 part("rolled_base",Vector3.new(.20,6.7,6.7),Vector3.new(.14,3.3,0),"aeb5b5","Cylinder")
 local rim={{0,-2.1},{0,2.1},{1.7,3.3},{4.9,3.3},{6.6,2.1},{6.6,-2.1},{4.9,-3.3},{1.7,-3.3}}
 for i,a in rim do
  local b=rim[i%#rim+1];local dy,dz=b[1]-a[1],b[2]-a[2]
  part("rolled_lid_"..i,Vector3.new(.20,math.sqrt(dy*dy+dz*dz)+.08,.20),
   Vector3.new(12.24,(a[1]+b[1])*.5,(a[2]+b[2])*.5),"c4cbcb",nil,Vector3.new(math.deg(math.atan2(dz,dy)),0,0))
 end
 part("label",Vector3.new(7,.025,3.2),Vector3.new(5.8,6.62,0),"ded6bd",nil,nil,"SmoothPlastic")
 part("label_band",Vector3.new(1,.028,3.2),Vector3.new(4.3,6.63,0),site.color,nil,nil,"SmoothPlastic")
 part("tab_left",Vector3.new(.12,.75,.12),Vector3.new(12.36,5.65,-.38),"d4d9d9")
 part("tab_right",Vector3.new(.12,.75,.12),Vector3.new(12.36,5.65,.38),"d4d9d9")
 part("tab_top",Vector3.new(.12,.12,.88),Vector3.new(12.36,6.025,0),"d4d9d9")
 part("tab_bottom",Vector3.new(.12,.12,.88),Vector3.new(12.36,5.275,0),"d4d9d9")
 part("dry_syrup",Vector3.new(2.2,.018,1.3),Vector3.new(13.3,.014,.3),"75523b","Ellipsoid",nil,"SmoothPlastic")
 part("scuff1",Vector3.new(.035,.04,1.4),Vector3.new(4,6.66,-.25),"a4aca7",nil,Vector3.new(0,17,0))
 return out
end
function Sites.drawnPieces(region: any): {string}
 if region.id==Pocket.REGION then return Pocket.drawnPieces() end
 local out: {string}={};for _,p in Sites.pieces(region) do table.insert(out,p.id) end;return out
end
return table.freeze(Sites)
