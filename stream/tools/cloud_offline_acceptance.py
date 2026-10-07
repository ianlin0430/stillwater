#!/usr/bin/env python3
"""Audit the original32 offline seeds and one fixed365-day stability pass."""
import argparse
import json
import re
import subprocess
from cloud_acceptance import ROOT, FLAGS, ERRORS, complete_chunks

SEEDS=(42,812,240921,1,2,3,5,7,11,13,17,19,23,29,31,37,101,202,303,404,
       505,606,707,808,909,1234,4321,9999,31337,65537,123456,999983)
YEAR_FLAGS={'species_persist','starvation','conservation','valid'}
LOG_DIR=re.compile(r'ecology-offline-180d-reef-default-feed-none-seed-(\d+)-chunk-(\d+)-log')

def flags_pass(value, expected):
    return isinstance(value,dict) and set(value)==expected and all(v is True for v in value.values())

def audit(run, raw, sha):
    failures, rows, years=[],[],[]
    if run.get('headSha')!=sha:
        failures.append('GitHub head SHA does not match requested revision')
    if run.get('status')!='completed' or run.get('conclusion')!='success':
        failures.append('Workflow is not completed successfully')
    seen=set()
    for path in sorted(raw.rglob('ci-offline-180d-*.json')):
        try:
            report=json.loads(path.read_text())
            if not isinstance(report,dict) or report.get('failures')!=[]:
                raise ValueError('missing successful report')
            runs=report.get('runs')
            if not isinstance(runs,list) or len(runs)!=1 or not isinstance(runs[0],dict):
                raise ValueError('missing single run')
            row=runs[0]
            seed=row.get('seed')
            if type(seed) is not int or seed not in SEEDS or seed in seen:
                raise ValueError('unexpected or duplicate seed')
            for k,v in {'mode':'offline','scene':'reef','decor':'default','feed':'none'}.items():
                if report.get(k)!=v or row.get(k)!=v:
                    raise ValueError('configuration mismatch: '+k)
            if report.get('days_per_seed')!=180 or row.get('days')!=180:
                raise ValueError('not a complete180-day run')
            if not flags_pass(row.get('acceptance'),FLAGS):
                raise ValueError('acceptance flag missing or failed')
            if not complete_chunks(row.get('chunks')):
                raise ValueError('invalid checkpoint coverage')
            year=report.get('stability_365')
            if 'stability_365' in report:
                if not isinstance(year,dict) or year.get('seed')!=240921 or year.get('days')!=365:
                    raise ValueError('incorrect365-day case')
                if any(year.get(k)!=v for k,v in {'mode':'offline','feed':'none','scene':'reef','decor':'default'}.items()):
                    raise ValueError('incorrect365-day configuration')
                if not flags_pass(year.get('acceptance'),YEAR_FLAGS):
                    raise ValueError('365-day acceptance missing or failed')
                years.append(year)
            seen.add(seed)
            rows.append(row)
        except (OSError,ValueError,KeyError,TypeError) as error:
            failures.append(f'{path.name}: {error}')
    missing=set(SEEDS)-seen
    if missing:
        failures.append(f'Missing {len(missing)} original seeds: {sorted(missing)}')
    if len(years)!=1:
        failures.append(f'Expected one fixed365-day pass, found {len(years)}')
    expected_logs={(seed,index) for seed in SEEDS for index in [1,2,3]}
    seen_logs=set()
    for path in sorted(raw.rglob('long-run-chunk-*.log')):
        match=LOG_DIR.fullmatch(path.parent.name)
        key=tuple(map(int,match.groups())) if match else None
        if key not in expected_logs or key in seen_logs or path.name!=f'long-run-chunk-{key[1]}.log':
            failures.append(f'{path}: unexpected or duplicate log')
            continue
        content=path.read_text()
        if key[1]==3:
            completed=re.search(r'^ACCEPTANCE PASS\s*$',content,re.MULTILINE)
        else:
            completed=re.search(rf'^CHUNK seed {key[0]} days {(key[1]-1)*60}-{key[1]*60} of 180 saved to .+$',content,re.MULTILINE)
        if ERRORS.search(content) or not completed:
            failures.append(f'{path.parent.name}: engine error or missing final verdict')
            continue
        seen_logs.add(key)
    if expected_logs-seen_logs:
        failures.append(f'Missing {len(expected_logs-seen_logs)} successful chunk logs')
    return {'run_id':run.get('databaseId'),'url':run.get('url'),'sha':sha,
            'workflow_status':run.get('status'),'workflow_conclusion':run.get('conclusion'),
            'expected_cases':32,'verified_cases':len(rows),'verified_logs':len(seen_logs),
            'stability_passes':len(years),'rows':rows,'stability_365':years[0] if len(years)==1 else None,
            'failures':failures,'passed':not failures}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-id',type=int,required=True)
    parser.add_argument('--sha',required=True)
    parser.add_argument('--repo',default='ianlin0430/stillwater')
    parser.add_argument('--skip-download',action='store_true')
    args=parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}',args.sha):
        parser.error('sha must be a full commit SHA')
    out=ROOT/'artifacts/completion/cloud'/str(args.run_id)
    out.mkdir(parents=True,exist_ok=True)
    receipt=out/'offline-acceptance.json'
    receipt.write_text(json.dumps({'passed':False,'sha':args.sha,'reason':'collection not completed'}))
    run=json.loads(subprocess.check_output(['gh','run','view',str(args.run_id),'--repo',args.repo,
        '--json','databaseId,headSha,status,conclusion,url,jobs'],text=True))
    (out/'run.json').write_text(json.dumps(run,indent=2))
    if run['headSha']!=args.sha or run['status']!='completed':
        print(json.dumps({'run_id':args.run_id,'status':run['status'],'verified':False}))
        return 2
    raw=out/'raw'
    if not args.skip_download:
        subprocess.run(['gh','run','download',str(args.run_id),'--repo',args.repo,'--dir',str(raw),
                        '--pattern','ecology-offline-180d-*'],check=True)
    result=audit(run,raw,args.sha)
    receipt.write_text(json.dumps(result,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k not in ('rows','stability_365')}))
    return 0 if result['passed'] else 1

if __name__=='__main__':
    raise SystemExit(main())
