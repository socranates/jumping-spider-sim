from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('folder',type=Path);p.add_argument('--run',required=True);a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.folder/'manifest.json').read_text());source='47241c994c7b2fbd4eb3fed0c4affd75ece88c10'
assert m['source']==source and len(m['scripts'])==221 and m['persistence_disabled']
assert sha((a.folder/'Windowsill-save-cost-review.rbxlx').read_bytes())==m['place_sha256']
assert next(r['sha256'] for r in m['scripts'] if r['path']=='StarterPlayer.StarterPlayerScripts.Client.SilkPlayback')==sha((HERE/'native-probe.luau').read_bytes())
with a.log.open(encoding='utf8',errors='replace') as f:rows=[s.rstrip('\n') for s in f if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]',s)]
begins=[i for i,s in enumerate(rows) if re.search(r'\[NATIVE_SAVE_COST_BEGIN\] '+a.run+' '+source+'$',s)];assert len(begins)==1
begin=begins[0];guards=[i for i,s in enumerate(rows[:begin]) if '[NATIVE_SAVE_COST_GUARD] '+source+' 221 persistence_disabled' in s];assert guards
ends=[i for i,s in enumerate(rows) if i>begin and '[NATIVE_SAVE_COST_DONE] '+a.run+' 13 local_transport_only' in s];assert len(ends)==1
kept=rows[guards[-1]:ends[0]+1]
assert not any('[FLog::CreatorError]' in s or '[NATIVE_SAVE_COST_FAIL]' in s for s in kept)
stages=[]
for s in kept:
 r=re.search(r'\[NATIVE_SAVE_COST_STAGE\] '+a.run+r' (\S+) ([0-9.]+) (\d+) ([0-9.]+)$',s)
 if r:stages.append(dict(name=r[1],elapsed_ms=float(r[2]),frame_samples=int(r[3]),max_frame_gap_ms=float(r[4])))
assert [s['name'] for s in stages]==['capture_full_world','receive_full_offer','five_immutable_repeats','actual_menu_continue_restore','actual_local_rest_and_queue','grant_and_actual_upload_copy_local_receipt']
record=[re.search(r'\[NATIVE_SAVE_COST_RECORD\] '+a.run+r' (\d+) (\d+)$',s) for s in kept];record=[r for r in record if r];assert len(record)==1 and record[0][1]=='233'
b=('\n'.join(kept)+'\n').encode();(HERE/'native-output.txt').write_bytes(b)
r=dict(source=source,run_id=a.run,assertions=13,stages=stages,region_initialization_attempts=233,resident_region_count_measured=False,all_regions_materialized_verified=False,record_canonical_chars=int(record[0][2]),place_sha256=m['place_sha256'],probe_sha256=sha((HERE/'native-probe.luau').read_bytes()),output_sha256=sha(b),creator_errors=0,creator_warnings=sum('[FLog::CreatorWarning]' in s for s in kept),persistence_disabled=True,native_controller_local_transport_completed=True,low_system_resources_warning_seen=True,concurrent_windows_full_session=63820,causal_performance_improvement_proven=False,typical_frame_rate_proven=False,remote_transfer_measured=False,online_save_accessed=False,online_rejoin_verified=False,physical_device_verified=False,published=False,scope='Actual Studio controller/local checkpoint path through a large Normal record and injected local transport. Initialization was attempted for233 regions subject to the existing streaming/readiness gates; actual resident/materialized region counts were not measured. Timings were collected under low-resource warning and concurrent CLI test load; not a causal FPS, network, phone or online-rejoin result.')
(HERE/'native-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
