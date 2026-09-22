#!/usr/bin/env python3
"""Read-only process sampling. CPU percentage uses one logical core = 100%."""
import argparse, json, pathlib, subprocess, time
p=argparse.ArgumentParser();p.add_argument('pid',type=int);p.add_argument('--seconds',type=int,default=30);p.add_argument('--out',required=True);a=p.parse_args()
rows=[]
for i in range(a.seconds):
    r=subprocess.run(['ps','-o','%cpu=,rss=','-p',str(a.pid)],capture_output=True,text=True)
    fields=r.stdout.split()
    if len(fields)!=2: break
    rows.append({'second':i,'cpu_percent_one_core':float(fields[0]),'rss_mb':int(fields[1])/1024})
    time.sleep(1)
pathlib.Path(a.out).write_text(json.dumps({'samples':rows,'mean_cpu':sum(r['cpu_percent_one_core'] for r in rows)/max(1,len(rows)),'max_rss_mb':max((r['rss_mb'] for r in rows),default=0)},indent=2))
