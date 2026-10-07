"""Bound hosted jobs while preserving every requested simulation day and case."""
import itertools
import json
import os


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


def main():
    result = plan(int(os.environ['RUN_DAYS']), [int(s) for s in os.environ['RUN_SEEDS'].split(',')],
                  os.environ['RUN_SCENE'], os.environ['RUN_DECOR'], os.environ['RUN_FEED'],
                  os.environ['RUN_MATRIX'] == 'true', os.environ.get('RUN_MODE', 'live'),
                  os.environ.get('RUN_YEAR', 'false') == 'true')
    with open(os.environ['GITHUB_OUTPUT'], 'a') as out:
        out.write('cases='+json.dumps(result['cases'], separators=(',', ':'))+'\n')
        out.write('chunks='+str(result['chunks'])+'\n')
        for i in range(result['chunks']):
            out.write(f'from{i+1}={result["bounds"][i]}\nto{i+1}={result["bounds"][i+1]}\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
