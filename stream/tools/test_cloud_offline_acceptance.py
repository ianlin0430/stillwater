"""Small synthetic evidence tests; do not launch Godot or GitHub jobs."""
import copy
import json
from cloud_offline_acceptance import audit, SEEDS, FLAGS, YEAR_FLAGS
import unittest
import tempfile
from pathlib import Path

class OfflineTests(unittest.TestCase):
    def setUp(self):
        temp=tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.raw=Path(temp.name)
        self.sha='a'*40
        self.run={'headSha':self.sha,'status':'completed','conclusion':'success'}
        self.paths=[]
        for seed in SEEDS:
            row={'seed':seed,'mode':'offline','scene':'reef','decor':'default','feed':'none','days':180,
                 'acceptance':dict.fromkeys(FLAGS,True),
                 'chunks':[{'from_day':s,'to_day':s+60,'seconds':1} for s in [0,60,120]]}
            report={k:row[k] for k in ['mode','scene','decor','feed']}
            report.update(days_per_seed=180,failures=[],runs=[row])
            if seed==SEEDS[0]:
                report['stability_365']={'seed':240921,'days':365,'mode':'offline','scene':'reef',
                    'decor':'default','feed':'none','acceptance':dict.fromkeys(YEAR_FLAGS,True)}
            path=self.raw/f'ci-offline-180d-reef-default-feed-none-{seed}.json'
            path.write_text(json.dumps(report))
            self.paths.append(path)
            for index in [1,2,3]:
                folder=self.raw/f'ecology-offline-180d-reef-default-feed-none-seed-{seed}-chunk-{index}-log'
                folder.mkdir()
                (folder/f'long-run-chunk-{index}.log').write_text('ACCEPTANCE PASS\n' if index==3 else f'CHUNK seed {seed} days {(index-1)*60}-{index*60} of 180 saved to ckpt/day-{index*60}.world\n')
    def result(self):
        return audit(self.run,self.raw,self.sha)
    def alter(self,change):
        value=json.loads(self.paths[0].read_text())
        change(value)
        self.paths[0].write_text(json.dumps(value))
    def test_complete(self):
        result=self.result()
        self.assertTrue(result['passed'],result['failures'])
        self.assertEqual((result['verified_cases'],result['verified_logs'],result['stability_passes']),(32,96,1))
    def test_missing_case(self):
        self.paths[-1].unlink()
        self.assertFalse(self.result()['passed'])
    def test_duplicate_case(self):
        (self.raw/'ci-offline-180d-duplicate.json').write_bytes(self.paths[0].read_bytes())
        self.assertFalse(self.result()['passed'])
    def test_bad_seed_and_configuration(self):
        original=self.paths[0].read_text()
        for key,value in [('seed',999),('mode','live'),('scene','shipwreck'),('decor','max'),('feed','daily'),('days',179)]:
            self.paths[0].write_text(original)
            self.alter(lambda r:r['runs'][0].update({key:value}))
            self.assertFalse(self.result()['passed'])
    def test_failed_missing_and_nonboolean_flags(self):
        for value in [False,None,1]:
            self.alter(lambda r:r['runs'][0]['acceptance'].update(starvation=value))
            self.assertFalse(self.result()['passed'])
        self.alter(lambda r:r['runs'][0]['acceptance'].pop('starvation'))
        self.assertFalse(self.result()['passed'])
    def test_checkpoint_gap(self):
        self.alter(lambda r:r['runs'][0]['chunks'][1].update(from_day=61))
        self.assertFalse(self.result()['passed'])
    def test_year_missing_and_duplicate(self):
        value=json.loads(self.paths[0].read_text())
        self.alter(lambda r:r.pop('stability_365'))
        self.assertFalse(self.result()['passed'])
        self.paths[0].write_text(json.dumps(value))
        other=json.loads(self.paths[1].read_text())
        other['stability_365']=value['stability_365']
        self.paths[1].write_text(json.dumps(other))
        self.assertFalse(self.result()['passed'])
    def test_wrong_year_or_failed_year(self):
        original=self.paths[0].read_text()
        for key,value in [('seed',42),('days',364),('mode','live'),('feed','daily')]:
            self.paths[0].write_text(original)
            self.alter(lambda r:r['stability_365'].update({key:value}))
            self.assertFalse(self.result()['passed'])
        self.paths[0].write_text(original)
        self.alter(lambda r:r['stability_365']['acceptance'].update(valid=False))
        self.assertFalse(self.result()['passed'])
    def test_bad_workflow_or_sha(self):
        for key,value in [('headSha','b'*40),('status','queued'),('conclusion','failure'),('conclusion','cancelled')]:
            run=copy.deepcopy(self.run)
            run[key]=value
            self.assertFalse(audit(run,self.raw,self.sha)['passed'])
    def test_log_missing_error_or_verdict(self):
        path=next(self.raw.rglob('long-run-chunk-3.log'))
        for text in ['ERROR: corrupt data\nACCEPTANCE PASS\n','SCRIPT ERROR: bad\nACCEPTANCE PASS\n','still running\n']:
            path.write_text(text)
            self.assertFalse(self.result()['passed'])
        path.unlink()
        self.assertFalse(self.result()['passed'])
    def test_malformed_report(self):
        for value in [None,[],{}, {'failures':[],'runs':'bad'}]:
            self.paths[0].write_text(json.dumps(value))
            self.assertFalse(self.result()['passed'])

    def test_duplicate_log(self):
        original=next(self.raw.rglob('long-run-chunk-1.log'))
        folder=self.raw/'duplicate'/original.parent.name
        folder.mkdir(parents=True)
        (folder/original.name).write_bytes(original.read_bytes())
        self.assertFalse(self.result()['passed'])

    def test_intermediate_log_requires_exact_completed_interval(self):
        path=next(self.raw.rglob('long-run-chunk-1.log'))
        path.write_text('CHUNK seed 999 days 0-60 of 180 saved to fixture.world\n')
        self.assertFalse(self.result()['passed'])

if __name__=='__main__':
    unittest.main()
