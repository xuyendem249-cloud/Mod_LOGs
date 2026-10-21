"""Replay existing PS1-delay-aware tests using the actual iOS C++ patcher.
Private ISO/RAM stay local; reports go only under legend_ios/build.
"""
from pathlib import Path
import ctypes as C,sys,importlib,json,hashlib,os
ROOT=Path(__file__).resolve().parents[1]
def main():
 sys.dont_write_bytecode=True
 sys.path.insert(0,str(ROOT.parent/'swanstation_v82_probe'))
 lib=C.CDLL(str(ROOT/'build/compatibility_bridge.dll'))
 lib.legend_apply.argtypes=[C.c_void_p,C.c_size_t,C.c_char_p];lib.legend_apply.restype=C.c_int
 import player_compat
 from player_trap_compat import PATCHES
 class IOSCompatibility:
  def __init__(self,digest):self.digest=digest;self.conflict=False;self.applied=set()
  def apply(self,ptr,size):
   self.conflict=bool(lib.legend_apply(ptr,size,self.digest.encode()))
   if self.digest in player_compat.KNOWN and all(C.string_at(ptr+at,len(new))==new for at,old,new in PATCHES):self.applied.add('trap_load_delays')
 player_compat.ModCompatibility=IOSCompatibility
 output=ROOT/'build/native-effects';output.mkdir(parents=True,exist_ok=True)
 for name in ['test_player_traps','test_summon_destruction']:
  test=importlib.import_module(name);test.HERE=output;test.main()
 report={'passed':True,'patcher':'Sources/Core/ModCompatibility.hpp actual compiled C++','android_compat_sha256':hashlib.sha256((ROOT.parent/'legend_android/assets/compat.json').read_bytes()).hexdigest(),'scope':'Bounded native PS1 load/branch-delay replay; not an iPhone animation or full-game test.'}
 (output/'ios_effects_report.json').write_text(json.dumps(report,indent=2))
if __name__=='__main__':main()
