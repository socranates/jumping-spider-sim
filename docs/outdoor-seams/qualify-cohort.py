"""Bind both native crossing cohorts to the current ordinary exported source."""
from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
sha=lambda b:hashlib.sha256(b).hexdigest()
build=json.loads((PORT/'build-receipt.json').read_text())
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def name(rel):
 parts=Path(rel).parts
 return '.'.join([prefix[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
normal={f.relative_to(PORT/'src').as_posix():sha(f.read_bytes().replace(b'\r\n',b'\n'))for f in (PORT/'src').rglob('*.luau')}
assert len(normal)==273 and {name(k):v for k,v in normal.items()}==build['sources']
for o in build['outputs']:assert sha((PORT/o['file']).read_bytes())==o['sha256']
rows=[]
for folder,tier in [('perimeter-full','full'),('perimeter-low','low')]:
 manifest=json.loads((H/folder/'manifest.json').read_text());native=json.loads((H/folder/'native.json').read_text())
 assert manifest['original_sources']==normal and manifest['source_count']==276
 assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']==native['model_sha256']
 assert native['passed']and native['tier']==tier and native['source_guards']>=2 and native['creator_errors']==0
 assert len(native['walks'])==len(native['hops'])==4
 assert sha((H/folder/'native-output.txt').read_bytes())==native['native_output_sha256']
 rows.append(dict(tier=tier,run=native['run'],model_sha256=native['model_sha256'],
  walks=len(native['walks']),hops=len(native['hops']),walking_frames=sum(w['frames']for w in native['walks']),
  hop_frames=sum(h['frames']for h in native['hops']),min_y=min(w['min_y']for w in native['walks']),
  creator_errors=native['creator_errors'],creator_warnings=native['creator_warnings']))
record=dict(evidence_id=build['evidence_id'],source_count=273,game_sources=normal,native=rows,
 total_walks=sum(x['walks']for x in rows),total_hops=sum(x['hops']for x in rows),
 total_walking_frames=sum(x['walking_frames']for x in rows),
 limits='Four selected hut-edge crossings in each detail tier, same ordinary game source as both current exports. Native trials overlapped the Windows CLI rerun and included UI snapshots; no FPS comparison or all-map/phone/natural-life qualification. Unpublished unbound memory fixtures only.')
target=H/'qualified-native.json';assert not target.exists();target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(evidence=record['evidence_id'],native=rows,total_walking_frames=record['total_walking_frames'])))
