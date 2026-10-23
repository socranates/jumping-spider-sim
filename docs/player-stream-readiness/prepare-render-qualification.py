"""Keep the first candidate's evidence intact while qualifying the native-driven correction."""
from pathlib import Path
import subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert source=='695e772d9d1ece490dd32132c655ac60c226c7b8'
target=ROOT/'docs/player-stream-render-readiness';assert not target.exists();target.mkdir()
for name in ['full.py','fetch-ci.py','locate-ci.py','verify-gates.py','check-production.py','check-private.py','build-production.py','build-native.py','verify-native-prepared.py','record-native.py','native-probe.luau']:
 text=(H/name).read_text(encoding='utf8').replace('bf94f9d034018613ed088db001e4f909a52db249',source).replace('Windowsill-production-bf94f9d','Windowsill-production-695e772').replace('Windowsill-native-player-bf94f9d-full','Windowsill-native-player-695e772-full').replace('player-types-1','player-render-types-1')
 if name=='verify-gates.py':
  text=text.replace("assert not re.search(r'\\b(?:fail|failed)","assert 'PLAYER_STREAM_RENDER_WAIT sub_tick_frames=12 waiting_stable=true clocks_frozen=true' in text\nassert not re.search(r'\\b(?:fail|failed)")
  text=text.replace('player_collision_hold_and_projected_tick_cli_verified=True,','player_collision_hold_and_projected_tick_cli_verified=True,player_sub_tick_render_wait_verified=True,')
 (target/name).write_text(text,encoding='utf8',newline='\n')
print(target)
