--!strict
-- Clock-derived ambient workers. The carried fragments are presentation, not
-- food removed from the saved prey ecology. No locomotion/capture rule changes.
local Environment=require(script.Parent.Environment)
local AntForage={}
local TAU=math.pi*2
local routes: {[number]:any}={}
function AntForage.route(index: number): any
 if routes[index] then return routes[index] end
 local angle=Environment.hash(914,index,211)*TAU
 local direction=Vector3.new(math.cos(angle),0,math.sin(angle))
 local distance=9+Environment.hash(914,index,223)*6
 local speed=1.1+Environment.hash(914,index,227)*.8
 local route=table.freeze({direction=direction,across=Vector3.new(-direction.Z,0,direction.X),distance=distance,
  bow=(Environment.hash(914,index,229)-.5)*2,travel=distance/speed,pause=2.5,inside=4})
 routes[index]=route;return route
end
function AntForage.sample(seconds: number,index: number): any
 local r=AntForage.route(index)
 local period=r.inside+r.travel*2+r.pause
 local phase=(seconds+index*7.3)%period
 local mode,u="inside",0
 if phase>=r.inside+r.travel+r.pause then
  mode="return";u=1-(phase-r.inside-r.travel-r.pause)/r.travel
 elseif phase>=r.inside+r.travel then mode="forage";u=1
 elseif phase>=r.inside then mode="outbound";u=(phase-r.inside)/r.travel end
 local offset=r.direction*(r.distance*u)+r.across*(r.bow*math.sin(math.pi*u))
 local heading=(r.direction*r.distance+r.across*(r.bow*math.pi*math.cos(math.pi*u))).Unit
 if mode=="return" then heading=-heading end
 local distance=offset.Magnitude
 return {offset=offset,heading=heading,mode=mode,visible=mode~="inside",moving=mode=="outbound" or mode=="return",
  carrying=mode=="return" and distance>.4,burrow=math.clamp(1-distance/.4,0,1)*.45,
  period=period}
end
return table.freeze(AntForage)
