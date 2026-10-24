"""Copy current immutable inputs, run a record inventory, and bind its output.

Never writes the live test stage, production sources, worlds, or native saves.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE=Path('C:/Users/natha/claude-xfer/Windowsill-menu-overflow-attempt1')
STAGE=Path('C:/Users/natha/claude-xfer/Windowsill-world-inventory-attempt1')
OUT=H/'integrated-world';sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
manifest=json.loads((SOURCE/'manifest.json').read_text())
assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']
def files(folder):return {f.relative_to(folder).as_posix():sha(f.read_bytes())for f in sorted(folder.rglob('*.luau'))}
before=files(SOURCE/'roblox_port/src');assert len(before)==273
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
model_name=lambda rel:'.'.join([prefix[Path(rel).parts[0]],*Path(rel).parts[1:-1],Path(rel).parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
assert {model_name(k):sha((SOURCE/'roblox_port/src'/k).read_bytes().replace(b'\r\n',b'\n'))for k in before}==manifest['sources']
if not a.check:
 assert not STAGE.exists()and not OUT.exists()
 shutil.copytree(SOURCE/'roblox_port/src',STAGE/'roblox_port/src')
 shutil.copytree(SOURCE/'roblox_port/tests',STAGE/'roblox_port/tests',ignore=shutil.ignore_patterns('__pycache__'))
 shutil.copyfile(H/'world_inventory.luau',STAGE/'roblox_port/tests/world_inventory.luau')
 subprocess.run([sys.executable,str(ROOT/'docs/integrated-release/run-cli.py'),'--stage',str(STAGE),
  '--prefix','world-current1','--suite','world_inventory.luau'],check=True)
run_path=ROOT/'docs/integrated-release/world-current1-receipt.json';run=json.loads(run_path.read_text())
assert run['all_passed']and run['requested']==['world_inventory.luau']and run['inputs']==before
assert sha((STAGE/'roblox_port/tests/world_inventory.luau').read_bytes())==sha((H/'world_inventory.luau').read_bytes())
assert run['test_inputs']['world_inventory.luau']==sha((H/'world_inventory.luau').read_bytes())
assert run['runner_sha256']==sha((ROOT/'docs/integrated-release/run-cli.py').read_bytes())
assert files(SOURCE/'roblox_port/src')==before==files(STAGE/'roblox_port/src')
result=run['results'][0];output=ROOT/'docs/integrated-release'/result['output'];raw=output.read_bytes()
assert result['exit_code']==0 and sha(raw)==result['output_sha256']
lines=raw.decode().splitlines();rows=[json.loads(s.removeprefix('WORLD_INVENTORY '))for s in lines if s.startswith('WORLD_INVENTORY ')]
assert lines[-1]=='WORLD_INVENTORY_END rows='+str(len(rows))and len(lines)==len(rows)+1
groups={}
for row in rows:
 key=row['world']+'/'+row['group'];count=groups.setdefault(key,dict(regions=0,walkable_records=0,full_draw_records=0,low_draw_records=0))
 count['regions']+=1
 for field in ['walkable_records','full_draw_records','low_draw_records']:count[field]+=row[field]
assert len({(r['world'],r['id'])for r in rows})==len(rows)
data=dict(model_sha256=manifest['place_sha256'],manifest_sha256=sha((SOURCE/'manifest.json').read_bytes()),
 source_hashes=before,probe_sha256=sha((H/'world_inventory.luau').read_bytes()),
 generator_sha256=sha(Path(__file__).read_bytes()),runner_receipt_sha256=sha(run_path.read_bytes()),
 output_sha256=sha(raw),summary=groups,rows=rows,
 limits='Authored generator records in the CLI shim, not native instance/physics counts, close visual traversal, active plan totals, memory or FPS.')
markdown=['# Current authored world inventory\n\n',f"Clean model SHA256 `{manifest['place_sha256']}`. All 273 staged sources match its manifest.\n\n",
 'This is an inventory of generator records from the actual current modules in the CLI shim. Draw specifications are not native part counts; summed full detail is not what a streamed client holds at once. Walkable records do not prove a route is free of native clipping. Boundaries, spawn, neighbor ids, retreat ids and streaming policy are in inventory.json. No game, source stage or save was changed.\n\n',
 '| World/group | Regions | Walkable records | Full draw records | Low draw records |\n|---|---:|---:|---:|---:|\n']
for key,item in groups.items():markdown.append('| '+key+' | '+' | '.join(str(item[k])for k in ['regions','walkable_records','full_draw_records','low_draw_records'])+' |\n')
markdown+=['\n| World | Group | Id | Kind | Walkable | Full draw | Low draw | Far full/low | Retreats | Streaming |\n|---|---|---|---|---:|---:|---:|---|---|---|\n']
for r in rows:markdown.append(f"| {r['world']} | {r['group']} | {r['id']} | {r['kind']} | {r['walkable_records']} | {r['full_draw_records']} | {r['low_draw_records']} | {r['far_full_records']}/{r['far_low_records']} | {', '.join(r['retreats'])} | {r['streaming_policy']} |\n")
markdown.append('\nRepeat/check with `python docs/audit/world_inventory.py --check`. This validates the retained output and exact inputs; it does not rerun native rendering. The sill has separate startup scenery; other station/verge collision is persistent, other walkable models atomic, drawn zones/patches are client looks. Full/low preserves the same support records. See HEALTH-CURRENT.md for unresolved close visual and device/performance coverage.\n')
payload=(json.dumps(data,indent=2)+'\n').encode();md=''.join(markdown).encode()
if a.check:assert (OUT/'inventory.json').read_bytes()==payload and (OUT/'MAP.md').read_bytes()==md
else:OUT.mkdir();(OUT/'inventory.json').write_bytes(payload);(OUT/'MAP.md').write_bytes(md)
print(json.dumps(dict(rows=len(rows),groups=groups)))
