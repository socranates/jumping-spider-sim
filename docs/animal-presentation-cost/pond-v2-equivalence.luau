-- Compare every rendered part, across live pose changes and visibility transitions.
-- __pondReference and __pondCandidate are private modules supplied by the runner.
local Reference=__pondReference
local Candidate=__pondCandidate
local checks=0
local function check(ok,why) assert(ok,why);checks+=1 end
local function equalVector(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
local function equalFrame(a,b)
 return equalVector(a.Position,b.Position) and equalVector(a.RightVector,b.RightVector)
  and equalVector(a.UpVector,b.UpVector) and equalVector(a.LookVector,b.LookVector)
end
local function same(a,b)
 for _,name in {"frog","darner"} do
  local x,y=a[name],b[name]
  if (x==nil)~=(y==nil) then return false,name.." presence" end
  if x then
   if x.count~=y.count then return false,name.." count" end
   for i=1,x.count do
    local p,q=x.parts[i],y.parts[i]
    if (p==nil)~=(q==nil) then return false,name.." tier hole" end
    if p then
     if p.Name~=q.Name or not equalVector(p.Size,q.Size) or not equalFrame(p.CFrame,q.CFrame)
      or p.Color.R~=q.Color.R or p.Color.G~=q.Color.G or p.Color.B~=q.Color.B
      or p.Material~=q.Material or p.Transparency~=q.Transparency or p.Reflectance~=q.Reflectance
      or p.CanCollide~=q.CanCollide or p.CanQuery~=q.CanQuery or p.Anchored~=q.Anchored then
      return false,name.." part "..i.." "..p.Name
     end
    end
   end
  end
 end
 return true,""
end
local totalCalls,totalFrogCalls=0,0
for _,tier in {"full","low"} do
 local a,b=Reference.new(workspace,tier),Candidate.new(workspace,tier)
 local other=Candidate.new(workspace,tier)
 local frog={here=true,pos=Vector3.zero,heading=Vector3.zAxis,length=0}
 function frog:mouth() return self.pos+Vector3.new(0,.9,-4.4) end
 function frog:tongue(target) return if self.length>0 then self:mouth()-Vector3.zAxis*self.length else nil end
 a:draw(nil,nil,nil,nil,0);b:draw(nil,nil,nil,nil,0)
 check(a.frog==nil and b.frog==nil and a.darner==nil and b.darner==nil,"empty draw built models")
 local buffers=nil;local recipe=nil;local frogRecipe=nil
 local original=Candidate.darnerParts;local calls=0
 local originalFrog=Candidate.frogParts;local frogCalls=0
 Candidate.darnerParts=function(...) calls+=1;return original(...) end
 Candidate.frogParts=function(...) frogCalls+=1;return originalFrog(...) end
 for i=1,420 do
  local t=(i-1)/60
  frog.here=(i%79)<60
  frog.pos=Vector3.new(math.sin(t)*8,math.cos(t)*2,t*3)
  frog.heading=Vector3.new(math.sin(t),0,math.cos(t))
  frog.length=if i%31<10 then (i%31)*1.7 else 0
  local at=if i%67<53 then Vector3.new(t*9,10+math.sin(t),-t*7) else nil
  local heading=if i%7==0 then nil else Vector3.new(math.cos(t),0,math.sin(t))
  local shownFrog=if i%101<95 then frog else nil
  a:draw(shownFrog,nil,at,heading,t);b:draw(shownFrog,nil,at,heading,t)
  local ok,why=same(a,b);check(ok,tier.." frame "..i.." "..why)
  if b.frog and b.darner then
   if not buffers then
    buffers={b.frog.moved,b.frog.frames,b.darner.moved,b.darner.frames};recipe=b.darner.recipe;frogRecipe=b.frog.recipe
    check(buffers[1]~=buffers[3] and buffers[2]~=buffers[4],"frog and darner share mutable buffers")
   end
   check(b.frog.moved==buffers[1] and b.frog.frames==buffers[2] and b.darner.moved==buffers[3]
    and b.darner.frames==buffers[4] and b.darner.recipe==recipe and b.frog.recipe==frogRecipe
    and b.frog.bodySpec.name=="Body" and b.frog.throatSpec.name=="Throat","buffer or recipe identity changed")
   check(#b.frog.moved==#b.frog.frames and #b.darner.moved==#b.darner.frames,"stale parallel entries")
  end
 end
 check(calls==1,tier.." invariant darner recipe rebuilt "..calls.." times")
 check(frogCalls==1,tier.." invariant frog recipe rebuilt "..frogCalls.." times")
 totalCalls+=calls
 totalFrogCalls+=frogCalls
 other:draw(frog,nil,Vector3.zero,nil,0)
 check(other.frog.moved~=b.frog.moved and other.darner.moved~=b.darner.moved
  and other.darner.recipe~=b.darner.recipe and other.frog.recipe~=b.frog.recipe
  and other.frog.bodySpec~=b.frog.bodySpec and other.frog.throatSpec~=b.frog.throatSpec,"presentation instances share mutable ownership")
 Candidate.darnerParts=original
 Candidate.frogParts=originalFrog
 -- Hidden parts must all leave and then reappear with the new transforms/sizes.
 a:draw(nil,nil,nil,nil,9);b:draw(nil,nil,nil,nil,9)
 local ok,why=same(a,b);check(ok,"hidden transition "..why)
 frog.here=true;frog.length=12
 a:draw(frog,nil,Vector3.one,Vector3.xAxis,10);b:draw(frog,nil,Vector3.one,Vector3.xAxis,10)
 ok,why=same(a,b);check(ok,"reappearance "..why)
end
for _,throat in {-.2,0,.1,.999,1,1.4} do
 for _,tongue in {0,.049,.05,.050001,.1,1,20} do
  for _,swell in {"default",0,.2,1} do
   local value=if swell=="default" then nil else swell
   local a,b=Reference.frogParts(throat,tongue,value),Candidate.frogParts(throat,tongue,value)
   local same=#a==#b
   for i,x in a do
    local y=b[i]
    same=same and y~=nil and x.name==y.name and equalVector(x.size,y.size) and equalFrame(x.frame,y.frame)
     and x.color==y.color and x.ball==y.ball and x.full==y.full and x.material==y.material
     and x.transparency==y.transparency and x.reflectance==y.reflectance
   end
   check(same,"public factory changed at "..throat.."/"..tongue.."/"..tostring(swell))
  end
 end
end
print("POND_EQUIVALENCE passed="..checks.." failed=0 recipe_builds="..totalCalls.." frog_recipe_builds="..totalFrogCalls)
