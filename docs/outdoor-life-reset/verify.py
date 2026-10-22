"""Verify source-bound outdoor reset receipts; report unfinished full/CI gates honestly."""
from pathlib import Path
import hashlib,json,re,subprocess,sys,xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
PORT=ROOT/'roblox_port'
SOURCE='3c8de801e5fab68598e1e5323e7f5e1c8151b0e6'
BASE='b1be9f1d59650463a0cc82c230dae63afdccb687'
EVIDENCE='d543592dddf4e621'
def obj(name):return json.loads((OUT/name).read_text(encoding='utf-8-sig'))
def text(name):return (OUT/name).read_text(encoding='utf-8-sig',errors='replace')
def digest(data):return hashlib.sha256(data).hexdigest()
def rows(name):return re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text(name),re.M)

changed=subprocess.check_output(['git','diff','--name-only',BASE,SOURCE,'--','roblox_port/src'],cwd=ROOT,text=True).splitlines()
assert changed==['roblox_port/src/Client/SpiderClient.client.luau','roblox_port/src/Shared/Predator/Bird.luau','roblox_port/src/Shared/Predator/CrabSpider.luau','roblox_port/src/Shared/Predator/Frog.luau'],changed
entries=[];expected={}
for line in subprocess.check_output(['git','ls-tree','-rz',SOURCE,'roblox_port/src'],cwd=ROOT).split(b'\0'):
    if not line:continue
    header,name=line.split(b'\t',1);path=name.decode();data=(ROOT/path).read_bytes()
    assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==header.split()[2].decode(),path
    parts=list(Path(path).relative_to('roblox_port/src').parts)
    prefix={'First':'ReplicatedFirst','Client':'StarterPlayer.StarterPlayerScripts.Client','Server':'ServerScriptService.Server','Shared':'ReplicatedStorage.Shared'}[parts.pop(0)]
    parts[-1]=parts[-1].removesuffix('.luau').removesuffix('.client').removesuffix('.server')
    instance=prefix+'.'+'.'.join(parts);norm=data.replace(b'\r\n',b'\n')
    expected[instance]=digest(norm);entries.append({'path':path,'instance':instance,'sha256':digest(data),'native_sha256':digest(norm)})
assert len(expected)==216
compiled=obj('compile.json');assert compiled['passed']==compiled['total']==216
assert {r['path'] for r in compiled['files']}=={r['path'] for r in entries}
assert all(r['exit_code']==0 and digest((ROOT/r['path']).read_bytes())==r['sha256'] for r in compiled['files'])
assert obj('strict-process.json')['exit_code']==0 and not re.search(r'TypeError|SyntaxError|Error:',text('strict.txt'))
assert obj('targeted-process.json')['exit_code']==0 and {r[0]:int(r[1]) for r in rows('targeted.txt')}=={'OUTDOOR_RESET':45,'NATURE':28890,'NATURE_CLIENT':6,'MINIMAL':63,'STATE_CLIENT':162}
assert all(int(r[2])==0 for r in rows('targeted.txt'))
assert obj('runner-process.json')['exit_code']==0 and 'Ran 5 tests' in text('runner.txt') and re.search(r'^OK$',text('runner.txt'),re.M)
assert obj('baseline-process.json')['expected_failure'] and obj('baseline-process.json')['exit_code']!=0
assert 'OUTDOOR_RESET passed=30 failed=15' in text('baseline.txt')
assert 'missing method' not in text('baseline.txt')
assert obj('baseline-process.json')['source_commit']==BASE
assert obj('baseline-process.json')['test_sha256']==digest((PORT/'tests/outdoor_life_reset.luau').read_bytes())
assert obj('baseline-process.json')['source_archive_sha256']==digest(subprocess.check_output(['git','archive','--format=zip',BASE,'roblox_port/src'],cwd=ROOT))
assert (PORT/'tests/run.py').read_bytes()==subprocess.check_output(['git','show',SOURCE+':roblox_port/tests/run.py'],cwd=ROOT)
full_done=(OUT/'windows-full-process.json').exists()
tests=rows('windows-full.txt') if (OUT/'windows-full.txt').exists() else []
if full_done:
    assert obj('windows-full-process.json')['exit_code']==0 and len(tests)==len({r[0] for r in tests})==63
    assert all(int(r[2])==0 for r in tests) and ('OUTDOOR_RESET','45','0') in tests
