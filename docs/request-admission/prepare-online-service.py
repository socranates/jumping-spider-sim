"""Derive test-universe-only real-store/actual-disconnect diagnostics."""
from pathlib import Path
import argparse,json,uuid
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--user');p.add_argument('--check',action='store_true');p.add_argument('--resume',action='store_true');a=p.parse_args()
config=H/'online-service-config.json'
if a.check or a.resume:
 user=json.loads(config.read_text(encoding='utf8'))['user'];assert not a.user or a.user==user
else:
 assert not config.exists(),'Preserve existing diagnostic identity';user=a.user or 'qa_'+uuid.uuid4().hex[:16]
 config.write_text(json.dumps(dict(user=user,store='WindowsillTest_v1',universe=10771634917,place=109879630247781,production_universe=10771103250,production_place=120119801868085,published=False),indent=2)+'\n',encoding='utf8',newline='\n')
def emit(name,text):
 path=H/name
 if a.check:assert path.read_bytes()==text.encode(),name
 else:path.write_text(text,encoding='utf8',newline='\n')
def change(text,old,new):
 assert text.count(old)==1,old;return text.replace(old,new)
s=(H/'native-service-server.server.luau').read_text(encoding='utf8')
s=change(s,'game.PlaceId==0','game.GameId==10771634917 and game.PlaceId==109879630247781')
s=change(s,'local Memory=shared("Persistence","MemoryBackend")\n','')
s=change(s,'local function now() return 200+(WS:GetServerTimeNow()-WS:GetAttribute("NativeApplicationClockStart"))*1 end','local function now() return WS:GetServerTimeNow() end')
s=s.replace('return 46001','return '+json.dumps(user)).replace('46001',user)
start=s.index('local store=Memory.new()');end=s.index('local checks=0',start)
observer=(ROOT/'docs/recovery-native-cost/server-observer.luau').read_text(encoding='utf8').replace('clock_scale=10','clock_scale=1').replace('online=false','online=true')
storage='''local TEST_USER="USER";local CONTROL_KEY="Q1_"..TEST_USER
local allowedKeys={[CONTROL_KEY]=true,["P_"..TEST_USER]=true,["A1_"..TEST_USER.."_progress"]=true,["A1_"..TEST_USER.."_index"]=true}
for _,mode in Rules.MODES do for _,prefix in {"R_","A1_","M1_"} do allowedKeys[prefix..TEST_USER.."_"..mode]=true end end
local store={data={}};local originals={};local owners={};local errors={}
local optionsCreated,optionsDestroyed=0,0
local DataStores=game:GetService("DataStoreService")
local actual=DataStores:GetDataStore("WindowsillTest_v1")
local ds={};local nativeStarts={};local providerActive=0;local callbackThreads={}
local function nativeStart(kind,key)
 assert(allowedKeys[key],"refusing a key outside the unique synthetic namespace")
 table.insert(nativeStarts,{kind=kind,key=key,at=now()});providerActive+=1
end
OBSERVER
function ds:GetAsync(key,options)
 nativeStart("read",key);local at=os.clock()
 if options then assert(options.UseCache==false);optionsCreated+=1;options.Destroying:Connect(function() optionsDestroyed+=1 end) end
 local ok,value=pcall(function() return actual:GetAsync(key,options) end)
 providerActive-=1;provider("read",at);assert(ok,value)
 store.data[key]=Json.copy(value);return value
end
function ds:UpdateAsync(key,fn)
 nativeStart("update",key);local at=os.clock()
 local issuing=coroutine.running()
 local ok,value=pcall(function() return actual:UpdateAsync(key,function(old)
  if string.sub(key,1,2)=="R_" and callbackThreads[key]==nil then
   callbackThreads[key]=coroutine.running()~=issuing
   print("[ONLINE_SERVICE_CALLBACK_THREAD]",key,"separate="..tostring(callbackThreads[key]))
  end
  return fn(old)
 end) end)
 providerActive-=1;provider("update",at);assert(ok,value)
 if value~=nil then store.data[key]=Json.copy(value) end;return value
end
'''.replace('"USER"',json.dumps(user)).replace('OBSERVER',observer)
s=s[:start]+storage+s[end:]
old='available=function() return {read=1000,write=1000} end';assert s.count(old)==2
s=s.replace(old,'available=function() return {read=DataStores:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead),write=DataStores:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)} end',1)
s=s.replace('headroom=0','headroom=2')
# Bootstrap needs digest and checks, so put it between the helper and snapshot.
marker='local function snapshot()'
s=change(s,marker,(H/'online-service-bootstrap.luau').read_text(encoding='utf8')+'\n'+marker)
s=change(s,'local current=owners[#owners]',"""local current=owners[#owners]
 local detail
 if current then
  local j=current.newLifeJob;local policy=current.newLifePolicy;local request=current.newLifeRequest;local session=current.session
  detail={sessionState=session.state,reason=session.reason,closed=session.closed,busy=session.busy,
   requestState=request and request.state,requestProblem=request and request.problem,
   jobState=j and j.state,jobPhase=j and j.phase,jobProblem=j and j.problem,
   leaseLost=policy and policy.leaseLost,leaseState=policy and policy.leaseJob and policy.leaseJob.state,
   leaseProblem=policy and policy.leaseJob and policy.leaseJob.problem}
 end""")
