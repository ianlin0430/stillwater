#!/usr/bin/env python3
"""Serial composite navigation gate. No thresholds or test implementations here.
Run: python3 stream/tools/nav_gate.py --label baseline
Natural motion keeps seeds 42,11 and adds the original eight-seed obstacle
checks. Guard keeps the original six on all four scene/decor parts and kinks.
Only the eight known failing scene/decor/seed cases are added; S6 uses
42,240921. Full suites remain mandatory.
Engine logs and HOME are confined to ignored stream/artifacts/nav-redesign.
"""
import argparse, hashlib, json, os, pathlib, subprocess, sys, time
parser = argparse.ArgumentParser()
parser.add_argument('--label', required=True)
parser.add_argument('--parts', help='Optional comma-separated parts for a serial diagnostic rerun')
parser.add_argument('--remaining-only', action='store_true', help='Diagnostic six reef hesitation cases; all original assertions remain')
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
 ('natural_obstacles', 'tools/nav_gate_natural_obstacles.gd', []),
 ('world_home', 'tools/nav_gate_world.gd', []),
 ('guard6', 'tests/test_obstacles.gd', ['--seeds=23,240921,2,29,37,17']),
 ('targeted_guard', str(out.relative_to(root/'stream')/'targeted_obstacles.gd'), ['--parts=obstacles']),
 ('clownfish', 'tests/test_clownfish.gd', ['--seeds=42,240921']),
 ('contract', 'tests/test_clownfish_contract.gd', []),
]
# Reuse the real obstacle_checks implementation and its entire assertion block.
# Only its seed traversal changes: eight cases, rather than their Cartesian product.
# Keeping those cases in one assertion pass preserves the original global detour
# and jerk measures; running reef-only parts cannot meet the global detour sample.
source = (root/'stream/tests/test_obstacles.gd').read_text()
method = source.split('func obstacle_checks() -> void:\n', 1)[1].split('\nfunc kink_checks()', 1)[0]
# Exclude the following method's comments; no assertion or threshold is replaced.
method = method[:method.rfind('\n# test_natural_motion')]
old = '\tvar seeds: Array=seed_list()'
cases = {'reef/min':[812,5,11,19,31], 'reef/max':[11]}
if not a.remaining_only:
    cases.update({'shipwreck/min':[5], 'shipwreck/max':[3]})
new = '\tvar cases: Dictionary='+json.dumps(cases)+'\n\tvar seeds: Array='+json.dumps(list(dict.fromkeys(seed for seeds in cases.values() for seed in seeds)))
assert method.count(old) == 1 and method.count('for seed_value: int in seeds:') == 1
method = method.replace(old, new).replace('for seed_value: int in seeds:', 'for seed_value: int in cases[tag]:')
(out/'targeted_obstacles.gd').write_text('extends "res://tests/test_obstacles.gd"\n# Generated from the real test; only case traversal is selected.\nfunc obstacle_checks() -> void:\n'+method+'\n')
if a.remaining_only:
    parts = [(name, script, args+['--scenes=reef']) for name, script, args in parts if name=='targeted_guard']
if a.parts:
    requested = a.parts.split(',')
    if any(name not in [p[0] for p in parts] for name in requested):
        parser.error('unknown part')
    parts = [p for p in parts if p[0] in requested]
def source_fingerprint():
    digest = hashlib.sha256()
    paths = [root/'stream/project.godot']
    for directory in ['scripts', 'tests', 'data']:
        paths += [p for p in (root/'stream'/directory).rglob('*')
                  if p.is_file() and p.suffix in {'.gd', '.gdshader', '.json'}]
    for path in sorted(paths):
        digest.update(str(path.relative_to(root/'stream')).encode())
        digest.update(b'\0')
        digest.update(path.read_bytes())
        digest.update(b'\0')
    return digest.hexdigest()

# Sequential subprocesses must judge one source revision. A mid-run edit must
# never produce a composite green verdict from different controllers.
fingerprint = source_fingerprint()
results = {}
started = time.monotonic()
for name, script, args in parts:
    if source_fingerprint() != fingerprint:
        results[name] = {'checks':0, 'failures':['Source changed between gate parts; rerun on a frozen revision'],
                         'source_sha256':fingerprint}
        (out/'result.json').write_text(encode(results, indent=2))
        break
    print('START '+name, flush=True)
    cmd = ['timeout', '-s', 'KILL', '1500', '/opt/homebrew/bin/godot', '--headless', '--path', str(root/'stream'), '--log-file', str(out/(name+'-engine.log')), '--script', script]
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
    engine_errors = [line for line in (out/(name+'.log')).read_text().splitlines() if 'SCRIPT ERROR' in line or 'Parse Error' in line]
    if result is None:
        result = {'failures':['Missing final JSON verdict'], 'exit_code':proc.returncode}
    elif proc.returncode not in (0,1):
        result['failures'].append('Engine exit '+str(proc.returncode))
    if engine_errors:
        result['failures'].extend(engine_errors)
    result['source_sha256'] = fingerprint
    source_changed = source_fingerprint() != fingerprint
    if source_changed:
        result['failures'].append('Source changed during gate part; rerun on a frozen revision')
    result['wall_seconds'] = round(time.monotonic()-t, 2)
    results[name] = result
    print('DONE '+name+' '+encode({'checks':result.get('checks'), 'failures':result['failures'], 'seconds':result['wall_seconds']}), flush=True)
    (out/'result.json').write_text(encode(results, indent=2))
    if source_changed:
        break
failures = [name+': '+f for name,r in results.items() for f in r['failures']]
print(encode({'failures':failures, 'parts':results, 'wall_seconds':round(time.monotonic()-started,2)}), flush=True)
sys.exit(bool(failures))
