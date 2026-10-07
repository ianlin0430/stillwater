import unittest
from cloud_plan import plan


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


if __name__=='__main__':
    unittest.main()
