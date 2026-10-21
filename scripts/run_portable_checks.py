"""Compile/run local portable frontend checks, with an optional private ISO oracle."""
from pathlib import Path
import argparse,json,os,subprocess,platform
ROOT=Path(__file__).resolve().parents[1]
def main(iso=None,fixture=None):
 zig=ROOT/'toolchain/zig/ziglang/zig.exe'
 if not zig.exists():raise SystemExit('Local Zig compiler is not installed; use the macOS build gate instead.')
 env=dict(os.environ,ZIG_GLOBAL_CACHE_DIR=str(ROOT/'build/zig-cache'));results=[]
 tests=[('frontend_test',[]),('audio_test',[]),('compatibility_test',[]),('geometry_test',[])]
 if iso and fixture:tests.append(('parity_test',['Sources/Core/GameData.cpp','Sources/Core/FusionAdvisor.cpp']))
 for name,sources in tests:
  output=ROOT/'build'/(name+'.exe');args=[str(zig),'c++','-std=c++17','-O2','-I',str(ROOT/'Sources/Core'),*[str(ROOT/s) for s in sources],str(ROOT/'tests'/(name+'.cpp')),'-o',str(output)]
  subprocess.run(args,env=env,check=True)
  run=[str(output)]+([iso,fixture] if name=='parity_test' else [])
  result=subprocess.run(run,text=True,capture_output=True,check=True);print(result.stdout.strip(),flush=True);results.append({'test':name,'passed':True,'output':result.stdout.strip()})
 report={'passed':True,'platform':platform.system(),'tests':results,'private_iso_or_ram_in_bundle':False,'apple_sdk_build_executed':False,'iphone_runtime_tested':False}
 (ROOT/'build/parity_check_report.json').write_text(json.dumps(report,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--iso');p.add_argument('--fixture');a=p.parse_args();main(a.iso,a.fixture)
