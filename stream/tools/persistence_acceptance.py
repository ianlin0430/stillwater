#!/usr/bin/env python3
"""Real quit -> relaunch persistence acceptance for the packaged app, in isolated --persist-qa mode.

Never launches the app without --persist-qa. The user's real stream.world/.bak/preferences.cfg are only hashed.
Exit triggers:
  auto      System Events (needs Accessibility for the calling process; denied -> mode UNVERIFIED).
  external  harness writes pending-action.json and waits for someone to perform the real UI action.
hidden_close never needs Accessibility: NSRunningApplication.hide + terminate (quit Apple event).

Mode hidden_resume hides the app long enough for several 60s hidden advances, unhides it and checks
that the whole absence was advanced exactly once and summarised once. With --trigger external the
harness does not hide anything itself: it asks for a real hide/sleep and wake, which is how a natural
machine sleep/wake is captured (see docs/validation.md, "Real sleep/wake procedure").
"""
import argparse, datetime, hashlib, json, pathlib, subprocess, sys, time

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / 'builds/Stillwater Stream.app'
EXE = APP / 'Contents/MacOS/Stillwater Stream'
USER = pathlib.Path.home() / 'Library/Application Support/Godot/app_userdata/Stillwater Stream'
REAL = ['stream.world', 'stream.world.bak', 'preferences.cfg']
PROC = 'Stillwater Stream.app/Contents/MacOS/Stillwater Stream'
MODES = ['window_close', 'cmd_q', 'hidden_close']
EXTRA_MODES = ['hidden_resume']


def real_hashes():
    return {n: hashlib.sha256((USER / n).read_bytes()).hexdigest() if (USER / n).exists() else 'missing' for n in REAL}


def running():
    return subprocess.run(['pgrep', '-f', PROC], capture_output=True, text=True).stdout.split()


def osa(script, js=False):
    r = subprocess.run(['osascript'] + (['-l', 'JavaScript'] if js else []) + ['-e', script], capture_output=True, text=True, timeout=20)
    return r.returncode == 0, (r.stdout + r.stderr).strip()


def app_js(pid, member):
    return osa(f"ObjC.import('AppKit'); $.NSRunningApplication.runningApplicationWithProcessIdentifier({pid}).{member}", js=True)


def se(pid, body):
    return osa(f'tell application "System Events" to tell (first process whose unix id is {pid})\n{body}\nend tell')


def load(p):
    try:
        return json.loads(p.read_text())
    except (FileNotFoundError, ValueError):
        return None


