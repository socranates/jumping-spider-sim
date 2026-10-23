"""Current corrected recovery adoption gate; prior evidence remains source-bound."""
import runpy
from pathlib import Path
target=Path(__file__).resolve().parents[1]/'recovery-verified-gates/verify.py'
assert target.exists(),'Current corrected recovery verification remains pending'
runpy.run_path(str(target))
