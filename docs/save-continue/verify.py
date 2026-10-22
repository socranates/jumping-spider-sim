"""Current cooperative preparation milestone; earlier receipts keep their scope."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parent/'cooperative-stage/verify.py'))
