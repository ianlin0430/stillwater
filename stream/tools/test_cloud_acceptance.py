"""Offline evidence-auditor tests; never launch the app or GitHub jobs."""
import copy
import itertools
import json
import pathlib
import tempfile
import unittest
from cloud_acceptance import audit, CORE, FLAGS, SEEDS


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.raw = pathlib.Path(self.temp.name)
        self.sha = 'a'*40
        self.run = {'headSha': self.sha, 'status': 'completed', 'conclusion': 'success'}
        for name in CORE:
            (self.raw / (name + '.log')).write_text('{"checks":1,"failures":[]}\n')
        self.paths = []
        for seed, scene, decor, feed in itertools.product(SEEDS, ['reef', 'shipwreck'], ['min', 'max'], ['none', 'daily']):
            row = {'seed': seed, 'scene': scene, 'decor': decor, 'feed': feed, 'mode': 'live', 'days': 180,
                   'acceptance': dict.fromkeys(FLAGS, True),
                   'chunks': [{'from_day': start, 'to_day': start+60, 'seconds': 1} for start in [0, 60, 120]],
                   'max_population': 18, 'max_material_residual': 0, 'starvation': 0,
                   'longest_absence': {}, 'depth': {'violations': 0}}
            report = {k: row[k] for k in ['mode', 'scene', 'decor', 'feed']}
            report.update(days_per_seed=180, failures=[], runs=[row])
            path = self.raw / f'ci-live-180d-{scene}-{decor}-{feed}-{seed}.json'
            path.write_text(json.dumps(report))
            self.paths.append(path)

    def result(self):
        return audit(self.run, self.raw, self.sha)

    def alter(self, change):
        value = json.loads(self.paths[0].read_text())
        change(value)
        self.paths[0].write_text(json.dumps(value))

    def test_complete_evidence(self):
        result = self.result()
        self.assertTrue(result['passed'], result['failures'])
        self.assertEqual(result['verified_cases'], 24)
        self.assertEqual(len(result['core']), len(CORE))

    def test_missing_case(self):
        self.paths[0].unlink()
        self.assertFalse(self.result()['passed'])

    def test_duplicate_case(self):
        (self.raw / 'ci-live-180d-duplicate.json').write_bytes(self.paths[0].read_bytes())
        self.assertFalse(self.result()['passed'])

    def test_revision_and_workflow(self):
        for key, value in [('headSha', 'b'*40), ('status', 'in_progress'), ('conclusion', 'failure')]:
            with self.subTest(key=key):
                run = copy.deepcopy(self.run)
                run[key] = value
                self.assertFalse(audit(run, self.raw, self.sha)['passed'])

    def test_failed_or_missing_acceptance(self):
        for value in [False, None]:
            with self.subTest(value=value):
                self.alter(lambda r: r['runs'][0]['acceptance'].update(starvation=value))
                self.assertFalse(self.result()['passed'])
        self.alter(lambda r: r['runs'][0]['acceptance'].pop('starvation'))
        self.assertFalse(self.result()['passed'])

    def test_chunk_gap(self):
        self.alter(lambda r: r['runs'][0]['chunks'][1].update(from_day=61))
        self.assertFalse(self.result()['passed'])

    def test_configuration_mismatch(self):
        self.alter(lambda r: r.update(scene='shipwreck' if r['scene']=='reef' else 'reef'))
        self.assertFalse(self.result()['passed'])

    def test_short_run(self):
        self.alter(lambda r: r['runs'][0].update(days=179))
        self.assertFalse(self.result()['passed'])

    def test_core_error_after_green_json(self):
        (self.raw / 'test_obstacles.log').write_text('{"failures":[]}\nSCRIPT ERROR: late failure\n')
        self.assertFalse(self.result()['passed'])

    def test_last_core_verdict_and_missing_log(self):
        path = self.raw / 'test_obstacles.log'
        path.write_text('{"failures":[]}\n{"failures":["failure"]}\n')
        self.assertFalse(self.result()['passed'])
        path.unlink()
        self.assertFalse(self.result()['passed'])


if __name__ == '__main__':
    unittest.main()
