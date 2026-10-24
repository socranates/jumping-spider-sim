"""Collect only the authorized private publication/probe observations.

Surrounding client/account/network log contents are never copied.
"""
from pathlib import Path
import argparse,collections,hashlib,json,re
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
LOGS=Path('C:/Users/natha/AppData/Local/Roblox/logs')
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
studio=LOGS/'0.744.0.7441077_20261024T042434Z_Studio_92729_last.log'
raw=studio.read_bytes();selected=[];studio_warnings=[]
for s in raw.decode('utf8',errors='replace').splitlines():
 if '[FLog::CreatorWarning]'in s or '[FLog::CreatorError]'in s:studio_warnings.append(s)
 if '[FLog::CreatorOutput]'not in s or '] > 'in s:continue
 if any(k in s for k in ['[ISOLATED_PLAYER_GUARD]','[PRIVATE_PUBLISH_EDITOR]','[PRIVATE_PUBLISH_POST]',
  'Published new changes in "VerifiedCandidate.rbxl"','Add publish notes to v13']):selected.append(s)
assert sum('[ISOLATED_PLAYER_GUARD] 274 'in s for s in selected)==2
assert any('[PRIVATE_PUBLISH_EDITOR] 10771634917 109879630247781 'in s for s in selected)
assert any('[PRIVATE_PUBLISH_POST] 10771634917 109879630247781 sources_unchanged'in s for s in selected)
assert any('Published new changes'in s for s in selected)and any('Add publish notes to v13'in s for s in selected)
safe=lambda s:re.sub(r'(https?://[^\s?]+)\?[^\s]+',r'\1?<query omitted>',s)
data=dict(studio_log_sha256=sha(raw),studio_warnings=[safe(s)for s in studio_warnings],runs=[])
for prefix,name in [('private13-final','0.744.0.7441080_20261024T043028Z_Player_E31C1_last.log'),
 ('private13-warm','0.744.0.7441080_20261024T043710Z_Player_5A016_last.log')]:
 receipt_path=ROOT/'docs/integrated-release'/(prefix+'-player.json');d=json.loads(receipt_path.read_text())
 b=(LOGS/name).read_bytes();assert sha(b)==d['log_sha256']and d['complete']
 assert d['place_id']==109879630247781 and d['universe']==10771634917
 events=d['events'];summaries=[e['value']for e in events if e['kind']=='SUMMARY']
 assert len(summaries)==6 and all(s['store']=='WindowsillTest_player57_20261023a1'for s in summaries)
 assert len([e for e in events if e['kind']=='END'])==1
 end=next(e['value']for e in events if e['kind']=='END');assert not end['world_failed']and not end['unavailable']
 lines=b.decode('utf8',errors='replace').splitlines();warnings=[];memory=[];errors=[];categories=collections.Counter();script_errors=[]
 for s in lines:
  if re.search(r',(?:Error|Warning)\s',s):
   m=re.search(r'\[([^\]]+)\]',s);categories[m[1]if m else 'unknown']+=1
  if '[FLog::CreatorWarning]'in s:warnings.append(safe(s))
  if '[FLog::CreatorError]'in s:errors.append(safe(s))
  if '[FLog::LowMemoryWarning]'in s:memory.append(safe(s))
  if '[FLog::Output]'in s and re.search(r'\bStack Begin\b|\bStack End\b|attempt to (?:index|call|perform)|Script .*, Line \d+',s):script_errors.append(safe(s))
 assert not errors and not script_errors,'inspect actual script error before qualifying'
 windows=[dict(end_seconds=s['t'],frames=s['frames'],mean_ms=s['seconds']*1000/s['frames'],
  fps=s['frames']/s['seconds'],worst_ms=s['worst_ms'],over50=s['over50'])for s in summaries]
 last=summaries[-2:];last_seconds=sum(s['seconds']for s in last);last_frames=sum(s['frames']for s in last)
 data['runs'].append(dict(prefix=prefix,run=d['run'],receipt_sha256=sha(receipt_path.read_bytes()),log_sha256=sha(b),
  title_ready_seconds=next(e['value']['t']for e in events if e['kind']=='PHASE'and e['value']['name']=='title-ready'),
  windows=windows,last30=dict(frames=last_frames,seconds=last_seconds,mean_ms=last_seconds*1000/last_frames,
   fps=last_frames/last_seconds,worst_ms=max(s['worst_ms']for s in last),over50=sum(s['over50']for s in last)),
  largest_reported_gap=next(e['value']for e in events if e['kind']=='GAP'),creator_warnings=warnings,
  creator_errors=errors,recognizable_script_error_records=script_errors,low_memory_records=memory,
  platform_warning_error_categories=dict(categories),complete=True))
data['limits']='Initial Heartbeat dt can span time before probe born. Window timings mix title/intro/gameplay; no matched source baseline, full traversal, device comfort, audible balance or direct runtime PlaceVersion query. Platform diagnostics are not all cleared.'
output=('\n'.join(selected)+'\n').encode();payload=(json.dumps(data,indent=2)+'\n').encode()
if a.check:assert (H/'studio-output.txt').read_bytes()==output and (H/'observations.json').read_bytes()==payload
else:
 assert not (H/'observations.json').exists();(H/'studio-output.txt').write_bytes(output);(H/'observations.json').write_bytes(payload)
print(json.dumps(dict(published=13,runs=[dict(run=r['run'],title_ready_seconds=r['title_ready_seconds'],last30=r['last30'],initial_gap_ms=r['largest_reported_gap']['ms'],creator_warning_count=len(r['creator_warnings']),low_memory_records=len(r['low_memory_records']))for r in data['runs']])))
