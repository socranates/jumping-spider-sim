"""Reconstruct source-bound save-notice gates; full Windows/Linux remain explicit."""
from pathlib import Path
import hashlib,io,json,re,subprocess,sys,tarfile,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
SOURCE='fab75695ba918eeebe793e6768a08cabe99a70f3'
def read(name):return json.loads((HERE/name).read_text())
def text(name):return (HERE/name).read_text(encoding='utf8')
def digest(b):return hashlib.sha256(b).hexdigest()
archive=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
 source={p.name:bundle.extractfile(p).read() for p in bundle if p.isfile()}
assert len(source)==216
expected={}
for path,data in source.items():
 parts=list(Path(path).relative_to('roblox_port/src').parts)
 prefix={'First':'ReplicatedFirst','Client':'StarterPlayer.StarterPlayerScripts.Client','Server':'ServerScriptService.Server','Shared':'ReplicatedStorage.Shared'}[parts.pop(0)]
 parts[-1]=parts[-1].removesuffix('.luau').removesuffix('.client').removesuffix('.server')
 expected[prefix+'.'+'.'.join(parts)]=digest(data.replace(b'\r\n',b'\n'))
compile=read('compile.json');assert compile['total']==compile['passed']==216
assert {row['path'] for row in compile['files']}==set(source)
for row in compile['files']:assert row['exit_code']==0 and row['sha256']==digest(source[row['path']])
for name in ['build','sourcemap','strict','runner']:assert read(name+'-process.json')['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',text('strict.txt'))
assert 'Ran 5 tests' in text('runner.txt') and re.search(r'^OK$',text('runner.txt'),re.M)
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text('targeted.txt'),re.M)
assert len(rows)==5 and sum(int(r[1]) for r in rows)==389 and all(int(r[2])==0 for r in rows)
assert 'FAIL' not in text('targeted.txt')
baseline=read('baseline-process.json');candidate=read('candidate-process.json')
assert baseline['source']=='3c8de801e5fab68598e1e5323e7f5e1c8151b0e6' and baseline['exit_code']!=0
assert candidate['source']==SOURCE and candidate['exit_code']==0
assert baseline['test_sha256']==candidate['test_sha256']==digest((HERE/'baseline.luau').read_bytes())
assert 'broken=true visible=false' in text('baseline.txt') and 'broken=true visible=true' in text('candidate.txt')
manifest=read('native-manifest.json');assert manifest['source']==SOURCE and manifest['persistence_disabled'] is True
native_sources={row['path']:row['sha256'] for row in manifest['scripts']}
assert len(native_sources)==len(manifest['scripts'])==217
assert native_sources.pop('StarterPlayer.StarterPlayerScripts.Client.SilkPlayback')==digest((HERE/'native-probe.luau').read_bytes().replace(b'\r\n',b'\n'))
assert native_sources==expected
events=text('native-events.txt')
assert '[SAVE_NOTICE_GUARD] '+SOURCE+' 217 persistence_disabled' in events
assert '[SAVE_NOTICE_DONE] 1792668342799 16' in events and '[SAVE_NOTICE_FAIL]' not in events and 'CreatorError' not in events

def release(path):
 found={}
 def walk(item,parent=''):
  name=item.findtext("./Properties/*[@name='Name']");full=parent+'.'+name if parent else name
  assert name not in {'SilkPlayback','PortTests','RigExperiment','RigCached','RigMeasured'} and not name.startswith('Chet')
  if item.attrib['class'] in {'Script','LocalScript','ModuleScript'}:
   code=item.findtext("./Properties/*[@name='Source']");assert code is not None and full not in found
   found[full]=digest(code.replace('\r\n','\n').encode())
  for child in item.findall('Item'):walk(child,full)
 for item in ET.parse(path).getroot().findall('Item'):walk(item)
 assert found==expected
 return digest(path.read_bytes())
release_hash=release(ROOT/'roblox_port/TheWindowsill.rbxlx')
try:release(ROOT/'roblox_port/TheWindowsillTests.rbxlx')
except AssertionError:pass
else:raise AssertionError('test place accepted as release')
full=False
if (HERE/'windows-full-process.json').exists():
 assert read('windows-full-process.json')['exit_code']==0
 all_rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text('windows-full.txt'),re.M)
 assert len(all_rows)==64 and sum(int(row[1]) for row in all_rows)==443522 and all(int(row[2])==0 for row in all_rows)
 full=True
ci=read('ci-final.json') if (HERE/'ci-final.json').exists() else None
if ci:
 assert ci['head_sha']==SOURCE and ci['conclusion']=='success' and ci['suites']==64 and ci['passed']==443522 and ci['failed']==0
 for name,sha in ci['logs_sha256'].items():assert digest((HERE/name).read_bytes())==sha
if '--require-full' in sys.argv:assert full and ci,'full Windows and Linux CI required'
receipt={'source':SOURCE,'evidence_id':'ed58c07d5b24c8ae','modules_compiled':216,'strict_clean':True,'targeted_suites':5,'targeted_passed':389,
 'baseline_hidden_warning_reproduced':True,'identical_candidate_probe_passed':True,'native_run':'1792668342799','native_assertions':16,
 'persistence_disabled':True,'release_sha256':release_hash,'test_place_rejected':True,'windows_full_complete':full,
 'windows_full_passed':443522 if full else None,'linux_ci_complete':bool(ci),'linux_ci_run':39770144327,
 'phone_verified':False,'actual_online_rejoin_verified':False,'performance_claim':False,'published':False,'publication_ready':False}
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
