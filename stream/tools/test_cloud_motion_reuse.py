import copy
import json
import os
import pathlib
import subprocess
import tempfile
import unittest
from cloud_motion_reuse import ENGINE, SEEDS, STEPS, SUITES, verify_logs, verify_run, verify_tree


class MotionReuse(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.raw = pathlib.Path(self.temp.name)
        self.run = {'status': 'completed', 'conclusion': 'success', 'event': 'workflow_dispatch',
                    'path': '.github/workflows/ecology-batch.yml',
                    'head_repository': {'full_name': 'owner/reef'}, 'head_sha': 'a' * 40}
        self.jobs = [{'conclusion': 'success', 'steps': [
            {'name': name, 'status': 'completed', 'conclusion': 'success'} for name in STEPS]}]
        for name, checks in SUITES.items():
            verdict = {'checks': checks, 'failures': []}
            if name == 'test_obstacles':
                verdict['numbers'] = {'obstacles': {'seeds': SEEDS, 'per_scene_decor': {
                    config: {key: dict.fromkeys(map(str, SEEDS), 0)
                             for key in ['hesitation', 'control_hesitation']}
                    for config in ['reef/min', 'reef/max', 'shipwreck/min', 'shipwreck/max']}}}
            (self.raw / (name + '.log')).write_text('Godot Engine v' + ENGINE + ' - fixture\n' + json.dumps(verdict) + '\n')
            (self.raw / (name + '.exit')).write_text('0\n')

    def tearDown(self):
        self.temp.cleanup()

    def change(self, name, **values):
        log = self.raw / (name + '.log')
        data = json.loads(log.read_text().splitlines()[-1])
        data.update(values)
        log.write_text('Godot Engine v' + ENGINE + ' - fixture\n' + json.dumps(data) + '\n')

    def test_complete_evidence(self):
        self.assertEqual(verify_run(self.run, self.jobs, 'owner/reef'), 'a' * 40)
        self.assertEqual(set(verify_logs(self.raw)), set(SUITES))

    def test_terminal_source_required(self):
        for key, value in [('status', 'in_progress'), ('conclusion', 'failure'),
                           ('conclusion', 'cancelled'), ('event', 'pull_request'),
                           ('head_sha', 'HEAD'), ('path', 'other.yml')]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                verify_run(dict(self.run, **{key: value}), self.jobs, 'owner/reef')

    def test_repository_required(self):
        with self.assertRaises(ValueError):
            verify_run(self.run, self.jobs, 'another/reef')

    def test_full_s5_step_required(self):
        jobs = copy.deepcopy(self.jobs)
        jobs[0]['steps'][0]['conclusion'] = 'skipped'
        with self.assertRaises(ValueError):
            verify_run(self.run, jobs, 'owner/reef')
        with self.assertRaises(ValueError):
            verify_run(self.run, [], 'owner/reef')
        with self.assertRaises(ValueError):
            verify_run(self.run, self.jobs + self.jobs, 'owner/reef')

    def test_missing_duplicate_logs(self):
        path = self.raw / 'test_decor_art.log'
        duplicate = self.raw / 'nested'
        duplicate.mkdir()
        (duplicate / path.name).write_bytes(path.read_bytes())
        with self.assertRaises(ValueError):
            verify_logs(self.raw)
        (duplicate / path.name).unlink()
        path.unlink()
        with self.assertRaises(ValueError):
            verify_logs(self.raw)

    def test_real_exit_required(self):
        (self.raw / 'test_seahorse.exit').write_text('124\n')
        with self.assertRaises(ValueError):
            verify_logs(self.raw)

    def test_actual_engine_build_required(self):
        with self.assertRaises(ValueError):
            verify_logs(self.raw, 'different-engine-build')

    def test_engine_errors_rejected(self):
        path = self.raw / 'test_natural_motion.log'
        original = path.read_text()
        for marker in ['ERROR:', 'SCRIPT ERROR', 'Parse Error', 'Failed loading resource']:
            with self.subTest(marker=marker), self.assertRaises(ValueError):
                path.write_text(original + marker + ' fixture error\n')
                verify_logs(self.raw)

    def test_complete_checks_and_no_failure(self):
        for value in [89, 90.0, True]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.change('test_seahorse', checks=value)
                verify_logs(self.raw)
        self.change('test_seahorse', checks=90, failures=['night hitch failed'])
        with self.assertRaises(ValueError):
            verify_logs(self.raw)

    def test_ambiguous_verdict_rejected(self):
        path = self.raw / 'test_seahorse.log'
        path.write_text(path.read_text() * 2)
        with self.assertRaises(ValueError):
            verify_logs(self.raw)

    def test_all_original_s5_seeds(self):
        path = self.raw / 'test_obstacles.log'
        data = json.loads(path.read_text().splitlines()[-1])
        data['numbers']['obstacles']['seeds'] = SEEDS[:-1]
        path.write_text('Godot Engine v' + ENGINE + ' - fixture\n' + json.dumps(data))
        with self.assertRaises(ValueError):
            verify_logs(self.raw)

    def test_all_s5_configurations(self):
        path = self.raw / 'test_obstacles.log'
        data = json.loads(path.read_text().splitlines()[-1])
        del data['numbers']['obstacles']['per_scene_decor']['shipwreck/max']
        path.write_text('Godot Engine v' + ENGINE + ' - fixture\n' + json.dumps(data))
        with self.assertRaises(ValueError):
            verify_logs(self.raw)

    def test_seed_coverage_in_each_configuration(self):
        path = self.raw / 'test_obstacles.log'
        data = json.loads(path.read_text().splitlines()[-1])
        del data['numbers']['obstacles']['per_scene_decor']['reef/min']['control_hesitation']['37']
        path.write_text('Godot Engine v' + ENGINE + ' - fixture\n' + json.dumps(data))
        with self.assertRaises(ValueError):
            verify_logs(self.raw)

    def test_actual_tree_identity(self):
        previous = pathlib.Path.cwd()
        os.chdir(self.raw)
        try:
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=Fixture',
                    '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false',
                    '-c', 'core.hooksPath=/dev/null', *args], text=True, stderr=subprocess.DEVNULL).strip()
            git('init', '-q')
            script = pathlib.Path('stream/scripts/world.gd')
            script.parent.mkdir(parents=True)
            script.write_text('original')
            git('add', '.')
            git('commit', '-qm', 'original')
            source = git('rev-parse', 'HEAD')
            docs = pathlib.Path('stream/docs/status.md')
            docs.parent.mkdir(parents=True)
            docs.write_text('new evidence')
            tool = pathlib.Path('stream/tools/cloud_motion_reuse.py')
            tool.parent.mkdir(parents=True)
            tool.write_text('# collector only')
            git('add', '.')
            git('commit', '-qm', 'evidence and collector')
            self.assertEqual(verify_tree(source), git('rev-parse', 'HEAD'))
            script.write_text('dirty changed motion')
            with self.assertRaises(subprocess.CalledProcessError):
                verify_tree(source)
            git('add', '.')
            git('commit', '-qm', 'changed motion')
            with self.assertRaises(subprocess.CalledProcessError):
                verify_tree(source)
            git('restore', '--source=' + source, '--', 'stream/scripts/world.gd')
            extra = pathlib.Path('stream/new-addon/changed.gd')
            extra.parent.mkdir(parents=True)
            extra.write_text('new executable code')
            git('add', '.')
            git('commit', '-qm', 'new executable path')
            with self.assertRaises(subprocess.CalledProcessError):
                verify_tree(source)
        finally:
            os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
