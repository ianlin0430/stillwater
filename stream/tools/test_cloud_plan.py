import unittest
from cloud_plan import plan, resume_plan, slot_plan, verify_source, APP_SCOPES


class PlanTests(unittest.TestCase):
    def test_complete_production_matrix(self):
        p=plan(180, [42,812,240921], broad=True)
        self.assertEqual(len(p['cases']),24)
        self.assertEqual(len({tuple(c.values()) for c in p['cases']}),24)
        self.assertEqual(p['bounds'],list(range(0,181,18)))
        self.assertEqual(p['chunks'],10)
        self.assertLessEqual(len(p['cases'])*p['chunks']+2,256)

    def test_short_and_uneven_runs_keep_all_days(self):
        for days in [3,6,9,12,36,183]:
            p=plan(days,[42])
            self.assertEqual(p['bounds'][0],0)
            self.assertEqual(p['bounds'][-1],days)
            self.assertTrue(all(b>a for a,b in zip(p['bounds'],p['bounds'][1:])))
            self.assertLessEqual(max(b-a for a,b in zip(p['bounds'],p['bounds'][1:])),(days+9)//10 if days>=10 else 1)

    def test_invalid_and_overflow(self):
        for days,seeds in [(0,[42]),(181,[42]),(180,[]),(180,[42,42]),(180,list(range(4)))]:
            with self.subTest(days=days,seeds=seeds), self.assertRaises(ValueError):
                plan(days,seeds,broad=True)

    def test_offline_32_seeds_keep_complete_coverage_with_fewer_jobs(self):
        p=plan(180,list(range(1,33)),mode='offline')
        self.assertEqual(p['chunks'],3)
        self.assertEqual(p['bounds'],[0,60,120,180])
        self.assertEqual(len(p['cases']),32)
        self.assertLessEqual(len(p['cases'])*p['chunks']+2,256)
        with self.assertRaises(ValueError):
            plan(180,[42],mode='unknown')

    def test_extra_year_runs_once_without_dropping_any_cases(self):
        for mode,broad,seeds in [('offline',False,list(range(1,33))),('live',True,[42,812,240921])]:
            p=plan(180,seeds,broad=broad,mode=mode,year=True)
            self.assertEqual(sum(case['year'] for case in p['cases']),1)
            self.assertTrue(p['cases'][0]['year'])
            self.assertEqual(len(p['cases']),len(seeds)*(8 if broad else 1))
            self.assertEqual(p['bounds'][-1],180)
        self.assertTrue(all(not case['year'] for case in plan(180,[42,812])['cases']))


SLOW = ['shipwreck/min/daily/42', 'shipwreck/max/none/812', 'shipwreck/max/daily/812']
RUN = '37654653638'
SHA = '9' * 40


def resume(**changes):
    options = dict(days=180, seeds=[42, 812, 240921], broad=True, chunk_days=9, start=54,
                   overrides=','.join(k + '=36' for k in SLOW), run_id=RUN)
    options.update(changes)
    return resume_plan(**options)


class ResumePlanTests(unittest.TestCase):
    def test_default_slots_match_the_original_chunk_bounds(self):
        p = plan(180, [42, 812, 240921], broad=True)
        slots = slot_plan(p['cases'], p['bounds'])
        self.assertEqual(len(slots), 10)
        for index, slot in enumerate(slots):
            self.assertEqual({(c['from_day'], c['to_day'], c['n'], c['src']) for c in slot},
                             {(18*index, 18*index+18, 10, '')})

    def test_resume_start_days_and_nine_day_chunks_reach_day_180(self):
        p = resume()
        self.assertEqual(len(p['cases']), 24)
        self.assertEqual(p['chunks'], 16)
        starts = {}
        for slot in p['slots']:
            for c in slot:
                starts.setdefault((c['scene'], c['decor'], c['feed'], c['seed']), []).append((c['from_day'], c['to_day']))
        self.assertEqual(len(starts), 24)
        for key, spans in starts.items():
            slow = '/'.join(map(str, key)) in SLOW
            first = 36 if slow else 54
            self.assertEqual(spans[0][0], first)
            self.assertEqual(spans[-1][1], 180)
            self.assertEqual(len(spans), 16 if slow else 14)
            self.assertTrue(all(b == c for (_, b), (c, _) in zip(spans, spans[1:])))
            self.assertTrue(all(b-a == 9 for a, b in spans))
        self.assertEqual(sum(len(slot) for slot in p['slots']), 3*16+21*14)
        self.assertEqual(len(p['slots'][0]), 24)
        self.assertEqual([len(s) for s in p['slots'][14:]], [3, 3])

    def test_only_first_slot_downloads_from_the_source_run(self):
        p = resume()
        self.assertTrue(all(c['src'] == RUN for c in p['slots'][0]))
        self.assertTrue(all(c['src'] == '' for slot in p['slots'][1:] for c in slot))
        self.assertEqual({c['from_day'] for c in p['slots'][0]}, {36, 54})

    def test_resume_rejects_bad_input(self):
        for changes in [dict(chunk_days=0), dict(chunk_days=9.0), dict(start=0), dict(start=180),
                        dict(chunk_days=1), dict(overrides='reef/min/none/1=36'),
                        dict(overrides='shipwreck/min/daily/42'), dict(overrides='shipwreck/min/daily/42=0'),
                        dict(run_id='abc'), dict(run_id='')]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                resume(**changes)

    def test_resume_without_overrides_uses_one_start_day(self):
        p = resume(overrides='', start=36, days=180, seeds=[42])
        self.assertEqual({c['from_day'] for c in p['slots'][0]}, {36})
        self.assertEqual(len(p['slots']), 16)


class VerifySourceTests(unittest.TestCase):
    def setUp(self):
        self.p = resume(seeds=[42], broad=False, scene='reef', decor='min', feed='none', overrides='')
        self.run = {'id': int(RUN), 'head_sha': SHA}
        self.artifacts = [{'name': 'checkpoint-live-180d-reef-min-feed-none-seed-42-day-54', 'expired': False,
                           'workflow_run': {'id': int(RUN), 'head_sha': SHA}}]

    def check(self, run=None, artifacts=None):
        return verify_source(run or self.run, self.artifacts if artifacts is None else artifacts,
                             self.p['slots'][0], 180, SHA)

    def test_exact_checkpoint_passes(self):
        self.check()

    def test_wrong_revision_missing_expired_or_duplicate_fails(self):
        other = dict(self.artifacts[0], expired=True)
        bad_run = dict(self.artifacts[0], workflow_run={'id': 1, 'head_sha': SHA})
        bad_sha = dict(self.artifacts[0], workflow_run={'id': int(RUN), 'head_sha': '8' * 40})
        for run, artifacts in [(dict(self.run, head_sha='8' * 40), None), (None, []), (None, [other]),
                               (None, [bad_run]), (None, [bad_sha]), (None, self.artifacts * 2),
                               (dict(self.run, id=5), None)]:
            with self.subTest(run=run, artifacts=artifacts), self.assertRaises(ValueError):
                self.check(run, artifacts)

    def test_app_scope_checks_simulation_code_and_tests_but_not_docs(self):
        self.assertIn('stream', APP_SCOPES)
        self.assertIn(':(exclude)stream/docs', APP_SCOPES)
        self.assertNotIn(':(exclude)stream/tests', APP_SCOPES)


if __name__=='__main__':
    unittest.main()
