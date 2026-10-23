from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=ROOT/'roblox_port/src/Server/DataStoreBackend.luau';original=p.read_bytes();body=original.decode()
extension=(HERE/'fresh-read-extension.luau').read_text();marker='return DataStoreBackend';assert body.count(marker)==1
candidate=body.replace(marker,extension+'\n'+marker)
(HERE/'fresh-read-backend-candidate.luau').write_text(candidate,encoding='utf8',newline='\n')
(HERE/'fresh-read-manifest.json').write_text(json.dumps(dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),original_sha256=hashlib.sha256(original).hexdigest(),candidate_sha256=hashlib.sha256(candidate.encode()).hexdigest(),production_changed=False,documentation='https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching'),indent=2)+'\n',encoding='utf8',newline='\n')
print('Private uncached/raw backend methods generated; ordinary read unchanged.')
