"""Actual replacement/service account visits over the qualified Profile cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def build(focused=False):
 base=load('service_profile',H/'run-profile.py');bundle,paths=base.build();r=load('service_core',ROOT/'roblox_port/tests/run.py')
 facade='(function()\n'+(H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 operation='(function()\n'+(H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 def io(path):return r.requires(r.strict(path.read_text(encoding='utf8').replace('require(script.Parent.RecoveryOperationAdmission)',operation)))
 before=io(H/'ordinary-io.luau');assert bundle.count(before)==1;bundle=bundle.replace(before,io(H/'ordinary-io-service.luau'))
 ordinary='(function()\n'+io(H/'ordinary-io-service.luau')+'\nend)()'
 def code(path):
  text=path.read_text(encoding='utf8').replace('require(Shared.Persistence.OrdinaryRequestAdmission)',ordinary)
  text=text.replace('require(Shared.Persistence.RecoveryOperationAdmission)',operation)
  text=text.replace('require(script.Parent.RecoveryProfileOwnerPrototype)','__profileOwnerPrototype').replace('require(Shared.Persistence.ReplacementProtocolPrototype)','__replacementProtocol')
  return r.requires(r.strict(text))
 for old,new in [(ROOT/'roblox_port/src/Server/SaveService.luau',H/'save-service.luau'),
  (ROOT/'docs/save-slot-isolation/replacement-owner-prototype.luau',H/'replacement-owner.luau'),
  (ROOT/'docs/save-slot-isolation/replacement-service-prototype.luau',H/'replacement-service.luau')]:
  before=code(old);assert bundle.count(before)==1,old.name;bundle=bundle.replace(before,code(new));paths.append(new)
 account='local __accountLifetimes=(function()\n'+code(H/'account-lifetimes.luau')+'\nend)()\n'
 fixture=ROOT/'docs/save-slot-isolation/replacement-tests.luau';text=fixture.read_text(encoding='utf8').split('-- A player can leave before a cooperative initial factory',1)[0]
 assert text.endswith(' return f\nend\n');text=text.replace('runReplacementChecks','runAccountServiceChecks',1)
 gate='(function()\n'+(H/'worker-admission.luau').read_text(encoding='utf8')+'\nend)()'
 text=text.replace('local count=0','local Gate='+gate+'\nlocal count=0',1)
 text=text.replace('  local now=f.clock.now;local recent={}','  f.starts=(f.starts or 0)+1\n  local now=f.clock.now;local recent={}',1)
 text=text.replace('check(#recent<=Rules.REQUESTS_PER_MINUTE or t and t.stage==','check(f.g~=nil or #recent<=Rules.REQUESTS_PER_MINUTE or t and t.stage==',1)
 text=text.replace(' function ds:UpdateAsync(key,fn)\n',''' function ds:UpdateAsync(key,fn)
  requested()
  local initial=if key=="P_46001" then f.pauseInitialStage else nil
  if initial then f.pauseInitialStage=nil end
''',1)
 marker='  requested()\n  local ok,value,why=f.b:update(key,fn);if not ok then error(why) end;return value';assert text.count(marker)==1
 text=text.replace(marker,'''  if initial=="before" then f.native=coroutine.running();coroutine.yield("account-before-callback") end
  local ok,value,why=f.b:update(key,fn);if not ok then error(why) end
  if initial=="after" then f.native=coroutine.running();coroutine.yield("account-after-commit") end
  if f.loseCleanupAck and f.owner and f.owner.session.closed and f.accounts.visits["46001"].cleanup and key=="P_46001" then f.loseCleanupAck=false;error("synthetic service unavailable after committed cleanup") end
  return value''',1)
 marker='  local ok,value,why=f.b:read(key);if not ok then error(why) end;return value';assert text.count(marker)==1
 text=text.replace(marker,'''  local ok,value,why=f.b:read(key);if not ok then error(why) end
  if f.pauseInitialRest and key=="R_46001_main" then f.pauseInitialRest=false;f.native=coroutine.running();coroutine.yield("account-rest-return") end
  return value''',1)
 marker=' local server=__replacementService.new({backend=Backend.new(ds,codec),now=function() return f.clock.now end,sleep=function(dt)';assert text.count(marker)==1
 end=text.index('  spawn=function(fn,...)',text.index(marker))
 original=text[text.index(marker):end]
 replacement=''' local now=function() return f.clock.now end
 local function sleep(dt)
  f.clock.now+=dt
  if f.onSleep then f.onSleep(dt) end
  if f.releaseNative and f.native and coroutine.status(f.native)=="suspended" then local co=f.native;f.native=nil;local ok,why=coroutine.resume(co);assert(ok,why) end
  if f.resumeClose and coroutine.status(f.resumeClose)=="suspended" then local ok,why=coroutine.resume(f.resumeClose);assert(ok,why) end
 end
 f.budget={read=1000,write=1000};f.g=Gate.new({now=now,available=function() return f.budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 f.seeds=0;f.accounts=__accountLifetimes.new(f.g,{now=now,sleep=sleep,legacyHistory=function(user)
  f.seeds+=1;if f.historyHook then return f.historyHook(user) end;return options.legacyHistory or {}
 end})
 local server=__replacementService.new({backend=Backend.new(ds,codec),now=now,sleep=sleep,accountLifetimes=f.accounts,
'''
 text=text.replace(original,replacement,1)
 text=text.replace('  keyOf=function()','  keyOf=function(who)',1).replace('return if options.changingKey and f.keyLookups>1 then 46002 else 46001','return if options.changingKey and f.keyLookups>1 then 46002 else who.UserId',1)
 marker='  ownerFactory=function(config,emit)';assert text.count(marker)==1
 text=text.replace(marker,'''  newLifeFactory=if options.newLife then {new=function(rt) return __newLifePolicy.new(rt,{work={now=function() return 0 end}}) end} else nil,
'''+marker,1)
 marker='client=__replacementClient.new(cfg,{onPause=function()';assert text.count(marker)==1
 text=text.replace(marker,'client=__replacementClient.new(cfg,{onNewState=if options.newLife then function(state) f.newState=state end else nil,onPause=function()',1)
 marker='validate=function(mode,record)\n';assert text.count(marker)==1
 text=text.replace(marker,'validate=function(mode,record,retired)\n   if retired and SaveRest.isRetired(record) then return SaveRest.bounded(record,10,3)==nil and #SaveRest.SPECS[mode].validate(record)==0 end\n',1)
 marker='  spawn=function(fn,...) fn(...) end';assert text.count(marker)==1
 text=text.replace(marker,'''  spawn=function(fn,...)
   f.spawnCount=(f.spawnCount or 0)+1
   if f.failSpawn then error("synthetic executor refused task") end
   if f.deferSpawn then
    local args=table.pack(...);f.tasks=f.tasks or {}
    table.insert(f.tasks,coroutine.create(function() fn(table.unpack(args,1,args.n)) end))
   else fn(...) end
  end''',1)
 text=text.replace('   local prior=f.owner\n   if prior then check(prior:replacementClosed(),"new owner constructed before exact old closure") end', '''   local prior
   for _,old in f.owners do if tostring(old.session.cfg.userId)==tostring(config.userId) then prior=old end end
   if prior then check(prior.session.closed and not prior.session.busy and not f.g:live(prior.session.ordinaryAdmission.scope),"new owner overlaps old account authority") end''',1)
 marker='   f.owner=__replacementOwner.new(config,emit,deps,profiles);table.insert(f.owners,f.owner);return f.owner';assert text.count(marker)==1
 text=text.replace(marker,'''   local owned=__replacementOwner.new(config,emit,deps,profiles)
   if config.userId==46001 then f.owner=owned else f.extraOwner=owned end
   table.insert(f.owners,owned);if f.configureOwner then f.configureOwner(owned) end;return owned''',1)
 tests=(H/'service-tests.luau').read_text(encoding='utf8')
 marker='print("ACCOUNT_SERVICE passed="..count.." failed=0 groups="..groups)';assert tests.count(marker)==1
 tests=tests.replace(marker,(H/'service-more-tests.luau').read_text(encoding='utf8')+'\n'+(H/'service-replacement-tests.luau').read_text(encoding='utf8')+'\n'+(H/'service-driver-tests.luau').read_text(encoding='utf8')+'\n'+(H/'service-new-tests.luau').read_text(encoding='utf8')+'\n'+(H/'service-timeout-test.luau').read_text(encoding='utf8')+'\n'+marker,1)
 text+=tests
 assert bundle.endswith('end\n');bundle=bundle[:-4]+account+r.requires(text)+'\nend\n'
 if focused:bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1]!='runAccountServiceChecks' else m[0],bundle)
 return bundle,list(dict.fromkeys(paths+[H/'ordinary-io-service.luau',H/'account-lifetimes.luau',fixture,H/'service-tests.luau',H/'service-more-tests.luau',H/'service-replacement-tests.luau',H/'service-driver-tests.luau',H/'service-new-tests.luau',H/'service-timeout-test.luau']))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix);out=H/(prefix+'-output.txt');assert not out.exists()
 focused='--focused' in sys.argv;bundle,paths=build(focused);sha=lambda b:hashlib.sha256(b).hexdigest();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
 with tempfile.TemporaryDirectory(prefix='windowsill-account-service-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),inputs=inputs,
  bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,focused=focused,
  account_service_candidate=True,provider='memory-injected-DataStoreBackend',clock='synthetic',normal_startup_installed=False,native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
