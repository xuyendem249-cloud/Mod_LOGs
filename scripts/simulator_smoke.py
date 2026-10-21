"""Launch the unsigned/ad-hoc simulator build. No BIOS/game is imported."""
import json,os,subprocess,time
from build_core import ROOT,run,capture

def main():
 devices=json.loads(capture(['xcrun','simctl','list','devices','available','-j']))['devices']
 choices=[d for runtime,items in devices.items() if 'iOS' in runtime for d in items if d.get('isAvailable') and 'iPhone' in d['name']]
 if not choices:raise RuntimeError('No available iPhone simulator runtime on this runner')
 template=choices[0];runtime=next(k for k,v in devices.items() if template in v)
 types=json.loads(capture(['xcrun','simctl','list','devicetypes','-j']))['devicetypes']
 kind=next(d['identifier'] for d in types if d['name']==template['name'])
 device=capture(['xcrun','simctl','create','Legend Step2 Smoke',kind,runtime])
 try:
  run(['xcrun','simctl','boot',device]);run(['xcrun','simctl','bootstatus',device,'-b'])
  run(['xcrun','simctl','install',device,ROOT/'build/iphonesimulator/Legend.app'])
  env=dict(os.environ,SIMCTL_CHILD_LEGEND_SMOKE='1')
  subprocess.run(['xcrun','simctl','launch',device,'vn.anhchugia35.legend'],env=env,check=True)
  from pathlib import Path
  data=Path(capture(['xcrun','simctl','get_app_container',device,'vn.anhchugia35.legend','data']))
  marker=data/'Documents/Legend/simulator_smoke.json';deadline=time.monotonic()+25
  while not marker.exists() and time.monotonic()<deadline:time.sleep(.5)
  report=json.loads(marker.read_text());assert report['app_launched'] and report['all_14_buttons_inside_view'] and report['approved_background_loaded'],report
  run(['xcrun','simctl','io',device,'screenshot',ROOT/'build/iphonesimulator/background-preview.png'])
  (ROOT/'build/iphonesimulator/simulator_smoke_report.json').write_text(json.dumps(report,indent=2));print(report)
 finally:
  subprocess.run(['xcrun','simctl','shutdown',device],check=False);subprocess.run(['xcrun','simctl','delete',device],check=False)
if __name__=='__main__':main()
