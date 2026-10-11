"""Bound hosted jobs while preserving every requested simulation day and case."""
import itertools
import json
import os
import re
import subprocess
import sys

SLOTS = 16
# Files that decide simulation results; docs, tools and CI plumbing may differ between revisions.
APP_SCOPES = ['stream', ':(exclude)stream/docs', ':(exclude)stream/tools', ':(exclude)stream/README.md',
              ':(exclude)stream/DESIGN.md', ':(exclude)stream/PRODUCT.md']


def plan(days, seeds, scene='reef', decor='default', feed='none', broad=False, mode='live', year=False):
    if type(days) is not int or days <= 0 or days % 3:
        raise ValueError('days must be a positive multiple of 3')
    if not seeds or any(type(s) is not int for s in seeds) or len(seeds) != len(set(seeds)):
        raise ValueError('seeds must be nonempty distinct integers')
    if scene not in ('reef', 'shipwreck') or decor not in ('default', 'min', 'max') or feed not in ('none', 'daily'):
        raise ValueError('unknown habitat or feeding configuration')
    if mode not in ('live', 'offline'):
        raise ValueError('unknown simulation mode')
    chunks = min(days, 10 if mode == 'live' else 3)
    cases = [dict(seed=s, scene=c, decor=d, feed=f) for s,c,d,f in itertools.product(
        seeds, ['reef', 'shipwreck'] if broad else [scene],
        ['min', 'max'] if broad else [decor], ['none', 'daily'] if broad else [feed])]
    if len(cases)*chunks+2 > 256:
        raise ValueError('case/chunk plan exceeds 256 hosted jobs; split the seed list')
    # long_run's stability pass always uses seed240921, independent of the case.
    # Exactly one final case executes it; every180-day case still runs in full.
    for index, case in enumerate(cases):
        case['year'] = bool(year and index == 0)
    return {'cases': cases, 'chunks': chunks,
            'bounds': [days*i//chunks for i in range(chunks+1)]}


def case_key(case):
    return '/'.join(str(case[k]) for k in ['scene', 'decor', 'feed', 'seed'])


def slot_plan(cases, bounds, run_id=''):
    """Per chunk slot, the cases that still have a chunk there, each with its own days.

    bounds is one list shared by every case, or a {case key: list} table when starts differ.
    Only slot 1 downloads from run_id; later slots read the current run's checkpoints."""
    table = bounds if isinstance(bounds, dict) else {case_key(c): bounds for c in cases}
    slots = []
    for index in range(max(len(b) for b in table.values()) - 1):
        slots.append([dict(c, from_day=table[case_key(c)][index], to_day=table[case_key(c)][index+1],
                           n=len(table[case_key(c)])-1, src=run_id if index == 0 else '')
                      for c in cases if index < len(table[case_key(c)])-1])
    return slots


def resume_starts(cases, start, overrides, days):
    """{case key: first day to simulate}: start for every case except the 'key=day' overrides."""
    table = {}
    for item in filter(None, (part.strip() for part in overrides.split(','))):
        key, equals, value = item.partition('=')
        if not equals or not value.isdigit():
            raise ValueError('resume overrides look like scene/decor/feed/seed=day: '+item)
        table[key] = int(value)
    unknown = set(table) - {case_key(c) for c in cases}
    if unknown:
        raise ValueError('resume override matches no case: '+', '.join(sorted(unknown)))
    if type(start) is not int:
        raise ValueError('resume start must be an integer day')
    starts = {case_key(c): table.get(case_key(c), start) for c in cases}
    for key, first in starts.items():
        if not 0 < first < days:
            raise ValueError(f'start day {first} must be inside 1..{days-1}: {key}')
    return starts


def resume_plan(days, seeds, chunk_days, start, overrides, run_id, scene='reef', decor='default',
                feed='none', broad=False):
    """Continue a live run from earlier checkpoints, each case at its own start day."""
    if type(chunk_days) is not int or chunk_days <= 0:
        raise ValueError('chunk_days must be a positive integer')
    if not re.fullmatch(r'[0-9]+', str(run_id)):
        raise ValueError('resume run must be a numeric workflow run id')
    base = plan(days, seeds, scene, decor, feed, broad, 'live', False)
    starts = resume_starts(base['cases'], start, overrides, days)
    bounds = {key: list(range(first, days, chunk_days))+[days] for key, first in starts.items()}
    slots = slot_plan(base['cases'], bounds, str(run_id))
    if len(slots) > SLOTS:
        raise ValueError(f'{len(slots)} chunk slots exceed the {SLOTS} the workflow provides')
    if any(len(slot) > 256 for slot in slots):
        raise ValueError('a chunk slot exceeds the 256 job matrix limit')
    return {'cases': base['cases'], 'chunks': len(slots), 'slots': slots, 'starts': starts}


def verify_source(run, artifacts, first_slot, days, sha):
    """Every case's start checkpoint must be one unexpired artifact of exactly this run and revision."""
    problems = []
    if run.get('head_sha') != sha:
        problems.append('source run revision is not '+sha)
    for case in first_slot:
        name = f"checkpoint-live-{days}d-{case['scene']}-{case['decor']}-feed-{case['feed']}-seed-{case['seed']}-day-{case['from_day']}"
        found = [a for a in artifacts if a.get('name') == name and not a.get('expired')]
        if len(found) != 1:
            problems.append(f'{name}: expected one unexpired artifact, found {len(found)}')
        elif found[0].get('workflow_run', {}).get('id') != run.get('id') \
                or found[0]['workflow_run'].get('head_sha') != sha:
            problems.append(f'{name}: artifact is not from the pinned run and revision')
    if problems:
        raise ValueError('; '.join(problems))


def verify(result, days):
    """Fail loudly unless the pinned source run still holds every checkpoint and matches this app tree."""
    run_id, sha = os.environ['RUN_RESUME_RUN'], os.environ.get('RUN_RESUME_SHA', '')
    if not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('resume_sha must be the full 40-character source revision')
    repo = os.environ['GITHUB_REPOSITORY']
    run = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repo}/actions/runs/{run_id}'], text=True))
    listing = subprocess.check_output(['gh', 'api', '--paginate', '--jq', '.artifacts[]',
                                       f'repos/{repo}/actions/runs/{run_id}/artifacts?per_page=100'], text=True)
    artifacts = [json.loads(line) for line in listing.splitlines()]
    verify_source(run, artifacts, result['slots'][0], days, sha)
    if subprocess.run(['git', 'cat-file', '-e', sha+'^{commit}'], capture_output=True).returncode:
        subprocess.run(['git', 'fetch', '--no-tags', '--depth=1', 'origin', sha], check=True)
    if subprocess.run(['git', 'diff', '--quiet', sha, 'HEAD', '--', *APP_SCOPES]).returncode:
        raise ValueError('application tree differs from the source run revision '+sha)


def build():
    days, seeds = int(os.environ['RUN_DAYS']), [int(s) for s in os.environ['RUN_SEEDS'].split(',')]
    flags = (os.environ['RUN_SCENE'], os.environ['RUN_DECOR'], os.environ['RUN_FEED'],
             os.environ['RUN_MATRIX'] == 'true')
    if os.environ.get('RUN_RESUME_RUN'):
        if os.environ.get('RUN_MODE', 'live') != 'live':
            raise ValueError('only live runs can resume')
        return resume_plan(days, seeds, int(os.environ['RUN_RESUME_CHUNK']), int(os.environ['RUN_RESUME_START']),
                           os.environ.get('RUN_RESUME_OVERRIDES', ''), os.environ['RUN_RESUME_RUN'], *flags)
    result = plan(days, seeds, *flags[:3], flags[3], os.environ.get('RUN_MODE', 'live'),
                  os.environ.get('RUN_YEAR', 'false') == 'true')
    result['slots'] = slot_plan(result['cases'], result['bounds'])
    return result


def main():
    result = build()
    if '--verify' in sys.argv and os.environ.get('RUN_RESUME_RUN'):
        verify(result, int(os.environ['RUN_DAYS']))
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as out:
            out.write('chunks='+str(result['chunks'])+'\n')
            for i, slot in enumerate(result['slots']):
                out.write(f'cases{i+1}='+json.dumps(slot, separators=(',', ':'))+'\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
