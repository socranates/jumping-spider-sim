"""Verify source/closure/provenance of attribution; never claim a production speedup."""
from pathlib import Path
import hashlib,io,json,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'prepared-current-manifest.json').read_text(encoding='utf8'))
r=json.loads((HERE/'native-receipt.json').read_text(encoding='utf8'))
closed=json.loads((HERE/'native-close.json').read_text(encoding='utf8'))
assert r['source']==m['source']=='59146e1005c083330455379766ab8c9dd2de2705'
assert r['scripts']==223 and r['creator_errors']==0 and r['persistence_disabled'] and m['persistence_disabled']
raw=subprocess.check_output(['git','archive','--format=tar',r['source'],'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={i.name:archive.extractfile(i).read() for i in archive if i.isfile()}
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for name,data in files.items():
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
expected['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']=sha((HERE/'native-probe.luau').read_bytes())
assert len(expected)==223 and {i['path']:i['sha256'] for i in m['scripts']}==expected
text=(HERE/'native-output.txt').read_text(encoding='utf8');assert sha(text.encode())==r['output_sha256']
assert '[NATIVE_ANIMAL_COST_GUARD] '+r['source']+' 223 persistence_disabled' in text
assert '[NATIVE_ANIMAL_COST_PASS] '+r['run']+' 2 9' in text and '[NATIVE_ANIMAL_COST_FAIL]' not in text
assert len(text.splitlines())==27
names={'Soundscape.update','Soundscape.updateWasp','Soundscape.updateMeal','WaspBody.draw','CrabBody.draw','StationMouseBody.draw','PondBodies.draw','BirdBody.draw','CatBody.draw'}
assert set(r['scenes'])=={'sill_noon','garden_mate'}
for scene in r['scenes'].values():
 assert len(scene['components'])==9 and {c['name'] for c in scene['components']}==names
 assert scene['frames']>=120 and abs(scene['observed_render_frames']-scene['frames'])<=2
 assert scene['observed_render_interval_mean_ms']>0 and scene['elapsed_seconds']>=12
 for row in scene['components']:
  assert abs(row['cpu_ms_per_frame']-row['total_cpu_ms']/scene['frames'])<1e-9
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed']
assert closed['prior_window_remained'] and closed['original_restored_sha256']==r['place_sha256']==m['place_sha256']
place=Path(r'C:/Users/natha/claude-xfer/Windowsill-animal-cost-59146e1/Windowsill-animal-cost-review.rbxlx')
assert sha(place.read_bytes())==m['place_sha256']
out=dict(source=r['source'],scripts=223,scenes=2,source_and_probe_hashes_verified=True,closure_verified=True,
 current_workspace_inputs_verified=all((ROOT/name).read_bytes()==data for name,data in files.items()),
 whole_game_fps_gain_proven=False,engine_audio_cost_measured=False,leak_proven=False,optimization_adopted=False,published=False)
(HERE/'verification.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(out,indent=2))
