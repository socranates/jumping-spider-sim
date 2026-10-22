"""Verify the exact cleanup source; keep native/full gates false until evidenced."""
from pathlib import Path
import hashlib,io,json,re,subprocess,sys,tarfile,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
SOURCE='a5dba50faa8efc2018acba90ad03356eb25ad20c'
BASE='fab75695ba918eeebe793e6768a08cabe99a70f3'
def read(name):return json.loads((HERE/name).read_text())
def text(name):return (HERE/name).read_text(encoding='utf8')
def digest(b):return hashlib.sha256(b).hexdigest()
def source_at(commit):
 archive=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as b:return {p.name:b.extractfile(p).read() for p in b if p.isfile()}
source=source_at(SOURCE);base=source_at(BASE);assert len(source)==len(base)==216
changed=[name for name in source if source[name]!=base[name]]
assert changed==['roblox_port/src/Client/WorldShadows.luau']
for name,data in source.items():assert (ROOT/name).read_bytes()==data,'worktree production input changed: '+name
compile=read('compile.json');assert compile['total']==compile['passed']==216
assert {row['path'] for row in compile['files']}==set(source)
for row in compile['files']:assert row['exit_code']==0 and row['sha256']==digest(source[row['path']])
for name in ['build','sourcemap','strict','runner']:assert read(name+'-process.json')['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',text('strict.txt'))
assert 'Ran 5 tests' in text('runner.txt') and re.search(r'^OK$',text('runner.txt'),re.M)
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text('targeted.txt'),re.M)
assert rows==[('SHADOWS','319','0'),('WORLD_CLIENT','30','0')]
progress=read('progress.json');assert progress['source']==SOURCE and progress['targeted_exit_code']==0
assert progress['targeted_sha256']==digest((HERE/'targeted.txt').read_bytes())
old=read('baseline-process.json');new=read('candidate-process.json')
assert old['exit_code']!=0 and new['exit_code']==0
assert old['test_sha256']==new['test_sha256']==digest((HERE/'probe.luau').read_bytes())
assert 'retained=3 fresh_shadow_off=0' in text('baseline.txt') and 'retained=0 fresh_shadow_off=3' in text('candidate.txt')
for receipt,tree in [(old,base),(new,source)]:
 for key,sha in receipt['source_hashes'].items():
  resolved=(ROOT/key).resolve();relative=resolved.relative_to(ROOT).as_posix()
  assert relative in tree and digest(tree[relative])==sha,relative
expected={}
for path,data in source.items():
 parts=list(Path(path).relative_to('roblox_port/src').parts)
 prefix={'First':'ReplicatedFirst','Client':'StarterPlayer.StarterPlayerScripts.Client','Server':'ServerScriptService.Server','Shared':'ReplicatedStorage.Shared'}[parts.pop(0)]
 parts[-1]=parts[-1].removesuffix('.luau').removesuffix('.client').removesuffix('.server')
 expected[prefix+'.'+'.'.join(parts)]=digest(data.replace(b'\r\n',b'\n'))
prepared=read('prepared-native-manifest.json');assert prepared['source']==SOURCE and prepared['persistence_disabled']
scripts={r['path']:r['sha256'] for r in prepared['scripts']};assert len(scripts)==len(prepared['scripts'])==217
assert scripts.pop('StarterPlayer.StarterPlayerScripts.Client.SilkPlayback')==digest((HERE/'native-probe.luau').read_bytes().replace(b'\r\n',b'\n'))
assert scripts==expected and 'Compiled' in text('native-compile.txt')
native=False;native_run=None;native_checks=None
if (HERE/'native-events.txt').exists():
 events=text('native-events.txt')
 assert '[SHADOW_CLEANUP_GUARD] '+SOURCE+' 217 persistence_disabled' in events
 assert '[SHADOW_CLEANUP_FAIL]' not in events and 'CreatorError' not in events
 done=re.findall(r'\[SHADOW_CLEANUP_DONE\]\s+(\d+)\s+7\s+(\d+)\s*$',events,re.M);assert len(done)==1
 native_run,native_checks=done[0];stages=re.findall(r'\[SHADOW_CLEANUP_CASE\]\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$',events,re.M)
 assert len(stages)==7 and [int(s[1]) for s in stages]==list(range(1,8)) and all(s[0]==native_run for s in stages)
 assert int(stages[-1][2])==int(native_checks);native=True
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
release_sha=release(ROOT/'roblox_port/TheWindowsill.rbxlx')
try:release(ROOT/'roblox_port/TheWindowsillTests.rbxlx')
except AssertionError:pass
else:raise AssertionError('test place accepted as release')
full=False
if (HERE/'windows-full-process.json').exists():
 assert read('windows-full-process.json')['exit_code']==0
 all_rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text('windows-full.txt'),re.M)
 assert len(all_rows)==64 and sum(int(row[1]) for row in all_rows)==443816 and all(int(row[2])==0 for row in all_rows)
 full=True
ci=read('ci-final.json') if (HERE/'ci-final.json').exists() else None
if ci:
 assert ci['head_sha']==SOURCE and ci['conclusion']=='success' and ci['suites']==64 and ci['passed']==443816 and ci['failed']==0
 for name,sha in ci['logs_sha256'].items():assert digest((HERE/name).read_bytes())==sha
if '--require-full' in sys.argv:assert full and ci and native,'full Windows/Linux and native execution required'
receipt={'source':SOURCE,'base_source':BASE,'evidence_id':'e7ee7af50d1b89b3','changed_production_modules':changed,
 'modules_compiled':216,'strict_clean':True,'runner_regressions':5,'targeted_suites':2,'targeted_passed':349,
 'same_behavioral_probe_fails_base_passes_candidate':True,'prepared_place_source_verified':True,
 'native_execution_verified':native,'native_run':native_run,'native_assertions':int(native_checks) if native_checks else None,
 'windows_full_complete':full,'windows_full_passed':443816 if full else None,'linux_ci_complete':bool(ci),'linux_ci_run':39777487503,
 'release_sha256':release_sha,'test_place_rejected':True,'network_streaming_verified':False,'fps_benefit_claimed':False,
 'isolated_studio_category_growth_fixed_claim':False,'published':False,'publication_ready':False}
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
