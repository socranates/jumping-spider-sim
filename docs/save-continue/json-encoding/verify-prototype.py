"""Bind paired evidence and adopted code; not a full integration/release gate."""
from pathlib import Path
import hashlib,io,json,re,statistics,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
SOURCE='ab8ca9577129e3d9583a0a8ab6824dae1a8cd014'
sha=lambda b:hashlib.sha256(b).hexdigest()
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as bundle:baseline={m.name:bundle.extractfile(m).read() for m in bundle if m.isfile()}
meta=json.loads((HERE/'attempt-1/receipt.json').read_text(encoding='utf8'))
assert meta['source']==SOURCE and meta['exit_code']==0 and not meta['production_changed']
for name,digest in meta['inputs'].items():assert sha(baseline[name])==digest,name
original=baseline['roblox_port/src/Shared/Persistence/Json.luau'].decode()
candidate=(HERE/'attempt-1/candidate-Json.luau').read_text(encoding='utf8')
assert sha(original.encode())==meta['reference_sha256'] and sha(candidate.encode())==meta['candidate_sha256']
start=original.index('function Json.canonical(');end=original.index('-- A deep copy of a storable value',start)
assert candidate==original[:start]+(HERE/'canonical.luau').read_text(encoding='utf8')+'\n'+original[end:]
adopted=candidate.replace('-- Private prototype: one fragment buffer, rather than a buffer/string per table.','-- One owned fragment buffer avoids a temporary buffer/string for every table.')
assert (ROOT/'roblox_port/src/Shared/Persistence/Json.luau').read_text(encoding='utf8')==adopted
assert (ROOT/'roblox_port/tests/studio/LegacyCanonical.luau').read_text(encoding='utf8').split('\n',2)[2]==original
text=(HERE/'attempt-1/output.txt').read_text(encoding='utf8')
assert sha(text.encode())==meta['output_sha256']
assert 'ENCODING_DIFFERENTIAL_PASS\t20716' in text and 'ENCODING_PAIRED_PASS\t20716' in text
rows=re.findall(r'^ENCODING_CPU\s+(original|candidate)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)',text,re.M)
assert len(rows)==8 and all(int(r[2])>1000000 for r in rows)
cli_a=statistics.mean(float(r[4]) for r in rows if r[0]=='original')
cli_b=statistics.mean(float(r[4]) for r in rows if r[0]=='candidate')
assert cli_b<cli_a
native=json.loads((HERE/'native-receipt.json').read_text(encoding='utf8'))
manifest=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'))
assert native['reference_source']==manifest['source']==SOURCE and native['scripts']==224 and native['assertions']==20738 and native['differential_checks']==20716
assert native['creator_errors']==0 and native['persistence_disabled'] and not native['online_store_accessed']
assert sha((HERE/'native-output.txt').read_bytes())==native['output_sha256']
assert sha((HERE/'paired-native.luau').read_bytes())==native['probe_sha256']
native_text=(HERE/'native-output.txt').read_text(encoding='utf8')
assert '[NATIVE_ENCODING_GUARD] '+SOURCE+' 224 persistence_disabled' in native_text
assert '[NATIVE_ENCODING_PASS] 1792705255081 20738 paired_encode_cpu_not_fps' in native_text and '[NATIVE_ENCODING_FAIL]' not in native_text
raw_rows=re.findall(r'\[NATIVE_ENCODING_CPU\] 1792705255081 (original|candidate) (\d+) (\d+) (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)',native_text)
assert len(raw_rows)==len(native['samples'])==8
for row,sample in zip(raw_rows,native['samples']):
 assert row[0]==sample['label'] and int(row[1])==sample['round'] and int(row[2])==sample['chars']==1503074 and int(row[3])==sample['steps']
 for value,key in zip(row[4:],['cpu_ms','max_update_ms','max_heartbeat_gap_ms','elapsed_ms','observed_peak_heap_delta_kb']):assert float(value)==sample[key]
a=statistics.mean(s['cpu_ms'] for s in native['samples'] if s['label']=='original')
b=statistics.mean(s['cpu_ms'] for s in native['samples'] if s['label']=='candidate')
assert a==native['mean_original_cpu_ms'] and b==native['mean_candidate_cpu_ms']
assert abs(100*(1-b/a)-native['mean_cpu_reduction_percent'])<1e-9
for round_ in range(1,5):
 old=next(s for s in native['samples'] if s['label']=='original' and s['round']==round_)
 new=next(s for s in native['samples'] if s['label']=='candidate' and s['round']==round_)
 assert new['cpu_ms']<old['cpu_ms'] and new['max_update_ms']<old['max_update_ms']
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for name,data in baseline.items():
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
expected['StarterPlayer.StarterPlayerScripts.Client.JsonCandidate']=sha(candidate.replace('require(script.Parent.SaveWork)','require(game.ReplicatedStorage.Shared.Persistence.SaveWork)').encode())
expected['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']=native['probe_sha256']
assert len(expected)==224 and {r['path']:r['sha256'] for r in manifest['scripts']}==expected
closed=json.loads((HERE/'native-close.json').read_text(encoding='utf8'))
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed']
assert closed['original_restored_sha256']==native['place_sha256']==manifest['place_sha256']
receipt=dict(reference_source=SOURCE,adopted_json_sha256=sha(adopted.encode()),adopted_code_matches_tested_candidate=True,
 cli_differential_checks=20716,cli_paired_samples=8,cli_mean_cpu_reduction_percent=100*(1-cli_b/cli_a),
 native_assertions=20738,native_paired_samples=8,native_mean_cpu_reduction_percent=100*(1-b/a),
 native_pose_or_fps_claim=False,hard_frame_budget_proven=False,heap_gain_proven=False,
 full_integration_gates_verified=False,release_rebuilt=False,goal_complete=False,published=False)
(HERE/'prototype-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
