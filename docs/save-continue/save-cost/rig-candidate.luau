-- Paired unchanged/candidate drawing under the CLI shim. No native FPS claim.
local Original=__mods.SpiderRig
local Candidate=__mods.RigCandidate
local Living=__mods.Living
local Appearances=__mods.Appearances
local ground=BoxWorld.folder("RigCostGround",{{name="floor",lo=Vector3.new(-2000,-1,-2000),hi=Vector3.new(2000,0,2000),profile="wood"}})
local counts={original=0,candidate=0,setup=0}
local phase="setup"
local lookAt=CFrame.lookAt
CFrame.lookAt=function(...) counts[phase]+=1;return lookAt(...) end
local worstPos,worstAxis,worstSize,comparisons,frames=0,0,0,0,0
local elapsed={original=0,candidate=0}
local function draw(rig,name,body,moving)
 phase=name;local at=os.clock();rig:update(body,1/60,true,moving)
 elapsed[name]+=os.clock()-at
end
local ids={};for id in Appearances.profiles do table.insert(ids,id) end;table.sort(ids)
for _,id in ids do for _,detail in {"full","low"} do
 phase="setup"
 local a,b=Original.new(ground,ground,id,detail,true),Candidate.new(ground,ground,id,detail,true)
 for _,r in {a,b} do if r._living then r._living=Living.new(r._appearance.idle,4242) end end
 local pa,pb=a.model:GetChildren(),b.model:GetChildren()
 assert(#pa==#pb,"candidate changed parts")
 for _,exact in {false,true} do
  a._exact=exact;b._exact=exact
  for i=1,180 do
   if i==40 then a:cue("groom");b:cue("groom") end
   if i==60 then a:setGrowthStage(2);b:setGrowthStage(2) end
   if i==90 then a:setGrowthStage(3);b:setGrowthStage(3) end
   if i==120 then a:setScale(1.7);b:setScale(1.7) end
   if i==150 then a:setCondition(.1);b:setCondition(.1) end
   local moving=i>30
   local offset=if i<90 then 0 else 1000
   local body=CFrame.new(offset+math.sin(i*.03),.31,-i*.02)*CFrame.Angles(0,i*.01,0)
   if i%2==0 then draw(a,"original",body,moving);draw(b,"candidate",body,moving)
   else draw(b,"candidate",body,moving);draw(a,"original",body,moving) end
   frames+=1
   for n,x in pa do
    local y=pb[n];assert(x.Name==y.Name,"part order changed")
    if x:IsA("BasePart") then
     worstPos=math.max(worstPos,(x.CFrame.Position-y.CFrame.Position).Magnitude)
     worstAxis=math.max(worstAxis,(x.CFrame.RightVector-y.CFrame.RightVector).Magnitude,
      (x.CFrame.UpVector-y.CFrame.UpVector).Magnitude,(x.CFrame.LookVector-y.CFrame.LookVector).Magnitude)
     worstSize=math.max(worstSize,(x.Size-y.Size).Magnitude);comparisons+=1
    end
   end
  end
 end
 a:destroy();b:destroy()
end end
CFrame.lookAt=lookAt
print("RIG_CANDIDATE_COMPARE",#ids,frames,comparisons,worstPos,worstAxis,worstSize)
print("RIG_CANDIDATE_CALLS",counts.original,counts.candidate,counts.setup)
print("RIG_CANDIDATE_CPU_MS",elapsed.original*1000,elapsed.candidate*1000)
assert(worstPos<1e-8 and worstAxis<1e-8 and worstSize==0,"candidate changed presentation beyond numerical roundoff")
assert(counts.candidate<counts.original,"candidate did not remove per-frame orientation work")
print("RIG_CANDIDATE_PASS")
