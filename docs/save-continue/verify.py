"""Current asynchronous owned-offer milestone; earlier receipts keep their scope."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parent/'async-offers/verify.py'))
