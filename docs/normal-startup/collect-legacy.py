"""Retain one native legacy-startup result with its exact model/source identity."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,re
H=Path(__file__).resolve().parent;sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--model',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--name',required=True);p.add_argument('--supplement',type=Path);a=p.parse_args()
assert re.fullmatch('[a-z0-9-]+',a.name);prefix=H/a.name;assert not prefix.with_suffix('.json').exists()
manifest=json.loads((a.model.parent/'manifest.json').read_text(encoding='utf8'))
spec=importlib.util.spec_from_file_location('legacy_model_check',H/'verify.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);v.model(manifest)
assert manifest['ordinary_ui'] and manifest['legacy_seeded'] and manifest['source_count'] in [275,276]
lines=a.log.read_text(encoding='utf8',errors='replace').splitlines()
selected=[s for s in lines if '[FLog::CreatorOutput]' in s and '> assert(' not in s and (
 '[LEGACY_STARTUP_' in s or '[NORMAL_STARTUP_GUARD]' in s or '[Windowsill] saves:' in s)]
assert sum('[NORMAL_STARTUP_GUARD] '+str(manifest['source_count'])+' unbound memory_only normal_startup_enabled' in s for s in selected)==1
supplement=None
if a.supplement:
 raw=('\n'.join(selected)+'\n').encode();prefix.with_name(prefix.name+'-raw-log.txt').write_bytes(raw)
 rows=a.supplement.read_text(encoding='utf8').splitlines()
 ui=[s for s in rows if '[LEGACY_STARTUP_PASS]' in s];cut=[s for s in selected if '[LEGACY_STARTUP_PASS]' in s]
 assert len(ui)==len(cut)==1
 full=re.search(r'\[LEGACY_STARTUP_PASS\]\s+(\d+)\s+(\{.*\})',ui[0]);assert full
 truncated=re.search(r'\[LEGACY_STARTUP_PASS\]\s+(\d+)\s+(\{.*)',cut[0]);assert truncated
 assert full[1]==truncated[1] and full[2].startswith(truncated[2]) and not truncated[2].endswith('}')
 selected=[s for s in selected if '[LEGACY_STARTUP_PASS]' not in s]+ui
 supplement=dict(path=a.supplement.name,sha256=sha(a.supplement.read_bytes()),raw_log_sha256=sha(raw),reason='Roblox log truncated terminal JSON; complete Studio Output retained')
found=[re.search(r'\[LEGACY_STARTUP_(PASS|FAIL)\]\s+(\d+)\s+(\{.*\})',s) for s in selected];found=[s for s in found if s];assert len(found)==1
kind,run,payload=found[0].groups();result=json.loads(payload)
if kind=='PASS':
 s=result['snapshot'];assert result['real_storage'] is False and result['ordinary_ui'] is True
 assert all(s['originalExact'][mode] for mode in ['main','free','easy']) and s['archives']==8 and s['archiveComplete']
 assert s['lockReleased'] and s['active']==s['gate']['scopes']==s['gate']['queued']==s['gate']['started']==0
 assert s['requests']==s['starts'] and s['optionsCreated']==s['optionsDestroyed']
 assert len(s['owners'])==3 and all(o['closed'] for o in s['owners'])
 modes=re.findall(r'\[LEGACY_STARTUP_MODE\]\s+\d+\s+(\{.*\})','\n'.join(selected))
 assert [json.loads(row)['mode'] for row in modes]==['main','free','easy']
output=('\n'.join(selected)+'\n').encode();prefix.with_suffix('.txt').write_bytes(output)
prefix.with_name(prefix.name+'-manifest.json').write_bytes((a.model.parent/'manifest.json').read_bytes())
receipt=dict(run=run,terminal='passed' if kind=='PASS' else 'failed',result=result,
 model_sha256=manifest['place_sha256'],source_count=manifest['source_count'],output_sha256=sha(output),log=str(a.log),supplement=supplement,real_storage=False,published=False)
prefix.with_suffix('.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode());print(json.dumps(receipt,indent=2))
