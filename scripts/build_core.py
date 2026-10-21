"""Actual macOS/iOS core build gate. This does not produce an installable app/IPA."""
from pathlib import Path
import argparse,subprocess,platform,json,hashlib,os
from prepare_core import ROOT,prepare
def run(args,cwd=None):
 print('RUN',' '.join(map(str,args)),flush=True);subprocess.run(list(map(str,args)),cwd=cwd or ROOT,check=True)
def capture(args):return subprocess.check_output(list(map(str,args)),text=True).strip()
def build(sdk):
 if platform.system()!='Darwin':raise SystemExit('Needs a real macOS/Xcode host. Windows can run local_checks.py and prepare the source bundle.')
 source=prepare();folder=ROOT/'build'/sdk;folder.mkdir(parents=True,exist_ok=True)
 sdkroot=capture(['xcrun','--sdk',sdk,'--show-sdk-path']);arch='arm64';minimum='17.0' if sdk!='macosx' else '11.0';system='Darwin' if sdk=='macosx' else 'iOS'
 run(['cmake','-S',source,'-B',folder,'-DCMAKE_BUILD_TYPE=Release','-DCMAKE_POLICY_VERSION_MINIMUM=3.5','-DCMAKE_SYSTEM_NAME='+system,'-DCMAKE_OSX_SYSROOT='+sdkroot,'-DCMAKE_OSX_ARCHITECTURES='+arch,'-DCMAKE_OSX_DEPLOYMENT_TARGET='+minimum,'-DLEGEND_DISABLE_JIT=ON','-DLEGEND_STATIC_CORE=ON','-DBUILD_SHARED_LIBS=OFF','-DUSE_X11=OFF','-DCMAKE_EXPORT_COMPILE_COMMANDS=ON'])
 run(['cmake','--build',folder,'--target','swanstation_libretro','--parallel','3'])
 commands=json.loads((folder/'compile_commands.json').read_text());compiled=[c for c in commands if c.get('file','').endswith(('.cpp','.cc','.c'))]
 for c in compiled:
  if any(name in Path(c['file']).name for name in ('cpu_recompiler_','jit_code_buffer')):raise RuntimeError('A JIT source was compiled: '+c['file'])
  flags=c.get('command',' '.join(c.get('arguments',[])))
  if '-DWITH_RECOMPILER' in flags or '-DWITH_MMAP_FASTMEM' in flags:raise RuntimeError('JIT/fastmem flags are present')
 archives=sorted(folder.rglob('*.a'));core=folder/'swanstation_libretro.a'
 if core not in archives:raise RuntimeError('Missing static libretro archive')
 combined=folder/'LegendSwanStation.a';archives=[a for a in archives if a!=combined]
 # Standard static archive; final app links libretro symbols directly, no dlopen.
 run(['xcrun','--sdk',sdk,'libtool','-static','-o',combined,*archives])
 machine=capture(['xcrun','lipo','-archs',combined]);assert machine=='arm64',machine
 symbols=capture(['xcrun','nm','-gU',combined]);required=['retro_init','retro_deinit','retro_run','retro_load_game','retro_get_system_info','retro_set_environment','retro_set_video_refresh','retro_set_input_state','retro_serialize','retro_unserialize','retro_get_memory_data']
 for symbol in required:
  if '_'+symbol not in symbols:raise RuntimeError('Missing libretro export: '+symbol)
 report=dict(sdk=sdk,architecture=machine,minimum_os=minimum,core_commit=json.loads((ROOT/'sources.lock.json').read_text())['commit'],library=str(combined.relative_to(ROOT)),sha256=hashlib.sha256(combined.read_bytes()).hexdigest(),jit_sources_compiled=False,required_symbols_verified=True,installable_app=False,game_or_bios_tested=False)
 if sdk=='macosx':
  clang=capture(['xcrun','--find','clang++']);include=source/'dep/libretro-common/include';tests=ROOT/'tests'
  run([clang,'-std=c++17','-arch','arm64','-mmacosx-version-min=11.0','-I'+str(ROOT/'Sources/Core'),tests/'frontend_test.cpp','-o',folder/'frontend_test']);run([folder/'frontend_test'])
  run([clang,'-std=c++17','-arch','arm64','-mmacosx-version-min=11.0','-I'+str(include),tests/'core_probe.cpp',combined,'-framework','CoreFoundation','-lobjc','-o',folder/'core_probe']);run([folder/'core_probe',folder/'probe-data'])
  report['macos_api_probe_passed']=True;report['frontend_tests_passed']=True
 (folder/'build_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--sdk',choices=['macosx','iphoneos','iphonesimulator'],required=True);args=p.parse_args();build(args.sdk)
