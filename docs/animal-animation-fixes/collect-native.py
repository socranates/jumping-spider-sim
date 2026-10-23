"""Verify the bounded local animation review; no full-game/FPS claim."""
from pathlib import Path
import hashlib,json,re
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
log=Path(r'C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261023T060621Z_Studio_D6B49_last.log')
text=log.read_text(encoding='utf8',errors='replace')
manifest=json.loads((H/'native-package.json').read_text())
assert manifest['production_startup'] is False and manifest['persistence'] is False
assert hashlib.sha256(Path(manifest['place']).read_bytes()).hexdigest()==manifest['sha256']
assert '[ANIMAL_ANIMATION_REVIEW_BEGIN] '+manifest['source'] in text
assert '[ANIMAL_ANIMATION_REVIEW_FAIL]' not in text and '[FLog::CreatorError]' not in text
match=re.search(r'\[ANIMAL_ANIMATION_REVIEW_PASS\]\s+(\d+)\s+collar_tag_and_cat_paw',text)
assert match and int(match[1])>=100,'Native scene did not complete'
for name in ['LivingWorld','CatBody']:
 raw=(ROOT/f'roblox_port/src/Client/{name}.luau').read_text().encode()
 expected=next(row['sha256'] for row in manifest['scripts'] if row['name']==name)
 assert hashlib.sha256(raw).hexdigest()==expected
events='\n'.join(line for line in text.splitlines() if 'ANIMAL_ANIMATION_REVIEW_' in line)+'\n'
(H/'native-events.txt').write_text(events,encoding='utf8',newline='\n')
receipt=dict(source=manifest['source'],log=str(log),log_sha256_at_capture=hashlib.sha256(log.read_bytes()).hexdigest(),events_sha256=hashlib.sha256(events.encode()).hexdigest(),place_sha256=manifest['sha256'],frames=int(match[1]),native_isolated_scene_passed=True,production_animal_modules_verified=True,manual_scene_observed=True,real_client_other_room_verified_by_shim_only=True,full_game_native_verified=False,fps_verified=False,published=False)
(H/'native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
