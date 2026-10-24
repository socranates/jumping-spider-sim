"""Bind the targeted CLI/static-build cohort; no native execution is inferred."""
from pathlib import Path
import hashlib,json,re
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
stage=Path('C:/Users/natha/claude-xfer/Windowsill-matrix-after-full-lens-trace30-r2')
sha=lambda b:hashlib.sha256(b).hexdigest()
raw=(H/'targeted.txt').read_bytes();text=raw.decode('utf8')
counts={k:(int(p),int(f))for k,p,f in re.findall(r'^(TITLE|SETTINGS|EYES|CLIENT) passed=(\d+) failed=(\d+)\s*$',text,re.M)}
assert counts=={'TITLE':(21,0),'SETTINGS':(1164,0),'EYES':(231,0),'CLIENT':(27,0)},counts
build=json.loads((ROOT/'roblox_port/build-receipt.json').read_text())
assert build['evidence_id']=='66a9319760fa7c29'and build['source_count']==273
manifest=json.loads((stage/'manifest.json').read_text())
assert manifest['source_count']==277 and manifest['long_trace_seconds']==1800
assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']
assert (stage/'compile.txt').read_text().strip()=='compile 277/277'
assert 'TypeError'not in (stage/'strict.txt').read_text()
sources={p.relative_to(ROOT/'roblox_port/src').as_posix():sha(p.read_bytes().replace(b'\r\n',b'\n'))for p in (ROOT/'roblox_port/src').rglob('*.luau')}
assert sources==manifest['original_sources']
for name in ['manifest.json','compile.txt','strict.txt']:
 (H/('trace30-'+name)).write_bytes((stage/name).read_bytes())
files=['roblox_port/src/Client/SpiderCamera.luau','roblox_port/tests/title.luau','roblox_port/tests/settings.luau',
 'roblox_port/build-receipt.json','roblox_port/TheWindowsill.rbxlx','roblox_port/TheWindowsillTests.rbxlx',
 'docs/camera-handover/targeted.txt','docs/camera-handover/red.txt']
record=dict(evidence_id=build['evidence_id'],targeted_passes=sum(p for p,f in counts.values()),targeted_failures=0,
 suites=counts,targeted_exit_code=0,compile='277/277 including all273 normal sources',strict_exit_code=0,
 full_current_cli_executed=False,native_corrected_handover_executed=False,trace30_native_executed=False,
 normal_sources=sources,files={f:sha((ROOT/f).read_bytes())for f in files},
 trace_model_sha256=manifest['place_sha256'],trace_manifest_sha256=sha((stage/'manifest.json').read_bytes()),
 limits='CLI/static qualification only. Four earlier native performance runs precede this fix. No publication or production/save access.')
(H/'receipt.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(targeted_passes=record['targeted_passes'],evidence_id=build['evidence_id'],native=False)))
