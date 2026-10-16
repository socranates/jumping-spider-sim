"""Export our original Godot synthesis as Roblox-compatible WAVs; no upload.
Usage: python tools/export_audio.py path/to/godot [output_directory]
The temporary script avoids adding a Godot resource to the frozen project.
"""
from pathlib import Path
import json
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[2]
out = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else repo / 'roblox_port/assets/audio'
out.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as temp:
    script = Path(temp) / 'export.gd'
    source = json.dumps((repo / 'scripts/audio/sound_bank.gd').as_posix())
    destination = json.dumps(out.as_posix() + '/')
    script.write_text(f'''extends SceneTree
func _initialize() -> void:
    var bank = load({source})
    for sound_name in bank.names():
        if bank.stream(sound_name).save_to_wav({destination} + sound_name + ".wav") != OK:
            quit(1)
            return
    quit()
''', encoding='utf-8')
    subprocess.run([sys.argv[1], '--headless', '--path', str(repo), '--script', str(script)], check=True)
