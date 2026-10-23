 -- Native initial-load cancellation after an actual committed lock. Keep it
 -- separate from the single player's application owner sequence.
 local function preflight(deferred)
  local user=if deferred then 46003 else 46002
  local serviceTest;local who={UserId=user};local owned;local completed=false;local suspended=false
  local startedCount=0;local active=0;local backendStore=Memory.new()
  local record=Envelope.make(Progress.SPEC,Progress.default(),100,nil)
  backendStore:poke("P_"..user,record)
  local mock={}
  function mock:GetAsync(key,options)
   if options then assert(options.UseCache==false) end
   startedCount+=1;active+=1;task.wait(.02)
   local ok,value,problem=backendStore:read(key);active-=1;assert(ok,problem);return value
  end
  function mock:UpdateAsync(key,fn)
   startedCount+=1;active+=1
   local ok,value,problem=backendStore:update(key,fn);assert(ok,problem)
   if not deferred and not suspended then
    suspended=true
    -- Service removal runs in another native task while this provider's
    -- committed stack remains suspended. No coroutine.resume in the test.
    task.delay(.02,function() serviceTest:removePlayer(who);completed=true end)
    task.wait(.15)
   else task.wait(.02) end
   active-=1;return value
  end
  local g=Gate.new({now=now,available=function() return {read=1000,write=1000} end,
   actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
  local a=Accounts.new(g,{now=now,sleep=task.wait,legacyHistory=function() return {} end})
  local launched=0
  serviceTest=Service.new({backend=Backend.new(mock,codec),now=now,sleep=task.wait,accountLifetimes=a,
   keyOf=function() return user end,jobId="native-cancel",send=function() end,
   spawn=function(fn,...)
    launched+=1
    if deferred then task.delay(.2,fn,...) else task.spawn(fn,...) end
   end,
   ownerFactory=function(config,emit)
    owned=Owner.new(config,emit,{codec=codec,rawBackend=Raw.new(mock),currentFormat=Format,entryFactory=Entry,saveFactory=Loop},assert(catalog:profiles()))
    return owned
   end})
  serviceTest:addPlayer(who)
  if deferred then serviceTest:removePlayer(who);completed=true end
  local expires=os.clock()+30
  repeat task.wait(.025) until completed and owned and owned.session.closed and not owned.session.busy and g:inspect().scopes==0 or os.clock()>=expires
  task.wait(.3) -- permit deferred task to execute and prove it remains inert
  check(completed and owned and owned.session.closed and not owned.session.busy,"native initial cancellation did not close")
  check(active==0 and g:inspect().started==0 and g:inspect().scopes==0,"native cancelled provider/scope failed to drain")
  local raw=backendStore.data["P_"..user]
  local retained=Json.copy(raw);retained.lock=nil
  check(raw.lock==nil and Json.canonical(retained)==Json.canonical(record),"native cancellation changed progress or retained lock")
  check(if deferred then startedCount==0 else suspended and startedCount>1,"native cancellation boundary not exercised")
  check(launched>=1,"native executor not used")
  print("[NATIVE_SERVICE_PREFLIGHT]",tag,Json.canonical({deferred=deferred,starts=startedCount,active=active,scopes=g:inspect().scopes,closed=owned.session.closed}))
 end
 preflight(false);preflight(true)
