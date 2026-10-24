"""Build an unpublished current/baseline native rig comparison fixture."""
from pathlib import Path
import hashlib,subprocess,sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
baseline=subprocess.check_output(['git','show','c5b61262:roblox_port/src/Shared/Rig/SpiderRig.luau'],cwd=ROOT)
assert (ROOT/'roblox_port/tests/rig_hair_reference.luau').read_bytes()==baseline
source=(ROOT/'docs/microprofiler-current/playback.luau').read_text()
source=source.replace('until d.life.elapsed-elapsed>=60','until d.life.elapsed-elapsed>=20')
anchor='d.cam.mouse=false;d.cam.yaw=yaw;d.cam.elevation=math.rad(25)'
assert source.count(anchor)==1
source=source.replace(anchor,anchor+'\n  game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.Default\n  game:GetService("UserInputService").MouseIconEnabled=true')
anchor='  local final=inspect("finish")'
assert source.count(anchor)==1
source=source.replace(anchor,'''  local floor=Instance.new("Folder");floor.Name="RigHairNativeComparison";floor.Parent=WS
  local part=Instance.new("Part");part.Name="Floor";part.Anchored=true;part.Size=Vector3.new(160,1,160)
  part.CFrame=CFrame.new(0,19.5,0);part.Parent=floor
  local passed,failed=0,0
  local result=require(script.Parent.RigHairChecks)(
   require(RS.Shared.Rig.SpiderRig),require(RS.Shared.Rig.RigHairReference),
   require(RS.Shared.Data.Appearances),require(RS.Shared.Rig.Living),floor,
   function(okay:boolean,message:string)
    if okay then passed+=1 else failed+=1 end
    print("[RIG_HAIR_NATIVE_CHECK]",Http:JSONEncode({ok=okay,message=message}))
   end,nil,function()Run.Heartbeat:Wait()end)
  floor:Destroy()
  print("[RIG_HAIR_NATIVE_RESULT]",Http:JSONEncode({passed=passed,failed=failed,metrics=result}))
  assert(failed==0,"native rig comparison failed")
''' + anchor)
playback=HERE/'playback.luau';playback.write_bytes(source.encode())
subprocess.run([sys.executable,str(ROOT/'docs/performance-matrix/build.py'),
 '--out','C:/Users/natha/claude-xfer/Windowsill-rig-hair-native1',
 '--tier','full','--variant','after','--playback-source',str(playback),'--rig-hair-checks'],cwd=ROOT,check=True)
