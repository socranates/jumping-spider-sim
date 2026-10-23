-- Expected integration counterexample, not a supported recovered entry.
do
 local f=fixture("main",{mainGentle=true});f.choose()
 f.drive(function() return f.adapter.job.phase=="held" end)
 local j=f.adapter.job
 check(f.adoptions==1 and d.session.mode=="main" and d.session.rules=="gentle","legacy main/gentle fixture did not preserve its rules")
 check(f.client.activeSlot=="easy" and d.saveClient.activeSlot=="easy","actual restore did not expose the legacy slot alias")
 check(j.hold.held() and f.acks==0 and f.owner.runtime.phase=="entering","slot alias was silently acknowledged or granted")
 print("RECOVERY_PROFILE_COUNTEREXAMPLE source_slot=main rules=gentle adopted_active_slot=easy acknowledged=false held=true supported=false")
 f.close()
end
print("RECOVERY_PROFILE_GUARD passed="..count.." failed=0")
end
runActualGameEntryChecks()
end
end
