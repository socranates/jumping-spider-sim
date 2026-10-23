for _,mode in {"free","easy"} do
 local before=count;local f=fixture(mode);local j=f.rt.job;local anchor=f.b.data["M1_46001_"..mode]
 check(j.state=="rebound" and f.rt.phase=="entry_required" and not f.rt.result.gameplayAuthorized,"typed profile pipeline did not stop at entry barrier")
 check(anchor.slot==mode and Json.canonical(f.b.data[f.rkey])==Json.canonical(anchor.target),"typed profile wrote wrong physical slot/target")
 check(f.s.intents.requests[mode].credential==nil and f.decisions()==0 and j.requests<=96 and f.gate:inspect().queued==0,"typed profile granted life early or leaked requests")
 check(f.b.data.A1_46001_index.complete and f.rt.result.requiresSchema3Entry,"typed profile archive/rebind result missing")
 print("COMMIT_PROFILE_CASE",mode,count-before)
end
print("COMMIT_PROFILE passed="..count.." failed=0 groups=2")
end
runCommitProfileChecks()
end
