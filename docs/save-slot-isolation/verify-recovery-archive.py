"""Verify the private archive preparation evidence, without claiming migration."""
from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
cli=json.loads((HERE/'recovery-archive-receipt.json').read_text());types=json.loads((HERE/'recovery-archive-types.json').read_text())
native=json.loads((HERE/'recovery-archive-native-receipt.json').read_text());manifest=json.loads((HERE/'prepared-recovery-archive-native-manifest.json').read_text());closed=json.loads((HERE/'recovery-archive-native-close.json').read_text())
source=cli['source'];assert source==native['source']==manifest['source']
assert sha((HERE/'recovery-archive-prototype.luau').read_bytes())==cli['candidate_sha256']==types['candidate_sha256']==native['candidate_sha256']
assert cli['exit_code']==0 and sha((HERE/'recovery-archive-tests.luau').read_bytes())==cli['test_sha256']
assert sha((HERE/'recovery-archive-output.txt').read_bytes())==cli['output_sha256']
assert (HERE/'recovery-archive-output.txt').read_text().strip()=='RECOVERY_ARCHIVE passed=73 failed=0 suspensions=16'
assert len(types['steps'])==3
for row in types['steps']:
 assert row['exit_code']==0 and sha((HERE/('recovery-archive-'+row['name']+'.txt')).read_bytes())==row['output_sha256']
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'};expected={}
for name,data in files.items():
 assert (ROOT/name).read_bytes()==data,name
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
expected['StarterPlayer.StarterPlayerScripts.Client.RecoveryArchivePrototype']=cli['candidate_sha256']
expected['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']=sha((HERE/'recovery-archive-native-probe.luau').read_bytes())
assert len(expected)==224 and {r['path']:r['sha256'] for r in manifest['scripts']}==expected
assert native['assertions']==82 and native['scripts']==224 and native['creator_errors']==0 and native['persistence_disabled'] and manifest['persistence_disabled']
assert sha((HERE/'recovery-archive-native-output.txt').read_bytes())==native['output_sha256']
assert '[NATIVE_RECOVERY_ARCHIVE_PASS] '+native['run']+' 82' in (HERE/'recovery-archive-native-output.txt').read_text()
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed'] and closed['prior_window_remained']
assert closed['original_restored_sha256']==native['place_sha256']==manifest['place_sha256']
receipt=dict(source=source,cli_assertions=73,native_assertions=82,native_scripts=224,creator_errors=0,strict_clean=True,production_changed=False,durable_archive_implemented=False,progress_import_implemented=False,published=False)
(HERE/'recovery-archive-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
