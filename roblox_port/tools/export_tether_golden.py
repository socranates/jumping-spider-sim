"""Export frozen Godot tether goldens and their Luau representation.
Usage: python tools/export_tether_golden.py path/to/godot
"""
from pathlib import Path
import json, subprocess, sys, tempfile

port = Path(__file__).resolve().parents[1]
def lua(value):
    if isinstance(value, dict):
        return '{' + ','.join('['+json.dumps(k)+']='+lua(v) for k,v in value.items()) + '}'
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    return json.dumps(value)

with tempfile.TemporaryDirectory() as temp:
    subprocess.run([sys.argv[1], '--headless', '--log-file', str(Path(temp)/'export.log'),
                    '--path', str(port.parent), '--script', str(port/'tools/export_tether_golden.gd')], check=True)
data=json.loads((port/'tests/tether_reference.json').read_text(encoding='utf-8'))
(port/'tests/tether_reference.luau').write_text(
    '-- Generated from frozen Godot by export_tether_golden.gd; source c87ce00\nreturn '+lua(data)+'\n',
    encoding='utf-8', newline='\n')
