"""Current milestone verifier; prior source-bound receipts stay historical."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parent/'client-final/verify.py'))
