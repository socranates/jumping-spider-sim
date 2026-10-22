"""Current encoder adoption gate; does not pass while full gates are pending."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parent/'json-encoding/verify.py'))
