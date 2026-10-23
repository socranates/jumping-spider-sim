"""Bind archive admission, nested counts, bounded history and explicit overlay scope."""
from pathlib import Path
import hashlib,importlib.util,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def bind(prefix,bundle,inputs):
 r=json.loads((H/(prefix+'-receipt.json')).read_text());raw=(H/(prefix+'-output.txt')).read_bytes()
 assert r['source']==SOURCE and r['inputs']==inputs and r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(raw)
 return r,raw.decode()
def main():
 runner=load('archive_qualified','run-archive.py');bundle,paths=runner.build()
 r,text=bind('archive-qualified-2',bundle,{p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths});assert r['exit_code']==0
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 prior=(H/'entry-qualified-2-output.txt').read_text();expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==38 and sum(p for p,f in expected.values())==212214 and all(f==0 for p,f in expected.values())
 expected.update(ARCHIVE_ADMISSION=(927,0),NESTED_OPERATION=(37,0),TYPED_HISTORY=(740,0))
 rows=re.findall(pattern,text,re.M);assert len(rows)==41 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 cases=re.findall(r'^ARCHIVE_ADMISSION_CASE\s([^\t\n]+)\s(\d+)$',text,re.M)
 assert len(cases)==8 and sum(int(p) for _,p in cases)==927
 assert {name for name,_ in cases}=={'cold-archive-retains-child-state-and-exact-accounting','collector-failure-backoff-and-budget-wait-are-distinct',
  'changed-unselected-source-refuses-before-publication','parent-cap-closes-all-child-operations','committed-publication-cancellation-keeps-debt-and-drains',
  'completed-original-reuse-is-read-only-except-lease','blocked-renewal-allows-cpu-and-independent-reads','repository-running-marker-blocks-reentrant-step'}
 assert len(re.findall(r'^OPERATION_CASE\s',text,re.M))==5 and sum(int(n) for n in re.findall(r'^OPERATION_CASE\s[^\n]+\s(\d+)$',text,re.M))==37
 assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',text)
 assert r['typed_overrides']==['discovery','entry','read_lease','source_collector','archive_repository','archive_controller']
 assert not any(r[k] for k in ['all_workers_typed','service_lanes_installed','normal_startup_installed','native_verified','online_verified','published'])
 history=load('history_qualification','run-history.py')
 hb,hi,hp=history.build();hr,ht=bind('history-qualified-3',hb,hi)
 assert hr['exit_code']==0 and 'REQUEST_ADMISSION passed=4771 failed=0 groups=22' in ht and 'ADMISSION_BACKEND passed=82 failed=0 groups=8 options=5' in ht
 assert 'ADMISSION_BRIDGE passed=20 failed=0 groups=6' in ht and 'NESTED_OPERATION passed=37 failed=0 groups=5' in ht and 'TYPED_HISTORY passed=740 failed=0 groups=2' in ht
 oldTests=H/'history-before-tests.luau';bb,bi,bp=history.build(True,oldTests)
 bi['docs/request-admission/history-tests.luau']=bi.pop(oldTests.relative_to(ROOT).as_posix())
 br,bt=bind('history-before-fix',bb,bi)
 assert br['exit_code']!=0 and (H/'history-before-fix-bundle.luau').read_bytes()==bb.encode()
 assert 'typed scheduler request history grows without bound' in bt and 'TYPED_HISTORY passed=' not in bt
 checker=load('archive_types','check-archive.py').checker();sources=checker.paths()
 types=json.loads((H/'archive-types-qualified-2-types.json').read_text());assert len(sources)==46
 assert len(types['candidates'])==45 and types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 mounted={}
 for target,p in sources.items():
  code=p.read_text()
  if p in [H/'worker-v3.luau',H/'operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert types['mounted']==mounted and len(types['steps'])==3
 for step in types['steps']:assert step['exit_code']==0 and sha((H/('archive-types-qualified-2-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'archive-types-qualified-2-compile.txt').read_text()=='compile 46/46\n'
 strict=(H/'archive-types-qualified-2-strict.txt').read_text();assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests','roblox_port/default.project.json'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(raw)) as a:production={m.name:sha(a.extractfile(m).read()) for m in a if m.isfile()}
 assert all(sha((ROOT/name).read_bytes())==digest for name,digest in production.items())
 private=[H/x for x in ['operation.luau','collector.luau','repository.luau','controller.luau','worker-v3.luau','archive-tests.luau','archive-lease-tests.luau','operation-tests.luau','history-tests.luau','run-archive.py','check-archive.py']]
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode==0 and subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)==p.read_bytes() for p in private)
 commit=subprocess.check_output(['git','log','-1','--format=%H','--',*[p.relative_to(ROOT).as_posix() for p in private]],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=commit,baseline_checks=212214,archive_checks=927,archive_groups=8,nested_operation_checks=37,nested_operation_groups=5,
  history_checks=740,history_groups=2,full_checks=213918,full_named_groups=73,full_failed=0,portable_checks=5650,history_counterexample_bound=True,
  overlay_targets=46,distinct_private_sources=45,strict_clean=True,provider='memory',clock='synthetic',typed_worker_overrides=r['typed_overrides'],
  all_workers_typed=False,service_lanes_installed=False,cooperative_driver_installed=False,normal_startup_installed=False,native_verified=False,online_verified=False,
  loading_speedup_proved=False,published=False,goal_complete=False)
 (H/'archive-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
