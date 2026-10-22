"""Retain bounded current-game evidence after stop/tab/window closure."""
from pathlib import Path
import hashlib,json,re
HERE=Path(__file__).resolve().parent
OUT=Path(r'C:/Users/natha/claude-xfer/Windowsill-encoder-game-068a878')
LOG=Path(r'C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261022T221533Z_Studio_91F56_last.log')
SOURCE='068a87891770dbdf291ec3cab0e67480d14c0251'
SAVE='1792707403197';RETURN='1792707441585';SEQUENCE='1792707403197'
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((HERE/'game-prepared-manifest.json').read_text(encoding='utf8'))
assert manifest['source']==SOURCE and len(manifest['scripts'])==225 and manifest['persistence_disabled']
place=OUT/'Windowsill-encoder-game-review.rbxlx';backup=OUT/'original-before-close.rbxlx'
assert sha(backup.read_bytes())==manifest['place_sha256']
saved=OUT/'studio-saved.rbxlx';assert not saved.exists()
saved.write_bytes(place.read_bytes());saved_hash=sha(saved.read_bytes())
place.write_bytes(backup.read_bytes());assert sha(place.read_bytes())==manifest['place_sha256']
lines=LOG.read_text(encoding='utf8').splitlines()
start=[i for i,l in enumerate(lines) if '[NATIVE_ENCODER_GAME_GUARD] '+SOURCE+' 225 persistence_disabled' in l][-1]
end=[i for i,l in enumerate(lines) if '[NATIVE_ENCODER_GAME_END] '+SEQUENCE in l][-1]
assert start<end
assert not [l for l in lines[start:end+1] if 'FLog::CreatorError' in l]
rows=[l.split('[FLog::CreatorOutput] ',1)[1] for l in lines[start:end+1]
 if 'FLog::CreatorOutput' in l and re.search(r'\[NATIVE_(?:ENCODER_GAME|SAVE_COST|LOCAL_RETURN)_',l) and ' > ' not in l]
assert len(rows)==49,len(rows)
text='\n'.join(rows)+'\n'
assert '[NATIVE_SAVE_COST_PASS] '+SAVE+' 10 ' in text and '[NATIVE_LOCAL_RETURN_PASS] '+RETURN+' 22' in text
assert not re.search(r'\[NATIVE_(?:SAVE_COST|LOCAL_RETURN)_FAIL\]',text)
(HERE/'game-native-output.txt').write_text(text,encoding='utf8',newline='\n')
receipt=dict(source=SOURCE,sequence=SEQUENCE,save_run=SAVE,return_run=RETURN,save_assertions=10,return_assertions=22,
 assertions=32,creator_errors=0,scripts=225,persistence_disabled=True,online_store_accessed=False,
 output_sha256=sha(text.encode()),place_sha256=manifest['place_sha256'],
 no_concurrent_cli=True,prior_stopped_rig_window_remained=True,low_resource_warning_observed=False,
 whole_game_fps_gain_proven=False,hard_frame_budget_proven=False,causal_end_to_end_speedup_proven=False,published=False)
for name in ['first','replacement']:
 capture=re.search(r'\[NATIVE_SAVE_COST_CAPTURE\] '+SAVE+' '+name+r' ([\d.]+)',text)
 work=re.search(r'\[NATIVE_SAVE_COST_WORK\] '+SAVE+' '+name+r' (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)',text)
 record=re.search(r'\[NATIVE_SAVE_COST_RECORD\] '+SAVE+' '+name+r' (\d+) (\d+)',text)
 assert capture and work and record
 receipt['save_'+name]=dict(capture_ms=float(capture[1]),steps=int(work[1]),cpu_ms=float(work[2]),
 max_update_ms=float(work[3]),max_heartbeat_gap_ms=float(work[4]),elapsed_ms=float(work[5]),
 chars=int(record[1]),initialization_attempts=int(record[2]),resident_regions_measured=False)
for name in ['local_continue','end_screen_return']:
 work=re.search(r'\[NATIVE_LOCAL_RETURN_WORK\] '+RETURN+' '+name+r' (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)',text)
 assert work
 receipt[name]=dict(steps=int(work[1]),max_update_ms=float(work[2]),max_heartbeat_gap_ms=float(work[3]),cpu_ms=float(work[4]),elapsed_ms=float(work[5]))
sync=re.search(r'\[NATIVE_LOCAL_RETURN_SYNC\] '+RETURN+r' choose ([\d.]+) (\d+)',text);assert sync and int(sync[2])==0
receipt['continue_choice_ms']=float(sync[1]);receipt['continue_synchronous_encodes']=0
(HERE/'game-native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
closed=dict(playback_stopped=True,place_closed=True,diagnostic_window_closed=True,diagnostic_window_id=25169032,
 prior_window_id=94504044,prior_window_remained=True,saved_serialization_sha256=saved_hash,original_restored_sha256=sha(place.read_bytes()))
(HERE/'game-native-close.json').write_text(json.dumps(closed,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
