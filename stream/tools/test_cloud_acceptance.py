"""Offline evidence-auditor tests; never launch the app or GitHub jobs."""
import copy
import itertools
import json
import pathlib
import tempfile
import unittest
from cloud_acceptance import audit, complete_chunks, CORE, FLAGS, SEEDS
from cloud_plan import case_key


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

    def test_ten_exact_chunks(self):
        chunks = [{'from_day': s, 'to_day': s+18, 'seconds': 1} for s in range(0,180,18)]
        self.assertTrue(complete_chunks(chunks))
        for path in self.paths:
            value=json.loads(path.read_text())
            value['runs'][0]['chunks']=chunks
            path.write_text(json.dumps(value))
        self.assertTrue(self.result()['passed'])

    def test_invalid_checkpoint_coverage(self):
        good=[{'from_day': s, 'to_day': s+18, 'seconds': 1} for s in range(0,180,18)]
        for chunks in [[],good[:-1],good[::-1],good+[good[-1]],None]:
            self.assertFalse(complete_chunks(chunks))
        for key,value in [('from_day',1),('to_day',0),('to_day',181),('to_day',18.0),
                          ('seconds',0),('seconds',float('nan')),('seconds',float('inf'))]:
            chunks=copy.deepcopy(good)
            chunks[0][key]=value
            self.assertFalse(complete_chunks(chunks))

    def test_configuration_mismatch(self):
        self.alter(lambda r: r.update(scene='shipwreck' if r['scene']=='reef' else 'reef'))
        self.assertFalse(self.result()['passed'])

    def test_short_run(self):
        self.alter(lambda r: r['runs'][0].update(days=179))
        self.assertFalse(self.result()['passed'])

    def test_core_error_after_green_json(self):
        (self.raw / 'test_obstacles.log').write_text('{"failures":[]}\nSCRIPT ERROR: late failure\n')
        self.assertFalse(self.result()['passed'])

    def test_engine_errors_before_and_after_green_verdict_are_rejected(self):
        verdict='{"checks":40,"failures":[]}\n'
        error='ERROR: Condition "(uint32_t)buff.size() != len" is true. Returning: Variant()\n'
        for content in [error+verdict, verdict+error]:
            with self.subTest(content=content):
                (self.raw / 'test_save_v3.log').write_text(content)
                result=self.result()
                self.assertFalse(result['passed'])
                self.assertNotIn('test_save_v3',result['core'])

    def test_last_core_verdict_and_missing_log(self):
        path = self.raw / 'test_obstacles.log'
        path.write_text('{"failures":[]}\n{"failures":["failure"]}\n')
        self.assertFalse(self.result()['passed'])
        path.unlink()
        self.assertFalse(self.result()['passed'])


SLOW = {'shipwreck/min/daily/42', 'shipwreck/max/none/812', 'shipwreck/max/daily/812'}


