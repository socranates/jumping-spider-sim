from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
prior=HERE.parent/'session-freshness-gates'
text=(prior/'full.py').read_text().replace("HERE.parent/'checkpoint-return-oracle/windows-full-process.json'","HERE.parent/'session-freshness-gates/windows-full-process.json'").replace('405e9df16f5a8dbccadbcab9c8a654487d161445','f4053597d03b99a61cb97e2eef1ec64ed174f22a').replace('468225','468352')
(HERE/'full.py').write_text(text,encoding='utf8',newline='\n')
text=(HERE.parent/'recovery-pacing-gates/verify.py').read_text()
text='\n'.join(line for line in text.splitlines() if "assert not (HERE/'initial-adoption-withdrawn.json')" not in line)+'\n'
text=text.replace('session-budget-yield-adoption.json','session-verified-adoption.json').replace('verify-session-budget-yield.py','verify-session-verified-native.py').replace('session-budget-yield-verification.json','session-verified-native-qualification.json').replace('468351','468352').replace("'1250'","'1251'").replace('==126','==127').replace('=126','=127')
assert 'budget-yield' not in text and 'withdrawn' not in text and "'STATE','1251','0'" in text
(HERE/'verify.py').write_text(text,encoding='utf8',newline='\n')
print('Prepared corrected adoption full runner and source-bound verifier')
