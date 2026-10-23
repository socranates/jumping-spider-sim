test("blocked-renewal-allows-cpu-and-independent-reads",function()
 local b,clock,s,g,scope,budget,c,j,base=fixture();budget.read=80;budget.write=80
 drive(b,s,c,j,base,function() return j.lastAck~=nil end)
 clock.now=j.lastAck+Rules.HEARTBEAT+5;budget.write=0
 tick(b,s,c,j,base);local transform=j.renewState.transform
 drive(b,s,c,j,base,function() return j.phase=="archive" end)
 check(j.collection.state=="complete" and j.collection.reads==8 and b.data.A1_46001_progress==nil,"write-starved heartbeat blocked independent reads/CPU or published without allowance")
 check(j.renewState.transform==transform and j.requests==10 and g:inspect().queued>=1,"heartbeat transform/counters did not survive independent work")
 clock.now+=25;budget.write=80
 check(tick(b,s,c,j,base) and j.lastAck==clock.now and s.sched.lastBeat==clock.now and b.data.P_46001.lock.beat==clock.now,"delayed heartbeat used the stale queued timestamp or lost priority")
 drive(b,s,c,j,base)
 check(j.state=="ready" and j.requests==21 and j.plan.entries.progress.raw.lock.beat<clock.now,"renewal changed the preserved original snapshot or double counted")
end)
test("repository-running-marker-blocks-reentrant-step",function()
 local b,clock,s,g,scope,budget,c,j,base=fixture();budget.read=80;budget.write=80
 local update=b.update;local nested=0
 b.update=function(self,key,fn)
  if string.sub(key,1,3)=="A1_" then
   local p=j.publication;local calls=self.requests
   check(p.state=="running" and not j.repository:step(p) and self.requests==calls,"reentrant publication started another operation")
   nested+=1
  end
  return update(self,key,fn)
 end
 drive(b,s,c,j,base)
 check(j.state=="ready" and nested==5 and j.requests==20 and b.data.A1_46001_index.complete,"nested publication marker changed archive behavior")
end)