class ResumeTests(unittest.TestCase):
    """Run A (18-day chunks, cancelled) plus run B (9-day chunks from each case's start day)."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = pathlib.Path(self.temp.name)
        self.raw, self.prior_raw = base / 'new', base / 'old'
        self.raw.mkdir()
        self.prior_raw.mkdir()
        self.sha, self.prior_sha = 'b'*40, 'a'*40
        self.run = {'headSha': self.sha, 'status': 'completed', 'conclusion': 'success'}
        self.prior = {'headSha': self.prior_sha, 'status': 'completed', 'conclusion': 'cancelled',
                      'jobs': [{'name': 'core tests', 'conclusion': 'success'}]}
        self.starts, self.paths = {}, {}
        for name in CORE:
            (self.prior_raw / (name + '.log')).write_text('{"checks":1,"failures":[]}\n')
        for seed, scene, decor, feed in itertools.product(SEEDS, ['reef', 'shipwreck'], ['min', 'max'], ['none', 'daily']):
            key = f'{scene}/{decor}/{feed}/{seed}'
            start = 36 if key in SLOW else 54
            self.starts[key] = start
            old = [{'from_day': a, 'to_day': a+18, 'seconds': 1} for a in range(0, start, 18)]
            new = [{'from_day': a, 'to_day': min(a+9, 180), 'seconds': 1} for a in range(start, 180, 9)]
            row = {'seed': seed, 'scene': scene, 'decor': decor, 'feed': feed, 'mode': 'live', 'days': 180,
                   'acceptance': dict.fromkeys(FLAGS, True), 'chunks': old+new,
                   'max_population': 18, 'max_material_residual': 0, 'starvation': 0,
                   'longest_absence': {}, 'depth': {'violations': 0}}
            report = {k: row[k] for k in ['mode', 'scene', 'decor', 'feed']}
            report.update(days_per_seed=180, failures=[], runs=[row])
            path = self.raw / f'ci-live-180d-{scene}-{decor}-{feed}-{seed}.json'
            path.write_text(json.dumps(report))
            self.paths[key] = path
            for index, chunk in enumerate(old, 1):
                self.log(self.prior_raw, key, index, chunk, False)
            for index, chunk in enumerate(new, 1):
                self.log(self.raw, key, index, chunk, chunk['to_day'] == 180)

    def log(self, root, key, index, chunk, final):
        scene, decor, feed, seed = key.split('/')
        folder = root / f'ecology-live-180d-{scene}-{decor}-feed-{feed}-seed-{seed}-chunk-{index}-log'
        folder.mkdir()
        lines = [f'RESUME seed {seed} from day {chunk["from_day"]} (res://artifacts/ckpt/day-{chunk["from_day"]}.world)'] if chunk['from_day'] else []
        lines.append('ACCEPTANCE PASS' if final else f'CHUNK seed {seed} days {chunk["from_day"]}-{chunk["to_day"]} of 180 saved to res://artifacts/ckpt/day-{chunk["to_day"]}.world')
        (folder / f'long-run-chunk-{index}.log').write_text('\n'.join(lines)+'\n')
        return folder / f'long-run-chunk-{index}.log'

    def result(self, **changes):
        resume = dict(run=self.prior, raw=self.prior_raw, sha=self.prior_sha, starts=self.starts, app_identical=True)
        resume.update(changes)
        return audit(self.run, self.raw, self.sha, resume)

    def alter(self, key, change):
        value = json.loads(self.paths[key].read_text())
        change(value['runs'][0])
        self.paths[key].write_text(json.dumps(value))

    def logfile(self, root, key, index):
        scene, decor, feed, seed = key.split('/')
        return root / f'ecology-live-180d-{scene}-{decor}-feed-{feed}-seed-{seed}-chunk-{index}-log' / f'long-run-chunk-{index}.log'

    def test_chunks_from_both_runs_cover_every_case_once(self):
        result = self.result()
        self.assertTrue(result['passed'], result['failures'])
        self.assertEqual((result['verified_cases'], result['verified_logs']), (24, 3*18+21*17))
        self.assertEqual(len(result['core']), len(CORE))

    def test_unresumed_audit_is_unchanged(self):
        self.assertFalse(audit(self.run, self.raw, self.sha)['passed'])

    def test_revision_and_prior_run_identity(self):
        self.assertFalse(self.result(app_identical=False)['passed'])
        self.assertFalse(self.result(sha='c'*40)['passed'])
        self.assertFalse(self.result(run=dict(self.prior, headSha='c'*40))['passed'])
        self.assertFalse(self.result(run=dict(self.prior, jobs=[{'name': 'core tests', 'conclusion': 'failure'}]))['passed'])
        self.assertFalse(self.result(run=dict(self.prior, jobs=[]))['passed'])

    def test_core_logs_come_from_the_prior_run(self):
        (self.prior_raw / 'test_world.log').unlink()
        self.assertFalse(self.result()['passed'])

    def test_missing_start_day_for_a_case(self):
        starts = dict(self.starts)
        starts.pop('reef/min/none/42')
        self.assertFalse(self.result(starts=starts)['passed'])

    def test_seam_gap_overlap_and_wrong_prior_chunk_size(self):
        self.alter('reef/min/none/42', lambda r: r['chunks'][3].update(from_day=55))
        self.assertFalse(self.result()['passed'])
        self.alter('reef/min/none/42', lambda r: r['chunks'][3].update(from_day=54))
        self.assertTrue(self.result()['passed'])
        self.alter('reef/min/none/42', lambda r: r['chunks'].insert(3, dict(r['chunks'][2])))
        self.assertFalse(self.result()['passed'])
        self.alter('reef/min/none/42', lambda r: r['chunks'].pop(3))
        self.assertTrue(self.result()['passed'])
        self.alter('reef/min/none/42', lambda r: (r['chunks'][0].update(to_day=9), r['chunks'][1].update(from_day=9)))
        self.assertFalse(self.result()['passed'])

    def test_resume_start_must_sit_on_a_chunk_boundary(self):
        starts = dict(self.starts, **{'reef/min/none/42': 50})
        self.assertFalse(self.result(starts=starts)['passed'])

    def test_missing_prior_or_new_log(self):
        for root, index in [(self.prior_raw, 3), (self.raw, 2), (self.raw, 14)]:
            path = self.logfile(root, 'reef/min/none/42', index)
            text = path.read_text()
            path.unlink()
            path.parent.rmdir()
            self.assertFalse(self.result()['passed'], (root, index))
            path.parent.mkdir()
            path.write_text(text)
        self.assertTrue(self.result()['passed'])

    def test_every_log_needs_its_resume_marker_completion_and_no_engine_error(self):
        for root, index in [(self.prior_raw, 2), (self.raw, 1), (self.raw, 14)]:
            path = self.logfile(root, 'reef/min/none/42', index)
            text = path.read_text()
            lines = text.splitlines()
            for bad in [lines[1:], lines[:-1], [lines[0], 'SCRIPT ERROR: x']+lines[1:],
                        [lines[0].replace('from day', 'from day 1')]+lines[1:]]:
                path.write_text('\n'.join(bad)+'\n')
                self.assertFalse(self.result()['passed'], (root, index, bad))
            path.write_text(text)
        self.assertTrue(self.result()['passed'])

    def test_incomplete_timed_out_chunk_log_is_not_used_but_unexpected_new_logs_fail(self):
        stale = self.log(self.prior_raw, 'shipwreck/min/daily/42', 3, {'from_day': 36, 'to_day': 54}, False)
        stale.write_text('RESUME seed 42 from day 36 (x)\n')
        self.assertTrue(self.result()['passed'])
        self.log(self.raw, 'shipwreck/min/daily/42', 17, {'from_day': 180, 'to_day': 189}, False)
        self.assertFalse(self.result()['passed'])


if __name__ == '__main__':
    unittest.main()
