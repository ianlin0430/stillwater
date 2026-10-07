import sys
import unittest
from low_power_check import run


class CheckTests(unittest.TestCase):
    def test_success_and_real_failure(self):
        for code in [0,7]:
            result=run([sys.executable,'-c',f'raise SystemExit({code})'],2)
            self.assertEqual(result['exit_code'],code)
            self.assertEqual(result['passed'],code==0)
            self.assertFalse(result['timed_out'])

    def test_timeout_is_not_accepted(self):
        result=run([sys.executable,'-c','import time; time.sleep(30)'],.3)
        self.assertTrue(result['timed_out'])
        self.assertFalse(result['passed'])
        self.assertLess(result['wall_seconds'],1)
        self.assertLess(result['child_cpu_seconds'],.2)

    def test_invalid_budgets_cannot_launch_a_worker(self):
        for budget in [0,-1,121]:
            with self.subTest(budget=budget), self.assertRaises(ValueError):
                run(['this-command-must-never-be-launched'],budget)


if __name__=='__main__':
    unittest.main()
