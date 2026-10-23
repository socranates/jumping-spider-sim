"""Current fresh-read adoption gate; prior evidence remains source-bound."""
import runpy
from pathlib import Path
target=Path(__file__).resolve().parents[1]/'session-freshness-gates/verify.py'
assert target.exists(),'Current save freshness verification remains pending'
runpy.run_path(str(target))
