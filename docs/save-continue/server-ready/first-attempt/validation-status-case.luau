
case("repeated validation failures never claim Saved and can recover unchanged authority",function()
 local e,s=authorityFixture(1611,"main",false,false);local offer=s:offer("main");local before=canon(e.backend.data[s.rkey.main])
 assert(s:requestLife("continue","main",1,offer.id));local r=s.intents.requests.main
 e.backend:fail({op="read",key=s.rkey.main,times=3,message="offline"});run(e,s,10)
 local status,reason=s:status()
 check(r.state=="readonly" and r.credential==nil and status=="saving" and reason=="write_failed","unresolved repeated validation is not falsely Saved")
 check(canon(e.backend.data[s.rkey.main])==before,"failed validation changes no stored rest")
 run(e,s,10)
 check(r.state=="writable" and select(1,s:status())=="saved","unchanged successful recovery clears the failure state")
end)
