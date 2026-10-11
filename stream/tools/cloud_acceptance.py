#!/usr/bin/env python3
"""Collect and audit the complete 24-case live matrix at one GitHub revision."""
import argparse
import itertools
import json
import math
import pathlib
import re
import subprocess

from cloud_plan import APP_SCOPES, case_key, plan, resume_starts

ROOT = pathlib.Path(__file__).resolve().parents[1]
SEEDS = (42, 812, 240921)
CORE = '''test_world test_swimmers test_roaming test_lifecycle test_persist_qa
test_presentation test_frontend test_reef_animation test_natural_motion test_obstacles
test_stage_scenes test_long_run_chunks test_scene_data test_scene_switch test_save_v3
test_home_layout_restore test_home_geometry test_home_behaviors test_seahorse test_gramma
test_chromis_roost test_clownfish test_clownfish_contract test_departures test_frame_pacer
test_cast_transition test_decor_art test_new_fish_art test_mirror_turn'''.split()
ERRORS = re.compile(r'^ERROR:|SCRIPT ERROR|Parse Error|Failed loading resource', re.MULTILINE)
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


def log_path(root, row, index):
    folder = f"ecology-live-180d-{row['scene']}-{row['decor']}-feed-{row['feed']}-seed-{row['seed']}-chunk-{index}-log"
    return root / folder / f'long-run-chunk-{index}.log'


def log_problem(path, seed, chunk, final):
    """Empty when the log shows a clean start (RESUME from this chunk's day) and this chunk's completion."""
    try:
        text = path.read_text()
    except OSError:
        return 'missing log'
    if ERRORS.search(text):
        return 'engine error'
    if chunk['from_day'] and not re.search(rf"^RESUME seed {seed} from day {chunk['from_day']} \(", text, re.MULTILINE):
        return 'no matching RESUME line'
    done = r'^ACCEPTANCE PASS\s*$' if final else rf"^CHUNK seed {seed} days {chunk['from_day']}-{chunk['to_day']} of 180 saved to .+$"
    return '' if re.search(done, text, re.MULTILINE) else 'no completion marker'


def audit_resume(rows, raw, resume, failures):
    """Chunks to each case's start day come from the earlier run, the rest from this one; none twice."""
    prior = resume['run']
    if prior.get('headSha') != resume['sha']:
        failures.append('Resume source run head SHA does not match the pinned revision')
    if not resume['app_identical']:
        failures.append('Application tree differs between the resume source and this run')
    if not any(j.get('name') == 'core tests' and j.get('conclusion') == 'success' for j in prior.get('jobs', [])):
        failures.append('Resume source run has no successful core tests job')
    expected, count = set(), 0
    for row in rows:
        key, start = case_key(row), resume['starts'].get(case_key(row))
        old = [c for c in row['chunks'] if start is not None and c['to_day'] <= start]
        new = row['chunks'][len(old):]
        if (not old or not new or old[-1]['to_day'] != start or new[0]['from_day'] != start
                or any(c['from_day'] != 18*i or c['to_day'] != 18*i+18 for i, c in enumerate(old))):
            failures.append(f'{key}: chunks do not split into 18-day prior chunks ending at start day {start}')
            continue
        for root, chunks in [(resume['raw'], old), (raw, new)]:
            for index, chunk in enumerate(chunks, 1):
                path = log_path(root, row, index)
                problem = log_problem(path, row['seed'], chunk, chunk['to_day'] == 180)
                if root is raw:
                    expected.add(path.parent.name)
                if problem:
                    failures.append(f'{path.parent.name}: {problem}')
                else:
                    count += 1
    for path in sorted(raw.rglob('long-run-chunk-*.log')):
        if path.parent.name not in expected:
            failures.append(f'{path.parent.name}: unexpected log')
    return count


def audit(run, raw, sha, resume=None):
    """resume (optional) = run/raw/sha of the earlier run, starts {case key: day}, app_identical."""
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
    verified_logs = audit_resume(rows, raw, resume, failures) if resume else 0
    core = {}
    for name in CORE:
        logs = list((resume['raw'] if resume else raw).rglob(name + '.log'))
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
            'expected_cases': len(expected), 'verified_cases': len(rows), 'verified_logs': verified_logs, 'core': core,
            'rows': rows, 'failures': failures, 'passed': not failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-id', required=True, type=int)
    parser.add_argument('--sha', required=True, help='exact40-character candidate commit')
    parser.add_argument('--repo', default='ianlin0430/stillwater')
    parser.add_argument('--skip-download', action='store_true', help='audit artifacts already collected for this run')
    parser.add_argument('--resume-run-id', type=int, help='earlier run whose chunks and core tests this run continues')
    parser.add_argument('--resume-sha', help='exact40-character revision of that earlier run')
    parser.add_argument('--resume-start', type=int, help='default start day of this run, as dispatched')
    parser.add_argument('--resume-overrides', default='', help='scene/decor/feed/seed=day list, as dispatched')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.sha):
        parser.error('sha must be a full commit SHA')
    if args.resume_run_id and not (args.resume_start and re.fullmatch(r'[0-9a-f]{40}', args.resume_sha or '')):
        parser.error('--resume-run-id needs --resume-start and a full --resume-sha')
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
    resume = None
    if args.resume_run_id:
        out_prior = ROOT / 'artifacts/completion/cloud' / str(args.resume_run_id)
        prior_raw = out_prior / 'raw'
        prior = json.loads(subprocess.check_output(['gh', 'run', 'view', str(args.resume_run_id), '--repo', args.repo,
                                                    '--json', 'databaseId,headSha,status,conclusion,url,jobs'], text=True))
        if not args.skip_download:
            subprocess.run(['gh', 'run', 'download', str(args.resume_run_id), '--repo', args.repo, '--dir', str(prior_raw),
                            '--pattern', 'ecology-live-180d-*-log', '--pattern', 'ecology-core-tests'], check=True)
        resume = {'run': prior, 'raw': prior_raw, 'sha': args.resume_sha, 'app_identical': subprocess.run(
            ['git', 'diff', '--quiet', args.resume_sha, args.sha, '--', *APP_SCOPES], cwd=ROOT.parent).returncode == 0,
            'starts': resume_starts(plan(180, list(SEEDS), broad=True)['cases'], args.resume_start,
                                    args.resume_overrides, 180)}
    result = audit(run, raw, args.sha, resume)
    (out / 'acceptance.json').write_text(json.dumps(result, indent=2))
    print(json.dumps({k: v for k, v in result.items() if k not in ['rows', 'core']}))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