h=hashlib.sha256()
for path in sorted([*PORT.glob('src/**/*.luau'),*PORT.glob('tests/**/*.luau'),*PORT.glob('*.project.json')]):
    if path.name!='BuildInfo.luau':h.update(path.relative_to(PORT).as_posix().encode()+b'\0'+path.read_bytes()+b'\0')
assert h.hexdigest()[:16]==EVIDENCE
assert EVIDENCE in (PORT/'tests/studio/BuildInfo.luau').read_text()

def release(path):
    found={}
    def walk(item,parent=''):
        name=item.findtext("./Properties/string[@name='Name']") or item.attrib['class']
        full=parent+'.'+name if parent else name
        assert not name.startswith('Chet') and name not in {'SilkPlayback','PortTests','RigExperiment','RigCached','RigMeasured'},'diagnostic content: '+full
        if item.attrib['class'] in {'Script','LocalScript','ModuleScript'}:
            assert full not in found
            code=item.findtext("./Properties/*[@name='Source']");assert code is not None
            found[full]=digest(code.replace('\r\n','\n').encode())
        if item.attrib['class']=='Workspace':assert item.findtext("./Properties/BinaryString[@name='AttributesSerialize']") in {None,''},'diagnostic workspace attributes'
        for child in item.findall('Item'):walk(child,full)
    for item in ET.parse(path).getroot().findall('Item'):walk(item)
    assert found==expected,'release source set/fingerprints differ'
    return {'sha256':digest(path.read_bytes()),'scripts':len(found),'diagnostic_content':False}

try:release(PORT/'TheWindowsillTests.rbxlx')
except AssertionError:test_place_rejected=True
else:raise AssertionError('test place accepted as a production release')

ci=obj('ci-final.json') if (OUT/'ci-final.json').exists() else obj('ci-progress.json') if (OUT/'ci-progress.json').exists() else None
if ci:assert ci.get('head_sha')==SOURCE
required={'Every module compiles','Strict types','All suites','Runner failure and cleanup regressions'}
steps={s['name']:s.get('conclusion') for j in (ci or {}).get('jobs_evidence',{}).get('jobs',[]) for s in j.get('steps',[])}
ci_pass=bool(ci and ci.get('head_sha')==SOURCE and ci.get('conclusion')=='success' and all(steps.get(s)=='success' for s in required))
native=text('native-events.txt')
manifest=obj('native-manifest.json')
assert manifest['source']==SOURCE and manifest['persistence_disabled'] is True
assert len(manifest['scripts'])==217
native_sources={r['path']:r['sha256'] for r in manifest['scripts']}
assert native_sources.pop('StarterPlayer.StarterPlayerScripts.Client.SilkPlayback')==digest((OUT/'native-probe.luau').read_bytes().replace(b'\r\n',b'\n'))
assert native_sources==expected
assert '[OUTDOOR_RESET_GUARD] '+SOURCE+' 217 persistence_disabled' in native
assert 'CreatorError' not in native and '[OUTDOOR_RESET_FAIL]' not in native
stages=re.findall(r'\[OUTDOOR_RESET_STAGE\]\s+(\d+)\s+(\w+)\s+(\d+)',native)
assert [(s[1],s[2]) for s in stages]==[('main','19'),('free','37')]
run=stages[0][0];assert all(s[0]==run for s in stages)
assert re.search(r'\[OUTDOOR_RESET_DONE\]\s+'+run+r'\s+46\s*$',native,re.M)
if '--require-full' in sys.argv:assert full_done and ci_pass,'full Windows and successful Linux CI required'
receipt={'source_commit':SOURCE,'base_source':BASE,'evidence_id':EVIDENCE,'changed_modules':changed,
         'compile':216,'strict_clean':True,'targeted_checks':29166,'runner_regressions':5,
         'baseline_regression_failed_as_expected':True,'windows_full_complete':full_done,
         'windows_full_suites':len(tests) if full_done else None,'windows_full_passed':sum(int(r[1]) for r in tests) if full_done else None,
         'release':release(PORT/'TheWindowsill.rbxlx'),'test_place_rejected':test_place_rejected,'linux_ci_verified':ci_pass,'linux_ci':ci,
         'native_studio_verified':True,'native_checks':46,'native_run':run,'native_scope':'Real client callbacks and in-session rest recovery, persistence script disabled; not online rejoin or a performance run',
         'actual_online_rejoin_verified':False,'performance_claim':False,'publication_ready':False,'published':False}
(OUT/'source-manifest.json').write_text(json.dumps({'source_commit':SOURCE,'files':entries},indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='linux_ci'},indent=2))
