"""Collect the exact-source actual-client fixture, without broad gameplay/FPS claims."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
text=Path(a.log).read_text(encoding='utf8',errors='replace')
package=json.loads((H/'native-package.json').read_text(encoding='utf8'))
assert package['source']=='441eacaec05d0e1164473f19764f7d56f12b8482' and package['persistence_disabled']
place=Path(r'C:/Users/natha/claude-xfer/Windowsill-world-animation-441eaca/Windowsill-world-animation-review.rbxlx')
assert hashlib.sha256(place.read_bytes()).hexdigest()==package['place_sha256']
assert re.search(r'\[WORLD_ANIMATION_NATIVE_GUARD\]\s+'+package['source']+r'\s+223\s+persistence_disabled',text)
assert '[WORLD_ANIMATION_NATIVE_FAIL]' not in text and '[FLog::CreatorError]' not in text
begin=re.findall(r'\[WORLD_ANIMATION_NATIVE_BEGIN\]\s+(\d+)',text)
passed=re.findall(r'\[WORLD_ANIMATION_NATIVE_PASS\]\s+(\d+)\s+(\d+)',text)
assert len(begin)==len(passed)==1 and begin[0]==passed[0][0] and int(passed[0][1])==17
viewport=re.search(r'\[WORLD_ANIMATION_NATIVE_VIEWPORT\]\s+'+begin[0]+r'\s+(\d+)\s+(\d+)',text)
assert viewport and int(viewport[1])>=320 and int(viewport[2])>=180
events='\n'.join(line for line in text.splitlines() if 'WORLD_ANIMATION_NATIVE_' in line)+'\n'
(H/'native-events.txt').write_text(events,encoding='utf8',newline='\n')
receipt=dict(source=package['source'],run=begin[0],assertions=17,script_fingerprints=223,persistence_disabled=True,place_sha256=package['place_sha256'],events_sha256=hashlib.sha256(events.encode()).hexdigest(),viewport=[int(viewport[1]),int(viewport[2])],actual_client_fixture=True,known_state_animal_pose_fixture=True,native_hud_and_clock_wiring_verified=True,natural_lifecycle_verified=False,physical_devices_verified=False,real_saves_verified=False,fps_verified=False,published=False)
(H/'native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
