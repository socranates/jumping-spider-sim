"""Bind typed held maintenance, actual retry/Runtime and unfixed Session probes."""
from pathlib import Path
import hashlib,importlib.util,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def main():
 runner=load('held_qualified','run-held.py');bundle,paths=runner.build()
 r=json.loads((H/'held-qualified-1-receipt.json').read_text());raw=(H/'held-qualified-1-output.txt').read_bytes();text=raw.decode()
 assert r['source']==SOURCE and r['exit_code']==0 and not r['focused']
 assert r['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 assert r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(raw)
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 prior=(H/'lifecycle-qualified-1-output.txt').read_text(encoding='utf8');expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==47 and sum(p for p,f in expected.values())==272651 and all(f==0 for p,f in expected.values())
 counts={'all-terminal-phases-maintain-only-the-owned-lock':8638,'stable-renewal-evidence-and-callback-replay-across-wait':62,
  'ambiguous-renewal-reprobes-with-provider-backoff':76,'queued-probe-expiry-foreign-owner-and-route-loss-refuse':54,'cancel-suspended-committed-renewal-drains-account':12,
  'explicit-retry-cancels-queued-idle-and-uses-shared-pipeline':354,'closed-departure-stops-held-route-and-preserves-local-choices':316}
 cases=re.findall(r'^HELD_ADMISSION_CASE\s([^\t\n]+)\s(\d+)$',text,re.M)
 assert len(cases)==7 and {name:int(p) for name,p in cases}==counts and sum(counts.values())==9512
 rt=re.findall(r'^HELD_RUNTIME_CASE\s([^\t\n]+)\s(\d+)$',text,re.M);assert rt==[('actual-Runtime-cancel-holds-maintains-and-departs-through-one-lane','207')]
 expected.update(HELD_ADMISSION=(9512,0),HELD_RUNTIME=(207,0))
 rows=re.findall(pattern,text,re.M);assert len(rows)==49 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 assert sum(p for p,f in expected.values())==282370 and not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',text)
 assert r['terminal_held_idle_typed'] and not any(r[k] for k in ['all_workers_typed','service_lanes_installed','normal_startup_installed','native_verified','online_verified','published'])
 checker=load('held_type_qualification','check-held.py').checker();sources=checker.paths()
 types=json.loads((H/'held-types-development-1-types.json').read_text());assert len(sources)==46 and len(types['candidates'])==45
 assert types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 mounted={}
 for target,p in sources.items():
  code=p.read_text()
  if p in [H/'worker-v3.luau',H/'operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert types['mounted']==mounted and len(types['steps'])==3
 for step in types['steps']:assert step['exit_code']==0 and sha((H/('held-types-development-1-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'held-types-development-1-compile.txt').read_text()=='compile 46/46\n'
 strict=(H/'held-types-development-1-strict.txt').read_text();assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 negative=load('held_preceding_counterexample','run-held-negative.py');nb,np=negative.build()
 nr=json.loads((H/'held-before-admission-negative-1-receipt.json').read_text());no=(H/'held-before-admission-negative-1-output.txt').read_bytes()
 assert nr['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in np} and nr['bundle_sha256']==sha(nb.encode())
 assert nr['output_sha256']==sha(no) and nr['exit_code']!=0 and nr['expected_failure'] in no.decode()
 probe=load('held_session_boundary','probe-session-boundaries.py')
 for case in ['late-lock','read-account']:
  pb,pp=probe.build(case);pr=json.loads((H/('session-boundaries-before-fix-1-'+case+'-receipt.json')).read_text());rawProbe=(H/('session-boundaries-before-fix-1-'+case+'-output.txt')).read_bytes()
  assert pr['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in pp}
  assert pr['bundle_sha256']==sha(pb.encode()) and pr['output_sha256']==sha(rawProbe) and pr['exit_code']!=0 and not pr['issue_fixed']
  assert pr['expected_failure'] in rawProbe.decode() and 'fixed=true' not in rawProbe.decode()
 session=(ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau').read_text(encoding='utf8')
 assert session.count('self.backend:update(')==5 and len(re.findall(r'(?<!function )readCurrent\(self,self.rkey\[mode\]\)',session))==3
 archive=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests','roblox_port/default.project.json'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as a:production={m.name:sha(a.extractfile(m).read()) for m in a if m.isfile()}
 assert all(sha((ROOT/name).read_bytes())==digest for name,digest in production.items())
 private=[H/x for x in ['idle.luau','runtime-held.luau','held-tests.luau','held-runtime-tests.luau','run-held.py','check-held.py','verify-held.py',
  'run-held-negative.py','session-boundary-tests.luau','probe-session-boundaries.py','SESSION-BOUNDARIES.md']]
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode==0 and subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)==p.read_bytes() for p in private)
 commit=subprocess.check_output(['git','log','-1','--format=%H','--',*[p.relative_to(ROOT).as_posix() for p in private]],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=commit,baseline_checks=272651,held_checks=9512,held_Runtime_checks=207,
  full_checks=282370,full_named_groups=119,full_failed=0,overlay_targets=46,distinct_private_sources=45,strict_clean=True,
  terminal_held_idle_typed=True,preceding_held_admission_failure_reproduced=True,actual_retry_and_Runtime_held_departure_verified=True,unfixed_ordinary_Session_boundary_counterexamples=2,
  provider='memory',clock='synthetic',all_workers_typed=False,ordinary_Session_typed=False,service_lanes_installed=False,cooperative_driver_installed=False,
  normal_startup_installed=False,native_verified=False,online_verified=False,loading_speedup_proved=False,published=False,goal_complete=False)
 (H/'held-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
