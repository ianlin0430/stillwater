#!/usr/bin/env python3
"""Serial composite navigation gate. No thresholds or test implementations here.
Run: python3 stream/tools/nav_gate.py --label baseline
Natural motion uses seeds 42,11; guard uses all four scene/decor parts on
23,240921,2,29,37,17; S6 uses 42,240921. Full suites remain mandatory later.
Engine logs and HOME are confined to ignored stream/artifacts/nav-redesign.
"""
import argparse, json, os, pathlib, subprocess, sys, time
parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
a = parser.parse_args()
if not a.label.replace('-', '').replace('_', '').isalnum():
    parser.error('label must be alphanumeric with - or _')
def encode(value, **kwargs):
    # Preserve Godot's valid overflow exponent for an infinite failure sentinel.
    # Python's default Infinity token is not JSON syntax.
    return json.dumps(value, **kwargs).replace('Infinity', '1e99999')
root = pathlib.Path(__file__).resolve().parents[2]
out = root / 'stream/artifacts/nav-redesign' / a.label
out.mkdir(parents=True, exist_ok=True)
home = out / 'home'
home.mkdir(exist_ok=True)
env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(home), XDG_CONFIG_HOME=str(home), XDG_CACHE_HOME=str(home))
parts = [
 ('natural', 'tools/nav_gate_natural.gd', []),
 ('world_home', 'tools/nav_gate_world.gd', []),
 ('guard', 'tests/test_obstacles.gd', ['--seeds=23,240921,2,29,37,17']),
 ('clownfish', 'tests/test_clownfish.gd', ['--seeds=42,240921']),
 ('contract', 'tests/test_clownfish_contract.gd', []),
]
results = {}
started = time.monotonic()
for name, script, args in parts:
    print('START '+name, flush=True)
    cmd = ['timeout', '900', '/opt/homebrew/bin/godot', '--headless', '--path', str(root/'stream'), '--log-file', str(out/(name+'-engine.log')), '--script', script]
    if args: cmd += ['--'] + args
    t = time.monotonic()
    with (out/(name+'.log')).open('w') as log:
        proc = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, env=env)
    # The LAST JSON line with failures is the verdict, even if the engine exits zero.
    result = None
    for line in (out/(name+'.log')).read_text().splitlines():
        try: value = json.loads(line)
        except json.JSONDecodeError: continue
        if isinstance(value, dict) and 'failures' in value: result = value
    if result is None:
        result = {'failures':['Missing final JSON verdict'], 'exit_code':proc.returncode}
    elif proc.returncode not in (0,1):
        result['failures'].append('Engine exit '+str(proc.returncode))
    result['wall_seconds'] = round(time.monotonic()-t, 2)
    results[name] = result
    print('DONE '+name+' '+encode({'checks':result.get('checks'), 'failures':result['failures'], 'seconds':result['wall_seconds']}), flush=True)
    (out/'result.json').write_text(encode(results, indent=2))
failures = [name+': '+f for name,r in results.items() for f in r['failures']]
print(encode({'failures':failures, 'parts':results, 'wall_seconds':round(time.monotonic()-started,2)}), flush=True)
sys.exit(bool(failures))
