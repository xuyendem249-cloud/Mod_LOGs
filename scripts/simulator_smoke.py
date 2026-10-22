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
  from pathlib import Path
  data=Path(capture(['xcrun','simctl','get_app_container',device,'vn.anhchugia35.legend','data']))
  orientations={}
  for orientation in ('portrait','landscape'):
   env=dict(os.environ,SIMCTL_CHILD_LEGEND_SMOKE='1',SIMCTL_CHILD_LEGEND_SMOKE_ORIENTATION=orientation)
   subprocess.run(['xcrun','simctl','launch',device,'vn.anhchugia35.legend'],env=env,check=True)
   marker=data/('Documents/Legend/simulator_smoke-'+orientation+'.json');deadline=time.monotonic()+30
   while not marker.exists() and time.monotonic()<deadline:time.sleep(.5)
   current=json.loads(marker.read_text())
   for field in ('app_launched','all_14_buttons_inside_view','approved_background_loaded','orientation_matches','logo_in_toolbar','speed_text_sync','speed_button_visibility','speed_button_inside_safe_area','landscape_game_fills_height','auto_ring_stops'):assert current[field],(orientation,field,current)
   run(['xcrun','simctl','io',device,'screenshot',ROOT/('build/iphonesimulator/background-'+orientation+'.png')])
   orientations[orientation]=current
   subprocess.run(['xcrun','simctl','terminate',device,'vn.anhchugia35.legend'],check=True)
  report=dict(orientations['portrait'],orientations=orientations)
  (ROOT/'build/iphonesimulator/simulator_smoke_report.json').write_text(json.dumps(report,indent=2));print(report)
 finally:
  subprocess.run(['xcrun','simctl','shutdown',device],check=False);subprocess.run(['xcrun','simctl','delete',device],check=False)
if __name__=='__main__':main()
