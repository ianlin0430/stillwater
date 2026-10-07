import sys
import subprocess
import unittest
from unittest.mock import Mock, patch
from low_power_check import run, signal_group


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

    def test_macos_exit_race_is_reaped(self):
        # Darwin can return EPERM when the group contains an exiting zombie.
        # The signal error is harmless only after our actual child has exited.
        child=Mock(pid=99999999,returncode=0)
        child.poll.side_effect=[None,0,0]
        with patch('low_power_check.subprocess.Popen',return_value=child), \
             patch('low_power_check.os.setpriority'), \
             patch('low_power_check.os.killpg',side_effect=PermissionError(1,'exit race')):
            result=run(['fixture'],1)
        self.assertTrue(result['passed'])
        self.assertEqual(result['exit_code'],0)
        child.wait.assert_called_once()

    def test_live_signal_denial_is_not_hidden(self):
        child=Mock(pid=99999999)
        child.poll.return_value=None
        child.wait.side_effect=subprocess.TimeoutExpired('fixture', .1)
        with patch('low_power_check.os.killpg',side_effect=PermissionError(1,'denied')):
            with self.assertRaises(PermissionError):
                signal_group(child, 19)

    def test_exiting_child_is_given_a_bounded_reap_window(self):
        child=Mock(pid=99999999)
        child.poll.return_value=None
        child.wait.return_value=0
        with patch('low_power_check.os.killpg',side_effect=PermissionError(1,'exiting')):
            self.assertFalse(signal_group(child, 19))
        child.wait.assert_called_once_with(timeout=.1)


if __name__=='__main__':
    unittest.main()
