"""Reconstruct and bind recovered saving, exact predecessor and negative proof."""
from pathlib import Path
import hashlib,importlib.util,io,json,re,subprocess,tarfile,zipfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def main():
 runner=load('saving_qualified','run-saving.py');bundle,paths=runner.build()
 r=json.loads((H/'saving-qualified-1-receipt.json').read_text());raw=(H/'saving-qualified-1-output.txt').read_bytes();text=raw.decode()
 assert r['source']==SOURCE and r['exit_code']==0 and not r['focused']
 assert r['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 assert r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(raw)
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 prior=(H/'commit-qualified-1-output.txt').read_text();expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==43 and sum(p for p,f in expected.values())==217320 and all(f==0 for p,f in expected.values())
 names={'all-modes-progress-checkpoint-and-idle-lease','queued-progress-keeps-later-player-choice-and-debounce','rest-readback-and-final-witness-waits-never-ack-early',
  'ambiguous-progress-and-rest-acks-require-fresh-readback','captured-checkpoint-not-starved-by-later-notebook-progress','queued-cancel-and-foreign-owner-never-publish-stored-receipt',
  'yielded-progress-retains-newer-player-choice','committed-rest-cancel-drains-before-account-replacement','typed-progress-does-not-reenter-old-aggregate-limiter',
  'thrown-provider-keeps-progress-readback-retry-and-cap','queued-current-rest-cap-and-deadline-cleanup'}
 cases=re.findall(r'^SAVING_ADMISSION_CASE\s([^\t\n]+)\s(\d+)$',text,re.M)
 assert len(cases)==11 and {name for name,p in cases}==names
 checks=sum(int(p) for _,p in cases);assert checks==37360
 expected['SAVING_ADMISSION']=(checks,0)
 rows=re.findall(pattern,text,re.M);assert len(rows)==44 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',text)
 assert r['typed_recovered_saving'] and not any(r[k] for k in ['all_workers_typed','service_lanes_installed','normal_startup_installed','native_verified','online_verified','published'])
 checker=load('saving_type_qualification','check-saving.py').checker();sources=checker.paths()
 types=json.loads((H/'saving-types-development-2-types.json').read_text());assert len(sources)==46 and len(types['candidates'])==45
 assert types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 mounted={}
 for target,p in sources.items():
  code=p.read_text()
  if p in [H/'worker-v3.luau',H/'operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert types['mounted']==mounted and len(types['steps'])==3
 for step in types['steps']:assert step['exit_code']==0 and sha((H/('saving-types-development-2-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'saving-types-development-2-compile.txt').read_text()=='compile 46/46\n'
 strict=(H/'saving-types-development-2-strict.txt').read_text();assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 negative=json.loads((H/'saving-old-due-negative-1-receipt.json').read_text());nb,np=runner.build(True)
 old='''-- The shared typed gate owns capacity; keep only per-key debounce here.
  -- Calling due() would silently retain the obsolete aggregate 10-start cap.
  if self.options.admission then
   if s.now()<s.sched.items.progress.nextAt then return false end
  elseif not s.sched:due("progress",s.now()) then return false end'''
 assert nb.count(old)==1;nb=nb.replace(old,'if not s.sched:due("progress",s.now()) then return false end')
 nr=(H/'saving-old-due-negative-1-output.txt').read_bytes()
 assert negative['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in np}
 assert negative['bundle_sha256']==sha(nb.encode()) and negative['output_sha256']==sha(nr) and negative['exit_code']!=0
 assert 'progress still depended on obsolete aggregate capacity' in nr.decode() and 'SAVING_ADMISSION passed=' not in nr.decode()
 development=json.loads((H/'saving-development-1-receipt.json').read_text())
 with zipfile.ZipFile(H/'saving-development-1-bundle.zip') as z:assert sha(z.read('run.luau'))==development['bundle_sha256']
 assert development['exit_code']!=0 and sha((H/'saving-development-1-output.txt').read_bytes())==development['output_sha256']
 assert 'typed route bypassed debounce' in (H/'saving-development-1-output.txt').read_text()
 archive=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests','roblox_port/default.project.json'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as a:production={m.name:sha(a.extractfile(m).read()) for m in a if m.isfile()}
 assert all(sha((ROOT/name).read_bytes())==digest for name,digest in production.items())
 private=[H/x for x in ['routine-progress.luau','current-writer.luau','save-loop.luau','saving-tests.luau','saving-lifetime-tests.luau','run-saving.py','check-saving.py','run-saving-negative.py','verify-saving.py']]
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode==0 and subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)==p.read_bytes() for p in private)
 commit=subprocess.check_output(['git','log','-1','--format=%H','--',*[p.relative_to(ROOT).as_posix() for p in private]],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=commit,baseline_checks=217320,saving_checks=checks,saving_groups=11,
  full_checks=217320+checks,full_named_groups=95,full_failed=0,overlay_targets=46,distinct_private_sources=45,strict_clean=True,
  old_aggregate_counterexample_reproduced=True,main_free_easy_recovered_saving_verified=True,suspended_committed_write_cancel_and_drain_verified=True,
  provider='memory',clock='synthetic',typed_recovered_saving=True,all_workers_typed=False,service_lanes_installed=False,cooperative_driver_installed=False,
  normal_startup_installed=False,native_verified=False,online_verified=False,loading_speedup_proved=False,published=False,goal_complete=False)
 (H/'saving-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
