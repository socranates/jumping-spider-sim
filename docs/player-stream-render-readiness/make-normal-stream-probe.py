"""Create a separate stronger Normal fixture without changing the frozen full-detail probe."""
from pathlib import Path
import hashlib
H=Path(__file__).resolve().parent
original=(H/'engine-stream-probe.luau').read_bytes()
assert hashlib.sha256(original).hexdigest()=='cf709722ad4176adb46e89cda7a85071d5e74dc1d356e6336f387f8b8780b405'
text=original.decode()
def replace(old,new):
 global text
 assert text.count(old)==1,old;text=text.replace(old,new)
replace('-- Private actual-client engine streaming experiment. Never publish.','-- Separate Normal-mode/low-detail fixture; diagnostic focus reports are delayed two seconds. Never publish.')
replace(' local samples={};local observedOut=false;local heldFrames=0',' local samples={};local observedOut=false;local heldFrames=0\n local restoreReports=nil;local firstHeld,lastHeld=nil,nil')
replace('d.fresh("free",false,nil)','d.fresh("main",false,nil)')
replace('  d.openMenu(true);check(d.menu:isShowing(),"menu did not pause fixture travel")','''  check(d.session.mode=="main" and d.session.rules=="standard" and d.needs.lifeMode and not d.needs.gentle,"fixture is not Normal life mode")
  check(d.detail=="low","Normal fixture expected the actual low-detail client")
  d.needs:configure({energy=.55,rest=.8});d.life.clock.hour=12
  d.openMenu(true);check(d.menu:isShowing(),"menu did not pause fixture travel")''')
replace('  d.menu:hide();frames(6)','''  local initialEnergy=d.needs.energy
  d.menu:hide();check(waitFor(function() return d.needs.energy<initialEnergy end,3),"Normal hunger did not drain before the loading hold")''')
replace('  d.place(nearAt)\n  local heldAt','''  local reportField=rawget(d.world,"report");local reportMethod=d.world.report
  restoreReports=function() d.world.report=reportField end
  d.world.report=function() return false end -- diagnostic only: server focus remains far for a bounded gap
  d.place(nearAt)
  local heldAt''')
replace('  d.menu:hide();d.world:report(nearAt,os.clock())','''  local reserve={}
  for _,key in {"energy","rest","elapsedS","starvingHours","starvingStreakH","_accActive","_accStill","_accHoursAwake","_accHoursAsleep"} do reserve[key]=d.needs[key] end
  local day,hour=d.life.clock.day,d.life.clock.hour
  local heldEnergy=d.needs.energy
  local releaseAt=os.clock()+2
  d.menu:hide()''')
replace('   frames(1)\n   if d.world.playerLoading then','''   frames(1)
   if os.clock()<releaseAt then
    check(not d.world:regionReady(near.id) and d.world.playerLoading,"collision gap ended before the diagnostic focus delay")
   elseif restoreReports then
    restoreReports();restoreReports=nil;reportMethod(d.world,nearAt,os.clock())
    check(d.world.report==reportMethod,"diagnostic report wrapper did not restore its original method")
   end
   if d.world.playerLoading then''')
replace('    heldFrames+=1','''    heldFrames+=1;firstHeld=firstHeld or os.clock();lastHeld=os.clock()
    for key,value in reserve do check(d.needs[key]==value,"Normal reserve or pending drain changed during collision hold: "..key) end
    check(d.life.clock.day==day and d.life.clock.hour==hour,"Normal day/hour advanced during collision hold")''')
replace('  check(ready,"near collision did not return before the deadline")','''  check(ready,"near collision did not return before the deadline")
  check(heldFrames>=2 and firstHeld~=nil and lastHeld-firstHeld>=1.5,"fixture did not observe a meaningful Normal hunger hold")
  check(waitFor(function() return d.needs.energy<heldEnergy end,3),"Normal hunger did not resume after complete collision return")
  note("normal_energy",{mode=d.session.mode,rules=d.session.rules,gentle=d.needs.gentle,energyBeforeWarm=initialEnergy,energyBeforeHold=heldEnergy,energyAfterResume=d.needs.energy,heldSeconds=lastHeld-firstHeld,heldFrames=heldFrames,focusReportDelaySeconds=2,pendingDrainRetained=true,reportMethodRestored=true})''')
replace(' if ok then\n  print("[ENGINE_STREAM_PASS]"',' if restoreReports then restoreReports();restoreReports=nil end\n if ok then\n  print("[ENGINE_STREAM_PASS]"')
out=H/'engine-stream-normal-probe.luau';assert not out.exists()
out.write_text(text,encoding='utf8',newline='\n');print('Created separate Normal fixture',hashlib.sha256(out.read_bytes()).hexdigest())
