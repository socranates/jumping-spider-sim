"""Current source-bound milestone; historical receipts retain their scope."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parent/'menu-ready/verify.py'))
