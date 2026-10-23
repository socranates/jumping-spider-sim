"""Preserve the exact minimal initial-factory reproduction without rerunning it."""
from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parent;ROOT=H.parents[1];P=ROOT/'docs/save-slot-isolation'
r=json.loads((P/'initial-scope-before-1-receipt.json').read_text(encoding='utf8'))
assert r['exit_code']==1 and r['focused']
text=(P/'replacement-tests.luau').read_text(encoding='utf8')
line='   if options.initialFactoryFail and #f.owners==0 then error("synthetic initial factory failure") end\n'
assert text.count(line)==1;text=text.replace(line,'')
start=text.index('-- Shutdown and a subsequent visit must also fence the first suspended factory.')
stop=text.index('for _,mode in Rules.MODES do\n local f=fixture();f.recover(mode)',start)
text=text[:start]+text[stop:]
data=text.encode();sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(data)==r['inputs']['docs/save-slot-isolation/replacement-tests.luau']
assert sha((H/'before-initial-scope-replacement-service.luau').read_bytes())==r['inputs']['docs/save-slot-isolation/replacement-service-prototype.luau']
out=H/'before-initial-scope-replacement-tests.luau';assert not out.exists()
out.write_bytes(data)
assert 'late initial factory revived a removed player or acquired a lease' in (P/'initial-scope-before-1-output.txt').read_text(encoding='utf8')
print('Preserved exact before-fix service and minimal regression inputs')
