from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('folder',type=Path);p.add_argument('--run',required=True);a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.folder/'manifest.json').read_text(encoding='utf8'))
assert len(m['scripts'])==223 and m['persistence_disabled']
assert sha((a.folder/'Windowsill-async-offers-review.rbxlx').read_bytes())==m['place_sha256']
assert next(r['sha256'] for r in m['scripts'] if r['path'].endswith('.SilkPlayback'))==sha((HERE/'native-probe.luau').read_bytes())
with a.log.open(encoding='utf8',errors='replace') as f:rows=[s.rstrip('\n') for s in f if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]',s)]
starts=[i for i,s in enumerate(rows) if '[NATIVE_ASYNC_OFFERS_BEGIN] '+a.run in s];assert len(starts)==1
guards=[i for i,s in enumerate(rows[:starts[0]]) if '[NATIVE_ASYNC_OFFERS_GUARD] '+m['source']+' 223 persistence_disabled' in s];assert guards
ends=[i for i,s in enumerate(rows) if i>starts[0] and '[NATIVE_ASYNC_OFFERS_DONE] '+a.run+' 20 local_transport_only' in s];assert len(ends)==1
kept=rows[guards[-1]:ends[0]+1]
assert not any('[FLog::CreatorError]' in s or '[NATIVE_ASYNC_OFFERS_FAIL]' in s for s in kept)
stages=[]
for line in kept:
 r=re.search(r'\[NATIVE_ASYNC_OFFERS_WORK\] '+a.run+r' (\S+) (\d+) ([0-9.]+) ([0-9.]+) ([0-9.]+) ([0-9.]+)$',line)
 if r:stages.append(dict(name=r[1],steps=int(r[2]),max_update_ms=float(r[3]),max_heartbeat_gap_ms=float(r[4]),total_update_ms=float(r[5]),elapsed_ms=float(r[6])))
assert [r['name'] for r in stages]==['initial_offer','actual_continue','replacement_offer'] and all(r['steps']>1 for r in stages)
costs={}
for line in kept:
 r=re.search(r'\[NATIVE_ASYNC_OFFERS_SYNC\] '+a.run+r' (\S+) ([0-9.]+)$',line)
 if r:costs[r[1]]=float(r[2])
assert set(costs)=={'initial_owned_receive','five_known_repeats','populated_menu','replacement_owned_receive'}
records=[re.search(r'\[NATIVE_ASYNC_OFFERS_RECORD\] '+a.run+r' (\d+) (\d+) resident_regions_unmeasured$',s) for s in kept];records=[r for r in records if r];assert len(records)==1
output=('\n'.join(kept)+'\n').encode();(HERE/'native-output.txt').write_bytes(output)
receipt=dict(source=m['source'],run_id=a.run,assertions=20,stages=stages,synchronous_costs_ms=costs,record_canonical_chars=int(records[0][2]),region_initialization_attempts=int(records[0][1]),resident_regions_measured=False,creator_errors=0,creator_warnings=sum('[FLog::CreatorWarning]' in s for s in kept),persistence_disabled=True,online_save_accessed=False,continue_worker_enabled=True,owned_offer_worker_enabled=True,all_save_stalls_resolved=False,low_system_resources_warning_seen=True,hard_frame_budget_proven=False,typical_fps_proven=False,place_sha256=m['place_sha256'],probe_sha256=sha((HERE/'native-probe.luau').read_bytes()),output_sha256=sha(output),published=False)
(HERE/'native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
