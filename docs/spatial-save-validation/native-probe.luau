-- Actual client save objects, synthetic corrupted copies, no persistent writes. Never publish.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Rest=require(Shared.Persistence.SaveRest)
local Json=require(Shared.Persistence.Json)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("SpatialSaveProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis);local count=0
 local function check(ok,why) count+=1;assert(ok,why) end
 local ok,err=xpcall(function()
  print("[NATIVE_SPATIAL_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true
  check(d.fresh("main",false,nil),"fresh refused")
  d.openMenu();d.place(Vector3.new(-25.5,.31,6))
  check(d.menu:isShowing() and d.motor.mode=="attached","fixture not paused and attached")
  local world={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,garden=d.world.garden}
  local control,why=Checkpoint.capture(world,0);assert(control,why)
  check(#Rest.check("main",control,world)==0,"healthy client checkpoint refused")
  local before=assert(Json.canonical(control))
  local values={
   {name="nan",v={['$v']={0,{['$n']="nan"},0}}},
   {name="positive_inf",v={['$v']={{['$n']="inf"},0,0}}},
   {name="negative_inf",v={['$v']={0,0,{['$n']="-inf"}}}},
   {name="plain_xyz",plain={{"X",0},{"Y",0},{"Z",0}}},
   {name="empty_table",plain={}},
  }
  for _,item in values do
   local record=assert(Json.copy(control));local value=item.v
   if item.plain~=nil then
    table.insert(record.world.objects,{e=item.plain});value={['$o']=#record.world.objects}
   end
   local changed=false
   for _,object in record.world.objects do
    if object.c=="Fly" then
     for _,entry in object.e do if entry[1]=="position" then entry[2]=value;changed=true;break end end
     if changed then break end
    end
   end
   assert(changed,"no fly position fixture")
   local source=assert(Json.canonical(record))
   local problems=Rest.check("main",record,world)
   check(#problems>0 and string.find(table.concat(problems,";"),"finite vector position",1,true)~=nil,"server accepted "..item.name)
   local commit,errors=Checkpoint.prepare(record,world)
   check(commit==nil and #errors>0,"preparation accepted "..item.name)
   local accepted=Checkpoint.restore(record,world)
   check(not accepted and Json.canonical(record)==source and Json.canonical(assert(Checkpoint.capture(world,0)))==before,"non-atomic refusal "..item.name)
   print("[NATIVE_SPATIAL_CASE]",id,item.name,"refused_unchanged")
  end
  check(#Rest.check("main",control,world)==0 and Json.canonical(control)==before,"healthy source altered")
 end,debug.traceback)
 if ok then print("[NATIVE_SPATIAL_PASS]",id,count) else warn("[NATIVE_SPATIAL_FAIL]",id,tostring(err)) end
end
