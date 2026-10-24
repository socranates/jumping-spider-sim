"""Offline LibMP file inspection; no live game or network access."""
from pathlib import Path
import json,sys,hashlib
SDK=Path('C:/Users/natha/claude-xfer/Windowsill-libmp-tools')
sys.path[:0]=[str(SDK/'python-deps'),str(SDK)]
import LibMP
path=Path('C:/Users/natha/AppData/Local/Roblox/logs/microprofile-20261024-072700-SillStart1.x.html')
mp=LibMP.create()
session=mp.Session.OpenFromFile(path)
assert session is not None and session.IsValid()
try:
 glob=session.FetchGlobalDesc()
 origin=session.FetchTracks()[0].timestampStart
 frames=[];segments=[]
 for segment in range(min(6,session.GetSegmentCount(0))):
  assert session.SelectSegment(segment)
  segments.append(dict(index=segment,minimum=session.GetFrameIdMin(),maximum=session.GetFrameIdMax(),utc=[vars(x)for x in session.FetchUtcTimestampSamples()]))
  for fid in range(session.GetFrameIdMin(),session.GetFrameIdMax()+1):
   f=session.FetchFrameDesc(fid)
   frames.append(dict(segment=segment,id=fid,absolute=f.frameAbsoluteId,
    start_ms=(f.tickStartCpu-origin)*glob.tickToMsCpu,
    duration_ms=(f.tickEndCpu-f.tickStartCpu)*glob.tickToMsCpu,
    paused=f.isPaused,incomplete=f.isIncomplete))
 top=sorted(frames,key=lambda x:x['duration_ms'],reverse=True)[:25]
 out=Path(__file__).parent/'stream-full1/frame-index.json'
 out.write_bytes((json.dumps(dict(segments=segments,top=top,frames=frames),indent=2)+'\n').encode())
 print(json.dumps(dict(segments=segments,top=top),indent=2),flush=True)
finally:
 session.Dispose();mp.Dispose()
