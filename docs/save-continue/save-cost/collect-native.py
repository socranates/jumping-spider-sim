"""Collect bounded diagnostics after Play/tab/window closure; preserve both XMLs."""
from pathlib import Path
import hashlib,json,re
HERE=Path(__file__).resolve().parent
OUT=Path(r'C:/Users/natha/claude-xfer/Windowsill-save-cost-ab8ca95')
LOG=Path(r'C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261022T211857Z_Studio_15ACB_last.log')
SOURCE='ab8ca9577129e3d9583a0a8ab6824dae1a8cd014';RUN='1792704319579'
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'))
assert m['source']==SOURCE and len(m['scripts'])==223 and m['persistence_disabled']
backup=OUT/'original-before-close.rbxlx';assert sha(backup.read_bytes())==m['place_sha256']
place=OUT/'Windowsill-save-cost-review.rbxlx'
saved=OUT/'studio-saved.rbxlx';assert not saved.exists()
saved.write_bytes(place.read_bytes());saved_hash=sha(saved.read_bytes())
place.write_bytes(backup.read_bytes());assert sha(place.read_bytes())==m['place_sha256']
lines=LOG.read_text(encoding='utf8').splitlines()
start=[i for i,l in enumerate(lines) if '[NATIVE_SAVE_COST_GUARD] '+SOURCE in l and 'CreatorOutput' in l][-1]
stop=[i for i,l in enumerate(lines) if '[NATIVE_SAVE_COST_PASS] '+RUN+' 10 ' in l][-1]
assert start<stop
assert not [l for l in lines[start:stop+1] if 'FLog::CreatorError' in l]
rows=[l.split('[FLog::CreatorOutput] ',1)[1] for l in lines[start:stop+1]
 if 'FLog::CreatorOutput' in l and re.search(r'\[NATIVE_SAVE_COST_(?:GUARD|BEGIN|CAPTURE|WORK|RECORD|CALL|PASS|FAIL)\]',l) and ' > ' not in l]
assert len(rows)==41 and sum('[NATIVE_SAVE_COST_CALL]' in r for r in rows)==32
text='\n'.join(rows)+'\n';assert '[NATIVE_SAVE_COST_FAIL]' not in text
(HERE/'native-output.txt').write_text(text,encoding='utf8',newline='\n')
preflight=[l for l in lines[:start] if 'FLog::CreatorError' in l and 'ReplicatedStorage.Shared.Life.LifeLoop' in l]
(HERE/'native-preflight-refusals.txt').write_text('\n'.join(preflight)+'\n',encoding='utf8',newline='\n')
receipt=dict(source=SOURCE,run=RUN,assertions=10,creator_errors_during_guarded_run=0,
 preflight_refusals_retained=len(preflight),preflight_cause='stale lexical costGuard; correct explicit scoped file guard passed unchanged expected fingerprints',
 scripts=223,persistence_disabled=True,online_save_accessed=False,output_sha256=sha(text.encode()),
 probe_sha256=sha((HERE/'native-probe.luau').read_bytes()),place_sha256=m['place_sha256'],
 no_concurrent_cli=True,prior_stopped_rig_window_remained=True,low_resource_warning_observed=False,
 typical_fps_proven=False,hard_frame_budget_proven=False,published=False)
for name in ['first','replacement']:
 capture=re.search(r'\[NATIVE_SAVE_COST_CAPTURE\] '+RUN+' '+name+r' ([\d.]+)',text)
 work=re.search(r'\[NATIVE_SAVE_COST_WORK\] '+RUN+' '+name+r' (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)',text)
 record=re.search(r'\[NATIVE_SAVE_COST_RECORD\] '+RUN+' '+name+r' (\d+) (\d+)',text)
 assert capture and work and record
 receipt[name]=dict(capture_ms=float(capture[1]),steps=int(work[1]),cpu_ms=float(work[2]),
 max_update_ms=float(work[3]),max_heartbeat_gap_ms=float(work[4]),elapsed_ms=float(work[5]),
 chars=int(record[1]),initialization_attempts=int(record[2]),resident_regions_measured=False)
(HERE/'native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
closed=dict(playback_stopped=True,place_closed=True,diagnostic_window_closed=True,
 diagnostic_window_id=55576086,prior_window_id=94504044,prior_window_remained=True,
 saved_serialization_sha256=saved_hash,original_restored_sha256=sha(place.read_bytes()))
(HERE/'native-close.json').write_text(json.dumps(closed,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
