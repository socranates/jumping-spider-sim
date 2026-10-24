"""Prepare an isolated live profiling fixture without changing game sources.

The existing guarded builder supplies unbound yielding memory storage and an
ordinary Free play entry. This is one rainy garden diagnostic, not a matched
performance-matrix cohort, natural life, online save or standalone server test.
"""
from pathlib import Path
import subprocess, sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
source = (ROOT / 'docs/performance-matrix/playback.luau').read_text()
begin = source.index('local scenes={')
end = source.index('\nreturn function(d:any)', begin)
source = source[:begin] + '''local scenes={
 {id="garden_rain",region="garden_a1",day=4,hour=9,yaw=math.pi/4},
}''' + source[end:]
source = source.replace('freshAt(scene);Probe.startSample(scene.id)', '''freshAt(scene)
   print("[MICROPROFILE_READY]",Http:JSONEncode({at=WS:GetServerTimeNow(),scene=scene.id,state=extra()}))
   Probe.startSample(scene.id)''')
assert source.count('until d.life.elapsed-elapsed>=20') == 1
source = source.replace('until d.life.elapsed-elapsed>=20', 'until d.life.elapsed-elapsed>=60')
begin = source.index('  -- Drive the real input state.')
end = source.index('  local final=inspect("finish")', begin)
source = source[:begin] + source[end:]
source = source.replace('-- Unpublished controlled workload.', '-- Unpublished profiling fixture; NOT a performance-matrix comparison.')
playback = HERE / 'playback.luau'
playback.write_bytes(source.encode())
subprocess.run([sys.executable, str(ROOT / 'docs/performance-matrix/build.py'),
 '--out', 'C:/Users/natha/claude-xfer/Windowsill-microprofile-fresh-full1',
 '--tier', 'full', '--variant', 'after', '--playback-source', str(playback)],
 cwd=ROOT, check=True)