class Run:
    def __init__(self, out, mode, trigger, external_timeout, hidden_seconds=200):
        self.out, self.mode, self.trigger, self.ext = out, mode, trigger, external_timeout
        self.hidden_seconds = hidden_seconds
        self.run_id = datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '_' + mode
        self.dir = USER / 'persistence-qa' / self.run_id
        self.checks = []

    def check(self, name, status, evidence):
        self.checks.append({'check': name, 'status': status, 'evidence': evidence})
        print(f'  [{status}] {name}: {evidence}', flush=True)

    def launch(self, n):
        log = open(self.out / f'{self.run_id}-launch-{n}.log', 'w')
        proc = subprocess.Popen([str(EXE), '--', f'--persist-qa={self.run_id}'], stdout=log, stderr=subprocess.STDOUT)
        deadline = time.time() + 40
        while time.time() < deadline:
            d = load(self.dir / f'launch-{n}.json')
            if d and 'post' in d:
                # A background launch starts occluded (window_can_draw false -> suspended view); bring it
                # forward so the visible path (60s periodic save, live advance) is what gets exercised.
                app_js(proc.pid, 'activateWithOptions(2)')
                time.sleep(2)
                return proc, d
            time.sleep(0.5)
        return proc, None

    def external(self, action, proc, mark=None):
        t0 = time.time()
        (self.out / 'pending-action.json').write_text(json.dumps({'run_id': self.run_id, 'pid': proc.pid, 'action': action, 'since': t0}))
        print(f'  ACTION NEEDED: {action} (pid {proc.pid}); waiting up to {self.ext}s', flush=True)
        try:
            if mark is not None:
                if self.absences_since(mark, self.ext):
                    return True, f'external {action} performed; absence report appeared after {time.time() - t0:.0f}s'
                return False, f'no external {action} within {self.ext}s'
            proc.wait(self.ext)
            return True, f'external {action} performed; process exited'
        except subprocess.TimeoutExpired:
            return False, f'no external {action} within {self.ext}s'
        finally:
            (self.out / 'pending-action.json').unlink(missing_ok=True)

    def close_window(self, proc):
        if self.trigger == 'external':
            return self.external('click the red window close button', proc)
        return se(proc.pid, 'click (first button of window 1 whose subrole is "AXCloseButton")')

    def cmd_q(self, proc):
        if self.trigger == 'external':
            return self.external('press Cmd-Q with Stillwater frontmost', proc)
        ok, msg = se(proc.pid, 'set frontmost to true\ndelay 1')
        if not ok:
            return ok, msg
        return osa('tell application "System Events" to keystroke "q" using command down')

    def finish(self, proc, label, trigger_ok, trigger_msg):
        """Wait for exit; if the trigger could not be delivered, fall back to a quit Apple event so the
        persistence data is still collected, but the mechanism stays UNVERIFIED."""
        fallback = False
        if not trigger_ok:
            self.check(f'{label}: trigger delivered', 'UNVERIFIED', trigger_msg)
            fallback = True
            app_js(proc.pid, 'terminate')
        t0 = time.time()
        try:
            proc.wait(15)
            exited = time.time() - t0
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            self.check(f'{label}: exits within 15s', 'FAIL', 'hung; killed')
            return fallback
        if trigger_ok:
            self.check(f'{label}: trigger delivered', 'PASS', trigger_msg or 'ok')
        self.check(f'{label}: exits within 15s', 'PASS', f'exit code {proc.returncode} after {exited:.1f}s' + (' (fallback quit event)' if fallback else ''))
        time.sleep(1)
        left = running()
        self.check(f'{label}: no process remains', 'PASS' if not left else 'FAIL', f'pgrep: {left}')
        return fallback

    def absences_since(self, mark, timeout):
        """Absence reports whose hide began at or after `mark`, oldest first; waits for the first."""
        deadline = time.time() + timeout
        while True:
            out = []
            for f in sorted(self.dir.glob('absence-*.json')):
                d = load(f)
                if d and d['absence']['since'] >= mark:
                    out.append((f.name, d))
            if out or time.time() >= deadline:
                return sorted(out, key=lambda x: x[1]['absence']['since'])
            time.sleep(1)

    def wait_for(self, path, timeout):
        deadline = time.time() + timeout
        while time.time() < deadline:
            d = load(path)
            if d:
                return d
            time.sleep(1)
        return None

    def execute_hidden_resume(self):
        """Hide the running app for a few minutes, unhide it, and check the absence was advanced
        exactly once and reported once. --trigger external asks a human to hide/sleep and wake."""
        print(f'== {self.mode} run_id={self.run_id}', flush=True)
        before = real_hashes()
        if running():
            self.check('no Stillwater running before start', 'FAIL', f'pgrep: {running()}')
            return self.result(before, before)
        proc, l1 = self.launch(1)
        if not l1:
            proc.kill()
            self.check('launch 1 writes launch-1.json', 'FAIL', 'timeout')
            return self.result(before, real_hashes())
        self.check('launch 1 isolated path', 'PASS' if '/persistence-qa/' + self.run_id + '/' in l1['path'] and l1['mode'] == 'persist-qa' else 'FAIL', l1['path'])
        # A launch can start occluded and resume when we activate it, which already writes an
        # absence report. Only reports that began after this mark belong to the hide below.
        mark = time.time()
        if self.trigger == 'external':
            ok, msg = self.external(f'hide Stillwater (Cmd-H) or sleep the Mac, wait at least {self.hidden_seconds}s, then wake/unhide it', proc, mark)
            self.check('external hide/wake performed', 'PASS' if ok else 'UNVERIFIED', msg)
            hidden_wall = None
        else:
            t_hide = time.time()
            app_js(proc.pid, 'hide')
            time.sleep(3)
            hidden = app_js(proc.pid, 'isHidden')[1] == 'true'
            self.check('app hidden (NSRunningApplication.hide)', 'PASS' if hidden else 'FAIL', f'isHidden={hidden}')
            time.sleep(self.hidden_seconds)
            still = app_js(proc.pid, 'isHidden')[1] == 'true'
            app_js(proc.pid, 'unhide')
            app_js(proc.pid, 'activateWithOptions(2)')
            hidden_wall = time.time() - t_hide
            self.check('app stayed hidden for the whole absence', 'PASS' if still else 'FAIL',
                       f'isHidden={still} after {hidden_wall:.1f}s')
        found = self.absences_since(mark, 60)
        if not found:
            proc.kill()
            self.check('an absence report is written on resume', 'FAIL', 'none written after the hide')
            return self.result(before, real_hashes())
        name, a = found[0]
        acc, span = a['absence'], a['resumed'] - a['absence']['since']
        self.check('an absence report is written on resume', 'PASS', f"{name}: span {span:.1f}s, advances {acc['advances']}")
        self.check('several 60s advances happened while hidden', 'PASS' if acc['advances'] >= 3 else 'FAIL',
                   f"advances={acc['advances']} over {span:.1f}s hidden")
        self.check('absence covers the whole hidden span', 'PASS' if abs(acc['seconds'] - span) < 2.0 else 'FAIL',
                   f"absence.seconds={acc['seconds']:.2f} vs wall span {span:.2f}s")
        advanced = a['elapsed_at_resume'] - a['elapsed_at_hide']
        self.check('elapsed advanced exactly once for the absence', 'PASS' if abs(advanced - acc['seconds']) < 0.001 else 'FAIL',
                   f"elapsed {a['elapsed_at_hide']:.2f} -> {a['elapsed_at_resume']:.2f} = {advanced:.2f}s advanced, absence.seconds={acc['seconds']:.2f}")
        self.check('one summary shown for the whole absence', 'PASS' if a['away_text'].startswith('While you were away') else 'FAIL',
                   a['away_text'] or '(empty)')
        self.check('no second absence report for the same hide', 'PASS' if len(found) == 1 else 'FAIL',
                   f"reports after the hide: {[n for n, _ in found]}")
        time.sleep(10)
        ok, msg = app_js(proc.pid, 'terminate')
        fb = self.finish(proc, 'exit after resume', ok, f'quit Apple event: {msg}')
        e1 = load(self.dir / 'exit-1.json')
        self.check('exit-1.json written', 'PASS' if e1 else 'FAIL', e1['reason'] if e1 else 'missing')
        if e1:
            self.check('the resumed world is what gets saved', 'PASS' if e1['summary']['elapsed'] >= a['elapsed_at_resume'] else 'FAIL',
                       f"elapsed at resume {a['elapsed_at_resume']:.1f} -> at exit {e1['summary']['elapsed']:.1f}")
        return self.result(before, real_hashes(), fb)

    def execute(self):
        if self.mode == 'hidden_resume':
            return self.execute_hidden_resume()
        print(f'== {self.mode} run_id={self.run_id}', flush=True)
        before = real_hashes()
        if running():
            self.check('no Stillwater running before start', 'FAIL', f'pgrep: {running()}')
            return self.result(before, before)
        proc, l1 = self.launch(1)
        if not l1:
            proc.kill()
            self.check('launch 1 writes launch-1.json', 'FAIL', 'timeout')
            return self.result(before, real_hashes())
        self.check('launch 1 isolated path', 'PASS' if '/persistence-qa/' + self.run_id + '/' in l1['path'] and l1['mode'] == 'persist-qa' else 'FAIL', l1['path'])
        world = self.dir / 'stream.world'
        m0 = world.stat().st_mtime
        time.sleep(75)
        saved = world.stat().st_mtime > m0 + 30
        # The 60s periodic save only runs while the window can draw; an occluded/hidden window takes the
        # suspended path (saves on enter/leave instead). Launch log records those transitions.
        flips = [l for l in (self.out / f'{self.run_id}-launch-1.log').read_text().splitlines() if 'suspended_view=' in l and float(l.split(' at ')[-1]) > m0]
        self.check('periodic save while running', 'PASS' if saved else 'UNVERIFIED' if flips else 'FAIL',
                   f'stream.world mtime +{world.stat().st_mtime - m0:.1f}s after launch save; suspend transitions: {flips}')
        if self.mode == 'window_close':
            ok, msg = self.close_window(proc)
        elif self.mode == 'cmd_q':
            ok, msg = self.cmd_q(proc)
        else:
            app_js(proc.pid, 'hide')
            time.sleep(2)
            hidden = app_js(proc.pid, 'isHidden')[1] == 'true'
            self.check('app hidden (NSRunningApplication.hide)', 'PASS' if hidden else 'FAIL', f'isHidden={hidden}')
            time.sleep(65)
            still = app_js(proc.pid, 'isHidden')[1] == 'true'
            ok, msg = app_js(proc.pid, 'terminate')
            ok = ok and still
            msg = f'quit Apple event via NSRunningApplication.terminate while hidden={still}: {msg}'
        fb1 = self.finish(proc, 'exit 1', ok, msg)
        e1 = load(self.dir / 'exit-1.json')
        if not e1:
            self.check('exit-1.json written after successful save', 'FAIL', 'missing')
            return self.result(before, real_hashes(), fb1)
        self.check('exit-1.json written after successful save', 'PASS', f"reason={e1['reason']} suspended_view={e1['suspended_view']}")
        if self.mode != 'hidden_close':
            self.check('close ran from visible (not suspended) view', 'PASS' if not e1['suspended_view'] else 'FAIL', f"suspended_view={e1['suspended_view']}")
        else:
            self.check('close ran while suspended (hidden) view', 'PASS' if e1['suspended_view'] else 'FAIL', f"suspended_view={e1['suspended_view']}")
        self.check('world changed while running', 'PASS' if e1['digest'] != l1['post']['digest'] else 'FAIL',
                   f"elapsed {l1['post']['summary']['elapsed']:.1f} -> {e1['summary']['elapsed']:.1f}")
        time.sleep(3)
        proc, l2 = self.launch(2)
        if not l2:
            proc.kill()
            self.check('launch 2 writes launch-2.json', 'FAIL', 'timeout')
            return self.result(before, real_hashes(), fb1)
        self.compare(e1, l2)
        time.sleep(15)
        ok, msg = self.close_window(proc)
        fb2 = self.finish(proc, 'relaunch exit (window close)', ok, msg)
        e2 = load(self.dir / 'exit-2.json')
        self.check('exit-2.json written', 'PASS' if e2 else 'FAIL', e2['reason'] if e2 else 'missing')
        return self.result(before, real_hashes(), fb1, fb2)

    def compare(self, e1, l2):
        pre, post = l2['pre']['summary'], l2['post']['summary']
        self.check('exit-1 digest == launch-2 pre-catch-up digest', 'PASS' if e1['digest'] == l2['pre']['digest'] else 'FAIL',
                   f"{e1['digest'][:16]} vs {l2['pre']['digest'][:16]}")
        for key in ['resources', 'events', 'last_event', 'totals', 'seed', 'rng', 'motion_rng', 'wall_checkpoint', 'elapsed', 'animals']:
            self.check(f'pre-catch-up {key} equal', 'PASS' if e1['summary'][key] == pre[key] else 'FAIL',
                       json.dumps(pre[key])[:120])
        lost = {x['id']: x['cause'] for x in l2['post']['lost']}
        now = {a['id']: a for a in post['animals']}
        kept = [a for a in e1['summary']['animals'] if a['id'] in now]
        same = all(now[a['id']] == a for a in kept)
        self.check('surviving animals keep id/name/parent/species', 'PASS' if same else 'FAIL',
                   f"{len(kept)}/{len(e1['summary']['animals'])} alive after catch-up; gone during catch-up: {lost or 'none'}")
        self.check('wall_checkpoint moves forward after catch-up', 'PASS' if post['wall_checkpoint'] > pre['wall_checkpoint'] else 'FAIL',
                   f"{pre['wall_checkpoint']:.1f} -> {post['wall_checkpoint']:.1f}; away={l2['post']['away']['seconds']:.1f}s")
        self.check('launch 2 path isolated and loaded primary', 'PASS' if not l2['post']['backup'] and not l2['post']['preserved'] and l2['post']['error'] == 0 and '/persistence-qa/' in l2['post']['saved_path'] else 'FAIL',
                   f"backup={l2['post']['backup']} preserved={l2['post']['preserved']} error={l2['post']['error']}")

    def result(self, before, after, *fallbacks):
        self.check('user stream.world/.bak/preferences.cfg unchanged', 'PASS' if before == after else 'FAIL', json.dumps(after))
        status = 'FAIL' if any(c['status'] == 'FAIL' for c in self.checks) else 'UNVERIFIED' if any(fallbacks) or any(c['status'] == 'UNVERIFIED' for c in self.checks) else 'PASS'
        return {'mode': self.mode, 'run_id': self.run_id, 'trigger': 'programmatic' if self.mode == 'hidden_close' else self.trigger,
                'status': status, 'user_hashes_before': before, 'user_hashes_after': after, 'checks': self.checks,
                'data_dir': str(self.dir)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--modes', default=','.join(MODES), help='any of ' + ','.join(MODES + EXTRA_MODES))
    ap.add_argument('--trigger', choices=['auto', 'external'], default='auto')
    ap.add_argument('--external-timeout', type=int, default=900)
    ap.add_argument('--hidden-seconds', type=int, default=200, help='hidden_resume: how long to stay hidden')
    a = ap.parse_args()
    if not EXE.exists():
        sys.exit(f'missing {EXE}; export first')
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    out = ROOT / 'artifacts/persistence-qa' / stamp
    out.mkdir(parents=True, exist_ok=True)
    print(f'report dir: {out}', flush=True)
    start = real_hashes()
    runs = [Run(out, m, a.trigger, a.external_timeout, a.hidden_seconds).execute() for m in a.modes.split(',')]
    end = real_hashes()
    report = {'app': str(APP), 'started': stamp, 'user_hashes_start': start, 'user_hashes_end': end,
              'user_files_unchanged': start == end, 'runs': runs}
    (out / 'report.json').write_text(json.dumps(report, indent=2))
    lines = [f'# Persistence acceptance {stamp}', '', f'App: `{APP}`', f"User files unchanged overall: {'PASS' if start == end else 'FAIL'}", '']
    for r in runs:
        lines += [f"## {r['mode']}: {r['status']}", f"run_id `{r['run_id']}`, trigger {r['trigger']}", '']
        lines += [f"- {c['status']} {c['check']}: {c['evidence']}" for c in r['checks']] + ['']
    (out / 'summary.md').write_text('\n'.join(lines))
    print(f"done: {[(r['mode'], r['status']) for r in runs]} -> {out}")
    sys.exit(1 if any(r['status'] == 'FAIL' for r in runs) or start != end else 0)


if __name__ == '__main__':
    main()
