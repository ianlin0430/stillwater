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


if __name__=='__main__':
    unittest.main()
