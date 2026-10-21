"""Fetch a pinned upstream core and apply narrowly guarded, reproducible iOS changes."""
from pathlib import Path
import subprocess,json,hashlib,argparse
ROOT=Path(__file__).resolve().parents[1]
def run(*args):return subprocess.check_output(args,text=True).strip()
def digest(value):return hashlib.sha256(value).hexdigest()
def patched_files(pristine):
 files=dict(pristine)
 def replace(path,old,new):
  if files[path].count(old)!=1:raise RuntimeError('Expected exactly one upstream anchor: '+path+' '+old[:60])
  files[path]=files[path].replace(old,new)
 replace('CMakeLists.txt','project(swanstation C CXX)','''project(swanstation C CXX)
option(LEGEND_DISABLE_JIT "Build interpreter only, with no JIT executable memory" OFF)
option(LEGEND_STATIC_CORE "Build a static libretro archive" OFF)
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  if(NOT LEGEND_DISABLE_JIT OR NOT LEGEND_STATIC_CORE)
    message(FATAL_ERROR "Legend iOS requires interpreter-only/static core")
  endif()
  add_definitions(-DLEGEND_IOS=1)
endif()
# CMake path must match the Makefile's libretro ABI throughout the source tree.
add_definitions(-D__LIBRETRO__)
''')
 replace('src/core/CMakeLists.txt','if(${CPU_ARCH} STREQUAL "x64")','''if(LEGEND_DISABLE_JIT)
  message(STATUS "Legend: JIT and mmap fastmem are disabled")
elseif(${CPU_ARCH} STREQUAL "x64")''')
 replace('dep/CMakeLists.txt','if(${CPU_ARCH} STREQUAL "aarch32" OR ${CPU_ARCH} STREQUAL "aarch64")','if(NOT LEGEND_DISABLE_JIT AND (${CPU_ARCH} STREQUAL "aarch32" OR ${CPU_ARCH} STREQUAL "aarch64"))')
 replace('src/common/CMakeLists.txt','target_include_directories(common PRIVATE','''if(LEGEND_DISABLE_JIT)
  get_target_property(LEGEND_COMMON_SOURCES common SOURCES)
  list(REMOVE_ITEM LEGEND_COMMON_SOURCES jit_code_buffer.cpp jit_code_buffer.h)
  set_property(TARGET common PROPERTY SOURCES "${LEGEND_COMMON_SOURCES}")
endif()

target_include_directories(common PRIVATE''')
 replace('src/libretro/CMakeLists.txt','add_library(swanstation_libretro SHARED','''if(LEGEND_STATIC_CORE)
  set(LEGEND_CORE_TYPE STATIC)
else()
  set(LEGEND_CORE_TYPE SHARED)
endif()
add_library(swanstation_libretro ${LEGEND_CORE_TYPE}''')
 replace('src/libretro/CMakeLists.txt','set_target_properties(swanstation_libretro PROPERTIES PREFIX "")','set_target_properties(swanstation_libretro PROPERTIES PREFIX "" ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")')
 # shm_open is not a supported iOS sandbox allocation strategy. Keep mmap views,
 # but back the arena with an unlinked file inside this app's temporary directory.
 replace('src/common/memory_arena.cpp','#include "memory_arena.h"','#include "memory_arena.h"\n#include <cstdlib>\n#include <vector>')
 replace('src/common/memory_arena.cpp','''#if defined(_WIN32)
  const DWORD protect''','''#if defined(LEGEND_IOS)
  if(executable) return false;
  const char* temp = std::getenv("TMPDIR");
  if(!temp || !*temp) return false;
  std::string path(temp);
  if(path.back() != '/') path += '/';
  path += "legend-arena-XXXXXX";
  std::vector<char> filename(path.begin(), path.end()); filename.push_back(0);
  m_shmem_fd = mkstemp(filename.data());
  if(m_shmem_fd < 0) return false;
  unlink(filename.data());
  if(ftruncate(m_shmem_fd, static_cast<off_t>(size)) != 0) {
    close(m_shmem_fd); m_shmem_fd = -1; return false;
  }
  m_size = size; m_writable = writable; m_executable = false;
  return true;
#elif defined(_WIN32)
  const DWORD protect''')
 return files
PATCH_PATHS=['CMakeLists.txt','src/core/CMakeLists.txt','dep/CMakeLists.txt','src/common/CMakeLists.txt','src/libretro/CMakeLists.txt','src/common/memory_arena.cpp']
def prepare(source=None):
 lock=json.loads((ROOT/'sources.lock.json').read_text());source=Path(source or ROOT/'vendor/swanstation')
 if not source.exists():
  source.parent.mkdir(parents=True,exist_ok=True)
  subprocess.run(['git','clone','--filter=blob:none','--no-checkout',lock['repository'],str(source)],check=True)
  subprocess.run(['git','-C',str(source),'checkout','--detach',lock['commit']],check=True)
 if run('git','-C',str(source),'rev-parse','HEAD')!=lock['commit']:raise RuntimeError('Unexpected core commit; refusing to overwrite it')
 pristine={p:subprocess.check_output(['git','-C',str(source),'show',lock['commit']+':'+p]).decode('utf-8').replace('\r\n','\n') for p in PATCH_PATHS}
 patched=patched_files(pristine)
 # Validate every input before modifying any file, preserving unknown user changes.
 for p in PATCH_PATHS:
  existing=(source/p).read_text(encoding='utf-8')
  if existing not in (pristine[p],patched[p]):raise RuntimeError('Unrecognized local changes; preserved: '+p)
 report=dict(commit=lock['commit'],profile=lock['patch_profile'],files=[])
 for p in PATCH_PATHS:
  (source/p).write_text(patched[p],encoding='utf-8',newline='\n')
  report['files'].append(dict(path=p,upstream_sha256=digest(pristine[p].encode()),patched_sha256=digest(patched[p].encode())))
 (ROOT/'build').mkdir(exist_ok=True)
 (ROOT/'build/core_patch_report.json').write_text(json.dumps(report,indent=2));print('Prepared pinned interpreter-only core:',lock['commit'])
 return source
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path);args=parser.parse_args();prepare(args.source)
