"""Verify the current server milestone; prior phase receipts remain historical."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parent/'server-ready/verify.py'))
