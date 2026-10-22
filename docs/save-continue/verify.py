"""Current readiness fix gate; earlier encoder evidence remains source-bound in its own folder."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parents[1]/'stream-readiness/verify.py'))
