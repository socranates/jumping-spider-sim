from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
log=Path(r'C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261023T020558Z_Studio_84DFC_last.log')
lines=log.read_text(encoding='utf8').splitlines()
rows=[line for line in lines if ' > ' not in line and ('[NATIVE_SESSION_BUDGET_GUARD]' in line or '[NATIVE_SESSION_BUDGET_BEGIN] 1792721291445' in line or '[NATIVE_SESSION_BUDGET_FAIL] 1792721291445' in line)]
# Keep only the initial guard, before any corrected attempt in the same process.
rows=[next(x for x in rows if '[NATIVE_SESSION_BUDGET_GUARD]' in x)]+[x for x in rows if '1792721291445' in x]
assert len(rows)==3 and "attempt to index nil with 'MODES'" in rows[-1]
text='\n'.join(rows)+'\n';m=json.loads((HERE/'prepared-session-budget-native-initial-manifest.json').read_text())
(HERE/'session-budget-native-initial-failure-output.txt').write_text(text,encoding='utf8',newline='\n')
r=dict(source=m['source'],run='1792721291445',status='failed-fixture-setup',reason='Diagnostic omitted SaveRules import; candidate source and acceptance unchanged',assertions_completed=0,place_sha256=m['place_sha256'],candidates=m['candidates'],output_sha256=hashlib.sha256(text.encode()).hexdigest(),production_changed=False,published=False)
(HERE/'session-budget-native-initial-failure.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
