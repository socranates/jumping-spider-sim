from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
prior=HERE.parent/'session-freshness-gates'
text=(prior/'full.py').read_text()
text=text.replace("HERE.parent/'checkpoint-return-oracle/windows-full-process.json'","HERE.parent/'session-freshness-gates/windows-full-process.json'")
text=text.replace('405e9df16f5a8dbccadbcab9c8a654487d161445','f4053597d03b99a61cb97e2eef1ec64ed174f22a').replace('468225','468351')
(HERE/'full.py').write_text(text,encoding='utf8',newline='\n')
print('Prepared next immutable full runner; previous full run must be terminal')
