#!/usr/bin/env python3
"""Collect and audit the complete 24-case live matrix at one GitHub revision."""
import argparse
import itertools
import json
import math
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
SEEDS = (42, 812, 240921)
CORE = '''test_world test_swimmers test_roaming test_lifecycle test_persist_qa
test_presentation test_frontend test_reef_animation test_natural_motion test_obstacles
test_stage_scenes test_long_run_chunks test_scene_data test_scene_switch test_save_v3
test_home_layout_restore test_home_geometry test_home_behaviors test_seahorse test_gramma
test_chromis_roost test_clownfish test_clownfish_contract test_departures test_frame_pacer
test_cast_transition test_decor_art test_new_fish_art test_mirror_turn'''.split()
ERRORS = re.compile(r'SCRIPT ERROR|Parse Error|Failed loading resource')
FLAGS = set('reproduction local_replacement old_age starvation predation population presence no_departures conservation plants valid depth_bands'.split())


def complete_chunks(chunks):
    """Reject gaps, overlaps, reordering and fake timing at any checkpoint size."""
    if not isinstance(chunks, list) or not chunks:
        return False
    end = 0
    for chunk in chunks:
        if not isinstance(chunk, dict):
            return False
        start, stop, seconds = (chunk.get(k) for k in ['from_day', 'to_day', 'seconds'])
        if type(start) is not int or type(stop) is not int or start != end or not start < stop <= 180:
            return False
        if type(seconds) not in (int, float) or not math.isfinite(seconds) or seconds <= 0:
            return False
        end = stop
    return end == 180


def audit(run, raw, sha):
    failures, rows = [], []
    if run.get('headSha') != sha:
        failures.append('GitHub head SHA does not match the requested revision')
    if run.get('status') != 'completed' or run.get('conclusion') != 'success':
        failures.append('Workflow is not completed successfully')
    expected = set(itertools.product(SEEDS, ['reef', 'shipwreck'], ['min', 'max'], ['none', 'daily']))
    seen = set()
    for path in sorted(raw.rglob('ci-live-180d-*.json')):
        try:
            report = json.loads(path.read_text())
            runs = report['runs']
            if len(runs) != 1 or report.get('failures') != []:
                raise ValueError('missing single successful run')
            row = runs[0]
            key = (row['seed'], row['scene'], row['decor'], row['feed'])
            if key not in expected or key in seen:
                raise ValueError('unexpected or duplicate scene/decor/feed/seed')
            seen.add(key)
            if report.get('mode') != 'live' or report.get('days_per_seed') != 180 or row.get('mode') != 'live' or row.get('days') != 180:
                raise ValueError('not a complete live180-day run')
            if any(report.get(k) != row[k] for k in ['scene', 'decor', 'feed']):
                raise ValueError('report/run configuration mismatch')
            if set(row.get('acceptance', {})) != FLAGS or any(flag is not True for flag in row['acceptance'].values()):
                raise ValueError('acceptance flag missing or failed')
            chunks = row.get('chunks', [])
            if not complete_chunks(chunks):
                raise ValueError('missing or invalid complete checkpoint coverage')
            rows.append({k: row[k] for k in ['seed', 'scene', 'decor', 'feed', 'days', 'chunks',
                                            'acceptance', 'max_population', 'max_material_residual',
                                            'starvation', 'longest_absence', 'depth']})
        except (OSError, ValueError, KeyError, TypeError) as error:
            failures.append(f'{path.name}: {error}')
    missing = expected - seen
    if missing:
        failures.append(f'Missing {len(missing)} cases: {sorted(missing)}')
    core = {}
    for name in CORE:
        logs = list(raw.rglob(name + '.log'))
        if len(logs) != 1:
            failures.append(f'{name}: missing or duplicate core log')
            continue
        content = logs[0].read_text()
        verdicts = []
        for line in content.splitlines():
            try:
                value = json.loads(line)
                if isinstance(value, dict) and 'failures' in value:
                    verdicts.append(value)
            except ValueError:
                pass
        if not verdicts or verdicts[-1]['failures'] not in ([], 0) or ERRORS.search(content):
            failures.append(f'{name}: failed or missing final verdict, or engine error')
        else:
            core[name] = verdicts[-1].get('checks')
    return {'run_id': run.get('databaseId'), 'url': run.get('url'), 'sha': sha,
            'workflow_status': run.get('status'), 'workflow_conclusion': run.get('conclusion'),
            'expected_cases': len(expected), 'verified_cases': len(rows), 'core': core,
            'rows': rows, 'failures': failures, 'passed': not failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-id', required=True, type=int)
    parser.add_argument('--sha', required=True, help='exact40-character candidate commit')
    parser.add_argument('--repo', default='ianlin0430/stillwater')
    parser.add_argument('--skip-download', action='store_true', help='audit artifacts already collected for this run')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.sha):
        parser.error('sha must be a full commit SHA')
    out = ROOT / 'artifacts/completion/cloud' / str(args.run_id)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'acceptance.json').write_text(json.dumps({'passed': False, 'sha': args.sha,
                                                  'reason': 'collection not completed'}))
    run = json.loads(subprocess.check_output(['gh', 'run', 'view', str(args.run_id), '--repo', args.repo,
                                              '--json', 'databaseId,headSha,status,conclusion,url,jobs'], text=True))
    (out / 'run.json').write_text(json.dumps(run, indent=2))
    if run['headSha'] != args.sha or run['status'] != 'completed':
        print(json.dumps({'run_id': args.run_id, 'headSha': run['headSha'], 'status': run['status'],
                          'verified': False, 'reason': 'revision mismatch or workflow still running'}))
        return 2
    raw = out / 'raw'
    if not args.skip_download:
        subprocess.run(['gh', 'run', 'download', str(args.run_id), '--repo', args.repo, '--dir', str(raw),
                        '--pattern', 'ecology-live-180d-*', '--pattern', 'ecology-core-tests'], check=True)
    result = audit(run, raw, args.sha)
    (out / 'acceptance.json').write_text(json.dumps(result, indent=2))
    print(json.dumps({k: v for k, v in result.items() if k not in ['rows', 'core']}))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
