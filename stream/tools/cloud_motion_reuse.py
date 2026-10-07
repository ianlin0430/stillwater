#!/usr/bin/env python3
"""Reuse complete motion evidence only for identical app/test/workflow trees.

Runs in cloud CI. Does not execute downloaded content or run a simulation.
The core suite still requires all29 logs; only these four proved suites may
avoid duplicate execution. Every other core suite runs normally.
"""
import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import tempfile

SUITES = {'test_natural_motion': 78, 'test_seahorse': 90,
          'test_obstacles': 20, 'test_decor_art': 75}
SEEDS = [42, 812, 240921, 1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
SCOPES = ['stream', ':(exclude)stream/docs', ':(exclude)stream/README.md',
          ':(exclude)stream/DESIGN.md', ':(exclude)stream/PRODUCT.md',
          ':(exclude)stream/tools/cloud_motion_reuse.py',
          ':(exclude)stream/tools/test_cloud_motion_reuse.py',
          '.github/workflows/motion-diagnostic.yml']
ENGINE = '4.6.3.stable.official.7d41c59c4'
STEPS = {'Complete natural motion, seahorse and decor gates',
         'Complete original 16-seed obstacle gate'}
ERRORS = re.compile(r'^ERROR:|SCRIPT ERROR|Parse Error|Failed loading resource', re.M)


def verify_run(run, jobs, repo):
    if (run.get('status') != 'completed' or run.get('conclusion') != 'success'
            or run.get('event') != 'workflow_dispatch'
            or run.get('path') != '.github/workflows/ecology-batch.yml'
            or run.get('head_repository', {}).get('full_name') != repo):
        raise ValueError('source is not a successful dispatch in the expected repository/workflow')
    sha = run.get('head_sha', '')
    if not re.fullmatch(r'[a-f0-9]{40}', sha):
        raise ValueError('invalid source revision')
    matches = [j for j in jobs if STEPS <= {s.get('name') for s in j.get('steps', [])}]
    if len(matches) != 1 or matches[0].get('conclusion') != 'success':
        raise ValueError('missing unique successful complete motion job')
    for name in STEPS:
        steps = [s for s in matches[0]['steps'] if s.get('name') == name]
        if len(steps) != 1 or steps[0].get('status') != 'completed' or steps[0].get('conclusion') != 'success':
            raise ValueError('complete motion group or full S5 was skipped/failed')
    return sha


def verify_logs(raw, engine=ENGINE):
    rows = {}
    for suite, checks in SUITES.items():
        logs = list(raw.rglob(suite + '.log'))
        if len(logs) != 1:
            raise ValueError(f'{suite}: missing/duplicate log')
        log = logs[0]
        text = log.read_text()
        if not text.startswith('Godot Engine v' + engine + ' - '):
            raise ValueError(f'{suite}: engine build differs from the current runner')
        if log.with_suffix('.exit').read_text().strip() != '0' or ERRORS.search(text):
            raise ValueError(f'{suite}: nonzero exit or engine error')
        verdicts = [json.loads(line) for line in text.splitlines()
                    if line.startswith('{') and '"failures"' in line]
        if len(verdicts) != 1:
            raise ValueError(f'{suite}: missing/ambiguous verdict')
        verdict = verdicts[0]
        if type(verdict.get('checks')) is not int or verdict['checks'] != checks or verdict.get('failures') != []:
            raise ValueError(f'{suite}: incomplete/failed gate')
        if suite == 'test_obstacles':
            numbers = verdict['numbers']['obstacles']
            if numbers.get('seeds') != SEEDS or any(type(s) is not int for s in numbers['seeds']):
                raise ValueError('S5 does not cover the original16 seeds')
            configs = numbers.get('per_scene_decor', {})
            if set(configs) != {'reef/min', 'reef/max', 'shipwreck/min', 'shipwreck/max'}:
                raise ValueError('S5 does not cover all four scene/decor combinations')
            for row in configs.values():
                for key in ['hesitation', 'control_hesitation']:
                    if set(row.get(key, {})) != set(map(str, SEEDS)):
                        raise ValueError('S5 configuration lacks original seed coverage')
        rows[suite] = {'checks': checks, 'sha256': hashlib.sha256(log.read_bytes()).hexdigest(),
                       'path': str(log), 'exit': 0}
    return rows


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def verify_tree(source):
    current = command('git', 'rev-parse', 'HEAD')
    if subprocess.run(['git', 'cat-file', '-e', source + '^{commit}'],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        subprocess.run(['git', 'fetch', '--no-tags', '--depth=1', 'origin', source], check=True)
    subprocess.run(['git', 'diff', '--quiet', source, current, '--', *SCOPES], check=True)
    # The checkout must also match that committed current tree.
    subprocess.run(['git', 'diff', '--quiet', 'HEAD', '--', *SCOPES], check=True)
    return current


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9]+', args.run) or not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repo):
        parser.error('run/repository must be a numeric run and owner/repository')
    run = json.loads(command('gh', 'api', f'repos/{args.repo}/actions/runs/{args.run}'))
    jobs = json.loads(command('gh', 'api', f'repos/{args.repo}/actions/runs/{args.run}/jobs?per_page=100'))
    source = verify_run(run, jobs['jobs'], args.repo)
    current = verify_tree(source)
    with tempfile.TemporaryDirectory(prefix='motion-reuse-') as temp:
        raw = pathlib.Path(temp)
        subprocess.run(['gh', 'run', 'download', args.run, '--repo', args.repo,
                        '-n', 'motion-regression-complete', '--dir', str(raw)], check=True)
        engine = command('godot', '--version')
        rows = verify_logs(raw, engine)
        args.output.mkdir(parents=True, exist_ok=True)
        for suite, row in rows.items():
            source_log = pathlib.Path(row.pop('path'))
            shutil.copyfile(source_log, args.output / (suite + '.log'))
        receipt = {'verified': True, 'source_run': args.run, 'source_sha': source,
                   'current_sha': current, 'engine': engine, 'identical_scopes': SCOPES, 'suites': rows}
        (args.output / 'motion-reuse-verified.json').write_text(json.dumps(receipt, indent=2) + '\n')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write('verified=true\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
