#!/usr/bin/env python3
"""Serial full-suite validation, preserving original arguments and verdicts.
Run named parts with --parts=natural,world,...; all engine writes stay in artifacts.
The composite remains the only candidate selection gate.
"""
import argparse, json, os, pathlib, subprocess, sys, time
parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
parser.add_argument('--parts', required=True)
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
available = {
 'natural': ('tests/test_natural_motion.gd', []),
 'world': ('tests/test_world.gd', []),
 'guard6': ('tests/test_obstacles.gd', ['--seeds=23,240921,2,29,37,17']),
 'guard16': ('tests/test_obstacles.gd', []),
 'clownfish': ('tests/test_clownfish.gd', []),
 'contract': ('tests/test_clownfish_contract.gd', []),
 'save_v3': ('tests/test_save_v3.gd', []),
 'scene_data': ('tests/test_scene_data.gd', []),
 'long_run_chunks': ('tests/test_long_run_chunks.gd', []),
 'frontend': ('tests/test_frontend.gd', []),
 'bench': ('tools/motion_tick_bench.gd', []),
}
names = a.parts.split(',')
if any(name not in available for name in names):
    parser.error('unknown part')
parts = [(name, *available[name]) for name in names]
results = {}
started = time.monotonic()
for name, script, args in parts:
    print('START '+name, flush=True)
    cmd = ['timeout', '1500', '/opt/homebrew/bin/godot', '--headless', '--path', str(root/'stream'), '--log-file', str(out/(name+'-engine.log')), '--script', script]
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
        elif name == 'bench' and isinstance(value, dict) and 'repeatable' in value:
            result = dict(value, failures=[] if value['repeatable'] else ['Benchmark repeatability failed'])
    engine_errors = [line for line in (out/(name+'.log')).read_text().splitlines() if 'SCRIPT ERROR' in line or 'Parse Error' in line]
    if result is None:
        result = {'failures':['Missing final JSON verdict'], 'exit_code':proc.returncode}
    elif proc.returncode not in (0,1):
        result['failures'].append('Engine exit '+str(proc.returncode))
    if engine_errors:
        result['failures'].extend(engine_errors)
    result['wall_seconds'] = round(time.monotonic()-t, 2)
    results[name] = result
    print('DONE '+name+' '+encode({'checks':result.get('checks'), 'failures':result['failures'], 'seconds':result['wall_seconds']}), flush=True)
    (out/'result.json').write_text(encode(results, indent=2))
failures = [name+': '+f for name,r in results.items() for f in r['failures']]
print(encode({'failures':failures, 'parts':results, 'wall_seconds':round(time.monotonic()-started,2)}), flush=True)
sys.exit(bool(failures))
