"""Current full Linux gate; earlier focused/native receipts keep their scope."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parent/'save-cost/verify.py'))
