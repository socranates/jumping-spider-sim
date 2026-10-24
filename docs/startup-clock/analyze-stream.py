"""Inspect closed CPU scopes in selected startup frames, clipping to each frame.
Inclusive, nested scopes are reported separately, never summed across threads.
Incomplete frames and stack under/overflow remain explicit in the output.
"""
from pathlib import Path
import sys,json,hashlib
SDK=Path('C:/Users/natha/claude-xfer/Windowsill-libmp-tools')
sys.path[:0]=[str(SDK/'python-deps'),str(SDK)]
import LibMP
H=Path(__file__).resolve().parent/'stream-full1'
raw=Path('C:/Users/natha/AppData/Local/Roblox/logs/microprofile-20261024-072700-SillStart1.x.html')
mp=LibMP.create();session=mp.Session.OpenFromFile(raw)
assert session is not None and session.IsValid()
decode=lambda b:b.decode('utf8',errors='replace')if isinstance(b,bytes)else str(b)
try:
 tick=session.FetchGlobalDesc().tickToMsCpu
 origin=session.FetchTracks()[0].timestampStart
 results=[]
 labels_only='--labels'in sys.argv
 selected=[(2,653),(2,654)]if labels_only else [(2,644),(2,649),(2,652),(2,653),(2,654),(2,655),(3,922)]
 for segment,fid in selected:
  assert session.SelectSegment(segment)
  frame=session.FetchFrameDesc(fid);timers={};threads={};groups={}
  def names(tid,thread):
   if tid not in timers:
    d=session.FetchTimerDesc(tid)
    if d.groupId not in groups:groups[d.groupId]=decode(session.FetchGroupDesc(d.groupId).groupName)
    timers[tid]=(decode(d.timerName),groups[d.groupId])
   if thread not in threads:threads[thread]=decode(session.FetchThreadDesc(thread).threadName)
   return timers[tid],threads[thread]
  iterator=session.CreateLogIterator()
  assert iterator.Configure(dict(SkipGpuThreads=True,SkipEvents=True,TrackScopeLabels=labels_only))
  state=iterator.GetState();iterator.RewindTo(fid,fid)
  scopes=[];steps=0;underflow=0;overflow=0
  try:
   while iterator.Step():
    steps+=1;assert steps<2000000,'Bounded frame analysis exceeded entry limit'
    if state.ThreadStackIsOverflowed():overflow+=1
    if state.IsExit():
     if state.ThreadStackIsUnderflowed():underflow+=1;continue
     end=state.Timestamp();depth=state.ThreadStackDepth();tid=state.TimerId();thread=state.ThreadId()
     element=iterator.GetCurrentThreadStackElement(depth)
     if element is None:continue
     begin=max(element.EnterTimestamp(),frame.tickStartCpu)
     end=min(end,frame.tickEndCpu)
     ms=(end-begin)*tick
     if ms>=1:
      (timer,group),threadName=names(tid,thread)
      row=dict(timer=timer,group=group,thread=threadName,timer_id=tid,
       depth=depth,ms=ms,start_ms=(begin-origin)*tick)
      if labels_only and ms>=50 and group in ['Script','Studio']:
       row['labels']=[decode(iterator.FetchCurrentScopeLabel(i))[:180]for i in range(iterator.GetCurrentScopeLabelCount())]
      scopes.append(row)
  finally:iterator.Dispose()
  scopes.sort(key=lambda x:x['ms'],reverse=True)
  row=dict(segment=segment,frame=fid,absolute=frame.frameAbsoluteId,
   start_ms=(frame.tickStartCpu-origin)*tick,duration_ms=(frame.tickEndCpu-frame.tickStartCpu)*tick,
   incomplete=frame.isIncomplete,paused=frame.isPaused,steps=steps,
   stack_underflow_exits=underflow,stack_overflow_steps=overflow,
   scopes_over_1ms=len(scopes),longest_scopes=scopes[:45])
  results.append(row)
  shown=[s for s in scopes if s.get('labels')]if labels_only else scopes[:12]
  print(json.dumps(dict(frame=fid,duration_ms=row['duration_ms'],incomplete=row['incomplete'],
   steps=steps,underflows=underflow,overflows=overflow,top=shown[:20])),flush=True)
 record=dict(raw_path=str(raw),raw_sha256=hashlib.sha256(raw.read_bytes()).hexdigest(),
  raw_bytes=raw.stat().st_size,frames=results,
  limits='One local Studio startup file stream including Edit/Play transitions and post-PASS UI. Source includes an unused replicated LibMP wrapper loaded in Edit before capture. Incomplete frame logs and stack underflows prevent exhaustive attribution; inclusive scopes overlap and waits are not exclusive CPU.')
 (H/('scope-labels.json'if labels_only else 'scope-analysis.json')).write_text(json.dumps(record,indent=2)+'\n')
finally:session.Dispose();mp.Dispose()
