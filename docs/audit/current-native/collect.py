"""Collect only bounded native audit diagnostics; never copies the whole engine log."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
p=argparse.ArgumentParser();p.add_argument('--log',required=True);p.add_argument('--tier',choices=['full','low'],required=True);a=p.parse_args()
manifest=json.loads((HERE/('prepared-'+a.tier+'-manifest.json')).read_text(encoding='utf8'))
source=manifest['source'];sha=lambda b:hashlib.sha256(b).hexdigest()
# Rebind every module fingerprint to committed bytes and the current unchanged tree.
expected={};prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
for entry in subprocess.check_output(['git','ls-tree','-rz',source,'roblox_port/src'],cwd=ROOT).split(b'\0'):
 if not entry:continue
 _,name=entry.split(b'\t',1);path=name.decode();data=(ROOT/path).read_bytes()
 frozen=subprocess.check_output(['git','show',source+':'+path],cwd=ROOT)
 assert data==frozen,path
 parts=list(Path(path).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
assert len(expected)==222 and {r['path']:r['sha256'] for r in manifest['scripts']}==expected
lines=Path(a.log).read_text(encoding='utf8').splitlines()
guard='[NATIVE_CURRENT_AUDIT_GUARD] '+source+' 222 persistence_disabled'
start=[i for i,l in enumerate(lines) if guard in l and ' > ' not in l][-1]
begins=[i for i,l in enumerate(lines) if i>start and '[SELFTEST] BEGIN' in l];assert len(begins)==1
ends=[i for i,l in enumerate(lines) if i>begins[0] and '[SELFTEST] END ' in l];assert len(ends)==1,'No unique terminal self-test marker'
span=lines[start:ends[0]+1]
rows=[l for l in span if '[FLog::CreatorOutput]' in l and ('[SELFTEST]' in l or guard in l) and ' > ' not in l]
text='\n'.join(rows)+'\n';end=re.search(r'END pass=(\d+) fail=(\d+) skip=(\d+)',rows[-1]);assert end
counts=dict(zip(['passed','failed','skipped'],map(int,end.groups())))
assert len([l for l in rows if '[SELFTEST] PASS ' in l])==counts['passed']
assert len([l for l in rows if '[SELFTEST] FAIL ' in l])==counts['failed']
assert len([l for l in rows if '[SELFTEST] SKIP ' in l])==counts['skipped']
assert not any('[SELFTEST] INFO scope: selected checks' in l for l in rows)
errors=[l for l in span if '[FLog::CreatorError]' in l]
(HERE/(a.tier+'-output.txt')).write_text(text,encoding='utf8',newline='\n')
(HERE/(a.tier+'-errors.json')).write_text(json.dumps(errors,indent=2)+'\n',encoding='utf8',newline='\n')
receipt={'source':source,'tier':a.tier,'scripts':222,'persistence_disabled':True,'place_sha256':manifest['place_sha256'],**counts,
 'creator_error_rows':len(errors),'output_sha256':sha(text.encode()),'full_selftest':True,
 'region_visits':len([l for l in rows if '[SELFTEST] PASS region ' in l]),
 'observations':[l.split('[SELFTEST] INFO ',1)[1] for l in rows if '[SELFTEST] INFO ' in l],
 'scope':'Scripted native support/creature/UI checks, not exhaustive manual traversal, physical devices, natural full lifecycle, online durability or causal FPS gain',
 'passed_gate':counts['failed']==counts['skipped']==len(errors)==0,'published':False}
(HERE/(a.tier+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='observations'},indent=2))
