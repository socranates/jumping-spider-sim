-- Static collision feasibility only; not native timing evidence.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Meadow=require("../src/Shared/World/Meadow")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
Map.use("preserve")
local root=Build.world(workspace);local lo,hi=Map.bounds()
local start=Vector3.new(-60,Meadow.GROUND+.31,-550)
local motor=Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,spawn=start,heading=-Vector3.zAxis,boundsMin=lo,boundsMax=hi})
motor:place(start,Vector3.yAxis,-Vector3.zAxis)
local seen={};local order={};local frames=0
repeat
 motor:tick({wish=-Vector3.zAxis,creep=false,reel=0,dropHeld=false,releaseHeld=false})
 frames+=1
 assert(motor.mode=="attached","route detached")
 local region=assert(Map.at(motor.pos)).id
 if not seen[region] then seen[region]=true;table.insert(order,region) end
until motor.pos.Z<=-720 or frames>=60*240
print("ROUTE_END",motor.pos,frames,table.concat(order,","));assert(motor.pos.Z<=-720,"route did not reach finish")
assert(seen.pad_a2 and seen.pad_b2 and seen.pad_c2,"route did not cross the three required regions")
print("CONTINUOUS_ROUTE",frames,frames/60,(motor.pos-start).Magnitude,table.concat(order,","),motor.pos)
