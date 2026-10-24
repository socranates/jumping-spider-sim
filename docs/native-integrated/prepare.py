"""Prepare an unpublished local fixture with the real engine self-test enabled."""
from pathlib import Path
import argparse,hashlib,json
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
src=Path('C:/Users/natha/claude-xfer/Windowsill-menu-player-attempt1')
guard=(src/'guard.luau').read_bytes();sha=lambda b:hashlib.sha256(b).hexdigest()
setup=b'assert(not game:GetService("RunService"):IsRunning() and game.PlaceId==0 and game.GameId==0);game:SetPlaceId(109879630247781);game:SetUniverseId(10771634917);workspace:SetAttribute("SelfTest",true);'
setup+=guard+b';assert(workspace:GetAttribute("SelfTest")==true);print("[INTEGRATED_NATIVE_FIXTURE]","selftest_only_never_publish",game.PlaceId,game.GameId)'
record=dict(source_model=str(src),manifest_sha256=sha((src/'manifest.json').read_bytes()),guard_sha256=sha(guard),setup_sha256=sha(setup),
 source_count=274,only_fixture_change='Workspace.SelfTest=true',never_publish=True,published=False,expected_checks=274)
post=guard+b';assert(workspace:GetAttribute("SelfTest")==true);print("[INTEGRATED_NATIVE_POST]","selftest_only_never_publish")'
record['post_guard_sha256']=sha(post)
if a.check:
 assert (H/'setup.luau').read_bytes()==setup and json.loads((H/'fixture.json').read_text())==record
 assert (H/'post-guard.luau').read_bytes()==post
else:
 if (H/'setup.luau').exists():assert (H/'setup.luau').read_bytes()==setup
 (H/'setup.luau').write_bytes(setup);(H/'post-guard.luau').write_bytes(post)
 (H/'fixture.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print('Native fixture setup verified'if a.check else 'Native fixture setup prepared')
