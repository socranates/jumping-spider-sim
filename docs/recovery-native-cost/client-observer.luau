 -- Diagnostic observer: no gameplay/schema/authority changes. Snapshots and
 -- post-run canonical encodes have separately reported overhead.
 local cost={samples={},counts={},trace={},updates={},gaps={},phases={},marks={},copySeconds=0}
 local function stage()
  return (app and app.phase or "boot")..":"..(app and app.entry.job and app.entry.job.phase or "none")..":"..tostring(client and client.activeSlot)
 end
 local function mark(name)
  table.insert(cost.marks,{name=name,t=WS:GetServerTimeNow()})
 end
 local function wire(direction,message)
  local kind=tostring(message.kind)
  local mode=message.mode or message.decision and message.decision.mode or "none"
  local key=direction..":"..kind..":"..tostring(mode)
  cost.counts[key]=(cost.counts[key] or 0)+1
  if not cost.samples[key] then
   local at=os.clock();local owned=Json.copy(message);local elapsed=os.clock()-at
   cost.copySeconds+=elapsed;cost.samples[key]={message=owned,copy_seconds=elapsed}
  end
  if #cost.trace>=4096 then error("diagnostic packet trace bound exceeded") end
  table.insert(cost.trace,{direction=direction,kind=kind,epoch=message.epoch,sequence=message.sequence,mode=mode,t=WS:GetServerTimeNow()})
 end
 local function observedRemotes(find)
  return function()
   local raw=find();if not raw then return nil end
   return {server={FireServer=function(_,message)
    wire("out",message);raw.server:FireServer(message)
   end},client={OnClientEvent={Connect=function(_,callback)
    return raw.client.OnClientEvent:Connect(function(message)
     -- Timestamp before copying: send-to-callback excludes this snapshot cost.
     local arrived=WS:GetServerTimeNow();wire("in",message);cost.trace[#cost.trace].t=arrived
     callback(message)
    end)
   end}}}
  end
 end
 local observerConnection
 local function watch(object,name)
  local original=object.update
  object.update=function(self,...)
   local key=name..":"..stage();local row=cost.updates[key]
   if not row then row={calls=0,seconds=0,max_seconds=0};cost.updates[key]=row end
   local at=os.clock();original(self,...);local elapsed=os.clock()-at
   row.calls+=1;row.seconds+=elapsed;row.max_seconds=math.max(row.max_seconds,elapsed)
  end
 end
 local function observeApplication()
  watch(app,"application");watch(app.entry,"entry");watch(client,"save_client")
  local previous
  observerConnection=Run.Heartbeat:Connect(function(dt)
   local key=stage();local row=cost.gaps[key]
   if not row then row={frames=0,seconds=0,max_seconds=0,over_50ms=0};cost.gaps[key]=row end
   row.frames+=1;row.seconds+=dt;row.max_seconds=math.max(row.max_seconds,dt)
   if dt>.05 then row.over_50ms+=1 end
   if previous~=key then table.insert(cost.phases,{name=key,t=WS:GetServerTimeNow()});previous=key end
  end)
 end
 local function reportCost()
  if observerConnection then observerConnection:Disconnect() end
  for key,row in cost.samples do
   local at=os.clock();local text=assert(Json.canonical(row.message));local elapsed=os.clock()-at
   print("[NATIVE_COST_CLIENT_PAYLOAD]",tag,Json.canonical({key=key,canonical_bytes=#text,copy_seconds=row.copy_seconds,encode_seconds=elapsed,count=cost.counts[key]}))
  end
  for key,row in cost.updates do row.key=key;print("[NATIVE_COST_CLIENT_UPDATE]",tag,Json.canonical(row)) end
  for key,row in cost.gaps do row.key=key;print("[NATIVE_COST_CLIENT_GAP]",tag,Json.canonical(row)) end
  for _,row in cost.trace do print("[NATIVE_COST_CLIENT_TRACE]",tag,Json.canonical(row)) end
  for _,row in cost.phases do print("[NATIVE_COST_CLIENT_PHASE]",tag,Json.canonical(row)) end
  for _,row in cost.marks do print("[NATIVE_COST_CLIENT_MARK]",tag,Json.canonical(row)) end
  print("[NATIVE_COST_CLIENT_END]",tag,Json.canonical({copy_seconds=cost.copySeconds,packets=#cost.trace,clock_scale=10,online=false}))
 end
