local SpiderRig=require("../src/Shared/Rig/SpiderRig")
local Before=require("./rig_hair_reference")()
local Appearances=require("../src/Shared/Data/Appearances")
local Living=require("../src/Shared/Rig/Living")
local checks=require("./studio/rig_hair_checks")
local passed,failed=0,0
local function check(ok,why)
 if ok then passed+=1 else failed+=1;print("FAIL rig hair cache: "..why)end
end
local ground=BoxWorld.folder("RigHairFloor",{{name="floor",lo=Vector3.new(-80,19,-80),hi=Vector3.new(80,20,80),profile="painted_wood_dry"}})
local original=CFrame.lookAt
local count=0
CFrame.lookAt=function(...)count+=1;return original(...)end
local calls={before=0,after=0}
local result=checks(SpiderRig,Before,Appearances,Living,ground,check,function(which,draw)
 local n=count;draw();calls[which]+=count-n
end)
CFrame.lookAt=original
check(result.legHairFrames>0 and calls.before-calls.after==result.legHairFrames,
 `one lookAt removed per updated leg hair: {calls.before-calls.after} of {result.legHairFrames}`)
print(`RIG_HAIR_CACHE cases={result.cases} frames={result.frames} part_comparisons={result.parts} lookat_before={calls.before} lookat_after={calls.after} worst_position={result.worstPosition} worst_axis={result.worstAxis} worst_size={result.worstSize}`)
ground:Destroy()
print(`RIG_HAIR_CACHE passed={passed} failed={failed}`)
if failed>0 then error("rig hair cache checks failed")end
