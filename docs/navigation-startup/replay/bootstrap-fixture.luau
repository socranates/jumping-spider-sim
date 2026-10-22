-- Whole controller on the CLI shim, not native/device/rendering evidence.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Scenery=require("../src/Shared/Habitat/Scenery")
local SelfTest=require("../src/Client/SelfTest")
local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
local Json=require("../src/Shared/Persistence/Json")
local Random=require("../src/Shared/Prey/PreyRandom")
local ObjectRecord=require("../src/Shared/Persistence/ObjectRecord")
local Wasp=require("../src/Shared/Predator/WaspDirector")
local Air=require("../src/Shared/World/StationAir")
local SaveClient=require("../src/Client/SaveClient")
local transportNow=0
local newSaveClient=SaveClient.new
SaveClient.new=function(config)
 local copy=table.clone(config);copy.now=function() return transportNow end;return newSaveClient(copy)
end
local tracking=false;local draws={};local nextRandom=Random.next
Random.next=function(self)
 local before=self.state;local result=nextRandom(self)
 if tracking then table.insert(draws,{before,self.state,result}) end
 return result
end
local FPS=__FPS__
local warn=print
workspace:ClearAllChildren();workspace:SetAttribute("World","preserve");workspace:SetAttribute("SelfTest",true)
Map.use("preserve")
local decor,replaced=Scenery.decor(nil,"preserve");decor.Parent=workspace
local hidden={};for id in replaced do hidden[id]=true end
Build.world(workspace,Map.SEED,hidden)
local hook=ClientStubs.scriptFolder:FindFirstChild("SilkPlayback");if hook then hook:Destroy() end
local d=nil
SelfTest.start=function(hooks) d=hooks;return true end
require("../src/Client/SpiderClient.client")
assert(d,"actual controller hooks unavailable")
local frame=assert(ClientStubs.renderSteps.SpiderSim)
local player=game:GetService("Players").LocalPlayer
local loadingFrames=0
while player:GetAttribute("TitleReady")~=true and loadingFrames<5000 do
 frame(1/FPS);loadingFrames+=1
 assert(d.navigation.status~="failed",d.navigation.problem)
end
assert(player:GetAttribute("TitleReady")==true and d.menu:isShowing(),"actual title menu never became ready")
transportNow=100;frame(1/FPS) -- deterministic offline transport fixture, no online service
tracking=true
d.title.seen=true
assert(d.menu:choose("New"),"New refused")
assert(d.session.started and not d.title:holding(),"life did not begin without intro")
local keys={Forward="W",Back="S",Right="D",Left="A",Creep="LeftControl",Jump="Space",Cancel="Q"}
local function key(action,down)
 local fn=assert(ClientStubs.actions["Spider"..action])
 fn("Spider"..action,if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
  {KeyCode=Enum.KeyCode[keys[action]],UserInputType=Enum.UserInputType.Keyboard,Position=Vector3.zero})
end
local events={
 [0]={{"Forward",true}},[1]={{"Forward",false}},[2]={{"Back",true}},[3]={{"Back",false}},
 [4]={{"Right",true}},[5]={{"Right",false}},[6]={{"Left",true}},[7]={{"Left",false}},
 [8]={{"Creep",true},{"Forward",true}},[9]={{"Forward",false},{"Creep",false}},
 [10]={{"Jump",true}},[11]={{"Cancel",true},{"Jump",false},{"Cancel",false}},
 [14]={{"Back",true}},[15]={{"Back",false}},
}
local function sample(second)
 local roots={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,wasp=d.wasp,garden=d.world.garden,cat=d.cat,water=d.water}
 local boundary=Checkpoint.boundaryProblem(roots)
 local record,why=Checkpoint.capture(roots,120)
 assert(record,why)
 local refs={world=d.wasp.world,station=Air}
 if d.wasp.rng then
  for name,value in d.wasp.rng do if type(value)=="function" then refs["rng_"..name]=value end end
 end
 local liveWasp,problem=ObjectRecord.capture({wasp=d.wasp},{WaspDirector=Wasp},refs)
 assert(liveWasp,problem)
 print("[CONTROLLER_REPLAY_SAMPLE]",FPS,second,boundary,assert(Json.canonical({checkpoint=record,live_wasp=liveWasp,draws=#draws})))
end
sample(0)
for f=0,FPS*20-1 do
 if f%FPS==0 then for _,event in events[f//FPS] or {} do key(event[1],event[2]) end end
 frame(1/FPS)
 if (f+1)%FPS==0 then sample((f+1)//FPS) end
end
print("[CONTROLLER_REPLAY_RNG]",FPS,assert(Json.canonical(draws)))
print("[CONTROLLER_REPLAY_DONE]",FPS,loadingFrames,21,d.navigation.slices)
