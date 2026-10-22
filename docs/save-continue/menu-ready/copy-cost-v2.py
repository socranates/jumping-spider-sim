"""Bounded CLI diagnostic: real233-region rest through the current continuation core.
Not native frame time, RemoteEvent transfer time, peak RSS, or a phone measurement.
"""
from pathlib import Path
import importlib.util,subprocess,tempfile,json,hashlib,time
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
TOOL=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
assert not (HERE/'copy-cost-v2.txt').exists()
spec=importlib.util.spec_from_file_location('windowsill_runner',ROOT/'roblox_port/tests/run.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
base=runner.bundle('rest_storage.luau')
append=r"""
local costs={}
local function timed(name,fn)
 local before=gcinfo();local at=os.clock();local result=fn()
 print(`COPY_COST stage={name} elapsed_ms={(os.clock()-at)*1000} heap_kib_before={before} heap_kib_after={gcinfo()}`)
 return result
end
local restores=0
local continuation=__mods.SaveContinuation.new({rules=Rules,copy=Json.copy,
 validate=function(mode,r,retired) return #SaveRest.check(mode,r)==0 and #Checkpoint.check(r,world)==0 end,
 onRestore=function(mode,r) restores+=1;assert(#Checkpoint.check(r,world)==0);return true end})
timed("receive_one_full_preserve_offer",function()
 assert(continuation:receive({kind="loaded",v=3,epoch="copy-cost",sequence=1,status="saved",offers={main={id="full",protected=false,record=fullRecord}}}))
end)
local copies=0;local copy=continuation.cfg.copy
continuation.cfg.copy=function(v) copies+=1;return copy(v) end
timed("menu_metadata_100_reads",function() for _=1,100 do assert(continuation:offerInfo("main").id=="full") end end)
assert(copies==0,"menu metadata copied the full world")
timed("explicit_continue_core",function() assert(continuation:choose("main","continue","full")) end)
assert(restores==1)
timed("queue_full_checkpoint",function() assert(continuation:checkpoint("main",fullRecord)) end)
local request=continuation:decision("main")
continuation:receive({kind="decision",epoch="copy-cost",sequence=2,decision={mode="main",kind="continue",serial=request.serial,offerId="full",revision=1,state="writable",credential="copy-grant",life=nil}})
local wire
timed("copy_outgoing_full_checkpoint_only",function()
 continuation:update(100,function(msg)
  if msg.kind=="rest" then
   wire=msg
  end
 end)
end)
assert(wire and #SaveRest.check("main",wire.record)==0)
print(`COPY_COST outgoing_canonical_chars={#assert(Json.canonical(wire))} record_chars={#assert(Json.canonical(fullRecord))}`)
print("COPY_COST_DONE one_full_preserve_slot metadata_reads_100_full_copies_0 restores_1")
"""
inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for subtree in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/subtree).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
with tempfile.TemporaryDirectory() as folder:
 f=Path(folder)/'copy-cost.luau';f.write_text(base+append,encoding='utf8',newline='\n')
 at=time.time();r=subprocess.run([str(TOOL),str(f)],capture_output=True,text=True)
 (HERE/'copy-cost-v2.txt').write_text(r.stdout+r.stderr,encoding='utf8',newline='\n')
 (HERE/'copy-cost-v2-process.json').write_text(json.dumps(dict(exit_code=r.returncode,elapsed_seconds=time.time()-at,inputs=inputs,diagnostic_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),native=False,remote_transfer_measured=False,frame_time_measured=False,peak_rss_measured=False),indent=2)+'\n',encoding='utf8',newline='\n')
 print(r.stdout+r.stderr);assert r.returncode==0
