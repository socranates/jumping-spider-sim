"""Bind observed diagnostic samples; canonical sizes are not wire bytes."""
from pathlib import Path
import argparse,hashlib,json,re,statistics,subprocess,sys
H=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--log',type=Path,required=True);p.add_argument('--artifact',type=Path,required=True);p.add_argument('--run',required=True);p.add_argument('--prefix',default='native-attempt1');p.add_argument('--check',action='store_true');a=p.parse_args()
assert re.fullmatch(r'native-attempt\d+',a.prefix)
manifest=json.loads((a.artifact/'manifest.json').read_text());prepared=H/(a.prefix.replace('native-','native-prepared-')+'.json')
assert json.loads(prepared.read_text())['place_sha256']==manifest['place_sha256']
verify=[sys.executable,str(H/'verify-native-prepared.py'),'--out',str(a.artifact),'--receipt',prepared.name,'--check']
if a.prefix=='native-attempt1':verify+=['--server-source','native-attempt1-server.luau']
subprocess.run(verify,check=True,capture_output=True)
assert sha((a.artifact/'Windowsill-native-new-application.rbxlx').read_bytes())==manifest['place_sha256']
rows=a.log.read_text(encoding='utf8',errors='replace').splitlines()
start=next(i for i,s in enumerate(rows) if '[FLog::CreatorOutput] [NEW_APP_NATIVE_SERVER_BEGIN] '+a.run+' ' in s)
guard=max(i for i,s in enumerate(rows[:start]) if '[FLog::CreatorOutput] [NEW_APP_NATIVE_GUARD]' in s)
assert manifest['source']+' 265 memory_only unbound do_not_publish' in rows[guard]
following=[i for i,s in enumerate(rows) if i>start and '[FLog::CreatorOutput] [NEW_APP_NATIVE_GUARD]' in s]
selected=[];stack=False
for s in rows[guard:following[0] if following else len(rows)]:
 if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]',s) and ' > ' not in s:selected.append(s);stack=True
 elif stack and s and not re.match(r'^\d{4}-\d\d-\d\dT',s):selected.append(s)
 else:stack=False
raw=('\n'.join(selected)+'\n').encode();text=raw.decode()
passed=re.findall(r'\[NEW_APP_NATIVE_CLIENT_PASS\] '+a.run+r' (\d+) (\{.*\})',text)
failed=f'[NEW_APP_NATIVE_CLIENT_FAIL] {a.run} ' in text or f'[NEW_APP_NATIVE_SERVER_FAIL] {a.run} ' in text
assert passed or failed,'Wait for the existing run to finish'
samples={}
for marker,record in re.findall(r'\[NATIVE_COST_([A-Z_]+)\] '+a.run+r' (\{.*\})',text):samples.setdefault(marker,[]).append(json.loads(record))
result=dict(source=manifest['source'],run=a.run,place_sha256=manifest['place_sha256'],manifest_sha256=sha((a.artifact/'manifest.json').read_bytes()),
 diagnostics=manifest['diagnostic_inputs'],terminal='failed' if failed else 'passed',output_sha256=sha(raw),
 clock_scale=10,memory_store=True,engine_codec=True,real_remote_events=True,online=False,published=False,
 canonical_bytes_are_not_wire_bytes=True,copy_observer_overhead_included_in_elapsed=True,samples=samples)
if not failed:
 assert len(passed)==1 and int(passed[0][0])==70 and '[FLog::CreatorError]' not in text
 assert samples['CLIENT_END'] and samples['SERVER_END']
 result['client_summary']=json.loads(passed[0][1]);result['client_checks']=70
 assert result['client_summary']['server_checks']==10
 assert len(samples['CLIENT_TRACE'])==samples['CLIENT_END'][0]['packets']
 assert len(samples['SERVER_TRACE'])==samples['SERVER_END'][0]['packets']
 received=[x for x in samples['CLIENT_TRACE'] if x['direction']=='in']
 def key(x):return (x.get('epoch'),x.get('sequence'),x['kind'])
 sends={key(x):x for x in samples['SERVER_TRACE']}
 assert len(sends)==len(samples['SERVER_TRACE']),'Server trace identity repeated'
 seen=set();delays=[];replays=[]
 for x in received:
  k=key(x);assert k in sends,'Unmatched server send/client receipt'
  if k in seen:replays.append(x);continue
  seen.add(k);delays.append(dict(kind=x['kind'],seconds=x['t']-sends[k]['t'],sequence=x['sequence'],epoch=x['epoch']))
 # The fixture deliberately replays one old grant directly through the Remote;
 # its original-send timestamp must never be called a network delivery delay.
 assert len(replays)==1 and replays[0]['kind']=='decision'
 result['deliberate_old_grant_replay_receipts_excluded']=replays
 result['send_to_callback']=delays
 result['send_to_callback_summary']=dict(count=len(delays),min_seconds=min(x['seconds'] for x in delays),median_seconds=statistics.median(x['seconds'] for x in delays),max_seconds=max(x['seconds'] for x in delays),negative_samples=sum(x['seconds']<0 for x in delays))
 marks={x['name']:x['t'] for x in samples['CLIENT_MARK']}
 spans={'main_choice_to_adoption':('main_continue_choice','main_adoption_applied'),'main_release_ack_to_playing':('main_release_ack','main_recovered_playing')}
 for mode in ['main','free','easy']:
  spans[mode+'_checkpoint_preparation']=(mode+'_checkpoint_begin',mode+'_checkpoint_prepared')
  spans[mode+'_checkpoint_to_stored']=(mode+'_checkpoint_begin',mode+'_checkpoint_stored')
 result['real_elapsed_spans']={name:marks[end]-marks[begin] for name,(begin,end) in spans.items()}
if a.check:
 assert (H/(a.prefix+'.txt')).read_bytes()==raw
 assert json.loads((H/(a.prefix+'.json')).read_text())==result,'Recorded cost result differs from raw evidence'
else:
 for suffix,data in [('.txt',raw),('.json',(json.dumps(result,indent=2)+'\n').encode())]:
  path=H/(a.prefix+suffix);assert not path.exists(),'Preserve earlier evidence';path.write_bytes(data)
print(json.dumps({k:v for k,v in result.items() if k not in ['samples','send_to_callback']},indent=2))
