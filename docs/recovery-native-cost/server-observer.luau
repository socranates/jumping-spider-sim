local cost={samples={},counts={},trace={},provider={},steps={},phases={}}
local previousStepKey,previousStepTime
local function stepState(owner)
 if not owner then return "none",false,0 end
 local rt=owner.runtime;local s=owner.session
 local key=rt.phase..":"..tostring(rt.job and rt.job.phase)..":"..tostring(rt.entryJob and rt.entryJob.phase)..":"..tostring(rt.discovery and rt.discovery.phase)
 local recent=0;local at=s.now()
 -- Observe without calling budgetOk, which prunes the live scheduler array.
 for _,started in s.sched.started do if at-started<60 then recent+=1 end end
 return key,recent>=Rules.REQUESTS_PER_MINUTE,s.counters.requests
end
local function measuredStep(service,owner)
 local key,full,requests=stepState(owner);local at=os.clock()
 if previousStepKey then cost.steps[previousStepKey].elapsed_seconds+=at-previousStepTime end
 local row=cost.steps[key]
 if not row then row={calls=0,seconds=0,max_seconds=0,budget_full_calls=0,request_starts=0,elapsed_seconds=0};cost.steps[key]=row end
 if previousStepKey~=key then table.insert(cost.phases,{name=key,t=WS:GetServerTimeNow(),budget_full=full,requests=requests}) end
 previousStepKey,previousStepTime=key,at
 service:step()
 local elapsed=os.clock()-at;row.calls+=1;row.seconds+=elapsed;row.max_seconds=math.max(row.max_seconds,elapsed)
 if full then row.budget_full_calls+=1 end
 if owner then row.request_starts+=math.max(0,owner.session.counters.requests-requests) end
end
local function wire(message)
 local kind=tostring(message.kind);local mode=message.mode or message.decision and message.decision.mode or "none"
 local key=kind..":"..tostring(mode);cost.counts[key]=(cost.counts[key] or 0)+1
 if not cost.samples[key] then
  local at=os.clock();local owned=Json.copy(message)
  cost.samples[key]={message=owned,copy_seconds=os.clock()-at}
 end
 if #cost.trace>=4096 then error("diagnostic server packet bound exceeded") end
 table.insert(cost.trace,{kind=kind,epoch=message.epoch,sequence=message.sequence,mode=mode,t=WS:GetServerTimeNow()})
end
local function provider(kind,started)
 local row=cost.provider[kind]
 if not row then row={calls=0,seconds=0,max_seconds=0};cost.provider[kind]=row end
 local elapsed=os.clock()-started;row.calls+=1;row.seconds+=elapsed;row.max_seconds=math.max(row.max_seconds,elapsed)
end
local function reportCost()
 for key,row in cost.samples do
  local at=os.clock();local text=assert(Json.canonical(row.message))
  print("[NATIVE_COST_SERVER_PAYLOAD]",tag,Json.canonical({key=key,canonical_bytes=#text,copy_seconds=row.copy_seconds,encode_seconds=os.clock()-at,count=cost.counts[key]}))
 end
 for key,row in cost.provider do row.key=key;print("[NATIVE_COST_SERVER_PROVIDER]",tag,Json.canonical(row)) end
 for key,row in cost.steps do row.key=key;print("[NATIVE_COST_SERVER_STEP]",tag,Json.canonical(row)) end
 for _,row in cost.phases do print("[NATIVE_COST_SERVER_PHASE]",tag,Json.canonical(row)) end
 for _,row in cost.trace do print("[NATIVE_COST_SERVER_TRACE]",tag,Json.canonical(row)) end
 print("[NATIVE_COST_SERVER_END]",tag,Json.canonical({packets=#cost.trace,clock_scale=10,online=false}))
end
