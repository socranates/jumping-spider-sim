"""Bind real-engine observations to their model/probe/settings and retain limits."""
from pathlib import Path
import hashlib,io,json,subprocess,tarfile,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
# Native receipts are immutable historical proof, independent of the current
# checkout. Reconstruct their exact production sources from this commit.
source='695e772d9d1ece490dd32132c655ac60c226c7b8'
expected={};prefixes={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 for item in archive:
  if not item.isfile() or not item.name.endswith('.luau'):continue
  parts=list(Path(item.name).relative_to('roblox_port/src').parts);leaf=parts[-1][:-5]
  for suffix in ['.client','.server']:
   if leaf.endswith(suffix):leaf=leaf[:-len(suffix)]
  expected['.'.join([prefixes[parts[0]],*parts[1:-1],leaf])]=sha(archive.extractfile(item).read().replace(b'\r\n',b'\n'))
assert len(expected)==222
rows={}
for prefix,behavior in [('engine-full-default-attempt-2','Default'),('engine-full-opportunistic','Opportunistic')]:
 r=json.loads((H/(prefix+'-receipt.json')).read_text(encoding='utf8'));assert r['source']==source
 assert r['executed'] and r['experiment_passed'] and r['terminal'] and r['stopped'] and r['editor_place_closed'] and r['creator_errors_during_fixture']==0
 assert sha((H/(prefix+'-output.txt')).read_bytes())==r['filtered_output_sha256']
 assert r['detail']=='full' and r['stream_out_behavior']==behavior and r['collision_mutations_in_probe'] is False
 assert r['probe_sha256']==sha((H/'engine-stream-probe.luau').read_bytes())
 model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256'] and r['original_model_unchanged']
 manifest=model.parent/'manifest.json';assert sha(manifest.read_bytes())==r['manifest_sha256']
 m=json.loads(manifest.read_text(encoding='utf8'));assert m['serialized_settings_verified'] and m['stream_out_behavior']==behavior
 assert sha((model.parent/'guard.luau').read_bytes())==r['guard_sha256']
 assert sha(Path(r['editor_copy_path']).read_bytes())==r['editor_copy_sha256']
 xml=ET.parse(model);workspace=next(i for i in xml.getroot().findall('Item') if i.attrib['class']=='Workspace');props=workspace.find('Properties')
 assert props.findtext("bool[@name='StreamingEnabled']")=='true' and props.findtext("int[@name='StreamingMinRadius']")=='96' and props.findtext("int[@name='StreamingTargetRadius']")=='160'
 enum=ET.parse(model.parent/'enum-policy.rbxlx').getroot().findtext("Item/Properties/token[@name='StreamOutBehavior']")
 assert props.findtext("token[@name='StreamOutBehavior']")==enum
 actual={}
 def walk(item,parent=''):
  props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
  code=props.find("*[@name='Source']")
  if code is not None:actual[path]=sha((code.text or '').replace('\r\n','\n').encode())
  for child in item.findall('Item'):walk(child,path)
 for item in xml.getroot().findall('Item'):walk(item)
 assert len(actual)==223 and actual=={row['path']:row['sha256'] for row in m['scripts']}
 assert actual=={**expected,'StarterPlayer.StarterPlayerScripts.Client.SilkPlayback':r['probe_sha256']}
 assert any(o['phase']=='arrival' and o['region']=='garden_b4' and o['serverFocusObserved'] for o in r['observations'])
 assert any(o['phase']=='arrival' and o['region']=='deck_n4' and o['serverFocusObserved'] for o in r['observations'])
 assert r['real_datastore_verified'] is False and r['published'] is False
 rows[behavior]=r
default=rows['Default'];active=rows['Opportunistic']
assert default['summary']['checks']==11 and default['engine_stream_out_observed'] is False and default['native_verified'] is False
assert any(o['phase']=='away' and o['seconds']>=45 and o['nearReady'] for o in default['observations'])
assert active['summary']['checks']==25 and active['summary']['heldFrames']==4 and active['summary']['renderFrames']==120
assert active['engine_remove_and_rearrival_verified'] and active['player_hold_during_engine_gap_observed']
sample=next(o for o in active['observations'] if o['phase']=='render_sample');assert sample['comparisonGainClaim'] is False
assert sample['frames']==120 and sample['viewport']=='1105, 433'
result=dict(source=source,default_checks=11,default_observation_seconds=45,default_stream_out_observed=False,
 opportunistic_checks=25,opportunistic_engine_remove_and_rearrival_verified=True,player_hold_frames=4,
 same_life_and_motor_resumed=True,position_velocity_mode_and_life_needs_prey_clocks_retained=True,
 collision_folder_mutations=False,production_streaming_policy_changed=False,script_fingerprints_each=223,
 creator_errors_during_each_fixture=0,full_detail=True,mode='Free play',native_low_detail_verified=False,
 render_sample=sample,whole_game_fps_gain_claim=False,real_network_pressure_under_default_verified=False,
 real_datastore_verified=False,recovery_native_verified=False,published=False,goal_complete=False)
(H/'engine-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