s=change(s,'return {run=tag,archives=', 'return {run=tag,detail=detail,resumingPartial=resumingPartial,rejoining=rejoining,priorPayloadDigests=priorPayloadDigests,archives=')
s=change(s,' -- Build the synthetic old garden',' if not rejoining and not resumingPartial then\n -- Build the synthetic old garden')
s=s.replace('store:poke(', 'seed(')
s=change(s,' catalog=assert(Templates.new(world))',' end\n gate:close(setup)\n catalog=assert(Templates.new(world))')
s=change(s,'elseif action=="finish" then service:removePlayer(player);WS:SetAttribute("NativeApplicationFinished",true)', '''elseif action=="arm_leave" then
   WS:SetAttribute("OnlineServiceLeaveArmed",true)
   task.delay(2,function() if selectedPlayer.Parent then selectedPlayer:Kick("Isolated save diagnostic: real departure") end end)''')
start=s.index(' -- Native initial-load cancellation');end=s.index(' selectedPlayer=readyPlayer;',start);s=s[:start]+s[end:]
s=change(s,' Players.PlayerRemoving:Connect(function(player) service:removePlayer(player) end)\n game:BindToClose(function() service:shutdown() end)',(H/'online-service-departure.luau').read_text(encoding='utf8'))
s=change(s,'while selectedPlayer.Parent and not WS:GetAttribute("NativeApplicationFinished")','while not WS:GetAttribute("NativeApplicationFinished") and not WS:GetAttribute("NativeApplicationServerFailed")')
s=change(s,' print("[NEW_APP_NATIVE_SERVER_END]",tag,Json.canonical(snapshot()));reportCost()', '''assert(optionsCreated==optionsDestroyed and #errors==0 and actualRemovals==1,"online departure leaked options/errors or was not a real removal")
 print("[ONLINE_SERVICE_SERVER_PASS]",tag,Json.canonical({checks=checks,rejoining=rejoining,user=TEST_USER,optionsCreated=optionsCreated,optionsDestroyed=optionsDestroyed,errors=#errors,actual_removals=actualRemovals}))
 reportCost()''')
s=s.replace('storage=memory','storage=WindowsillTest_v1 online=true')
emit('online-service-server.server.luau',s)
c=(H/'native-service-client.luau').read_text(encoding='utf8').replace('46001',user)
c=change(c,'game.PlaceId==0','game.GameId==10771634917 and game.PlaceId==109879630247781')
c=change(c,'local replies={};local serial=0','local appliedRestDigest;local replies={};local serial=0')
c=change(c,'  local start=assert(WS:GetAttribute("NativeApplicationClockStart"))\n','')
c=change(c,'cfg.now=function() return 200+(WS:GetServerTimeNow()-start)*1 end','''cfg.now=function() return WS:GetServerTimeNow() end
    local restore=cfg.continuation.onRestore
    cfg.continuation=table.clone(cfg.continuation)
    cfg.continuation.onRestore=function(mode,record,serial)
     appliedRestDigest=Json.checksum((assert(Json.canonical(record))))
     return restore(mode,record,serial)
    end''')
