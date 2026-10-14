"""Build isolated full/low-detail profiling places, excluding server test fixtures.
Usage: python tools/build_profile.py path/to/rojo output-directory
Open a generated place and Play; do not capture screenshots until PORT_PROFILE appears.
"""
from pathlib import Path
import json,subprocess,sys
r=Path(__file__).resolve().parents[1]
out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=True)
p=json.loads((r/'default.project.json').read_text())
def paths(node):
    if isinstance(node,dict):
        for k,v in node.items():
            if k=='$path':node[k]=str(r/v)
            else:paths(v)
paths(p)
p['tree']['StarterPlayer']['StarterPlayerScripts']['Client']['SilkPlayback']={'$path':str(r/'tools/profile_play.luau')}
for tier in ['full','low']:
    p['tree']['Workspace']['$attributes']={'Detail':tier}
    project=out/(tier+'.project.json');project.write_text(json.dumps(p),encoding='utf-8')
    subprocess.run([sys.argv[1],'build',str(project),'-o',str(out/(tier+'.rbxlx'))],check=True)
