-- Private paired component benchmark; ordinary gameplay and persistence are not changed.
local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Reference=require(script.Parent.PondBodies)
local Candidate=require(script.Parent.PondCandidate)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("PondReuseProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local count=0;local folders={};local losses=0
 local connection=UIS.WindowFocusReleased:Connect(function() losses+=1 end)
 local function check(ok,why) count+=1;assert(ok,why) end
 local function same(a,b)
  for _,name in {"frog","darner"} do
   local x,y=a[name],b[name]
   if (x==nil)~=(y==nil) then return false end
   if x then
    if x.count~=y.count then return false end
    for i=1,x.count do
     local p,q=x.parts[i],y.parts[i]
     if (p==nil)~=(q==nil) then return false end
     if p and (p.Name~=q.Name or p.Size~=q.Size or p.CFrame~=q.CFrame or p.Color~=q.Color
      or p.Material~=q.Material or p.Transparency~=q.Transparency or p.Reflectance~=q.Reflectance
      or p.CanCollide~=q.CanCollide or p.CanQuery~=q.CanQuery or p.Anchored~=q.Anchored) then return false end
    end
   end
  end
  return true
 end
 local ok,err=xpcall(function()
  print("[NATIVE_POND_V2_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true;check(d.fresh("free",false,nil),"Free life refused")
  d.openMenu();check(d.menu:isShowing(),"game not paused")
  local began=os.clock();local changed=began;local view=workspace.CurrentCamera.ViewportSize
  repeat
   Run.Heartbeat:Wait()
   local current=workspace.CurrentCamera.ViewportSize
   if current~=view then view=current;changed=os.clock() end
   assert(os.clock()-began<45,"viewport did not settle")
  until view.X>=320 and view.Y>=180 and os.clock()-began>=10 and os.clock()-changed>=3
  local focusAt=losses;local viewport=workspace.CurrentCamera.ViewportSize
  for _,tier in {"full","low"} do
   local a,b=Reference.new(workspace,tier),Candidate.new(workspace,tier)
   table.insert(folders,a.folder);table.insert(folders,b.folder)
   local origin=Vector3.new(3000,3000,3000) -- outside the camera; component timing, not a rendering/FPS benchmark
   local frog={here=true,pos=origin,heading=Vector3.zAxis,length=1}
   function frog:mouth() return self.pos+Vector3.new(0,.9,-4.4) end
   function frog:tongue(target) return if self.length>0 then self:mouth()-Vector3.zAxis*self.length else nil end
   a:draw(frog,nil,origin,nil,0);b:draw(frog,nil,origin,nil,0)
   check(same(a,b),tier.." warm pose differs")
   local buffers={b.frog.moved,b.frog.frames,b.darner.moved,b.darner.frames};local recipe=b.darner.recipe
   check(buffers[1]~=buffers[3] and buffers[2]~=buffers[4] and type(recipe)=="table",tier.." ownership invalid")
   for i=1,60 do
    Run.Heartbeat:Wait()
    a:draw(frog,nil,origin,nil,i/60);b:draw(frog,nil,origin,nil,i/60)
    assert(same(a,b),tier.." warmup differs")
   end
   for pair=1,4 do
    local first=pair%2==1;local sums={{cpu=0,heap=0,worst=0},{cpu=0,heap=0,worst=0}}
    for i=1,120 do
     Run.Heartbeat:Wait()
     local t=(pair-1)*2+(i-1)/60
     frog.here=(i%29)<23;frog.length=if i%17<6 then (i%17)*2 else 0
     frog.pos=origin+Vector3.new(math.sin(t)*8,math.cos(t)*2,t*3)
     frog.heading=Vector3.new(math.sin(t),0,math.cos(t))
     local at=if i%31<25 then origin+Vector3.new(t*9,10+math.sin(t),-t*7) else nil
     local heading=if i%7==0 then nil else Vector3.new(math.cos(t),0,math.sin(t))
     local shown=if i%41<38 then frog else nil
     local function draw(index,body)
      local heap=gcinfo();local start=os.clock();body:draw(shown,nil,at,heading,t)
      local cpu=os.clock()-start;local grew=math.max(0,gcinfo()-heap);local row=sums[index]
      row.cpu+=cpu;row.heap+=grew;row.worst=math.max(row.worst,cpu)
     end
     if first then draw(1,a);draw(2,b) else draw(2,b);draw(1,a) end
     check(same(a,b),tier.." pair "..pair.." frame "..i.." differs")
    end
    check(b.frog.moved==buffers[1] and b.frog.frames==buffers[2] and b.darner.moved==buffers[3]
     and b.darner.frames==buffers[4] and b.darner.recipe==recipe,tier.." buffers/recipe replaced")
    check(#b.frog.moved==#b.frog.frames and #b.darner.moved==#b.darner.frames,tier.." stale entries")
    print("[NATIVE_POND_V2_PAIR]",id,tier,pair,if first then "AB" else "BA",120,
     string.format("%.6f",sums[1].cpu*1000),string.format("%.6f",sums[2].cpu*1000),
     string.format("%.3f",sums[1].heap),string.format("%.3f",sums[2].heap),
     string.format("%.6f",sums[1].worst*1000),string.format("%.6f",sums[2].worst*1000))
   end
  end
  check(losses==focusAt,"focus changed during paired measurement")
  check(workspace.CurrentCamera.ViewportSize==viewport,"viewport changed during paired measurement")
 end,debug.traceback)
 connection:Disconnect()
 for _,folder in folders do folder:Destroy() end
 if ok then print("[NATIVE_POND_V2_PASS]",id,count) else warn("[NATIVE_POND_V2_FAIL]",id,tostring(err)) end
end
