--!strict
-- Compare the actual new rig with the frozen pre-cache module, including every
-- part and scale transition. Used by the CLI and a separate native diagnostic.
return function(New:any,Before:any,Appearances:any,Living:any,ground:Instance,
 check:(boolean,string)->(),observe:((string,()->())->())?,yieldCase:(()->())?):any
 local ids:{string}={}
 for id in Appearances.profiles do table.insert(ids,id)end
 table.sort(ids)
 local total={cases=0,frames=0,parts=0,legHairFrames=0,worstPosition=0,worstAxis=0,worstSize=0}
 for _,id in ids do
  for _,detail in {"full","low"}do
   local a,b=New.new(ground,ground,id,detail,true),Before.new(ground,ground,id,detail,true)
   a._exact,b._exact=true,true
   if a._living then a._living=Living.new(a._appearance.idle,4242)end
   if b._living then b._living=Living.new(b._appearance.idle,4242)end
   local pa,pb={},{}
   for _,p in a.model:GetChildren()do if p:IsA("BasePart")then table.insert(pa,p)end end
   for _,p in b.model:GetChildren()do if p:IsA("BasePart")then table.insert(pb,p)end end
   local sameParts=#pa==#pb
   for i,p in pa do sameParts=sameParts and pb[i]~=nil and p.Name==pb[i].Name end
   check(sameParts,id.." "..detail..": same parts in creation order")
   local pos,axis,size=0,0,0
   local legHairs=0
   for _,leg in a._legs do legHairs+=#leg.hairs end
   for frame=1,40 do
    local group=math.floor((frame-1)/5)+1
    local scales={0.48,0.73,1,1.7,0.48,1,0.73,1.7}
    local normal=if group==3 then Vector3.xAxis elseif group==6 then -Vector3.yAxis else Vector3.yAxis
    local forward=if group==3 then Vector3.zAxis else Vector3.new(math.sin(frame*.17),0,-math.cos(frame*.17))
    local position=Vector3.new(math.sin(frame*.13)*2,20.31,-frame*.07)
    local body=CFrame.lookAt(position,position+forward,normal)
    local grounded=group~=4 and group~=5
    for _,r in {a,b}do
     if frame%5==1 then r:setGrowthStage((group-1)%4);r:setScale(scales[group])end
     r:setCondition(if group==7 then .1 else .8)
     r:setSoftness(if group==8 then .5 else 0)
     r.hangDirection=if not grounded then Vector3.new(.07,1,.035).Unit else nil
     r.focusPoint=if group==2 then Vector3.new(1.5,20.5,-2)else nil
     r.mealHeld=group==7;r.mealPulse=if group==7 then .8 else 0
     r.jumpLoad=if group==4 then .7 else 0;r.jumpPush=if group==5 then .6 else 0
     if frame==6 then r:cue("groom")elseif frame==31 then r:cue("alarm")end
    end
    local function update(r:any)r:update(body,1/60,grounded,group==2 or group==3)end
    if observe then observe("after",function()update(a)end);observe("before",function()update(b)end)
    else update(a);update(b)end
    if sameParts then
     for i,p in pa do
      local q=pb[i];local c,d=p.CFrame,q.CFrame
      pos=math.max(pos,(c.Position-d.Position).Magnitude)
      axis=math.max(axis,(c.RightVector-d.RightVector).Magnitude,(c.UpVector-d.UpVector).Magnitude,(c.LookVector-d.LookVector).Magnitude)
      size=math.max(size,(p.Size-q.Size).Magnitude)
     end
    end
    total.frames+=1;total.parts+=#pa;total.legHairFrames+=legHairs
   end
   check(pos<2e-5 and axis<2e-4 and size<1e-6,
    string.format("%s %s: all-part bounds, position %.3g, axis %.3g, size %.3g",id,detail,pos,axis,size))
   total.cases+=1;total.worstPosition=math.max(total.worstPosition,pos)
   total.worstAxis=math.max(total.worstAxis,axis);total.worstSize=math.max(total.worstSize,size)
   a:destroy();b:destroy()
   if yieldCase then yieldCase()end
  end
 end
 return total
end
