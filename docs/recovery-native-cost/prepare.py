"""Derive an instrumented diagnostic from the qualified native fixture.

Production and private candidates remain unchanged; only the two diagnostic
scripts add bounded observational copies/timing. Never publish this model.
"""
from pathlib import Path
import argparse
H=Path(__file__).resolve().parent;BASE=H.parent/'new-life-application'
parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');parser.add_argument('--cadence',choices=['20hz','frame'],default='frame');args=parser.parse_args()
def emit(name,text):
 path=H/name
 if args.check:assert path.read_bytes()==text.encode(),name+' differs from its inputs'
 else:path.write_text(text,encoding='utf8',newline='\n')
def change(text,old,new):
 assert text.count(old)==1,old
 return text.replace(old,new)
c=(BASE/'native-client.luau').read_text(encoding='utf8')
c=change(c,' local replies={};local serial=0',' local replies={};local serial=0\n'+(H/'client-observer.luau').read_text())
c=change(c,'    return Client.new(cfg,options)','    cfg.findRemotes=observedRemotes(cfg.findRemotes)\n    return Client.new(cfg,options)')
c=change(c,'  app=d.saveState.application;client=app.client','  app=d.saveState.application;client=app.client;observeApplication()')
c=change(c,'offered("main");d.openMenu(true);check(d.menu:choose("Continue"),','offered("main");d.openMenu(true);mark("main_continue_choice");check(d.menu:choose("Continue"),')
c=change(c,'  check(app.phase=="entry" and app:held(),"native adoption resumed before grant")','  mark("main_adoption_applied")\n  check(app.phase=="entry" and app:held(),"native adoption resumed before grant")')
c=change(c,'  paused();after=inspect("release_ack")','  paused();mark("main_release_ack");after=inspect("release_ack")')
c=change(c,'  check(app.recoveredPlaying and not app:held(),','  mark("main_recovered_playing")\n  check(app.recoveredPlaying and not app:held(),')
c=change(c,'  local kept=d.life.save()','  mark(mode.."_checkpoint_begin");local kept=d.life.save()')
c=change(c,'  check(kept.ok,"actual native life.save failed: "..tostring(kept.message))','  mark(mode.."_checkpoint_prepared")\n  check(kept.ok,"actual native life.save failed: "..tostring(kept.message))')
c=change(c,'  check(client:decision(mode).state=="writable","native normal checkpoint lost its grant")','  mark(mode.."_checkpoint_stored")\n  check(client:decision(mode).state=="writable","native normal checkpoint lost its grant")')
# Capture the prior epoch before any yielding observer/pause can see completion.
c=change(c,'  newMenu("easy");paused();epoch=client.bound.epoch','  epoch=client.bound.epoch;newMenu("easy");paused()')
c=change(c,'  print("[NEW_APP_NATIVE_CLIENT_PASS]",tag,checks,','  reportCost()\n  print("[NEW_APP_NATIVE_CLIENT_PASS]",tag,checks,')
emit('native-client.luau',c)
s=(BASE/'native-server.server.luau').read_text(encoding='utf8')
s=change(s,'local ds={}\n','local ds={}\n'+(H/'server-observer.luau').read_text()+'\n')
s=change(s,'function ds:GetAsync(key,options)\n','function ds:GetAsync(key,options)\n local started=os.clock()\n')
s=change(s,'local ok,value,why=store:read(key);assert(ok,why);return value','local ok,value,why=store:read(key);assert(ok,why);provider("read",started);return value')
s=change(s,'function ds:UpdateAsync(key,fn)\n','function ds:UpdateAsync(key,fn)\n local started=os.clock()\n')
s=change(s,'local ok,value,why=store:update(key,fn);assert(ok,why);return value','local ok,value,why=store:update(key,fn);assert(ok,why);provider("update",started);return value')
s=change(s,'   toClient:FireClient(player,message)','   wire(message);toClient:FireClient(player,message)')
s=change(s,' print("[NEW_APP_NATIVE_SERVER_END]",tag,Json.canonical(snapshot()))',' print("[NEW_APP_NATIVE_SERVER_END]",tag,Json.canonical(snapshot()));reportCost()')
step_wait='Run.Heartbeat:Wait()' if args.cadence=='frame' else 'task.wait(.05)'
s=change(s,'do task.wait(.05);service:step() end','do '+step_wait+';measuredStep(service,owners[#owners]) end')
emit('native-server.server.luau',s)
build=(BASE/'build-native.py').read_text(encoding='utf8')
build=change(build,"str(H/'verify-private.py')","str(ROOT/'docs/new-life-application/verify-private.py')")
emit('build-native.py',build)
verify=(BASE/'verify-native-prepared.py').read_text(encoding='utf8').replace('docs/new-life-application/native-','docs/recovery-native-cost/native-')
verify=change(verify,"a=parser.parse_args()","parser.add_argument('--server-source',default='native-server.server.luau')\na=parser.parse_args()")
verify=change(verify,"client_source=(H/a.client_source).resolve();assert client_source.parent==H","client_source=(H/a.client_source).resolve();assert client_source.parent==H\nserver_source=(H/a.server_source).resolve();assert server_source.parent==H")
verify=verify.replace("H/'native-server.server.luau'","server_source")
emit('verify-native-prepared.py',verify)
print('Instrumented diagnostics checked.' if args.check else 'Instrumented diagnostics derived; production/private sources unchanged.')
