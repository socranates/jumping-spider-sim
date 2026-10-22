"""Protocol corruption tests. All generated records here are synthetic, not native evidence."""
from pathlib import Path
import copy,importlib.util,json,unittest,zlib
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('churn_collect',HERE/'collect.py');c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
M=json.loads((HERE/'manifest-v1.json').read_text())
def fixture():
 h={'kind':'header','version':1,'probe_sha256':M['probe_sha256'],'gc':'natural; no forced collection',
    **{k:M[k] for k in ['parts','cycles','stationary_seconds','quiet_seconds','sample_seconds']}}
 rows=[h]
 def s(phase,at,seconds,cycle):
  made=1000 if phase=='stationary' else 1000+1000*cycle
  dead=0 if phase=='stationary' else made if phase=='quiet' else cycle*1000
  tags={k:20. for k in c.TAGS};tags['BaseParts']+=cycle*.4
  return {'kind':'sample','phase':phase,'elapsed':at,'phase_seconds':seconds,'cycle':cycle,'created':made,'destroyed':dead,
          'live_parts':made-dead,'memory':{'total_mb':300.,'gc_mib':12.,'instances':3000,'tags_mb':tags},
          'frames':at*60,'frame_seconds':at,'focus_losses':0}
 for n in range(7):rows.append(s('stationary',.1+n*5,n*5,0))
 for cycle in range(0,61,5):rows.append(s('churn',30.2+cycle,cycle,cycle))
 for n in range(7):rows.append(s('quiet',90.3+n*5,n*5,60))
 rows.append({'kind':'final','elapsed':120.4,'stationary_seconds':30,'churn_seconds':60,'quiet_seconds':30,
              'created':61000,'destroyed':61000,'live_parts':0,'frames':7200,'frame_seconds':120.4,'focus_losses':0})
 return rows
def encode(rows):
 lines=['[PART_CHURN_GUARD] '+M['probe_sha256']+' 1 no_game_no_persistence']
 for i,r in enumerate(rows,1):
  data=json.dumps(r,separators=(',',':'));b=data.encode()
  lines.append(f'[PART_CHURN_RECORD] 123456 {i} {len(b)} {zlib.adler32(b)} '+data)
 lines.append('[PART_CHURN_DONE] 123456 '+str(len(rows)))
 return '\n'.join(lines)
class ProtocolTests(unittest.TestCase):
 def test_synthetic_growth_path(self):
  r=c.collect(encode(fixture()),M)
  self.assertTrue(r['complete'] and r['isolated_part_growth_observed'] and r['persists_after_30_seconds'])
 def test_payload_changed_without_checksum(self):
  self.assertRaises(ValueError,c.collect,encode(fixture()).replace('"created":1000','"created":1001',1),M)
 def test_missing_or_reordered_record(self):
  lines=encode(fixture()).splitlines();del lines[4]
  self.assertRaises(ValueError,c.collect,'\n'.join(lines),M)
 def test_focus_loss_rejected(self):
  rows=fixture();rows[8]['focus_losses']=1;self.assertRaises(ValueError,c.collect,encode(rows),M)
 def test_incomplete_stays_incomplete(self):
  self.assertFalse(c.collect('\n'.join(encode(fixture()).splitlines()[:-1]),M)['complete'])
 def test_wrong_cleanup_rejected(self):
  rows=fixture();rows[-1]['destroyed']=60000;self.assertRaises(ValueError,c.collect,encode(rows),M)
 def test_nonfinite_activity_rejected(self):
  rows=fixture();rows[-1]['frame_seconds']=float('inf');self.assertRaises(ValueError,c.collect,encode(rows),M)
 def test_different_source_rejected(self):
  manifest=copy.deepcopy(M);manifest['probe_sha256']='0'*64
  self.assertRaises(ValueError,c.collect,encode(fixture()),manifest)
if __name__=='__main__':unittest.main()
