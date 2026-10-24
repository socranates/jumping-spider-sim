--!strict
-- Separate unbound native fixture. Deliberately replaces optional visuals while
-- ordinary title holds the life. This cohort is NOT a performance measurement.
return function(d:any,probe:any)
 local WS=game:GetService("Workspace")
 local Run=game:GetService("RunService")
 assert(Run:IsStudio()and game.PlaceId==0 and game.GameId==0)
 assert(not d.session.started and d.menu:isShowing()and d.navigation.status=="ready")
 local function waitFor(fn:()->boolean)
  local deadline=os.clock()+20
  repeat if fn()then return end;Run.Heartbeat:Wait()until os.clock()>=deadline
  error("late Decor native binding deadline")
 end
 local function folder(parent:Instance,name:string):Instance
  local f=Instance.new("Model");f.Name=name;f.Parent=parent;return f
 end
 local function part(parent:Instance,name:string):BasePart
  local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
  p.CFrame=CFrame.new(27,5,-3);p.Transparency=.3;p.Parent=parent;return p
 end
 local leaf=d.breakaway
 local hut=d.world.hut
 waitFor(function():boolean return d.world.decor~=nil and #leaf.pieces>0 and hut.decor==d.world.decor end)
 local original=assert(d.world.decor)
 local originalCount=#leaf.pieces
 assert(leaf.left==0 and not hut.open and hut.sash.CanQuery)
 local record=leaf:record();local opened=hut.opened
 local initial={}
 for _,entry in leaf.pieces do initial[entry.part]={frame=entry.frame,transparency=entry.transparency}end
 local replacement:Instance?=nil
 local okay,why=xpcall(function()
  leaf:apply({left=3})
  original.Parent=nil
  waitFor(function():boolean return d.world.decor==nil and #leaf.pieces==0 and hut.decor==nil end)
  assert(leaf.left==3 and not leaf.part.CanQuery and hut.sash.CanQuery,"stream-out changed collision or logical progress")
  replacement=folder(WS,"Decor")
  waitFor(function():boolean return d.world.decor==replacement and hut.decor==replacement end)
  local pilea=folder(replacement :: Instance,"Pilea");local tip=folder(pilea,"leaf_tip")
  local blade=part(tip,"Blade");local home=blade.CFrame
  waitFor(function():boolean return #leaf.pieces==1 end)
  assert(blade.Transparency==1 and blade.Position.Y<home.Position.Y-4 and leaf.left==3,"late leaf did not join saved fall")
  local vein=part(tip,"Vein");local veinHome=vein.CFrame
  waitFor(function():boolean return #leaf.pieces==2 end)
  assert(vein.Transparency==1 and leaf.left==3,"later descendant did not bind")
  local wall=folder(replacement :: Instance,"Wall");local rail=part(wall,"SashRail");local top=part(wall,"SashTop")
  waitFor(function():boolean return rail.Transparency==1 and top.Transparency==1 end)
  assert(not hut:passable()and hut.sash.CanQuery and hut.opened==opened,"late sash replayed opening")
  hut:restore(true)
  assert(math.abs(rail.Transparency-.3)<.001 and math.abs(top.Transparency-.3)<.001 and hut:passable())
  local wedge=hut.wedge
  Run.Heartbeat:Wait();Run.Heartbeat:Wait()
  assert(hut.wedge==wedge and hut.opened==opened+1,"visual refresh replayed a restored opening")
  hut:reshut();hut.opened=opened
  leaf:apply(nil)
  assert((blade.Position-home.Position).Magnitude<.001 and(vein.Position-veinHome.Position).Magnitude<.001,"leaf baseline drifted")
  probe.note("DECOR_EXERCISE",{root_stream_out=true,partial_leaf=true,late_descendant=true,late_sash=true,restored_opening=true,baseline_restored=true})
 end,debug.traceback)
 -- Always return ordinary geometry and logical state, even after a failed check.
 if replacement then replacement.Parent=nil end
 original.Parent=WS
 if hut.open then hut:reshut()end;hut.opened=opened
 leaf:apply(record)
 waitFor(function():boolean return d.world.decor==original and hut.decor==original and #leaf.pieces==originalCount end)
 for p,state in initial do
  assert((p.Position-state.frame.Position).Magnitude<.001 and math.abs(p.Transparency-state.transparency)<.001,"original visual state was not restored")
 end
 if replacement then replacement:Destroy()end
 assert(leaf.left==0 and leaf.part.CanQuery and hut.sash.CanQuery and not hut:passable()and not d.session.started)
 probe.note("DECOR_RESTORED",{parts=originalCount,window_closed=true,collision_ready=true,life_started=false})
 assert(okay,tostring(why))
end
