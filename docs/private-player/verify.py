"""Bind actual private publication, exact editor guards and standalone probes."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
for script in ['prepare.py','collect.py']:subprocess.run([sys.executable,str(H/script),'--check'],check=True)
prepared=json.loads((H/'prepared.json').read_text());stage=Path(prepared['candidate_manifest']).parent
manifest=json.loads(Path(prepared['candidate_manifest']).read_text())
assert manifest['source_count']==274 and manifest['unchanged_game_sources']==273
assert sha(Path(prepared['candidate_manifest']).read_bytes())==prepared['candidate_manifest_sha256']
assert sha(Path(manifest['place']).read_bytes())==prepared['model_sha256']
assert prepared['universe']==10771634917 and prepared['place_id']==109879630247781
assert 'Publish private test build'in prepared['authorization']
assert sha(Path(prepared['local_editor']).read_bytes())=='b541faea86aa5d9fea9d36d6de442d97c83baded8cbe235629da07066181de09'
before=(H/'before-published.txt').read_text();after=(H/'after-published.txt').read_text();access=(H/'after-private-access.txt').read_text()
url='create.roblox.com/dashboard/creations/experiences/10771634917/places/109879630247781/version-history'
assert url in before and url in after
assert 'Show published only, Value: 1'in before and 'Show published only, Value: 1'in after
# The pagination control also contains a numeric text child (page size 10).
# Restrict this check to the version rows above the observed pagination label.
def versions(snapshot):
 assert snapshot.count('text Rows per page:')==1
 return re.findall(r'\btext (\d+)\s*$',snapshot.split('text Rows per page:')[0],re.M)
assert versions(before)==['2']
assert versions(after)==['13','2']
assert 'Game access:'in access and 'Audience reach:'in access and access.count('Description: Private')==2
first=json.loads((H/'cli-first-pass.json').read_text());assert first['complete']and first['suites']==78 and first['passed']==468967 and first['failed']==0
assert first['model_sha256']==prepared['clean_model_sha256']
cli=ROOT/'docs/integrated-release/menu-full1-receipt.json';assert sha(cli.read_bytes())==first['receipt_sha256']
observations=json.loads((H/'observations.json').read_text());assert len(observations['runs'])==2
inputs={}
def bind(path):inputs[path.relative_to(ROOT).as_posix()]=sha(path.read_bytes())
for name in ['prepare.py','prepared.json','setup.luau','post-guard.luau','collect.py','verify.py','README.md',
 'before-published.txt','before-published.png','after-published.txt','after-published.png','after-private-access.txt',
 'guard.png','guard-output.txt','post-guard.png','studio-output.txt','observations.json','cli-first-pass.json',
 'player-title.png','player-entry.png','player-gameplay.png','player-actions.json','player-warm-gameplay.png','player-warm-actions.json']:bind(H/name)
for row in observations['runs']:
 path=ROOT/'docs/integrated-release'/(row['prefix']+'-player.json');bind(path)
 d=json.loads(path.read_text());assert sha(path.read_bytes())==row['receipt_sha256']and d['complete']
 assert d['model_sha256']==prepared['model_sha256']and d['manifest_sha256']==prepared['candidate_manifest_sha256']
 assert not row['creator_errors']and not row['recognizable_script_error_records']
assert {r['run']for r in observations['runs']}=={'1792816238921','1792816638859'}
result=dict(inputs=inputs,source_identity_verified_in_studio=True,game_sources=273,readonly_probe_sources=1,
 universe=10771634917,place_id=109879630247781,published_version=13,private_access_verified=True,
 normal_menu_new_life_observed=True,complete_probe_runs=2,full_manual_playthrough=False,
 full_save_rest_rejoin_proved=False,runtime_place_version_directly_queried=False,
 published_asset_independently_downloaded=False,broad_fps_improvement_proved=False,startup_stall_fixed=False,
 production_published=False,goal_complete=False)
target=H/'qualification.json'
if a.check:assert json.loads(target.read_text())==result
else:assert not target.exists();target.write_bytes((json.dumps(result,indent=2)+'\n').encode())
print('Private version13 publication + 274-source guards + two standalone arrivals verified; limits retained')
