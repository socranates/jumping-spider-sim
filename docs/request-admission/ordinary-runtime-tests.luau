local groups=0
for _,mode in Rules.MODES do
 local before=count;local f=fixture(mode)
 check(f.s.ordinaryAdmission==f.lane and f.rt.pipeline.options.admission==f.lane and f.rt.reader.options.admission==f.lane
  and f.rt.recovery.entryOptions.admission==f.lane and f.rt.saveLoop.options.admission==f.lane and f.rt.recovery.lifecycleAdmission==f.lane,"Runtime did not bind one lane from initial load through entry/saving")
 check(f.s.counters.requests==f.b.requests and f.s._ordinaryContext==nil,"initial-through-entry typed provider totals differ or loader stack retained")
 local function originals()
  local q={};for k,v in f.b.data do if string.sub(k,1,3)=="A1_" or string.sub(k,1,3)=="M1_" then q[k]=v end end;return Json.canonical(q)
 end
 local kept=originals();choose(f,.7);check(checkpoint(f,1),"constructor-lane checkpoint refused")
 for _=1,1600 do
  if f.stored()==1 then break end
  local n=f.b.requests;f.rt:step();check(f.b.requests-n<=1 and f.s.counters.requests==f.b.requests,"Runtime post-entry provider counters differ")
  f.clock.now+=1
 end
 check(f.stored()==1 and f.b.data.P_46001.payload.settings.MasterVolume==.7 and originals()==kept,"constructor-lane save failed or changed immutable originals")
 f.rt:flush()
 check(f.s.closed and f.rt.result.progressPreserved and f.rt.result.leaseReleased and f.b.data.P_46001.lock==nil and f.s.counters.requests==f.b.requests,"constructor-lane Runtime departure failed/accounting bypassed")
 check(originals()==kept,"constructor-lane departure changed A1/M1")
 f.gate:close(f.scope);local q=f.gate:inspect();check(q.queued==0 and q.started==0,"constructor-lane Runtime retained tickets")
 groups+=1;print("ORDINARY_RUNTIME_CASE",mode,count-before)
end
print("ORDINARY_RUNTIME passed="..count.." failed=0 groups="..groups)
end
runOrdinaryRuntimeChecks()
end
