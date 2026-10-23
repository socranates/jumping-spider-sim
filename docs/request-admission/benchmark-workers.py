"""CLI CPU samples for the candidate queue, not Roblox frame-rate evidence."""
from pathlib import Path
import hashlib,json,subprocess,tempfile,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau')
def main():
 prefix=sys.argv[1];out=H/(prefix+'-output.txt');assert not out.exists()
 source_path=(H/(sys.argv[2] if len(sys.argv)>2 else 'worker-admission.luau')).resolve();assert source_path.parent==H
 source=source_path.read_text()
 fixture='''
local function sample(actors,debt,pending)
 local g=Gate.new({now=function() return 200 end,available=function() return {read=10000,write=10000} end,
  actorRead=debt,actorWrite=debt,serverRead=10000,serverWrite=10000,headroom=0,maxActors=64,maxPending=256})
 local scopes={}
 for a=1,actors do
  scopes[a]=assert(g:open(tostring(a),"1"));local history={}
  if a<actors then for _=1,debt do table.insert(history,199) end end
  assert(g:importLegacy(scopes[a],history))
 end
 for i=1,pending-1 do assert(g:request(scopes[1+(i-1)%(actors-1)],"read")) end
 local ticket=assert(g:request(scopes[actors],"read"));local samples={}
 for _=1,20 do local before=os.clock();assert(g:reserve(ticket));table.insert(samples,(os.clock()-before)*1000) end
 table.sort(samples)
 print(string.format("ADMISSION_CPU actors=%d debt=%d pending=%d median_ms=%.6f p95_ms=%.6f max_ms=%.6f",actors,debt,pending,samples[10],samples[19],samples[20]))
end
sample(16,6,32)
sample(64,150,256)
'''
 bundle='local Gate=(function()\n'+source+'\nend)()\n'+fixture
 with tempfile.TemporaryDirectory(prefix='windowsill-admission-cpu-') as folder:
  path=Path(folder)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([str(TOOLS/'luau.exe'),str(path)],cwd=ROOT,capture_output=True,text=True)
 text=r.stdout+r.stderr;out.write_text(text,encoding='utf8',newline='\n');sha=lambda b:hashlib.sha256(b).hexdigest()
 result=dict(input_path=source_path.relative_to(ROOT).as_posix(),input_sha256=sha(source.encode()),bundle_sha256=sha(bundle.encode()),output_sha256=sha(text.encode()),exit_code=r.returncode,samples_per_case=20,native_verified=False,frame_rate_claim=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(text);raise SystemExit(r.returncode)
if __name__=='__main__':main()
