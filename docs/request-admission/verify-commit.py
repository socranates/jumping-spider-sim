"""Bind typed commit/writer/pipeline recovery, retaining the no-activation boundary."""
from pathlib import Path
import hashlib,importlib.util,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def main():
 runner=load('commit_qualified','run-commit.py');bundle,paths=runner.build()
 r=json.loads((H/'commit-qualified-1-receipt.json').read_text());raw=(H/'commit-qualified-1-output.txt').read_bytes();text=raw.decode()
 assert r['source']==SOURCE and r['exit_code']==0 and r['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 assert r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(raw)
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 prior=(H/'archive-qualified-2-output.txt').read_text();expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==41 and sum(p for p,f in expected.values())==213918 and all(f==0 for p,f in expected.values())
 cases=re.findall(r'^COMMIT_ADMISSION_CASE\s([^\t\n]+)\s(\d+)$',text,re.M)
 assert len(cases)==9 and {name for name,p in cases}=={'cold-plain-compressed-and-archive-policies','selected-rest-readback-wait-does-not-repeat-cas',
  'ambiguous-m1-rest-and-progress-writes-require-readback','root-cap-and-deadline-close-nested-work','cancel-committed-raw-rest-drains-without-rebind',
  'resume-reuses-exact-m1-and-immutable-originals','foreign-final-lease-cannot-verify-commit','deferred-rebind-witness-is-fresh-and-held-on-change',
  'queued-final-lease-must-execute-and-ack-current-owner'}
 commitCount=sum(int(p) for _,p in cases);assert commitCount==2980
 profiles=re.findall(r'^COMMIT_PROFILE_CASE\s(free|easy)\s(\d+)$',text,re.M)
 assert len(profiles)==2 and {name for name,p in profiles}=={'free','easy'}
 profileCount=sum(int(p) for _,p in profiles);assert profileCount==422
 expected.update(COMMIT_ADMISSION=(commitCount,0),COMMIT_PROFILE=(profileCount,0))
 rows=re.findall(pattern,text,re.M);assert len(rows)==43 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',text)
 for compressed in ['false','true']:
  for readonly,requests in [('false',52),('true',43)]:assert f'COMMIT_ADMISSION cold_compressed={compressed} read_only_archive={readonly} requests={requests} exact_raw_target=true gameplay_grant=false' in text
 assert r['typed_cold_pipeline'] and not any(r[k] for k in ['all_workers_typed','service_lanes_installed','normal_startup_installed','native_verified','online_verified','published'])
 checker=load('commit_type_qualification','check-commit.py').checker();sources=checker.paths()
 types=json.loads((H/'commit-types-development-1-types.json').read_text());assert len(sources)==46 and len(types['candidates'])==45
 assert types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 mounted={}
 for target,p in sources.items():
  code=p.read_text()
  if p in [H/'worker-v3.luau',H/'operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert types['mounted']==mounted and len(types['steps'])==3
 for step in types['steps']:assert step['exit_code']==0 and sha((H/('commit-types-development-1-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'commit-types-development-1-compile.txt').read_text()=='compile 46/46\n'
 strict=(H/'commit-types-development-1-strict.txt').read_text();assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 archive=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests','roblox_port/default.project.json'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as a:production={m.name:sha(a.extractfile(m).read()) for m in a if m.isfile()}
 assert all(sha((ROOT/name).read_bytes())==digest for name,digest in production.items())
 private=[H/x for x in ['proposal.luau','rest-writer.luau','progress-writer.luau','commit.luau','pipeline.luau','commit-tests.luau','commit-profile-tests.luau','commit-final-lease-tests.luau','run-commit.py','check-commit.py']]
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode==0 and subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)==p.read_bytes() for p in private)
 commit=subprocess.check_output(['git','log','-1','--format=%H','--',*[p.relative_to(ROOT).as_posix() for p in private]],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=commit,baseline_checks=213918,commit_pipeline_checks=commitCount,commit_pipeline_groups=9,
  profile_checks=profileCount,profile_groups=2,full_checks=213918+commitCount+profileCount,full_named_groups=84,full_failed=0,overlay_targets=46,distinct_private_sources=45,strict_clean=True,
  provider='memory',clock='synthetic',typed_cold_pipeline=True,main_raw_and_compressed_verified=True,free_easy_runtime_profiles_verified=True,
  all_workers_typed=False,service_lanes_installed=False,cooperative_driver_installed=False,normal_startup_installed=False,native_verified=False,online_verified=False,
  loading_speedup_proved=False,published=False,goal_complete=False)
 (H/'commit-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
