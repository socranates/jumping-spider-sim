"""Verify the caption candidate's source, release XML and retained offline receipts."""
from pathlib import Path
import hashlib,json,re,subprocess,xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
PORT=ROOT/'roblox_port'
SOURCE='bd91ee2ec2f4db1dad296cd2be9fc1ee23f4938e'
FULL_SOURCE='a36789375dd75920c0eca59ac524644b8776477f'
BASE='3647a94c67f83076a0c7be09d75ef4a60bb0b4d5'
EVIDENCE='fbcc7d9ce546a9b8'
def obj(name):return json.loads((OUT/name).read_text(encoding='utf-8-sig'))
def text(name):return (OUT/name).read_text(encoding='utf-8-sig',errors='replace')
def digest(data):return hashlib.sha256(data).hexdigest()
def rows(name):return re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text(name),re.M)

changed=subprocess.check_output(['git','diff','--name-only',BASE,SOURCE,'--','roblox_port/src'],cwd=ROOT,text=True).splitlines()
assert changed==['roblox_port/src/Client/SpiderClient.client.luau','roblox_port/src/Client/SpiderHud.luau','roblox_port/src/Shared/UI/SettingsModel.luau'],changed
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
assert obj('targeted-process.json')['exit_code']==0 and {r[0]:int(r[1]) for r in rows('targeted.txt')}=={'MINIMAL':63,'SETTINGS':1163,'QUIET':10,'STATE_CLIENT':162}
assert all(int(r[2])==0 for r in rows('targeted.txt'))
assert obj('runner-process.json')['exit_code']==0 and 'Ran 5 tests' in text('runner.txt') and re.search(r'^OK$',text('runner.txt'),re.M)
assert obj('baseline-process.json')['expected_failure'] and obj('baseline-process.json')['exit_code']!=0
assert 'MINIMAL passed=46 failed=17' in text('baseline-regression.txt')
tests=rows('windows-full.txt')
assert obj('windows-full-process.json')['exit_code']==0 and len(tests)==len({r[0] for r in tests})==62
assert sum(int(r[1]) for r in tests)==443424 and all(int(r[2])==0 for r in tests),tests
assert subprocess.check_output(['git','diff',FULL_SOURCE,SOURCE,'--','roblox_port/src'],cwd=ROOT)==b''
old_test=subprocess.check_output(['git','show',FULL_SOURCE+':roblox_port/tests/minimal_hud.luau'],cwd=ROOT)
assert (PORT/'tests/minimal_hud.luau').read_bytes()==old_test.replace(b'"controller"',b'"gamepad"')
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
native=text('native-caption-events.txt')
manifest=obj('native-manifest.json')
assert manifest['source']==FULL_SOURCE and manifest['persistence_disabled'] is True
assert len(manifest['scripts'])==217
native_sources={r['path']:r['sha256'] for r in manifest['scripts']}
assert native_sources.pop('StarterPlayer.StarterPlayerScripts.Client.SilkPlayback')==digest((OUT/'native-probe.luau').read_bytes().replace(b'\r\n',b'\n'))
assert native_sources==expected
assert '[CAPTION_NATIVE_GUARD] '+FULL_SOURCE+' 217 persistence_disabled' in native
assert 'CreatorError' not in native and '[CAPTION_NATIVE_FAIL]' not in native
stages=re.findall(r'\[CAPTION_NATIVE_STAGE\]\s+(\d+)\s+(\w+)\s+(\{.*\})',native)
assert [s[1] for s in stages]==['default_off','normal','large','off','reset_off']
run=stages[0][0];assert all(s[0]==run for s in stages)
assert re.search(r'\[CAPTION_NATIVE_DONE\]\s+'+run+r'\s+18\s*$',native,re.M)
for _,name,data in stages:
    d=json.loads(data);assert d['food_words']=='' and not d['food_label_visible']
    assert d['visible']==(name in {'normal','large'})
    if d['visible']:assert d['fits'] and d['text_size']==(23 if name=='large' else 15)
receipt={'source_commit':SOURCE,'base_source':BASE,'evidence_id':EVIDENCE,'changed_modules':changed,
         'compile':216,'strict_clean':True,'targeted_checks':1398,'runner_regressions':5,
         'baseline_regression_failed_as_expected':True,'windows_full_suites':62,'windows_full_passed':443424,
         'windows_full_source':FULL_SOURCE,'full_run_scope':'Initial tests used controller, not valid gamepad; final corrected test has separate targeted and CI results',
         'native_source':FULL_SOURCE,'production_sources_equal':True,
         'release':release(PORT/'TheWindowsill.rbxlx'),'test_place_rejected':test_place_rejected,'linux_ci_verified':ci_pass,'linux_ci':ci,
         'native_studio_verified':True,'native_checks':18,'native_scope':'Caption UI with persistence disabled; simulated device modes, desktop viewport only',
         'actual_client_rejoin_verified':False,'performance_claim':False,'publication_ready':False,'published':False}
(OUT/'source-manifest.json').write_text(json.dumps({'source_commit':SOURCE,'files':entries},indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(receipt,indent=2))
