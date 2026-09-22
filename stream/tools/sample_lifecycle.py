#!/usr/bin/env python3
import argparse,json,pathlib,subprocess,time,hashlib
p=argparse.ArgumentParser();p.add_argument('pid');p.add_argument('phase');p.add_argument('--seconds',type=int,default=130);a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];out=root/'artifacts/lifecycle';user=pathlib.Path.home()/'Library/Application Support/Godot/app_userdata/Stillwater Stream';rows=[];start=time.monotonic()
def digest():return hashlib.sha256((user/'stream.world').read_bytes()).hexdigest()
before=digest()
for i in range(a.seconds):
 fields=subprocess.run(['ps','-o','%cpu=,rss=,time=','-p',a.pid],capture_output=True,text=True).stdout.split()
 if len(fields)!=3:break
 cpu=sum(float(n)*60**j for j,n in enumerate(reversed(fields[2].split(':'))))
 try:qa=json.loads((user/'qa-progress.json').read_text())
 except (ValueError,FileNotFoundError):qa={}
 rows.append({'seconds':time.monotonic()-start,'cpu_seconds':cpu,'rss_mib':int(fields[1])/1024,'qa':qa})
 (out/(a.phase+'-progress.json')).write_text(json.dumps(rows[-1]))
 time.sleep(1)
mean=(rows[-1]['cpu_seconds']-rows[0]['cpu_seconds'])/(rows[-1]['seconds']-rows[0]['seconds'])*100 if len(rows)>1 else None
result={'phase':a.phase,'samples':rows,'mean_cpu_percent_one_core':mean,'peak_rss_mib':max((r['rss_mib'] for r in rows),default=0),'save_unchanged':before==digest()}
(out/(a.phase+'.json')).write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k!='samples'}))
