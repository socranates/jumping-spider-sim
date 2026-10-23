test("queued-final-lease-must-execute-and-ack-current-owner",function()
 local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(false,{reuseCompleteOriginal=true})
 budget.read=1000;budget.write=1000
 driveTyped(b,s,w,c,j,base,function() return j.phase=="commit" and j.child.phase=="finalLease" end)
 budget.write=0;local countBefore=j.requests;local child=j.child
 for _=1,20 do check(not tick(b,s,w,c,j,base),"final lease capacity wait started a request") end
 local transform=child.renewState.transform
 check(j.state=="pending" and child.state=="pending" and child.phase=="finalLease" and j.requests==countBefore,"queued final lease completed commit or consumed attempts")
 check(s.intents.requests.main.credential==nil and w.held.enforced and g:inspect().queued==1,"queued final lease released authority")
 local progress=Json.copy(b.data.P_46001);progress.lock.session="new-foreign-owner";b:poke("P_46001",progress)
 clock.now+=10;budget.write=1000;driveTyped(b,s,w,c,j,base)
 check(j.state=="refused" and j.requests==countBefore+1 and b.data.P_46001.lock.session=="new-foreign-owner","queued lease used stale ownership or overwrote foreign owner")
 check(w.held.enforced and not j.result.gameplayAuthorized and g:inspect().queued==0,"failed final lease released recovery hold")
end)
