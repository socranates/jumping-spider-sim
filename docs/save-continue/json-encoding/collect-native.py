"""Collect the completed private paired trial after its window closed."""
from pathlib import Path
import hashlib,json,re,statistics
HERE=Path(__file__).resolve().parent
OUT=Path(r'C:/Users/natha/claude-xfer/Windowsill-json-encoding-ab8ca95-v2')
LOG=Path(r'C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261022T213926Z_Studio_64019_last.log')
SOURCE='ab8ca9577129e3d9583a0a8ab6824dae1a8cd014';RUN='1792705255081'
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'))
assert manifest['source']==SOURCE and len(manifest['scripts'])==224 and manifest['persistence_disabled']
backup=OUT/'original-before-close.rbxlx';assert sha(backup.read_bytes())==manifest['place_sha256']
place=OUT/'Windowsill-json-encoding-review.rbxlx';saved=OUT/'studio-saved.rbxlx';assert not saved.exists()
saved.write_bytes(place.read_bytes());place.write_bytes(backup.read_bytes());assert sha(place.read_bytes())==manifest['place_sha256']
lines=LOG.read_text(encoding='utf8').splitlines()
start=[i for i,l in enumerate(lines) if '[NATIVE_ENCODING_GUARD] '+SOURCE+' 224 persistence_disabled' in l][-1]
end=[i for i,l in enumerate(lines) if '[NATIVE_ENCODING_PASS] '+RUN+' 20738 ' in l][-1]
assert start<end
assert not [l for l in lines[start:end+1] if 'FLog::CreatorError' in l]
rows=[l.split('[FLog::CreatorOutput] ',1)[1] for l in lines[start:end+1] if 'FLog::CreatorOutput' in l and '[NATIVE_ENCODING_' in l and ' > ' not in l]
assert len(rows)==13
text='\n'.join(rows)+'\n';assert '[NATIVE_ENCODING_FAIL]' not in text
(HERE/'native-output.txt').write_text(text,encoding='utf8',newline='\n')
pattern=r'\[NATIVE_ENCODING_CPU\] '+RUN+r' (original|candidate) (\d+) (\d+) (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)'
samples=[]
for match in re.findall(pattern,text):
 label,round_,chars,steps,cpu,worst,gap,elapsed,heap=match
 samples.append(dict(label=label,round=int(round_),chars=int(chars),steps=int(steps),cpu_ms=float(cpu),max_update_ms=float(worst),max_heartbeat_gap_ms=float(gap),elapsed_ms=float(elapsed),observed_peak_heap_delta_kb=float(heap)))
assert len(samples)==8
assert [(s['label'],s['round']) for s in samples]==[('original',1),('candidate',1),('candidate',2),('original',2),('original',3),('candidate',3),('candidate',4),('original',4)]
original=statistics.mean(s['cpu_ms'] for s in samples if s['label']=='original')
candidate=statistics.mean(s['cpu_ms'] for s in samples if s['label']=='candidate')
for round_ in range(1,5):
 a=next(s for s in samples if s['round']==round_ and s['label']=='original')
 b=next(s for s in samples if s['round']==round_ and s['label']=='candidate')
 assert a['chars']==b['chars']==1503074 and b['cpu_ms']<a['cpu_ms'] and b['max_update_ms']<a['max_update_ms']
receipt=dict(reference_source=SOURCE,run=RUN,assertions=20738,differential_checks=20716,scripts=224,creator_errors=0,
 persistence_disabled=True,online_store_accessed=False,production_changed_during_trial=False,
 output_sha256=sha(text.encode()),probe_sha256=sha((HERE/'paired-native.luau').read_bytes()),place_sha256=manifest['place_sha256'],
 samples=samples,mean_original_cpu_ms=original,mean_candidate_cpu_ms=candidate,mean_cpu_reduction_percent=100*(1-candidate/original),
 no_concurrent_cli=True,prior_stopped_rig_window_remained=True,low_resource_warning_observed=False,
 heap_regression_or_gain_proven=False,whole_game_fps_gain_proven=False,hard_frame_budget_proven=False,published=False)
(HERE/'native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
closed=dict(playback_stopped=True,place_closed=True,diagnostic_window_closed=True,diagnostic_window_id=63963396,
 prior_window_id=94504044,prior_window_remained=True,saved_serialization_sha256=sha(saved.read_bytes()),original_restored_sha256=sha(place.read_bytes()))
(HERE/'native-close.json').write_text(json.dumps(closed,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='samples'},indent=2))
