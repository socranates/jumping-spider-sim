from pathlib import Path
import hashlib,io,json,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'prepared-recovery-store-native-manifest.json').read_text());native=json.loads((HERE/'recovery-store-native-receipt.json').read_text());closed=json.loads((HERE/'recovery-store-native-close.json').read_text());types=json.loads((HERE/'fresh-read-types.json').read_text())
assert types['candidates']==m['candidates']==native['candidates']
for name,digest in m['candidates'].items():assert sha((HERE/name).read_bytes())==digest,name
for stem,count in [('recovery-archive-store',272),('fresh-read',32)]:
 receipt=json.loads((HERE/(stem+'-receipt.json')).read_text());assert receipt['source']==m['source'] and receipt['exit_code']==0
 assert receipt['archive_sha256']==m['candidates']['recovery-archive-prototype.luau']
 candidate='recovery-archive-store-prototype.luau' if stem=='recovery-archive-store' else 'fresh-read-backend-candidate.luau'
 assert receipt['candidate_sha256']==m['candidates'][candidate]
 if stem=='fresh-read':assert receipt['store_sha256']==m['candidates']['recovery-archive-store-prototype.luau']
 assert sha((HERE/(stem+'-tests.luau')).read_bytes())==receipt['test_sha256']
 assert sha((HERE/(stem+'-output.txt')).read_bytes())==receipt['output_sha256']
 assert ('passed='+str(count)+' failed=0') in (HERE/(stem+'-output.txt')).read_text()
assert len(types['steps'])==4
for step in types['steps']:
 assert step['exit_code']==0 and sha((HERE/('fresh-read-'+step['name']+'.txt')).read_bytes())==step['output_sha256']
raw=subprocess.check_output(['git','archive','--format=tar',m['source'],'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={row.name:archive.extractfile(row).read() for row in archive if row.isfile()}
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'};expected={}
for name,data in files.items():
 assert (ROOT/name).read_bytes()==data,name
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
for key,name in {'RecoveryArchivePrototype':'recovery-archive-prototype.luau','RecoveryArchiveStorePrototype':'recovery-archive-store-prototype.luau','FreshReadBackendPrototype':'fresh-read-backend-candidate.luau','RecoveryStoreProbe':'recovery-store-native-probe.server.luau'}.items():expected['ServerScriptService.Server.'+key]=sha((HERE/name).read_bytes())
assert len(expected)==226 and {row['path']:row['sha256'] for row in m['scripts']}==expected
assert m['production_scripts_disabled'] and native['production_scripts_disabled']
assert sum(not row[1] for row in m['disabled_scripts'])==1
assert [row[0] for row in m['disabled_scripts'] if not row[1]]==['ServerScriptService.Server.RecoveryStoreProbe']
assert native['source']==m['source'] and native['assertions']==304 and native['scripts']==226 and native['creator_errors']==0
assert sha((HERE/'recovery-store-native-output.txt').read_bytes())==native['output_sha256']
assert '[NATIVE_RECOVERY_STORE_PASS] '+native['run']+' 304' in (HERE/'recovery-store-native-output.txt').read_text()
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed'] and closed['prior_window_remained']
assert closed['original_restored_sha256']==m['place_sha256']==native['place_sha256']
r=dict(source=m['source'],publication_cli_assertions=272,fresh_read_cli_assertions=32,native_assertions=304,native_scripts=226,creator_errors=0,strict_clean=True,production_changed=False,real_datastore_verified=False,progress_import_implemented=False,ordinary_production_reads_unchanged=True,published=False)
(HERE/'recovery-store-verification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
