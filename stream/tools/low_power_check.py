"""Run one short POSIX check with a10% duty cycle and a strict wall-time limit.

For headless tests only. A timeout is incomplete evidence, never a passing test.
This bounds local CPU activity; it does not measure electrical energy or app watts.
"""
import argparse
import json
import os
import resource
import signal
import subprocess
import time


def signal_group(child, sig):
    try:
        os.killpg(child.pid, sig)
    except ProcessLookupError:
        return False
    except PermissionError:
        # Darwin may deny a signal to an exiting zombie process group.
        # Never mask a denial while our child is still running.
        if child.poll() is None:
            try:
                child.wait(timeout=.1)
            except subprocess.TimeoutExpired:
                raise PermissionError('Cannot signal a still-running check group')
        return False
    return True


def run(command, wall_seconds=20):
    if os.name != 'posix' or not 0 < wall_seconds <= 120:
        raise ValueError('POSIX only; wall budget must be positive and at most120 seconds')
    start=time.monotonic()
    before=resource.getrusage(resource.RUSAGE_CHILDREN)
    child=subprocess.Popen(command, start_new_session=True)
    timed_out=False
    try:
        try:
            os.setpriority(os.PRIO_PROCESS, child.pid, 15)
        except ProcessLookupError:
            pass
        while child.poll() is None:
            remaining=wall_seconds-(time.monotonic()-start)
            if remaining<=0:
                timed_out=True
                break
            if not signal_group(child, signal.SIGSTOP):
                break
            time.sleep(min(.18,remaining))
            remaining=wall_seconds-(time.monotonic()-start)
            if remaining<=0:
                timed_out=True
                break
            if not signal_group(child, signal.SIGCONT):
                break
            time.sleep(min(.02,remaining))
    finally:
        # Always remove the entire check group, including stopped descendants.
        # SIGKILL avoids briefly releasing a timed-out CPU-bound worker again.
        signal_group(child, signal.SIGKILL)
        child.wait()
    after=resource.getrusage(resource.RUSAGE_CHILDREN)
    return {'exit_code':child.returncode, 'timed_out':timed_out,
            'wall_seconds':round(time.monotonic()-start,3),
            'child_cpu_seconds':round(after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,3),
            'duty_cycle':.1, 'passed':not timed_out and child.returncode==0}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wall-seconds',type=float,default=20)
    parser.add_argument('command',nargs=argparse.REMAINDER)
    args=parser.parse_args()
    command=args.command[1:] if args.command[:1]==['--'] else args.command
    if not command: parser.error('a command is required')
    result=run(command,args.wall_seconds)
    print(json.dumps({'low_power_check':result}),flush=True)
    return 0 if result['passed'] else 124 if result['timed_out'] else 1


if __name__=='__main__':
    raise SystemExit(main())
