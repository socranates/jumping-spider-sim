--!strict
-- Native and box-world T07 acceptance: never through cover, no teleports, reserved perches and conserved meals.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local D=require(Shared.Prey.PreyDirector)
local P=require(Shared.Prey.PreyPopulation)
local F=require(Shared.Prey.Feeding)
local Species=require(Shared.Data.Species)
local Layout=require(Shared.Habitat.WindowsillLayout)
local Sensor=require(Shared.Perception.Sensor)
local Memory=require(Shared.Perception.ObservationMemory)
return function(check: (string,()->())->())
 local p=Species.fly_like_prototype
 local world=Instance.new('Folder');world.Name='PreyTestWorld';world.Parent=workspace
 -- Use the same authored sill as the real client, moved nowhere; casts include only this private copy.
 for _,b in Layout.PIECES do
  local part=Instance.new('Part');part.Anchored=true;part.Size=b.hi-b.lo;part.CFrame=CFrame.new((b.hi+b.lo)*.5);part.Parent=world
 end
 local d=D.engine(world,p,914,4)
 check('T07 valid starts and swept flight reaches a reserved perch without teleporting',function()
  assert(#d.flies==4,'expected four validated starting perches, got '..#d.flies)
  local f=d.flies[1];assert(f:launch('move',0),'no flyable move')
  local target=f.flight.target;assert(target.reserved==f.id and f.perch.occupant=='')
  for i=1,1800 do
   local prev=f.position;f.flight:step(i/60,1/60)
   assert((f.position-prev).Magnitude<=p.flight.flee_speed_wu_s/60+.001,'teleport')
   if f.state=='PERCHED' then break end
  end
  assert(f.state=='PERCHED' and f.perch==target and target.occupant==f.id and target.reserved=='')
 end)
 check('T07 population waits, checks twice, rejects visible entrances and respects capacity',function()
  local pop=P.new(p.population,7,1);local n=0;local safe=false;local vents={{id='v'}}
  local function step(t: number) pop:step(t,n,vents,function()return safe end,function()n+=1;return true end) end
  step(0);step(24);assert(n==0);step(46);assert(n==0)
  safe=true;step(47);assert(n==0);safe=false;step(47.5);safe=true;step(48);assert(n==0)
  step(48.5);assert(n==1);step(100);assert(n==1 and #pop.owed==0)
 end)
 check('T07 feeding waits for landing, automatic grip works and nutrition cannot be duplicated',function()
  local feed=F.new();local fly={profile=p,nutrition=.35,state='CAPTURED',captureKey='meal1'}
  feed:capture(fly);feed.auto=true
  feed:step(.5,false,false,function()error('unexpected escape')end);assert(feed.grip==.4 and feed.needs.energy<=.55 and feed.needs.grantedTotal==0)
  for _=1,1500 do feed:step(1/60,true,false,function()error('unexpected escape')end) end
  assert(fly.state=='CONSUMED' and math.abs(feed.taken-.35)<1e-6 and feed.granted<=feed.taken+1e-9) -- the reserve records what it actually rose by (ROBLOX-24)
  local taken=feed.taken;feed:press();for _=1,120 do feed:step(1/60,true,false,function()end) end
  assert(feed.taken==taken and feed.ledger.meal1<=.35+1e-9)
 end)
 check('T07 no tapping lets a caught fly escape without a meal',function()
  local feed=F.new();local escaped=0;local fly={profile=p,nutrition=.35,state='CAPTURED',captureKey='meal2'}
  feed:capture(fly)
  for _=1,240 do feed:step(1/60,true,false,function()escaped+=1 end) end
  assert(escaped==1 and feed.taken==0 and not feed.held)
 end)
 check('T07 movement interrupts feeding on the same tick',function()
  local feed=F.new();feed.held={profile=p,nutrition=.35,state='CAPTURED',captureKey='meal3'};feed.feeding=true
  feed:step(1/60,true,true,function()end);assert(not feed.feeding and feed.taken==0)
 end)
 check('T07 jaws resolve one position-size contact; ambiguous capture resolves neither',function()
  local memory=Memory.new();local sensor=Sensor.new(memory);sensor:configureFrom(Species.phidippus_audax_prototype.perception)
  local observer={eye=Vector3.new(0,10,0),gaze=-Vector3.zAxis,heading=-Vector3.zAxis,up=Vector3.yAxis}
  local target={id='no-secret-id',position=Vector3.new(0,10,-4),radius=.3,velocity=Vector3.zero,maxCategory='fly_like_prey'}
  for _=1,90 do sensor:step(1/60,observer,{target},function()return nil end) end
  assert(sensor:onCapture(target.position,.3) and #memory:contacts()==0)
  local other={id='other',position=target.position+Vector3.xAxis*.2,radius=.3,velocity=Vector3.zero,maxCategory='fly_like_prey'}
  for _=1,90 do sensor:step(1/60,observer,{target,other},function()return nil end) end
  assert(not sensor:onCapture(target.position,.3) and #memory:contacts()==2)
 end)
 check('T07 a changed obstacle stops the flight before penetration',function()
  local f=d.flies[2];assert(f:launch('move',0))
  local pos=f.position;local old=d.graph.clear
  d.graph.clear=function()return false end
  f.flight:step(1/60,1/60)
  d.graph.clear=old
  assert(f.position==pos and f.velocity.Magnitude==0 and f.flight.blocked>0)
 end)
 check('T07 capture cannot cross a wall or start from an ordinary fall',function()
  local f=d.flies[1];f.state='PERCHED';f.position=Vector3.new(0,10,0);f.prevPosition=f.position
  local motor={mode='air',pos=Vector3.new(.2,10,0),events={},preparing=false,moving=false,vel=Vector3.zero,heading=Vector3.zAxis,up=Vector3.yAxis,
   eyePosition=function()return Vector3.new(.2,10,0)end}
  d.previousPosition=Vector3.new(-.2,10,0);d.previousMode='attached';d.tick=10;d.strikeEnd=-1
  local captures=0;local sensor={onCapture=function()captures+=1 end}
  d:after(1/60,motor,sensor,function()return nil end);assert(not d.feeding.held and captures==0)
  d.previousMode='attached';motor.events={{kind='launched'}}
  d:after(1/60,motor,sensor,function(a,b)return (a+b)*.5 end);assert(not d.feeding.held and captures==0)
  motor.pos=Vector3.new(.76,10,0);d.previousPosition=motor.pos
  d:after(1/60,motor,sensor,function()return nil end);assert(not d.feeding.held,"outside the modest new reach must miss")
  motor.pos=Vector3.new(.74,10,0);d.previousPosition=motor.pos
  d:after(1/60,motor,sensor,function()return nil end);assert(d.feeding.held==f and captures==1,"near miss inside new reach should catch")
 end)
 d.probe:Destroy();world:Destroy()
end
