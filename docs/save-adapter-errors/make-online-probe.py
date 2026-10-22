"""Build an isolated, source-verified Studio command. Never changes the cloud edit model."""
from pathlib import Path
import hashlib,json,subprocess,zlib
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
candidate=json.loads((OUT/'candidate.json').read_text(encoding='utf-8'));source=candidate['source_commit'];port=ROOT/'roblox_port'
changed=set(subprocess.check_output(['git','diff','--name-only','14e60991c785c4293c3560e6d8b7ecded7e7ac75',source,'--','roblox_port/src/Shared'],cwd=ROOT).decode().splitlines())
files=sorted((port/'src/Shared').rglob('*.luau'))+[port/'src/Server/RestCompression.luau',port/'src/Server/DataStoreBackend.luau']
patches=[];rows=[]
for p in files:
 rel=p.relative_to(ROOT).as_posix();raw=p.read_bytes();assert raw==subprocess.check_output(['git','show',source+':'+rel],cwd=ROOT),rel
 text=raw.decode('utf-8').replace('\r\n','\n');data=text.encode();name=p.relative_to(port/'src').as_posix().removesuffix('.luau')
 rows.append({'path':rel,'module':name,'bytes':len(data),'adler32':zlib.adler32(data),'sha256':hashlib.sha256(data).hexdigest()})
 if rel in changed or '/Server/' in rel:patches.append([name,text])
def lua(v):
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
 return str(v)
fixturePath=ROOT/'docs/save-compaction/native-engine-capture.json';fixture=fixturePath.read_text(encoding='utf-8')
fixtureHash=hashlib.sha256(fixturePath.read_bytes()).hexdigest();assert fixtureHash=='d7743248887c9529da805472022ea40f8c8a61bc3d387e6888128007e094b86f'
driver=(OUT/'online-driver.luau').read_text(encoding='utf-8')
code='assert(game.GameId==10771103250 and game.PlaceId==120119801868085 and not game:GetService("RunService"):IsRunning());local lab=Instance.new("Folder");lab.Name="ChetIsolatedAdapterLab";local shared=game.ReplicatedStorage.Shared:Clone();shared.Parent=lab;local server=Instance.new("Folder");server.Name="Server";server.Parent=lab;local patches='+lua(patches)+';'
code+='for _,r in patches do local bits=string.split(r[1],"/");local parent=lab;for i=1,#bits-1 do parent=assert(parent:FindFirstChild(bits[i])) end;local m=parent:FindFirstChild(bits[#bits]);if not m then m=Instance.new("ModuleScript");m.Name=bits[#bits];m.Parent=parent end;m.Source=r[2] end;'
code+='local expected='+lua([[r['module'],r['bytes'],r['adler32']] for r in rows])+';local function adler(s) local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;return b*65536+a end;local count=0;for _,d in lab:GetDescendants() do if d:IsA("ModuleScript") then count+=1 end end;assert(count==#expected,"unexpected cloned module set");for _,r in expected do local m=lab;for _,bit in string.split(r[1],"/") do m=assert(m:FindFirstChild(bit),r[1]) end;local s=string.gsub(m.Source,"\\r\\n","\\n");assert(#s==r[2] and adler(s)==r[3],"candidate source mismatch: "..r[1]) end;assert(lab.Parent==nil);print("[CHET_ADAPTER_ONLINE_SOURCE]",#expected,"'+source+'","'+candidate['evidence_id']+'");local nativePacket='+json.dumps(fixture,ensure_ascii=False)+';local ok,err=pcall(function() '+driver+' end);lab:Destroy();if not ok then warn("[CHET_ADAPTER_ONLINE_FAIL]",tostring(err));error(err,0) end;'
(OUT/'online-loader.luau').write_text(code,encoding='utf-8')
(OUT/'online-manifest.json').write_text(json.dumps({'source_commit':source,'evidence_id':candidate['evidence_id'],'modules':rows,'fixture_sha256':fixtureHash,'loader_sha256':hashlib.sha256((OUT/'online-loader.luau').read_bytes()).hexdigest(),'cloud_model_modified':False},indent=2)+'\n',encoding='utf-8')
print('Online loader:',len(code.encode()),'bytes;',len(rows),'source-verified modules')
