"""Qualify the separate Normal/low fixture without rewriting the frozen full fixture."""
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('baseline_engine_verifier',H/'verify-engine-stream.py');base=importlib.util.module_from_spec(spec)
with contextlib.redirect_stdout(io.StringIO()):spec.loader.exec_module(base)
sha=base.sha;source=base.source
prefix='engine-low-opportunistic-normal';r=json.loads((H/(prefix+'-receipt.json')).read_text(encoding='utf8'))
assert r['source']==source and r['executed'] and r['experiment_passed'] and r['terminal'] and r['stopped'] and r['editor_place_closed'] and r['creator_errors_during_fixture']==0
assert r['summary']==dict(renderFrames=120,heldFrames=124,engineStreamOutObserved=True,checks=1631)
assert r['engine_remove_and_rearrival_verified'] and r['player_hold_during_engine_gap_observed'] and r['detail']=='low' and r['stream_out_behavior']=='Opportunistic'
assert sha((H/(prefix+'-output.txt')).read_bytes())==r['filtered_output_sha256']
probe=H/'engine-stream-normal-probe.luau';assert sha(probe.read_bytes())==r['probe_sha256']
model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256'] and r['original_model_unchanged']
assert sha((model.parent/'manifest.json').read_bytes())==r['manifest_sha256'] and sha((model.parent/'guard.luau').read_bytes())==r['guard_sha256']
assert sha(Path(r['editor_copy_path']).read_bytes())==r['editor_copy_sha256']
manifest=json.loads((model.parent/'manifest.json').read_text(encoding='utf8'));assert manifest['probe_variant']==probe.name and manifest['tier']=='low' and manifest['serialized_settings_verified']
xml=ET.parse(model);actual={};disabled=False
def walk(item,parent=''):
 global disabled
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 code=props.find("*[@name='Source']")
 if code is not None:actual[path]=sha((code.text or '').replace('\r\n','\n').encode())
 if path=='ServerScriptService.Server.Persistence':disabled=props.findtext("bool[@name='Disabled']")=='true'
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
assert disabled and actual=={**base.expected,'StarterPlayer.StarterPlayerScripts.Client.SilkPlayback':r['probe_sha256']}
props=next(i for i in xml.getroot().findall('Item') if i.attrib['class']=='Workspace').find('Properties')
assert props.findtext("bool[@name='StreamingEnabled']")=='true' and props.findtext("int[@name='StreamingMinRadius']")=='96' and props.findtext("int[@name='StreamingTargetRadius']")=='160'
assert props.findtext("token[@name='StreamOutBehavior']")==ET.parse(model.parent/'enum-policy.rbxlx').getroot().findtext("Item/Properties/token[@name='StreamOutBehavior']")
energy=next(o for o in r['observations'] if o['phase']=='normal_energy')
assert energy['mode']=='main' and energy['rules']=='standard' and energy['gentle'] is False and energy['pendingDrainRetained'] and energy['reportMethodRestored']
assert energy['energyBeforeWarm']>energy['energyBeforeHold']>energy['energyAfterResume'] and energy['heldSeconds']>=1.5 and energy['focusReportDelaySeconds']==2 and energy['heldFrames']==124
sample=next(o for o in r['observations'] if o['phase']=='render_sample');assert sample['detail']=='low' and sample['frames']==120 and sample['comparisonGainClaim'] is False
result=dict(source=source,native_low_detail_normal_verified=True,checks=1631,script_fingerprints=223,creator_errors=0,energy_and_pending_drain_retained_during_actual_engine_gap=True,hunger_active_before_and_after=True,held_heartbeat_observations=124,held_seconds=energy['heldSeconds'],energy=energy,render_sample=sample,diagnostic_focus_report_delay_seconds=2,diagnostic_stream_out_policy='Opportunistic',production_code_and_policy_changed=False,default_network_pressure_verified=False,whole_game_fps_gain_claim=False,physical_phone_verified=False,recovery_native_verified=False,real_datastore_verified=False,published=False,goal_complete=False)
(H/'normal-stream-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
