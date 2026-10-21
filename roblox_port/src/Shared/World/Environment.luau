--!strict
-- Habitat weather is reconstructed from the saved life clock, not rerolled on load.
-- Weather probabilities, temperatures and wind are authored temperate late-summer art direction.
-- Solar elevation uses the standard latitude/declination/hour-angle relation (NOAA solar equations).
-- Hours are local apparent solar time; no claim of matching the player's real location or civil timezone.
local Environment = {}
Environment.LATITUDE = 41.88
Environment.START_DAY_OF_YEAR = 235
Environment.FRONT_HOURS = 2
Environment.INDOORS = table.freeze({sill=true,counter=true,kitchen_floor=true,hut_floor=true,hut_upper=true,hut_desk=true,
 hut_board=true,hut_shelf=true,hut_chair=true,hut_window=true,hut_doorway=true,hut_door_up=true,
 room_floor=true,room_sofa=true,room_tv=true,room_games=true,room_window=true})

local TAU = math.pi*2
local function good(x: number, fallback: number): number
 return if x==x and math.abs(x)<1e12 then x else fallback
end
local function smooth(x: number): number
 local t=math.clamp(x,0,1);return t*t*(3-2*t)
end
function Environment.hash(seed: number, n: number, salt: number): number
 local x=(math.floor(seed)+math.floor(n)*7919+salt*104729)%2147483647
 x=(x*16807+12345)%2147483647;x=(x*16807)%2147483647
 return x/2147483647
end
local function front(seed: number, n: number): any
 local h=Environment.hash(seed,n,13)
 local rain=if h>.84 then .85 elseif h>.65 then .32 else 0
 return {rain=rain,cloud=if rain>0 then .85 else .12+.5*Environment.hash(seed,n,17),
  wind=.6+Environment.hash(seed,n,19)*3.2,angle=Environment.hash(seed,n,23)*TAU}
end
function Environment.solar(day: number, hour: number): any
 local doy=(Environment.START_DAY_OF_YEAR+math.floor(good(day,1))-2)%365+1
 local gamma=TAU*(doy-1+(hour-12)/24)/365
 local dec=.006918-.399912*math.cos(gamma)+.070257*math.sin(gamma)-.006758*math.cos(2*gamma)
  +.000907*math.sin(2*gamma)-.002697*math.cos(3*gamma)+.00148*math.sin(3*gamma)
 local lat=math.rad(Environment.LATITUDE);local ha=math.rad((hour-12)*15)
 local east=-math.cos(dec)*math.sin(ha)
 local north=math.cos(lat)*math.sin(dec)-math.sin(lat)*math.cos(dec)*math.cos(ha)
 local up=math.sin(lat)*math.sin(dec)+math.cos(lat)*math.cos(dec)*math.cos(ha)
 local altitude=math.deg(math.asin(math.clamp(up,-1,1)))
 return {direction=Vector3.new(east,up,-north),altitude=altitude,declination=math.deg(dec),dayOfYear=doy,
  daylight=smooth((altitude+6)/12)}
end
-- Roblox's native sky uses a tilted circular track: changing ClockTime alone
-- gives a constant north/south component. Convert the astronomical direction to
-- the two rendering controls instead. The life clock remains local solar time.
-- The 23.5-degree engine tilt was checked against Lighting:GetSunDirection in Studio.
function Environment.nativeSun(direction: Vector3): any
 local v=direction.Unit
 return {clock=(12+math.atan2(-v.X,v.Y)*12/math.pi)%24,
  latitude=23.5+math.deg(math.asin(math.clamp(v.Z,-1,1)))}
end
function Environment.sample(day: number, hour: number, seed: number?): any
 local d=math.max(1,good(day,1));local h=good(hour,9)
 local total=(d-1)*24+h;local slot=math.floor(total/Environment.FRONT_HOURS)
 local t=smooth((total-slot*Environment.FRONT_HOURS)/.75)
 local s=seed or 914;local a,b=front(s,slot-1),front(s,slot)
 local rain=a.rain+(b.rain-a.rain)*t;local cloud=a.cloud+(b.cloud-a.cloud)*t
 -- Blend vectors, rather than angles, so a front never spins through the long way round north.
 local wx=math.cos(a.angle)*a.wind*(1-t)+math.cos(b.angle)*b.wind*t
 local wz=math.sin(a.angle)*a.wind*(1-t)+math.sin(b.angle)*b.wind*t
 local gust=.8+.16*math.sin(total*147)+.12*math.sin(total*53+.7)
 local solar=Environment.solar(d,h%24)
 local damp=rain
 for back=1,4 do damp=math.max(damp,front(s,slot-back).rain*(1-back*.19)) end
 local seasonal=math.cos(TAU*(solar.dayOfYear-200)/365)
 local temperature=13+9*seasonal+5*math.cos(TAU*((h%24)-15)/24)-3*rain
 return {day=d,hour=h%24,totalHours=total,solar=solar,cloud=cloud,rain=rain,
  name=if rain>.62 then "rain" elseif rain>.08 then "drizzle" elseif cloud>.55 then "overcast" else "fair",
  wind=Vector3.new(wx,0,wz)*gust,wetness=math.clamp(damp,0,1),temperature=temperature,
  humidity=math.clamp(.42+cloud*.27+rain*.25+(1-solar.daylight)*.12,0,1),
  mist=math.clamp(damp*(1-solar.daylight)*.45,0,.4)}
