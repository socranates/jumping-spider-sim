"""Recheck the two scoped real-store receipts against their retained output."""
from pathlib import Path
import argparse,hashlib,json
H=Path(__file__).resolve().parent;sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
def read(name):return json.loads((H/name).read_text(encoding='utf8'))
def marker(text,name,run):
 rows=[line for line in text.splitlines() if '['+name+'] '+run+' ' in line]
 assert len(rows)==1,(name,len(rows))
 tail=rows[0].split('['+name+'] '+run+' ',1)[1]
 return json.JSONDecoder().raw_decode(tail[tail.index('{'):])[0]
guards=read('online-service-live-guards.json');prepared=read('online-service-prepared-attempt4.json')
manifest_hashes=[];results=[]
for number,run,client_checks,server_checks,options,starts,state in [
 (4,'1792800470163',52,18,188,222,'await_rejoin'),
 (5,'1792800884543',15,24,32,37,'done')]:
 prefix='online-service-attempt'+str(number)
 r=read(prefix+'-receipt.json');text=(H/(prefix+'-output.txt')).read_bytes()
 assert sha(text)==r['output_sha256'] and r['run']==run and r['terminal']=='passed'
 assert sha((H/(prefix+'-manifest.json')).read_bytes())==r['manifest_sha256']==prepared['manifest_sha256']
 manifest_hashes.append(r['manifest_sha256'])
 text=text.decode('utf8')
 assert '[NEW_APP_NATIVE_CLIENT_FAIL]' not in text and '[NEW_APP_NATIVE_SERVER_FAIL]' not in text
 client=marker(text,'NEW_APP_NATIVE_CLIENT_PASS',run)
 assert f'[NEW_APP_NATIVE_CLIENT_PASS] {run} {client_checks} ' in text and client['online'] and not client['memory_store']
 server=marker(text,'ONLINE_SERVICE_SERVER_PASS',run)
 assert server['checks']==server_checks and server['optionsCreated']==server['optionsDestroyed']==options
 assert server['actual_removals']==1 and server['errors']==0 and server['rejoining']==(number==5)
 departure=marker(text,'ONLINE_SERVICE_DEPARTURE_PASS',run)
 assert departure['state']==state and departure['lock_released'] and departure['scopes']==departure['provider_active']==0
 assert departure['actual_removals']==1 and departure['stored_keys']==11
 assert f'[ONLINE_SERVICE_PLAYER_REMOVING] {run} qa_3cb3b30963a84dc6 1 PlayerRemoving' in text
 ledger=marker(text,'NATIVE_SERVICE_LEDGER',run)
 assert ledger['starts']==starts and ledger['active']==ledger['scopes']==0
 assert ledger['read']==ledger['history'] and ledger['write']<=ledger['read']
 if number==4:
  assert '[ONLINE_SERVICE_PARTIAL_SOURCE] '+run in text
  for mode in ['main','free','easy']:assert '[NEW_APP_NATIVE_NEW_STORED] '+run+' '+mode in text
 else:assert '[ONLINE_SERVICE_REJOIN_SOURCE] '+run in text and client['rejoin']
 guard=next(g for g in guards if g['run']==run)
 assert guard['guard_sha256']==prepared['guard_sha256'] and ' 273 isolated_test_store never_production do_not_publish' in guard['line']
 results.append(dict(run=run,client_checks=client_checks,server_checks=server_checks,options_destroyed=options,sdk_starts=starts,state=state))
assert len(set(manifest_hashes))==1
result=dict(private_commit=read('native-callback-qualification.json')['private_commit'],production_source=prepared['source'],
 universe=10771634917,place=109879630247781,store='WindowsillTest_v1',synthetic_actor='qa_3cb3b30963a84dc6',
 runs=results,manifest_sha256=manifest_hashes[0],real_leave_rejoin_verified=True,
 retained_failure_resumed_without_reset=True,normal_startup_installed=False,published=False,goal_complete=False,
 scope='Unpublished local Studio, real storage, real clock and remotes; not public-server or general performance qualification')
path=H/'online-service-verification.json'
if a.check:assert read(path.name)==result
else:assert not path.exists();path.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(result,indent=2))
