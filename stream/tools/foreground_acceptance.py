#!/usr/bin/env python3
"""Measure the packaged app; QA mode never writes the user's world."""
import datetime, hashlib, json, pathlib, statistics, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/performance-30m'
OUT.mkdir(exist_ok=True)
USER = pathlib.Path.home() / 'Library/Application Support/Godot/app_userdata/Stillwater Stream'
APP = ROOT / 'builds/Stillwater Stream.app'
EXE = str(APP / 'Contents/MacOS/Stillwater Stream')
def digest():
    p = USER / 'stream.world'
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
def write(name, data):
    tmp = OUT / (name + '.tmp')
    tmp.write_text(json.dumps(data, indent=2))
    tmp.replace(OUT / name)
def cpu_seconds(s):
    parts = s.split(':')
    return sum(float(v) * 60**i for i, v in enumerate(reversed(parts)))
before = digest()
started = datetime.datetime.now().astimezone().isoformat()
subprocess.run(['open', '-n', str(APP), '--args', '--', '--qa', '--duration=1860'], check=True)
pid = None
for _ in range(40):
    result = subprocess.run(['pgrep', '-f', '^' + EXE + '$|^' + EXE + ' '], capture_output=True, text=True)
    if result.stdout.strip():
        ids = result.stdout.split()
        if len(ids) != 1:
            raise RuntimeError('Ambiguous app process: ' + result.stdout)
        pid = int(ids[0]); break
    time.sleep(.25)
if pid is None:
    raise RuntimeError('App did not start')
print(json.dumps({'pid': pid, 'started': started, 'duration_seconds': 1860}), flush=True)
rows, thermal = [], []
begin = time.monotonic()
base_cpu = base_wall = None
last_cpu = last_wall = None
next_thermal = 0
def report(final=False):
    elapsed = time.monotonic() - begin
    qa = None
    for name in ['qa-progress.json'] if not final else ['qa-performance.json', 'qa-performance-hidden.json']:
        path = USER / name
        if path.exists() and path.stat().st_mtime >= start_epoch:
            try: qa = json.loads(path.read_text())
            except (ValueError, OSError): pass
    mean = 100 * (last_cpu - base_cpu) / (last_wall - base_wall) if base_wall is not None and last_wall > base_wall else None
    data = {'pid': pid, 'started': started, 'elapsed_seconds': elapsed, 'finished': final,
            'mean_cpu_percent_one_core': mean,
            'max_rss_mib': max((r['rss_mib'] for r in rows), default=0),
            'samples': rows, 'thermal_samples': thermal, 'qa': qa,
            'save_sha256_before': before, 'save_sha256_after': digest(), 'user_save_unchanged': before == digest()}
    if final:
        data['foreground_eligible'] = bool(qa and qa.get('foreground_30_minute_eligible'))
        data['cpu_below_15_percent'] = mean is not None and mean < 15
        data['memory_below_350_mb'] = data['max_rss_mib'] * 1048576 < 350000000
        data['thermal_nominal_throughout_samples'] = bool(thermal) and all(t.get('thermal_state') == 'nominal' for t in thermal)
        data['foreground_acceptance_passed'] = data['foreground_eligible'] and data['cpu_below_15_percent'] and data['memory_below_350_mb'] and data['user_save_unchanged']
    write('results.json', data)
    return data
start_epoch = time.time()
while time.monotonic() - begin < 1920:
    tick = time.monotonic()
    result = subprocess.run(['ps', '-o', '%cpu=,rss=,time=', '-p', str(pid)], capture_output=True, text=True)
    fields = result.stdout.split()
    if len(fields) != 3: break
    sec = tick - begin
    total_cpu = cpu_seconds(fields[2])
    rows.append({'second': round(sec,3), 'cpu_percent_ps': float(fields[0]), 'rss_mib': int(fields[1])/1024, 'cpu_seconds_total': total_cpu})
    if sec >= 5 and base_cpu is None:
        base_cpu, base_wall = total_cpu, tick
    last_cpu, last_wall = total_cpu, tick
    if sec >= next_thermal:
        result = subprocess.run([str(ROOT/'tools/thermal')], capture_output=True, text=True)
        try: thermal.append({'second': round(sec,3), **json.loads(result.stdout)})
        except ValueError: thermal.append({'second': round(sec,3), 'error': result.stderr})
        data = report()
        print(json.dumps({k:data[k] for k in ['elapsed_seconds','mean_cpu_percent_one_core','max_rss_mib','qa']}),flush=True)
        next_thermal += 30
    time.sleep(max(0, 1-(time.monotonic()-tick)))
data = report(final=True)
for name in ['qa-performance.json','qa-performance-hidden.json','qa-progress.json']:
    p=USER/name
    if p.exists() and p.stat().st_mtime >= start_epoch:
        (OUT/name).write_bytes(p.read_bytes())
print(json.dumps({k:v for k,v in data.items() if k not in ['samples','thermal_samples']}), flush=True)
