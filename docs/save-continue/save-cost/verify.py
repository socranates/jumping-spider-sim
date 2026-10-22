"""Current full Linux gate, exact live bytes; native/Windows scope stays explicit."""
from pathlib import Path
import hashlib,io,json,re,runpy,subprocess,tarfile,importlib.util,zipfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
SOURCE='ab8ca9577129e3d9583a0a8ab6824dae1a8cd014'
BASE='4ee6aecc06f4753a85e40fc98a1487dc5126d27d'
sha=lambda b:hashlib.sha256(b).hexdigest()
def archive(source):
 raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(raw)) as bundle:
  return {m.name:bundle.extractfile(m).read() for m in bundle if m.isfile()}
current=archive(SOURCE);base=archive(BASE)
assert current.keys()==base.keys()
assert [name for name in current if current[name]!=base[name]]==['roblox_port/src/Client/SelfTest.luau']
for name,data in current.items():assert (ROOT/name).read_bytes()==data,name
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==SOURCE
# Earlier stage still checks immutable original/corrected focused cohorts and
# the exact old native fingerprints. It does not claim native proof on SOURCE.
runpy.run_path(str(HERE.parent/'local-return/verify.py'))
ci=json.loads((HERE/'ci-final.json').read_text(encoding='utf8'))
assert ci['id']==39852128734 and ci['head_sha']==SOURCE and ci['status']=='completed' and ci['conclusion']=='success'
assert ci['modules_compiled']==222 and ci['suites']==75 and ci['passed']==444664 and ci['failed']==0 and ci['runner_regressions']==5
assert sha(current['.github/workflows/roblox-port.yml'])==ci['workflow_sha256']
for name,digest in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==digest,name
for job in ci['jobs_evidence']['jobs']:
 assert job['status']=='completed' and job['conclusion']=='success'
 for step in job['steps']:assert step['status']=='completed' and step['conclusion']=='success',step['name']
text=(HERE/'ci-suites.txt').read_text(encoding='utf8')
clean='\n'.join(re.sub(r'^\d{4}-\d\d-\d\dT\S+\s+','',line) for line in text.splitlines())
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',clean,re.M)
assert len(rows)==75 and sum(int(r[1]) for r in rows)==444664 and all(int(r[2])==0 for r in rows)
assert '[SELFTEST] END pass=41 fail=0 skip=0' in clean
assert '[SELFTEST] END pass=274 fail=0 skip=0' in clean
assert not re.search(r'\[SELFTEST\] FAIL|^FAIL|##\[error\]',clean,re.M)
old_windows=json.loads((HERE.parent/'local-return/windows-full-process.json').read_text(encoding='utf8'))
old_summary=json.loads((HERE/'prior-windows-full.json').read_text(encoding='utf8'))
assert old_windows['source']==old_summary['source']==BASE and old_windows['exit_code']==old_summary['exit_code']==1
for name,digest in old_windows['inputs'].items():assert sha(base[name])==digest,name
old_text=(HERE.parent/'local-return/windows-full.txt').read_text(encoding='utf8')
assert sha(old_text.encode())==old_summary['log_sha256']
old_rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',old_text,re.M)
assert len(old_rows)==old_summary['suites']==75
assert sum(int(r[1]) for r in old_rows)==old_summary['passed']==444661
assert sum(int(r[2]) for r in old_rows)==old_summary['failed']==3
assert [(r[0],r[1],r[2]) for r in old_rows if int(r[2])]==[('SELFTEST','3','2'),('SELFTEST_PRESERVE','6','1')]
follow=json.loads((HERE/'follow-up-summary.json').read_text(encoding='utf8'))
process=json.loads((HERE/'follow-up.json').read_text(encoding='utf8'))
assert follow['source']==SOURCE and follow['exit_code']==process['exit_code']==0
assert follow['suites']==2 and follow['passed']==12 and follow['failed']==0 and follow['internal_checks']==[41,274]
assert sha((HERE/'selftest.txt').read_bytes())==follow['log_sha256']
with zipfile.ZipFile(HERE/'windows-raw-cli-outputs.zip') as raw_archive:
 raw=raw_archive.read(follow['raw_archive_entry'])
 assert sha(raw)==follow['original_log_sha256'] and raw.replace(b'\r\n',b'\n')==(HERE/'selftest.txt').read_bytes()