end
function Environment.grub(day: number, hour: number, index: number, wetness: number): (number, number)
 local t=((day-1)*24+hour)*3600/48 -- action seconds at the sill's normal clock rate
 local period=34+Environment.hash(914,index,47)*37
 local phase=(t+Environment.hash(914,index,53)*period)%period
 local show=if wetness>.18 and phase<7 then math.sin(math.pi*phase/7) else 0
 return show,phase
end
function Environment.flea(seconds: number, index: number): (Vector3, boolean)
 local period=2.7+Environment.hash(914,index,59)*2.2
 local phase=(seconds+index*.83)%period;local hop=.22
 local u=math.clamp(phase/hop,0,1)
 local heading=Environment.hash(914,math.floor((seconds+index*.83)/period),index+61)*TAU
 return Vector3.new(math.cos(heading)*u*1.6,if phase<hop then 4*1.8*u*(1-u) else 0,math.sin(heading)*u*1.6),phase<hop
end
-- A leashed-sized park dog on a lawn circuit, with stops to sniff. No attack or save outcome is added.
-- The dog needs room for its whole body, not merely four supported paw points.
-- This lawn loop stays west of the raised beds and inside the authored ground.
Environment.DOG_ROUTE=table.freeze({Vector3.new(-340,-84.6,-100),Vector3.new(-235,-84.6,-100),
 Vector3.new(-285,-84.6,-150)})
function Environment.dog(seconds: number, rain: number): any
 local route=Environment.DOG_ROUTE;local durations={};local total=0
 for i,a in route do
  local move=(route[i%#route+1]-a).Magnitude/140
  durations[i]=move+5.5;total+=durations[i]
 end
 local cycle=seconds%total;local leg=1
 while cycle>durations[leg] and leg<#route do cycle-=durations[leg];leg+=1 end
 local a,b=route[leg],route[leg%#route+1]
 local moving=durations[leg]-5.5;local sniff=cycle>=moving
 local u=math.clamp(cycle/moving,0,1)
 local position=a:Lerp(b,u)
 local heading=(b-a).Unit
 if sniff then
  local nextHeading=(route[(leg+1)%#route+1]-b).Unit
  local turn=smooth(math.clamp((cycle-moving-4)/1.5,0,1))
  local yaw=math.atan2(heading.Z,heading.X)
  local nextYaw=math.atan2(nextHeading.Z,nextHeading.X)
  local delta=math.atan2(math.sin(nextYaw-yaw),math.cos(nextYaw-yaw))
  yaw+=delta*turn;heading=Vector3.new(math.cos(yaw),0,math.sin(yaw))
 end
 return {position=position,heading=heading,sniff=sniff,visible=true,
  stride=if sniff then 0 else math.sin(seconds*TAU*2.4),tail=math.sin(seconds*TAU*2.2)*(.3-.2*math.clamp(rain,0,1))}
end

-- Local presentation state, separate from the saved ecology. In rain, finish
-- the supported circuit to a sniff stop near the hut; never cut across beds.
-- Keep the route clock there until rain eases, then resume without a jump.
function Environment.stepDog(wander: any,seconds: number,rain: number): any
 local delta=if wander.raw then seconds-wander.raw else 0
 if wander.time==nil or delta<0 or delta>2 then wander.time=seconds;wander.rest=false;delta=0 end
 wander.raw=seconds
 if wander.rest and rain<.45 then wander.rest=false end
 if not wander.rest then wander.time+=delta end
 local pose=Environment.dog(wander.time,rain)
 if rain>.7 and pose.sniff and pose.position.Z>-130 then wander.rest=true end
 pose.rainRest=wander.rest==true
 return pose
end

return table.freeze(Environment)
