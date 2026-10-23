"""Retain bounded native diagnostics, never control Studio or a real store."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,statistics
H=Path(__file__).resolve().parent;sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--artifact',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--run',required=True);p.add_argument('--prefix',required=True);p.add_argument('--check',action='store_true');a=p.parse_args()
assert re.fullmatch(r'native-service-attempt\d+',a.prefix)
prepared=a.prefix.replace('native-service-','native-service-prepared-')+'.json'
subprocess.run([sys.executable,str(H/'verify-native-service.py'),'--out',str(a.artifact),'--receipt',prepared,'--check'],check=True,capture_output=True)
manifest=json.loads((a.artifact/'manifest.json').read_text(encoding='utf8'))
rows=a.log.read_text(encoding='utf8',errors='replace').splitlines()
begin=next(i for i,row in enumerate(rows) if '[FLog::CreatorOutput] [NEW_APP_NATIVE_SERVER_BEGIN] '+a.run+' ' in row)
guard=max(i for i,row in enumerate(rows[:begin]) if '[FLog::CreatorOutput] [NATIVE_SERVICE_GUARD] ' in row)
assert manifest['source']+f" {manifest['script_count']} memory_only unbound do_not_publish" in rows[guard]
following=[i for i,row in enumerate(rows[begin+1:],begin+1) if '[FLog::CreatorOutput] [NATIVE_SERVICE_GUARD] ' in row]
terminal=next((i+1 for i,row in enumerate(rows[begin:],begin) if any(marker+' '+a.run+' ' in row for marker in ['[NEW_APP_NATIVE_CLIENT_PASS]','[NEW_APP_NATIVE_CLIENT_FAIL]','[NEW_APP_NATIVE_SERVER_FAIL]'])),None)
assert terminal is not None,'Wait for a terminal native result'
selected=[];stack=False
for row in rows[guard:min(terminal,following[0]) if following else terminal]:
 if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]',row) and ' > ' not in row:selected.append(row);stack=True
 elif stack and row and not re.match(r'^\d{4}-\d\d-\d\dT',row):selected.append(row)
 else:stack=False
text='\n'.join(selected)+'\n'
passed=re.findall(r'\[NEW_APP_NATIVE_CLIENT_PASS\] '+a.run+r' (\d+) (\{.*\})',text)
failed=f'[NEW_APP_NATIVE_CLIENT_FAIL] {a.run} ' in text or f'[NEW_APP_NATIVE_SERVER_FAIL] {a.run} ' in text
assert passed or failed,'Only collect a terminal diagnostic; wait on the existing run'
samples={}
for marker,row in re.findall(r'\[NATIVE_COST_([A-Z_]+)\] '+a.run+r' (\{.*\})',text):samples.setdefault(marker,[]).append(json.loads(row))
preflights=[json.loads(row) for row in re.findall(r'\[NATIVE_SERVICE_PREFLIGHT\] '+a.run+r' (\{.*\})',text)]
ledger=[json.loads(row) for row in re.findall(r'\[NATIVE_SERVICE_LEDGER\] '+a.run+r' (\{.*\})',text)]
result=dict(source=manifest['source'],run=a.run,artifact=str(a.artifact.resolve()),place_sha256=manifest['place_sha256'],manifest_sha256=sha((a.artifact/'manifest.json').read_bytes()),
 diagnostics=manifest['diagnostic_inputs'],scripts=manifest['script_count'],production_untouched=manifest['untouched_production'],production_overrides=manifest['production_overrides'],
 terminal='failed' if failed else 'passed',output_sha256=sha(text.encode()),clock_scale=1,memory_store=True,engine_codec=True,real_remote_events=True,
 online_verified=False,published=False,normal_startup_installed=False,goal_complete=False,preflights=preflights,ledger=ledger,samples=samples,
 canonical_bytes_are_not_wire_bytes=True,observer_overhead_included=True,old_aggregate_budget_flag_is_not_typed_admission_wait=True)
if not failed:
 assert len(passed)==1 and '[FLog::CreatorError]' not in text
 assert len(preflights)==2 and [row['deferred'] for row in preflights]==[False,True]
 assert preflights[0]['starts']>1 and preflights[1]['starts']==0
 assert all(row['closed'] and row['active']==0 and row['scopes']==0 for row in preflights)
 assert len(ledger)==1 and ledger[0]['active']==0 and ledger[0]['scopes']==0
 assert len(samples.get('CLIENT_END',[]))==1 and len(samples.get('SERVER_END',[]))==1,'Wait for both observational reports'
 summary=json.loads(passed[0][1]);assert summary['clock_scale']==1 and summary['real_remote_events'] and summary['memory_store'] and not summary['online']
 end_rows=re.findall(r'\[NEW_APP_NATIVE_SERVER_END\] '+a.run+r' (.*)',text);assert len(end_rows)==1
 try:
  server=json.JSONDecoder().raw_decode(end_rows[0])[0];truncated=False
 except json.JSONDecodeError:
  # Studio truncates a CreatorOutput record at 1022 characters. Only retain
  # the complete fields before the owners array; never invent its lost tail.
  assert end_rows[0].count(',"owners":[')==1
  original_row=next(row for row in selected if '[NEW_APP_NATIVE_SERVER_END] '+a.run+' ' in row)
  assert len(original_row)==1022
  server=json.loads(end_rows[0].split(',"owners":[',1)[0]+'}');truncated=True
 assert server['checks']==summary['server_checks'] and server['lockReleased'] and server['errors']==0
 assert server['optionsCreated']==server['optionsDestroyed']==summary['options']
 assert server['accountGate']['scopes']==0 and server['nativeStarts']==ledger[0]['starts']
 result.update(native_verified=True,client_checks=int(passed[0][0]),server_checks=summary['server_checks'],client_summary=summary,
  server_summary_complete=not truncated,server_summary_available_fields=server)
 marks={row['name']:row['t'] for row in samples.get('CLIENT_MARK',[])}
 result['marks']=marks
 if 'main_continue_choice' in marks and 'main_recovered_playing' in marks:result['main_continue_real_seconds']=marks['main_recovered_playing']-marks['main_continue_choice']
 for mode in ['main','free','easy']:
  first=marks.get(mode+'_checkpoint_begin');last=marks.get(mode+'_checkpoint_stored')
  if first is not None and last is not None:result[mode+'_checkpoint_real_seconds']=last-first
 for role in ['CLIENT','SERVER']:
  steps=samples.get(role+'_STEP',[]) if role=='SERVER' else samples.get('CLIENT_UPDATE',[])
  if steps:result[role.lower()+'_observed_update_seconds']=sum(row['seconds'] for row in steps)
else:result['native_verified']=False
raw_path=H/(a.prefix+'.txt');receipt=H/(a.prefix+'.json')
if a.check:assert raw_path.read_bytes()==text.encode() and json.loads(receipt.read_text(encoding='utf8'))==result
else:
 assert not raw_path.exists() and not receipt.exists(),'Preserve previous evidence'
 raw_path.write_text(text,encoding='utf8',newline='\n');receipt.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps({k:v for k,v in result.items() if k!='samples'},indent=2))
