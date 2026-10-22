"""Replay the iOS production C++ Auto through the same isolated native oracle as APK."""
from pathlib import Path
import json,os,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
def main():
 zig=ROOT/'toolchain/zig/ziglang/zig.exe';env=dict(os.environ,ZIG_GLOBAL_CACHE_DIR=str(ROOT/'build/zig-cache'))
 replay=ROOT/'build/auto_replay.exe'
 subprocess.run([str(zig),'c++','-std=c++17','-O2','-I'+str(ROOT/'Sources/Core'),str(ROOT/'tests/auto_replay.cpp'),str(ROOT/'Sources/Core/GameData.cpp'),str(ROOT/'Sources/Core/FusionAdvisor.cpp'),'-o',str(replay)],env=env,check=True)
 env.update(LEGEND_AUTO_REPLAY_EXE=str(replay),LEGEND_AUTO_REPORT_ROOT=str(ROOT/'build/auto'))
 reports=[]
 for scenario in ['duel','trap','equip','fallback']:
  log=ROOT/'build'/('auto-'+scenario+'.log')
  with log.open('w',encoding='utf-8') as stream:subprocess.run([sys.executable,'-u','-B',str(ROOT.parent/'legend_android/test_auto_core.py'),scenario],env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)
  folder='auto-core'+('' if scenario=='duel' else '-'+scenario)
  report=json.loads((ROOT/'build/auto'/folder/'report.json').read_text());assert report['passed']
  trace=json.loads((ROOT/'build/auto'/folder/'trace.json').read_text(encoding='utf-8'))
  oracle=json.loads((ROOT.parent/'legend_android/build'/folder/'trace.json').read_text(encoding='utf-8'))
  assert trace==oracle,'iOS/Android Auto trace differs: '+scenario
  reports.append(report);print('PASS iOS native Auto '+scenario+'; Android trace identical',flush=True)
 result=dict(passed=True,implementation='Production iOS C++ Auto',native_scenarios=reports,android_traces_identical=True,live_app_untouched=True,iphone_runtime_tested=False)
 (ROOT/'build/auto_test_report.json').write_text(json.dumps(result,indent=2));print('All Auto native scenarios passed.')
if __name__=='__main__':main()
