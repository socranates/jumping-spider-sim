"""Prepare a new local copy of the already qualified private player editor.

Does not publish, change sources, or touch the separate SelfTest fixture.
"""
from pathlib import Path
import argparse,hashlib,json
H=Path(__file__).resolve().parent
SOURCE=Path('C:/Users/natha/claude-xfer/Windowsill-menu-player-attempt1')
DEST=Path('C:/Users/natha/claude-xfer/Windowsill-private-publish-attempt1')
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
manifest=json.loads((SOURCE/'manifest.json').read_text());editor=SOURCE/'VerifiedEditorBeforeUpload.rbxl'
assert sha(editor.read_bytes())=='8616844ac52cffcbac84ada921bc146c04c0eb75766ddcf32e74dc1809edb042'
assert manifest['source_count']==274 and manifest['unchanged_game_sources']==273
assert manifest['universe']==10771634917 and manifest['place_id']==109879630247781
assert manifest['test_store']=='WindowsillTest_player57_20261023a1'
assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']
guard=(SOURCE/'guard.luau').read_bytes();assert sha(guard)==manifest['guard_sha256']
prefix='assert(not game:GetService("RunService"):IsRunning());assert((game.PlaceId==0 and game.GameId==0)or(game.PlaceId==109879630247781 and game.GameId==10771634917),"wrong publication target");if game.PlaceId==0 then game:SetPlaceId(109879630247781);game:SetUniverseId(10771634917)end;'
setup=prefix.encode()+guard+b'\nprint("[PRIVATE_PUBLISH_EDITOR]",game.GameId,game.PlaceId,"verified_candidate_normal_gameplay")\n'
result=dict(source_editor=str(editor),source_editor_sha256=sha(editor.read_bytes()),
 local_editor=str(DEST/'VerifiedCandidate.rbxl'),initial_copy_sha256=sha(editor.read_bytes()),
 candidate_manifest=str(SOURCE/'manifest.json'),candidate_manifest_sha256=sha((SOURCE/'manifest.json').read_bytes()),
 model_sha256=manifest['place_sha256'],clean_model_sha256=manifest['clean_place_sha256'],
 setup_sha256=sha(setup),universe=manifest['universe'],place_id=manifest['place_id'],test_store=manifest['test_store'],
 authorization='Human reply: Publish private test build; specific candidate, read-only probe, existing private target and fresh test namespace.',
 published=False)
if a.check:
 assert json.loads((H/'prepared.json').read_text())==result and (H/'setup.luau').read_bytes()==setup
else:
 assert not DEST.exists()and not (H/'prepared.json').exists()
 DEST.mkdir();(DEST/'VerifiedCandidate.rbxl').write_bytes(editor.read_bytes())
 (H/'setup.luau').write_bytes(setup);(H/'prepared.json').write_bytes((json.dumps(result,indent=2)+'\n').encode())
print('Private publication preparation verified; no upload/publication performed')