assert sha((HERE/'follow-up.json').read_bytes())==follow['process_sha256']
for name,digest in process['inputs'].items():assert sha(current[name])==digest,name
follow_text=(HERE/'selftest.txt').read_text(encoding='utf8')
assert re.findall(r'^(SELFTEST(?:_PRESERVE)?) passed=(\d+) failed=(\d+)',follow_text,re.M)==[('SELFTEST','5','0'),('SELFTEST_PRESERVE','7','0')]
assert '[SELFTEST] END pass=41 fail=0 skip=0' in follow_text and '[SELFTEST] END pass=274 fail=0 skip=0' in follow_text
assert '[SELFTEST] FAIL' not in follow_text
spec=importlib.util.spec_from_file_location('save_cost_runner',ROOT/'roblox_port/tests/run.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
for folder,probe in [(HERE,'profile.luau'),(HERE/'preserve','preserve-profile.luau')]:
 profile=json.loads((folder/'receipt.json').read_text(encoding='utf8'));assert profile['exit_code']==0
 for name,digest in profile['inputs'].items():assert sha(current[name])==digest,name
 body=runner.bundle('local_rest_client.luau');marker='-- Real client loop on shim services; not native rendering/network evidence.'
 assert body.count(marker)==1
 body=body.split(marker)[0]+runner.requires((HERE/probe).read_text(encoding='utf8'))
 assert sha(body.encode())==profile['bundle_sha256']
 output=(folder/'output.txt').read_bytes();assert sha(output)==profile['output_sha256']
 with zipfile.ZipFile(HERE/'windows-raw-cli-outputs.zip') as raw_archive:
  raw=raw_archive.read(profile['raw_archive_entry'])
  assert sha(raw)==profile['original_output_sha256'] and raw.replace(b'\r\n',b'\n')==output
 text=output.decode().replace('\r\n','\n');assert text.endswith('PROFILE_PASS\n')
 records=re.findall(r'^PROFILE_REST\s+(first|replacement)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)',text,re.M)
 assert len(records)==2
 if folder!=HERE:assert all(int(r[1])>1000000 and int(r[5])==233 for r in records)
native=json.loads((HERE/'native-receipt.json').read_text(encoding='utf8'))
manifest=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'))
assert native['source']==manifest['source']==SOURCE and native['assertions']==10 and native['scripts']==223
assert native['persistence_disabled'] and not native['online_save_accessed'] and native['creator_errors_during_guarded_run']==0
assert sha((HERE/'native-output.txt').read_bytes())==native['output_sha256']
assert sha((HERE/'native-probe.luau').read_bytes())==native['probe_sha256']
native_text=(HERE/'native-output.txt').read_text(encoding='utf8')
assert '[NATIVE_SAVE_COST_GUARD] '+SOURCE+' 223 persistence_disabled' in native_text
assert '[NATIVE_SAVE_COST_PASS] 1792704319579 10 inclusive_rows_overlap_not_fps' in native_text
assert '[NATIVE_SAVE_COST_FAIL]' not in native_text
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for name,data in current.items():
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
assert len(expected)==222 and len(manifest['scripts'])==223
assert {r['path']:r['sha256'] for r in manifest['scripts'] if not r['path'].endswith('.SilkPlayback')}==expected
assert [r['sha256'] for r in manifest['scripts'] if r['path'].endswith('.SilkPlayback')]==[native['probe_sha256']]
closed=json.loads((HERE/'native-close.json').read_text(encoding='utf8'))
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed']
assert closed['original_restored_sha256']==manifest['place_sha256']==native['place_sha256']
receipt=dict(source=SOURCE,current_workspace_inputs_verified=True,linux_run=ci['id'],linux_suites=75,linux_passed=444664,failed=0,
 modules_compiled=222,strict_clean=True,runner_regressions=5,shim_selftest_checks=[41,274],
 native_historical_source='07234cae75b5a62b820dc6dda830dce7e503c36b',native_historical_assertions=22,
 historical_windows_source=BASE,historical_windows_full_suites=75,historical_windows_passed=444661,historical_windows_failed=3,
 windows_corrected_selftest_suites=2,windows_corrected_selftest_checks=12,windows_combined_cohort_suites=75,windows_combined_cohort_passed=444664,
 current_source_native_verified=False,native_save_cost_probe_current_source_verified=True,native_save_cost_assertions=10,
 current_source_windows_full_verified=False,save_cost_measurements_pending=False,small_and_large_cli_profiles_verified=True,
 rig_candidate_adopted=False,hard_frame_budget_proven=False,goal_complete=False,published=False)
(HERE/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
