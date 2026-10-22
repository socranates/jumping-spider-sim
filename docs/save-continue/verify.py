"""Current cost-reduction milestone; earlier source receipts stay historical."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parent/'cost-reduction/verify.py'))
