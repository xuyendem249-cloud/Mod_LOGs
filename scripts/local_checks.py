"""Honest Windows/preflight checks. Never reports an Apple build as tested on Windows."""
from pathlib import Path
import ast,json,subprocess,sys,hashlib
from prepare_core import ROOT,PATCH_PATHS,patched_files
def main():
 lock=json.loads((ROOT/'sources.lock.json').read_text());source=ROOT/'vendor/swanstation'
 sha=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip();assert sha==lock['commit']
 pristine={p:subprocess.check_output(['git','-C',str(source),'show',sha+':'+p]).decode().replace('\r\n','\n') for p in PATCH_PATHS}
 expected=patched_files(pristine)
 for path,value in expected.items():assert (source/path).read_text(encoding='utf-8')==value,path
 broken=dict(pristine);broken['src/core/CMakeLists.txt']=broken['src/core/CMakeLists.txt'].replace('if(${CPU_ARCH} STREQUAL "x64")','if(UNKNOWN_ARCH)')
 try:patched_files(broken)
 except RuntimeError:pass
 else:raise AssertionError('Patch must refuse an unknown source layout')
 for path in (ROOT/'scripts').glob('*.py'):ast.parse(path.read_text(encoding='utf-8'),filename=str(path))
 workflow=(ROOT/'.github/workflows/core-build.yml').read_text();assert 'workflow_dispatch:' in workflow and '\n  push:' not in workflow and 'secrets.' not in workflow
 assert 'sdk: [macosx, iphoneos]' in workflow
 cpp_syntax=False
 # Reuse an existing compiler only for portable C++ syntax; this is NOT an iOS SDK.
 compilers=list((ROOT.parent/'legend_android/toolchain/ndk').glob('android-ndk-*/toolchains/llvm/prebuilt/windows-x86_64/bin/clang++.exe'))
 if sys.platform=='win32' and compilers:
  for name,include in [('frontend_test.cpp',ROOT/'Sources/Core'),('core_probe.cpp',source/'dep/libretro-common/include')]:
   subprocess.run([str(compilers[0]),'--target=aarch64-linux-android24','-std=c++17','-Wall','-Wextra','-Werror','-fsyntax-only','-I'+str(include),str(ROOT/'tests'/name)],check=True)
  cpp_syntax=True
 report=dict(passed=True,core_commit=sha,guarded_patch_files=len(expected),unknown_upstream_rejected=True,python_syntax_checked=True,manual_cloud_workflow_prepared=True,portable_cpp_arm64_syntax_checked=cpp_syntax,apple_sdk_build_executed=False,frontend_runtime_executed=False,iphone_runtime_tested=False,ipa_available=False,testflight_available=False)
 (ROOT/'build/local_check_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
