"""Compile actual iOS compatibility C++ and replay PC regressions locally."""
from pathlib import Path
import os,subprocess
from native_effect_replay import replay
ROOT=Path(__file__).resolve().parents[1]
def main():
 env=dict(os.environ,ZIG_GLOBAL_CACHE_DIR=str(ROOT/'build/zig-cache'))
 dll=ROOT/'build/compatibility_bridge.dll'
 subprocess.run([str(ROOT/'toolchain/zig/ziglang/zig.exe'),'c++','-std=c++17','-O2','-shared','-I'+str(ROOT/'Sources/Core'),str(ROOT/'tests/compatibility_bridge.cpp'),'-o',str(dll)],env=env,check=True)
 replay(dll,ROOT/'build/card-effects')
if __name__=='__main__':main()