c=change(c,'  local before=inspect();local epoch=client.bound.epoch',(H/'online-service-rejoin-client.luau').read_text(encoding='utf8')+'\n  local before=inspect();local epoch=client.bound.epoch')
c=change(c,'inspect("finish");frames(3);after=inspect()','inspect("arm_leave");frames(3);after=inspect()')
c=change(c,'check(after.lockReleased and after.errors==0 and after.optionsCreated>0 and after.optionsCreated==after.optionsDestroyed,','check(not after.lockReleased and after.errors==0 and after.optionsCreated>0,')
c=c.replace('memory_store=true','memory_store=false').replace('online=false','online=true').replace('memory store','real isolated test store')
c=change(c,'WS:SetAttribute("NativeApplicationFinished",true);WS:SetAttribute("NativeApplicationPassed",ok)','WS:SetAttribute("NativeApplicationClientFinished",true);WS:SetAttribute("NativeApplicationPassed",ok)')
c=change(c,'  local before=inspect();local epoch=client.bound.epoch','  local before=inspect();local epoch=client.bound.epoch;local after\n  if not WS:GetAttribute("OnlineServiceResumePartial") then')
c=change(c,'  local after=inspect()','  after=inspect()')
c=change(c,'  for _,mode in {"main","free"} do','  end -- initial recovery was already observed in the retained failed run\n  for _,mode in {"main","free"} do')
c=change(c,' if not ok then warn("[NEW_APP_NATIVE_CLIENT_FAIL]",tag,tostring(why)) end',""" if not ok then
  warn("[NEW_APP_NATIVE_CLIENT_FAIL]",tag,tostring(why))
  local seen,observation=pcall(inspect)
  if seen then print("[ONLINE_SERVICE_FAILURE_DETAIL]",tag,Json.canonical({detail=observation.detail,gate=observation.accountGate,providerActive=observation.providerActive})) end
 end""")
emit('online-service-client.luau',c)
b=(H/'build-native-service.py').read_text(encoding='utf8')
b=b.replace("H/'native-service-client.luau'","H/'online-service-client.luau'").replace("H/'native-service-server.server.luau'","H/'online-service-server.server.luau'")
b=b.replace("H/'prepare-native-service.py'","H/'prepare-online-service.py'")
b=change(b,"project['tree']['Workspace']['$attributes']=",'''project.update(name='WindowsillOnlineAdmissionDiagnostic',servePort=34873,servePlaceIds=[0,109879630247781],placeId=109879630247781,gameId=10771634917)
 serverNode={'$className':'Folder','$ignoreUnknownInstances':False}
 for path in sorted((src/'Server').glob('*.luau')):
  name=path.name.removesuffix('.luau').removesuffix('.server')
  serverNode[name]={'$path':str(path)}
  if name=='Persistence':serverNode[name]['$properties']={'Disabled':True}
 project['tree']['ServerScriptService']['Server']=serverNode
 project['tree']['Workspace']['$attributes']=''')
b=b.replace("'Windowsill-native-service.rbxlx'","'Windowsill-online-service.rbxlx'").replace('game.PlaceId==0','game.GameId==10771634917 and game.PlaceId==109879630247781').replace('[NATIVE_SERVICE_GUARD]','[ONLINE_SERVICE_GUARD]').replace('memory_only unbound do_not_publish','isolated_test_store never_production do_not_publish')
b=b.replace('memory_store=True','memory_store=False').replace('executed=False,published=False','executed=False,published=False,universe=10771634917,place_id=109879630247781,synthetic_user='+repr(user))
b=change(b,"verification=json.loads((H/'service-verification.json').read_text(encoding='utf8'))","""subprocess.run([sys.executable,str(H/'qualify-native-callback.py'),'--check'],check=True)
 verification=json.loads((H/'native-callback-qualification.json').read_text(encoding='utf8'))""")
b=b.replace("H/'service-types-qualified-1-types.json'","H/'native-callback-types-1-types.json'")
emit('build-online-service.py',b)
print('Online test identity:',user,'(unchanged)' if a.check or a.resume else '(new)')
